import { Prisma } from '@prisma/client';
import { PrismaService } from '../common/prisma.service';
import { PushService } from './push.service';
export declare class NotificationsService {
    private readonly prisma;
    private readonly push;
    private readonly logger;
    private static readonly REMINDER_WINDOW_MS;
    constructor(prisma: PrismaService, push: PushService);
    listForUser(userId: string): Prisma.PrismaPromise<({
        event: {
            id: string;
            title: string;
            startAt: Date;
            coverUrl: string | null;
            owner: {
                id: string;
                firstName: string;
                lastName: string;
                avatarUrl: string | null;
            };
        } | null;
    } & {
        message: string;
        id: string;
        createdAt: Date;
        userId: string;
        type: import(".prisma/client").$Enums.NotificationType;
        eventId: string | null;
        read: boolean;
    })[]>;
    markRead(userId: string, notificationId: string): Promise<{
        ok: boolean;
        unread: number;
    }>;
    markAllRead(userId: string): Promise<{
        ok: boolean;
        unread: number;
    }>;
    notifyFollowersAboutNewEvent(eventId: string): Promise<void>;
    sendEventReminders(): Promise<void>;
    unreadCount(userId: string): Prisma.PrismaPromise<number>;
    registerDevice(userId: string, token: string, platform: string): Promise<void>;
    deregisterDevice(token: string): Promise<void>;
}
