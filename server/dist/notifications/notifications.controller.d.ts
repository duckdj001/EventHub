import { NotificationsService } from './notifications.service';
import { DeregisterDeviceDto, RegisterDeviceDto } from './dto/register-device.dto';
import { UpdateNotificationPreferencesDto } from './dto/update-preferences.dto';
export declare class NotificationsController {
    private readonly notifications;
    constructor(notifications: NotificationsService);
    list(req: any): import(".prisma/client").Prisma.PrismaPromise<({
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
        meta: import("@prisma/client/runtime/library").JsonValue | null;
        read: boolean;
    })[]>;
    markAll(req: any): Promise<{
        ok: boolean;
        unread: number;
    }>;
    markOne(id: string, req: any): Promise<{
        ok: boolean;
        unread: number;
    }>;
    unreadCount(req: any): Promise<{
        count: number;
    }>;
    registerDevice(req: any, dto: RegisterDeviceDto): Promise<{
        ok: boolean;
    }>;
    deregisterDevice(dto: DeregisterDeviceDto): Promise<{
        ok: boolean;
    }>;
    getSettings(req: any): Promise<{
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
    updateSettings(req: any, dto: UpdateNotificationPreferencesDto): Promise<{
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
}
