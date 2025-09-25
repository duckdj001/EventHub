"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
var NotificationsService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.NotificationsService = void 0;
const common_1 = require("@nestjs/common");
const client_1 = require("@prisma/client");
const library_1 = require("@prisma/client/runtime/library");
const prisma_service_1 = require("../common/prisma.service");
const push_service_1 = require("./push.service");
const FOLLOWER_USER_SELECT = {
    id: true,
    firstName: true,
    lastName: true,
    avatarUrl: true,
};
const DEFAULT_PREFERENCES = {
    newEvent: true,
    eventReminder: true,
    participationApproved: true,
    newFollower: true,
    organizerContent: true,
    followedStory: true,
    eventUpdated: true,
};
const TYPE_TO_PREF = {
    [client_1.NotificationType.NEW_EVENT]: 'newEvent',
    [client_1.NotificationType.EVENT_REMINDER]: 'eventReminder',
    [client_1.NotificationType.PARTICIPATION_APPROVED]: 'participationApproved',
    [client_1.NotificationType.NEW_FOLLOWER]: 'newFollower',
    [client_1.NotificationType.EVENT_STORY_ADDED]: 'organizerContent',
    [client_1.NotificationType.EVENT_PHOTO_ADDED]: 'organizerContent',
    [client_1.NotificationType.FOLLOWED_STORY_ADDED]: 'followedStory',
    [client_1.NotificationType.EVENT_UPDATED]: 'eventUpdated',
};
const SEAT_OCCUPYING_STATUSES = ['approved', 'attended'];
function formatUserName(user) {
    var _a, _b;
    if (!user)
        return '';
    return `${(_a = user.firstName) !== null && _a !== void 0 ? _a : ''} ${(_b = user.lastName) !== null && _b !== void 0 ? _b : ''}`.trim();
}
let NotificationsService = NotificationsService_1 = class NotificationsService {
    constructor(prisma, push) {
        this.prisma = prisma;
        this.push = push;
        this.logger = new common_1.Logger(NotificationsService_1.name);
    }
    listForUser(userId) {
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
    async markRead(userId, notificationId) {
        await this.prisma.notification.updateMany({
            where: { id: notificationId, userId },
            data: { read: true },
        });
        const unread = await this.unreadCount(userId);
        return { ok: true, unread };
    }
    async markAllRead(userId) {
        await this.prisma.notification.updateMany({ where: { userId, read: false }, data: { read: true } });
        const unread = await this.unreadCount(userId);
        return { ok: true, unread };
    }
    async getPreferences(userId) {
        return this.prisma.notificationPreference.upsert({
            where: { userId },
            update: {},
            create: { userId },
        });
    }
    async updatePreferences(userId, update) {
        const data = {};
        Object.keys(DEFAULT_PREFERENCES).forEach((key) => {
            var _a;
            if (update[key] != null) {
                data[key] = (_a = update[key]) !== null && _a !== void 0 ? _a : DEFAULT_PREFERENCES[key];
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
    async notifyFollowersAboutNewEvent(eventId) {
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
        const recipients = await this.filterUsersByPreference(followerIds, client_1.NotificationType.NEW_EVENT);
        if (!recipients.length)
            return;
        const ownerName = formatUserName(event.owner) || 'организатор';
        const message = `Новый ивент от ${ownerName}: ${event.title}`;
        await Promise.all(recipients.map(async (userId) => {
            await this.saveNotification({
                userId,
                type: client_1.NotificationType.NEW_EVENT,
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
                    type: client_1.NotificationType.NEW_EVENT,
                    eventId: event.id,
                },
            });
        }));
    }
    async sendEventReminders() {
        const now = new Date();
        const windowEnd = new Date(now.getTime() + NotificationsService_1.REMINDER_WINDOW_MS);
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
        if (!events.length)
            return;
        const ownerIds = Array.from(new Set(events.map((e) => e.ownerId)));
        const follows = await this.prisma.follow.findMany({
            where: { followeeId: { in: ownerIds } },
            select: { followeeId: true, followerId: true },
        });
        const followersByOwner = new Map();
        follows.forEach((f) => {
            var _a;
            const list = (_a = followersByOwner.get(f.followeeId)) !== null && _a !== void 0 ? _a : [];
            list.push(f.followerId);
            followersByOwner.set(f.followeeId, list);
        });
        const eventsToMark = [];
        await Promise.all(events.map(async (event) => {
            var _a;
            const followerIds = (_a = followersByOwner.get(event.ownerId)) !== null && _a !== void 0 ? _a : [];
            const recipients = await this.filterUsersByPreference(followerIds, client_1.NotificationType.EVENT_REMINDER);
            if (!recipients.length)
                return;
            const ownerName = formatUserName(event.owner) || 'организатор';
            const message = `Событие "${event.title}" скоро начнётся`;
            await Promise.all(recipients.map(async (userId) => {
                await this.saveNotification({
                    userId,
                    type: client_1.NotificationType.EVENT_REMINDER,
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
                        type: client_1.NotificationType.EVENT_REMINDER,
                        eventId: event.id,
                    },
                });
            }));
            eventsToMark.push(event.id);
        }));
        if (eventsToMark.length) {
            await this.prisma.event.updateMany({
                where: { id: { in: eventsToMark } },
                data: { reminderSentAt: now },
            });
        }
    }
    async notifyParticipationApproved(eventId, participantId, actorId) {
        var _a;
        const [recipient] = await this.filterUsersByPreference([participantId], client_1.NotificationType.PARTICIPATION_APPROVED);
        if (!recipient)
            return;
        const event = await this.prisma.event.findUnique({
            where: { id: eventId },
            select: {
                id: true,
                title: true,
                owner: { select: FOLLOWER_USER_SELECT },
            },
        });
        if (!event)
            return;
        let actorName = '';
        if (actorId) {
            if (actorId === ((_a = event.owner) === null || _a === void 0 ? void 0 : _a.id)) {
                actorName = formatUserName(event.owner);
            }
            else {
                const actor = await this.prisma.user.findUnique({
                    where: { id: actorId },
                    select: FOLLOWER_USER_SELECT,
                });
                actorName = formatUserName(actor !== null && actor !== void 0 ? actor : undefined);
            }
        }
        const message = actorName
            ? `${actorName} подтвердил(а) вашу заявку на "${event.title}"`
            : `Ваша заявка на "${event.title}" одобрена`;
        await this.saveNotification({
            userId: participantId,
            type: client_1.NotificationType.PARTICIPATION_APPROVED,
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
                type: client_1.NotificationType.PARTICIPATION_APPROVED,
                eventId,
            },
        });
    }
    async notifyNewFollower(followeeId, followerId) {
        const [recipient] = await this.filterUsersByPreference([followeeId], client_1.NotificationType.NEW_FOLLOWER);
        if (!recipient)
            return;
        const follower = await this.prisma.user.findUnique({
            where: { id: followerId },
            select: FOLLOWER_USER_SELECT,
        });
        if (!follower)
            return;
        const followerName = formatUserName(follower) || 'Пользователь';
        const message = `${followerName} подписался(лась) на вас`;
        await this.saveNotification({
            userId: followeeId,
            type: client_1.NotificationType.NEW_FOLLOWER,
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
                type: client_1.NotificationType.NEW_FOLLOWER,
                actorId: followerId,
            },
        });
    }
    async notifyOrganizerStoryAdded(eventId, organizerId, authorId, storyId) {
        if (organizerId === authorId)
            return;
        const [recipient] = await this.filterUsersByPreference([organizerId], client_1.NotificationType.EVENT_STORY_ADDED);
        if (!recipient)
            return;
        const [event, author] = await Promise.all([
            this.prisma.event.findUnique({ where: { id: eventId }, select: { id: true, title: true } }),
            this.prisma.user.findUnique({ where: { id: authorId }, select: FOLLOWER_USER_SELECT }),
        ]);
        if (!event || !author)
            return;
        const authorName = formatUserName(author) || 'Участник';
        const message = `${authorName} добавил(а) историю в событие "${event.title}"`;
        await this.saveNotification({
            userId: organizerId,
            type: client_1.NotificationType.EVENT_STORY_ADDED,
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
                type: client_1.NotificationType.EVENT_STORY_ADDED,
                eventId,
                storyId,
            },
        });
    }
    async notifyOrganizerPhotoAdded(eventId, organizerId, authorId, photoId) {
        if (organizerId === authorId)
            return;
        const [recipient] = await this.filterUsersByPreference([organizerId], client_1.NotificationType.EVENT_PHOTO_ADDED);
        if (!recipient)
            return;
        const [event, author] = await Promise.all([
            this.prisma.event.findUnique({ where: { id: eventId }, select: { id: true, title: true } }),
            this.prisma.user.findUnique({ where: { id: authorId }, select: FOLLOWER_USER_SELECT }),
        ]);
        if (!event || !author)
            return;
        const authorName = formatUserName(author) || 'Участник';
        const message = `${authorName} добавил(а) фото к событию "${event.title}"`;
        await this.saveNotification({
            userId: organizerId,
            type: client_1.NotificationType.EVENT_PHOTO_ADDED,
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
                type: client_1.NotificationType.EVENT_PHOTO_ADDED,
                eventId,
                photoId,
            },
        });
    }
    async notifyFollowersStoryAdded(eventId, authorId, storyId) {
        const event = await this.prisma.event.findUnique({
            where: { id: eventId },
            select: { id: true, title: true, startAt: true, endAt: true },
        });
        if (!event)
            return;
        const now = new Date();
        if (event.startAt.getTime() > now.getTime())
            return;
        if (event.endAt && event.endAt.getTime() < now.getTime())
            return;
        const followers = await this.prisma.follow.findMany({
            where: { followeeId: authorId },
            select: { followerId: true },
        });
        const followerIds = followers.map((f) => f.followerId).filter((id) => id !== authorId);
        const recipients = await this.filterUsersByPreference(followerIds, client_1.NotificationType.FOLLOWED_STORY_ADDED);
        if (!recipients.length)
            return;
        const author = await this.prisma.user.findUnique({
            where: { id: authorId },
            select: FOLLOWER_USER_SELECT,
        });
        if (!author)
            return;
        const authorName = formatUserName(author) || 'Знакомый';
        const message = `${authorName} поделился(лась) новой историей в событии "${event.title}"`;
        await Promise.all(recipients.map(async (userId) => {
            await this.saveNotification({
                userId,
                type: client_1.NotificationType.FOLLOWED_STORY_ADDED,
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
                    type: client_1.NotificationType.FOLLOWED_STORY_ADDED,
                    eventId,
                    storyId,
                },
            });
        }));
    }
    async notifyEventUpdated(eventId, actorId) {
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
        if (!event)
            return;
        const participants = event.parts.map((p) => p.userId).filter((id) => id !== actorId);
        const recipients = await this.filterUsersByPreference(participants, client_1.NotificationType.EVENT_UPDATED);
        if (!recipients.length)
            return;
        const ownerName = formatUserName(event.owner) || 'Организатор';
        const message = `${ownerName} обновил(а) событие "${event.title}"`;
        await Promise.all(recipients.map(async (userId) => {
            await this.saveNotification({
                userId,
                type: client_1.NotificationType.EVENT_UPDATED,
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
                    type: client_1.NotificationType.EVENT_UPDATED,
                    eventId,
                },
            });
        }));
    }
    unreadCount(userId) {
        return this.prisma.notification.count({ where: { userId, read: false } });
    }
    async registerDevice(userId, token, platform) {
        await this.push.registerDevice(userId, token, platform);
    }
    async deregisterDevice(token) {
        await this.push.deregisterDevice(token);
    }
    preferenceKey(type) {
        var _a;
        return (_a = TYPE_TO_PREF[type]) !== null && _a !== void 0 ? _a : null;
    }
    preferenceEnabled(pref, type) {
        const key = this.preferenceKey(type);
        if (!key)
            return true;
        if (!pref)
            return DEFAULT_PREFERENCES[key];
        return pref[key];
    }
    async filterUsersByPreference(userIds, type) {
        const uniqueIds = Array.from(new Set(userIds)).filter(Boolean);
        if (!uniqueIds.length)
            return [];
        const key = this.preferenceKey(type);
        if (!key)
            return uniqueIds;
        const prefs = await this.prisma.notificationPreference.findMany({
            where: { userId: { in: uniqueIds } },
        });
        const map = new Map();
        prefs.forEach((pref) => map.set(pref.userId, pref));
        return uniqueIds.filter((id) => { var _a; return this.preferenceEnabled((_a = map.get(id)) !== null && _a !== void 0 ? _a : null, type); });
    }
    async saveNotification(input) {
        var _a, _b;
        const data = {
            userId: input.userId,
            type: input.type,
            message: input.message,
            eventId: input.eventId,
            actorId: input.actorId,
            contextId: input.contextId,
        };
        if (input.meta !== undefined) {
            data.meta = (_a = input.meta) !== null && _a !== void 0 ? _a : client_1.Prisma.JsonNull;
        }
        try {
            return await this.prisma.notification.create({ data });
        }
        catch (err) {
            if (err instanceof library_1.PrismaClientKnownRequestError && err.code === 'P2002') {
                const updateData = {
                    message: input.message,
                    read: false,
                    createdAt: new Date(),
                };
                if (input.meta !== undefined) {
                    updateData.meta = (_b = input.meta) !== null && _b !== void 0 ? _b : client_1.Prisma.JsonNull;
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
            this.logger.error('Failed to persist notification', err instanceof Error ? err.stack : String(err));
            return null;
        }
    }
};
exports.NotificationsService = NotificationsService;
NotificationsService.REMINDER_WINDOW_MS = 24 * 60 * 60 * 1000;
exports.NotificationsService = NotificationsService = NotificationsService_1 = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService, push_service_1.PushService])
], NotificationsService);
//# sourceMappingURL=notifications.service.js.map