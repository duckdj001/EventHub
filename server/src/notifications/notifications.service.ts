import { Injectable, Logger } from '@nestjs/common';
import {
  NotificationPreference,
  NotificationType,
  Prisma,
} from '@prisma/client';
import { PrismaClientKnownRequestError } from '@prisma/client/runtime/library';

import { PrismaService } from '../common/prisma.service';
import { PushService } from './push.service';

const FOLLOWER_USER_SELECT = {
  id: true,
  firstName: true,
  lastName: true,
  avatarUrl: true,
};

type PreferenceFlag =
  | 'newEvent'
  | 'eventReminder'
  | 'participationApproved'
  | 'newFollower'
  | 'organizerContent'
  | 'followedStory'
  | 'eventUpdated';

const DEFAULT_PREFERENCES: Record<PreferenceFlag, boolean> = {
  newEvent: true,
  eventReminder: true,
  participationApproved: true,
  newFollower: true,
  organizerContent: true,
  followedStory: true,
  eventUpdated: true,
};

const TYPE_TO_PREF: Record<NotificationType, PreferenceFlag | null> = {
  [NotificationType.NEW_EVENT]: 'newEvent',
  [NotificationType.EVENT_REMINDER]: 'eventReminder',
  [NotificationType.PARTICIPATION_APPROVED]: 'participationApproved',
  [NotificationType.NEW_FOLLOWER]: 'newFollower',
  [NotificationType.EVENT_STORY_ADDED]: 'organizerContent',
  [NotificationType.EVENT_PHOTO_ADDED]: 'organizerContent',
  [NotificationType.FOLLOWED_STORY_ADDED]: 'followedStory',
  [NotificationType.EVENT_UPDATED]: 'eventUpdated',
};

const SEAT_OCCUPYING_STATUSES = ['approved', 'attended'] as const;

function formatUserName(user?: { firstName?: string | null; lastName?: string | null }): string {
  if (!user) return '';
  return `${user.firstName ?? ''} ${user.lastName ?? ''}`.trim();
}

type CreateNotificationInput = {
  userId: string;
  type: NotificationType;
  message: string;
  eventId?: string;
  actorId?: string;
  contextId?: string;
  meta?: Prisma.InputJsonValue | null;
};

@Injectable()
export class NotificationsService {
  private readonly logger = new Logger(NotificationsService.name);
  private static readonly REMINDER_WINDOW_MS = 24 * 60 * 60 * 1000; // 24 часа

  constructor(private readonly prisma: PrismaService, private readonly push: PushService) {}

