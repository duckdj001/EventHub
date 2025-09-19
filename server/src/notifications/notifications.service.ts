import { Injectable, Logger } from '@nestjs/common';
import { NotificationType, Prisma } from '@prisma/client';
import { PrismaService } from '../common/prisma.service';
import { PushService } from './push.service';

const FOLLOWER_USER_SELECT = {
  id: true,
  firstName: true,
  lastName: true,
  avatarUrl: true,
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
    if (!followers.length) return;

    const ownerName = `${event.owner.firstName ?? ''} ${event.owner.lastName ?? ''}`.trim() || 'организатор';
    const message = `Новый ивент от ${ownerName}: ${event.title}`;

    const data: Prisma.NotificationCreateManyInput[] = followers.map((f) => ({
      userId: f.followerId,
      type: NotificationType.NEW_EVENT,
      eventId: event.id,
      message,
    }));

    await this.prisma.notification.createMany({ data, skipDuplicates: true });

    await Promise.all(
      followers.map(async (f) => {
        const unread = await this.unreadCount(f.followerId);
        await this.push.sendToUser(f.followerId, {
          title: 'Новый ивент',
          body: message,
          badge: unread,
          data: {
            type: 'NEW_EVENT',
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

    const notifications: Prisma.NotificationCreateManyInput[] = [];
    const eventsToMark: string[] = [];
    for (const event of events) {
      const followerIds = followersByOwner.get(event.ownerId) ?? [];
      if (!followerIds.length) continue;
      const message = `Событие "${event.title}" скоро начнётся`;
      followerIds.forEach((userId) => {
        notifications.push({
          userId,
          type: NotificationType.EVENT_REMINDER,
          eventId: event.id,
          message,
        });
      });
      eventsToMark.push(event.id);
    }

    if (notifications.length) {
      await this.prisma.notification.createMany({ data: notifications, skipDuplicates: true });

      const userIds = notifications.map((n) => n.userId);
      await Promise.all(
        Array.from(new Set(userIds)).map(async (userId) => {
          const unread = await this.unreadCount(userId);
          const firstNotification = notifications.find((n) => n.userId === userId);
          if (!firstNotification?.eventId) return;
          const event = events.find((e) => e.id === firstNotification.eventId);
          const title = event ? `Скоро начнётся ${event.title}` : 'Событие скоро начнётся';
          await this.push.sendToUser(userId, {
            title,
            body: 'Не забудьте подготовиться!',
            badge: unread,
            data: {
              type: 'EVENT_REMINDER',
              eventId: firstNotification.eventId!,
            },
          });
        }),
      );
    }

    if (eventsToMark.length) {
      await this.prisma.event.updateMany({ where: { id: { in: eventsToMark } }, data: { reminderSentAt: now } });
    }
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
}
