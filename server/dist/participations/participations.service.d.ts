import { PrismaService } from '../common/prisma.service';
import { RateParticipantDto } from './dto';
import { NotificationsService } from '../notifications/notifications.service';
export declare class ParticipationsService {
    private prisma;
    private notifications;
    constructor(prisma: PrismaService, notifications: NotificationsService);
    private getEventOrThrow;
    request(eventId: string, userId: string): Promise<{
        autoconfirmed: boolean;
        availableSpots: number | null;
        user: {
            id: string;
            email: string;
            firstName: string;
            lastName: string;
            avatarUrl: string | null;
        };
        id: string;
        createdAt: Date;
        userId: string;
        eventId: string;
        status: string;
    }>;
    listForOwner(eventId: string, ownerId: string): Promise<{
        participantReview: {
            id: string;
            createdAt: Date;
            targetUserId: string | null;
            rating: number;
            text: string | null;
        } | null;
        user: {
            id: string;
            email: string;
            firstName: string;
            lastName: string;
            avatarUrl: string | null;
        };
        id: string;
        createdAt: Date;
        userId: string;
        eventId: string;
        status: string;
    }[]>;
    changeStatus(eventId: string, ownerId: string, participationId: string, status: 'approved' | 'rejected' | 'cancelled'): Promise<{
        availableSpots: number | null;
        user: {
            id: string;
            email: string;
            firstName: string;
            lastName: string;
            avatarUrl: string | null;
        };
        id: string;
        createdAt: Date;
        userId: string;
        eventId: string;
        status: string;
    }>;
    getForUser(eventId: string, userId: string): Promise<{
        participantReview: {
            id: string;
            createdAt: Date;
            eventId: string;
            authorId: string;
            targetUserId: string | null;
            target: string;
            rating: number;
            text: string | null;
        } | null;
        availableSpots: number | null;
        id: string;
        createdAt: Date;
        userId: string;
        eventId: string;
        status: string;
    } | null>;
    cancel(eventId: string, userId: string): Promise<{
        availableSpots: number | null;
        user: {
            id: string;
            email: string;
            firstName: string;
            lastName: string;
            avatarUrl: string | null;
        };
        id: string;
        createdAt: Date;
        userId: string;
        eventId: string;
        status: string;
    }>;
    rateParticipant(eventId: string, ownerId: string, participationId: string, dto: RateParticipantDto): Promise<{
        event: {
            id: string;
            title: string;
            startAt: Date;
            endAt: Date;
        };
        author: {
            id: string;
            email: string;
            firstName: string;
            lastName: string;
            avatarUrl: string | null;
        };
    } & {
        id: string;
        createdAt: Date;
        eventId: string;
        authorId: string;
        targetUserId: string | null;
        target: string;
        rating: number;
        text: string | null;
    }>;
    private calculateRemainingSpots;
    private isSeatOccupyingStatus;
    private isAdult;
}