  listForUser(userId: string) {
    return this.prisma.notification.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: 100,
      include: {
        event: {
          select: {
            id: true,
            title: true,
            startAt: true,
            coverUrl: true,
            owner: { select: FOLLOWER_USER_SELECT },
          },
        },
        actor: { select: FOLLOWER_USER_SELECT },
      },
    });
  }

  async markRead(userId: string, notificationId: string) {
    await this.prisma.notification.updateMany({
      where: { id: notificationId, userId },
      data: { read: true },
    });
    const unread = await this.unreadCount(userId);
    return { ok: true, unread };
  }

  async markAllRead(userId: string) {
    await this.prisma.notification.updateMany({ where: { userId, read: false }, data: { read: true } });
    const unread = await this.unreadCount(userId);
    return { ok: true, unread };
  }

  async getPreferences(userId: string) {
    return this.prisma.notificationPreference.upsert({
      where: { userId },
      update: {},
      create: { userId },
    });
  }

  async updatePreferences(userId: string, update: Partial<Record<PreferenceFlag, boolean>>) {
    const data: Partial<Record<PreferenceFlag, boolean>> = {};
    (Object.keys(DEFAULT_PREFERENCES) as PreferenceFlag[]).forEach((key) => {
      if (update[key] != null) {
        data[key] = update[key] ?? DEFAULT_PREFERENCES[key];
      }
    });

    return this.prisma.notificationPreference.upsert({
      where: { userId },
      update: data,
      create: {
        userId,
        ...DEFAULT_PREFERENCES,
        ...data,
      },
    });
  }

  async notifyFollowersAboutNewEvent(eventId: string) {
    const event = await this.prisma.event.findUnique({
      where: { id: eventId },
      select: {
        id: true,
        title: true,
        startAt: true,
        ownerId: true,
        owner: { select: FOLLOWER_USER_SELECT },
      },
    });
    if (!event) {
      this.logger.warn(`Event ${eventId} not found for notification`);
      return;
    }

    const followers = await this.prisma.follow.findMany({
      where: { followeeId: event.ownerId },
      select: { followerId: true },
    });
    const followerIds = followers.map((f) => f.followerId);
    const recipients = await this.filterUsersByPreference(followerIds, NotificationType.NEW_EVENT);
    if (!recipients.length) return;

    const ownerName = formatUserName(event.owner) || 'организатор';
    const message = `Новый ивент от ${ownerName}: ${event.title}`;

    await Promise.all(
      recipients.map(async (userId) => {
        await this.saveNotification({
          userId,
          type: NotificationType.NEW_EVENT,
          eventId: event.id,
          actorId: event.ownerId,
          message,
        });
        const unread = await this.unreadCount(userId);
        await this.push.sendToUser(userId, {
          title: 'Новый ивент',
          body: message,
          badge: unread,
          data: {
            type: NotificationType.NEW_EVENT,
            eventId: event.id,
          },
        });
      }),
    );
  }

  async sendEventReminders() {
    const now = new Date();
    const windowEnd = new Date(now.getTime() + NotificationsService.REMINDER_WINDOW_MS);

    const events = await this.prisma.event.findMany({
      where: {
        status: 'published',
        reminderSentAt: null,
        startAt: { gt: now, lte: windowEnd },
      },
      select: {
        id: true,
        title: true,
        startAt: true,
        ownerId: true,
        owner: { select: FOLLOWER_USER_SELECT },
      },
    });
    if (!events.length) return;

    const ownerIds = Array.from(new Set(events.map((e) => e.ownerId)));
    const follows = await this.prisma.follow.findMany({
      where: { followeeId: { in: ownerIds } },
      select: { followeeId: true, followerId: true },
    });

    const followersByOwner = new Map<string, string[]>();
    follows.forEach((f) => {
      const list = followersByOwner.get(f.followeeId) ?? [];
      list.push(f.followerId);
      followersByOwner.set(f.followeeId, list);
    });

    const eventsToMark: string[] = [];

    await Promise.all(
      events.map(async (event) => {
        const followerIds = followersByOwner.get(event.ownerId) ?? [];
        const recipients = await this.filterUsersByPreference(
          followerIds,
          NotificationType.EVENT_REMINDER,
        );
        if (!recipients.length) return;

        const ownerName = formatUserName(event.owner) || 'организатор';
        const message = `Событие "${event.title}" скоро начнётся`;

        await Promise.all(
          recipients.map(async (userId) => {
            await this.saveNotification({
              userId,
              type: NotificationType.EVENT_REMINDER,
              eventId: event.id,
              actorId: event.ownerId,
              message,
            });
            const unread = await this.unreadCount(userId);
            await this.push.sendToUser(userId, {
              title: `Скоро начнётся ${event.title}`,
              body: 'Не забудьте подготовиться!',
              badge: unread,
              data: {
                type: NotificationType.EVENT_REMINDER,
                eventId: event.id,
              },
            });
          }),
        );

        eventsToMark.push(event.id);
      }),
    );

    if (eventsToMark.length) {
      await this.prisma.event.updateMany({
        where: { id: { in: eventsToMark } },
        data: { reminderSentAt: now },
      });
    }
  }

  async notifyParticipationApproved(eventId: string, participantId: string, actorId?: string) {
    const [recipient] = await this.filterUsersByPreference(
      [participantId],
      NotificationType.PARTICIPATION_APPROVED,
    );
    if (!recipient) return;

    const event = await this.prisma.event.findUnique({
      where: { id: eventId },
      select: {
        id: true,
        title: true,
        owner: { select: FOLLOWER_USER_SELECT },
      },
    });
    if (!event) return;

    let actorName = '';
    if (actorId) {
      if (actorId === event.owner?.id) {
        actorName = formatUserName(event.owner);
      } else {
        const actor = await this.prisma.user.findUnique({
          where: { id: actorId },
          select: FOLLOWER_USER_SELECT,
        });
        actorName = formatUserName(actor ?? undefined);
      }
    }

    const message = actorName
      ? `${actorName} подтвердил(а) вашу заявку на "${event.title}"`
      : `Ваша заявка на "${event.title}" одобрена`;

    await this.saveNotification({
      userId: participantId,
      type: NotificationType.PARTICIPATION_APPROVED,
      eventId,
      actorId,
      contextId: 'participation-approved',
      message,
    });
    const unread = await this.unreadCount(participantId);
    await this.push.sendToUser(participantId, {
      title: 'Заявка одобрена',
      body: message,
      badge: unread,
      data: {
        type: NotificationType.PARTICIPATION_APPROVED,
        eventId,
      },
    });
  }

  async notifyNewFollower(followeeId: string, followerId: string) {
    const [recipient] = await this.filterUsersByPreference(
      [followeeId],
      NotificationType.NEW_FOLLOWER,
    );
    if (!recipient) return;

    const follower = await this.prisma.user.findUnique({
      where: { id: followerId },
      select: FOLLOWER_USER_SELECT,
    });
    if (!follower) return;

    const followerName = formatUserName(follower) || 'Пользователь';
    const message = `${followerName} подписался(лась) на вас`;

    await this.saveNotification({
      userId: followeeId,
      type: NotificationType.NEW_FOLLOWER,
      actorId: followerId,
      contextId: followerId,
      message,
      meta: { followerId },
    });

    const unread = await this.unreadCount(followeeId);
    await this.push.sendToUser(followeeId, {
      title: 'Новый подписчик',
      body: message,
      badge: unread,
      data: {
        type: NotificationType.NEW_FOLLOWER,
        actorId: followerId,
      },
    });
  }

  async notifyOrganizerStoryAdded(
    eventId: string,
    organizerId: string,
    authorId: string,
    storyId: string,
  ) {
    if (organizerId === authorId) return;
    const [recipient] = await this.filterUsersByPreference(
      [organizerId],
      NotificationType.EVENT_STORY_ADDED,
    );
    if (!recipient) return;

    const [event, author] = await Promise.all([
      this.prisma.event.findUnique({ where: { id: eventId }, select: { id: true, title: true } }),
      this.prisma.user.findUnique({ where: { id: authorId }, select: FOLLOWER_USER_SELECT }),
    ]);
    if (!event || !author) return;

    const authorName = formatUserName(author) || 'Участник';
    const message = `${authorName} добавил(а) историю в событие "${event.title}"`;

    await this.saveNotification({
      userId: organizerId,
      type: NotificationType.EVENT_STORY_ADDED,
      eventId,
      actorId: authorId,
      contextId: storyId,
      message,
      meta: { storyId },
    });

    const unread = await this.unreadCount(organizerId);
    await this.push.sendToUser(organizerId, {
      title: 'Новая история',
      body: message,
      badge: unread,
      data: {
        type: NotificationType.EVENT_STORY_ADDED,
        eventId,
        storyId,
      },
    });
  }

  async notifyOrganizerPhotoAdded(
    eventId: string,
    organizerId: string,
    authorId: string,
    photoId: string,
  ) {
    if (organizerId === authorId) return;
    const [recipient] = await this.filterUsersByPreference(
      [organizerId],
      NotificationType.EVENT_PHOTO_ADDED,
    );
    if (!recipient) return;

    const [event, author] = await Promise.all([
      this.prisma.event.findUnique({ where: { id: eventId }, select: { id: true, title: true } }),
      this.prisma.user.findUnique({ where: { id: authorId }, select: FOLLOWER_USER_SELECT }),
    ]);
    if (!event || !author) return;

    const authorName = formatUserName(author) || 'Участник';
    const message = `${authorName} добавил(а) фото к событию "${event.title}"`;

    await this.saveNotification({
      userId: organizerId,
      type: NotificationType.EVENT_PHOTO_ADDED,
      eventId,
      actorId: authorId,
      contextId: photoId,
      message,
      meta: { photoId },
    });

    const unread = await this.unreadCount(organizerId);
    await this.push.sendToUser(organizerId, {
      title: 'Новое фото',
      body: message,
      badge: unread,
      data: {
        type: NotificationType.EVENT_PHOTO_ADDED,
        eventId,
        photoId,
      },
    });
  }

  async notifyFollowersStoryAdded(eventId: string, authorId: string, storyId: string) {
    const event = await this.prisma.event.findUnique({
      where: { id: eventId },
      select: { id: true, title: true, startAt: true, endAt: true },
    });
    if (!event) return;
    const now = new Date();
    if (event.startAt.getTime() > now.getTime()) return;
    if (event.endAt && event.endAt.getTime() < now.getTime()) return;

    const followers = await this.prisma.follow.findMany({
      where: { followeeId: authorId },
      select: { followerId: true },
    });
    const followerIds = followers.map((f) => f.followerId).filter((id) => id !== authorId);
    const recipients = await this.filterUsersByPreference(
      followerIds,
      NotificationType.FOLLOWED_STORY_ADDED,
    );
    if (!recipients.length) return;

    const author = await this.prisma.user.findUnique({
      where: { id: authorId },
      select: FOLLOWER_USER_SELECT,
    });
    if (!author) return;

    const authorName = formatUserName(author) || 'Знакомый';
    const message = `${authorName} поделился(лась) новой историей в событии "${event.title}"`;

    await Promise.all(
      recipients.map(async (userId) => {
        await this.saveNotification({
          userId,
          type: NotificationType.FOLLOWED_STORY_ADDED,
          eventId,
          actorId: authorId,
          contextId: storyId,
          message,
          meta: { storyId },
        });
        const unread = await this.unreadCount(userId);
        await this.push.sendToUser(userId, {
          title: 'Новая история у знакомого',
          body: message,
          badge: unread,
          data: {
            type: NotificationType.FOLLOWED_STORY_ADDED,
            eventId,
            storyId,
          },
        });
      }),
    );
  }

  async notifyEventUpdated(eventId: string, actorId: string) {
    const event = await this.prisma.event.findUnique({
      where: { id: eventId },
      select: {
        id: true,
        title: true,
        owner: { select: FOLLOWER_USER_SELECT },
        parts: {
          where: { status: { in: Array.from(SEAT_OCCUPYING_STATUSES) } },
          select: { userId: true },
        },
      },
    });
    if (!event) return;

    const participants = event.parts.map((p) => p.userId).filter((id) => id !== actorId);
    const recipients = await this.filterUsersByPreference(
      participants,
      NotificationType.EVENT_UPDATED,
    );
    if (!recipients.length) return;

    const ownerName = formatUserName(event.owner) || 'Организатор';
    const message = `${ownerName} обновил(а) событие "${event.title}"`;

    await Promise.all(
      recipients.map(async (userId) => {
        await this.saveNotification({
          userId,
          type: NotificationType.EVENT_UPDATED,
          eventId,
          actorId,
          message,
        });
        const unread = await this.unreadCount(userId);
        await this.push.sendToUser(userId, {
          title: 'Изменение события',
          body: message,
          badge: unread,
          data: {
            type: NotificationType.EVENT_UPDATED,
            eventId,
          },
        });
      }),
    );
  }

  unreadCount(userId: string) {
    return this.prisma.notification.count({ where: { userId, read: false } });
  }

  async registerDevice(userId: string, token: string, platform: string) {
    await this.push.registerDevice(userId, token, platform);
  }

  async deregisterDevice(token: string) {
    await this.push.deregisterDevice(token);
  }

  private preferenceKey(type: NotificationType): PreferenceFlag | null {
    return TYPE_TO_PREF[type] ?? null;
  }

  private preferenceEnabled(pref: NotificationPreference | null, type: NotificationType): boolean {
    const key = this.preferenceKey(type);
    if (!key) return true;
    if (!pref) return DEFAULT_PREFERENCES[key];
    return pref[key];
  }

  private async filterUsersByPreference(
    userIds: string[],
    type: NotificationType,
  ): Promise<string[]> {
    const uniqueIds = Array.from(new Set(userIds)).filter(Boolean);
    if (!uniqueIds.length) return [];

    const key = this.preferenceKey(type);
    if (!key) return uniqueIds;

    const prefs = await this.prisma.notificationPreference.findMany({
      where: { userId: { in: uniqueIds } },
    });
    const map = new Map<string, NotificationPreference>();
    prefs.forEach((pref) => map.set(pref.userId, pref));

    return uniqueIds.filter((id) => this.preferenceEnabled(map.get(id) ?? null, type));
  }

  private async saveNotification(input: CreateNotificationInput) {
    const data: Prisma.NotificationUncheckedCreateInput = {
      userId: input.userId,
      type: input.type,
      message: input.message,
      eventId: input.eventId,
      actorId: input.actorId,
      contextId: input.contextId,
    };
    if (input.meta !== undefined) {
      data.meta = input.meta ?? Prisma.JsonNull;
    }

    try {
      return await this.prisma.notification.create({ data });
    } catch (err) {
      if (err instanceof PrismaClientKnownRequestError && err.code === 'P2002') {
        const updateData: Prisma.NotificationUpdateManyMutationInput = {
          message: input.message,
          read: false,
          createdAt: new Date(),
        };
        if (input.meta !== undefined) {
          updateData.meta = input.meta ?? Prisma.JsonNull;
        }
        await this.prisma.notification.updateMany({
          where: {
            userId: input.userId,
            type: input.type,
            eventId: input.eventId,
            actorId: input.actorId,
            contextId: input.contextId,
          },
          data: updateData,
        });
        return this.prisma.notification.findFirst({
          where: {
            userId: input.userId,
            type: input.type,
            eventId: input.eventId,
            actorId: input.actorId,
            contextId: input.contextId,
          },
        });
      }

      this.logger.error(
        'Failed to persist notification',
        err instanceof Error ? err.stack : String(err),
      );
      return null;
    }
  }
}
