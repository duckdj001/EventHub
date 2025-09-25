import { Prisma } from '@prisma/client';
import { PrismaService } from '../common/prisma.service';
import { PushService } from './push.service';
type PreferenceFlag = 'newEvent' | 'eventReminder' | 'participationApproved' | 'newFollower' | 'organizerContent' | 'followedStory' | 'eventUpdated';
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
        actor: {
            id: string;
            firstName: string;
            lastName: string;
            avatarUrl: string | null;
        } | null;
    } & {
        message: string;
        id: string;
        createdAt: Date;
        userId: string;
        type: import(".prisma/client").$Enums.NotificationType;
        eventId: string | null;
        actorId: string | null;
        contextId: string | null;
        meta: Prisma.JsonValue | null;
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
    getPreferences(userId: string): Promise<{
        createdAt: Date;
        updatedAt: Date;
        userId: string;
        newEvent: boolean;
        eventReminder: boolean;
        participationApproved: boolean;
        newFollower: boolean;
        organizerContent: boolean;
        followedStory: boolean;
        eventUpdated: boolean;
    }>;
    updatePreferences(userId: string, update: Partial<Record<PreferenceFlag, boolean>>): Promise<{
        createdAt: Date;
        updatedAt: Date;
        userId: string;
        newEvent: boolean;
        eventReminder: boolean;
        participationApproved: boolean;
        newFollower: boolean;
        organizerContent: boolean;
        followedStory: boolean;
        eventUpdated: boolean;
    }>;
    notifyFollowersAboutNewEvent(eventId: string): Promise<void>;
    sendEventReminders(): Promise<void>;
    notifyParticipationApproved(eventId: string, participantId: string, actorId?: string): Promise<void>;
    notifyNewFollower(followeeId: string, followerId: string): Promise<void>;
    notifyOrganizerStoryAdded(eventId: string, organizerId: string, authorId: string, storyId: string): Promise<void>;
    notifyOrganizerPhotoAdded(eventId: string, organizerId: string, authorId: string, photoId: string): Promise<void>;
    notifyFollowersStoryAdded(eventId: string, authorId: string, storyId: string): Promise<void>;
    notifyEventUpdated(eventId: string, actorId: string): Promise<void>;
    unreadCount(userId: string): Prisma.PrismaPromise<number>;
    registerDevice(userId: string, token: string, platform: string): Promise<void>;
    deregisterDevice(token: string): Promise<void>;
    private preferenceKey;
    private preferenceEnabled;
    private filterUsersByPreference;
    private saveNotification;
}
export {};
