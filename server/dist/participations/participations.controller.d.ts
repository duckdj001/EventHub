import { ParticipationsService } from './participations.service';
import { RateParticipantDto } from './dto';
export declare class ParticipationsController {
    private readonly participations;
    constructor(participations: ParticipationsService);
    request(eventId: string, req: any): Promise<{
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
    list(eventId: string, req: any): Promise<{
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
    me(eventId: string, req: any): Promise<{
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
    cancel(eventId: string, req: any): Promise<{
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
    setStatus(eventId: string, participationId: string, status: 'approved' | 'rejected' | 'cancelled', req: any): Promise<{
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
    rate(eventId: string, participationId: string, dto: RateParticipantDto, req: any): Promise<{
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
}
