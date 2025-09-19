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
const prisma_service_1 = require("../common/prisma.service");
const push_service_1 = require("./push.service");
const FOLLOWER_USER_SELECT = {
    id: true,
    firstName: true,
    lastName: true,
    avatarUrl: true,
};
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
    async notifyFollowersAboutNewEvent(eventId) {
        var _a, _b;
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
        if (!followers.length)
            return;
        const ownerName = `${(_a = event.owner.firstName) !== null && _a !== void 0 ? _a : ''} ${(_b = event.owner.lastName) !== null && _b !== void 0 ? _b : ''}`.trim() || 'организатор';
        const message = `Новый ивент от ${ownerName}: ${event.title}`;
        const data = followers.map((f) => ({
            userId: f.followerId,
            type: client_1.NotificationType.NEW_EVENT,
            eventId: event.id,
            message,
        }));
        await this.prisma.notification.createMany({ data, skipDuplicates: true });
        await Promise.all(followers.map(async (f) => {
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
        }));
    }
    async sendEventReminders() {
        var _a;
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
        const notifications = [];
        const eventsToMark = [];
        for (const event of events) {
            const followerIds = (_a = followersByOwner.get(event.ownerId)) !== null && _a !== void 0 ? _a : [];
            if (!followerIds.length)
                continue;
            const message = `Событие "${event.title}" скоро начнётся`;
            followerIds.forEach((userId) => {
                notifications.push({
                    userId,
                    type: client_1.NotificationType.EVENT_REMINDER,
                    eventId: event.id,
                    message,
                });
            });
            eventsToMark.push(event.id);
        }
        if (notifications.length) {
            await this.prisma.notification.createMany({ data: notifications, skipDuplicates: true });
            const userIds = notifications.map((n) => n.userId);
            await Promise.all(Array.from(new Set(userIds)).map(async (userId) => {
                const unread = await this.unreadCount(userId);
                const firstNotification = notifications.find((n) => n.userId === userId);
                if (!(firstNotification === null || firstNotification === void 0 ? void 0 : firstNotification.eventId))
                    return;
                const event = events.find((e) => e.id === firstNotification.eventId);
                const title = event ? `Скоро начнётся ${event.title}` : 'Событие скоро начнётся';
                await this.push.sendToUser(userId, {
                    title,
                    body: 'Не забудьте подготовиться!',
                    badge: unread,
                    data: {
                        type: 'EVENT_REMINDER',
                        eventId: firstNotification.eventId,
                    },
                });
            }));
        }
        if (eventsToMark.length) {
            await this.prisma.event.updateMany({ where: { id: { in: eventsToMark } }, data: { reminderSentAt: now } });
        }
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
};
exports.NotificationsService = NotificationsService;
NotificationsService.REMINDER_WINDOW_MS = 24 * 60 * 60 * 1000;
exports.NotificationsService = NotificationsService = NotificationsService_1 = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService, push_service_1.PushService])
], NotificationsService);
//# sourceMappingURL=notifications.service.js.map