import { PrismaService } from '../common/prisma.service';
import { RateParticipantDto } from './dto';
export declare class ParticipationsService {
    private prisma;
    constructor(prisma: PrismaService);
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
        eventId: string;
        userId: string;
        status: string;
        createdAt: Date;
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
        eventId: string;
        userId: string;
        status: string;
        createdAt: Date;
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
        eventId: string;
        userId: string;
        status: string;
        createdAt: Date;
    }>;
    getForUser(eventId: string, userId: string): Promise<{
        participantReview: {
            id: string;
            eventId: string;
            createdAt: Date;
            authorId: string;
            targetUserId: string | null;
            target: string;
            rating: number;
            text: string | null;
        } | null;
        availableSpots: number | null;
        id: string;
        eventId: string;
        userId: string;
        status: string;
        createdAt: Date;
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
        eventId: string;
        userId: string;
        status: string;
        createdAt: Date;
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
        eventId: string;
        createdAt: Date;
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
