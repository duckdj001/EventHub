import { ParticipationsService } from './participations.service';
import { RateParticipantDto } from './dto';
export declare class ParticipationsController {
    private readonly participations;
    constructor(participations: ParticipationsService);
    request(eventId: string, req: any): Promise<{
        autoconfirmed: boolean;
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
        eventId: string;
        userId: string;
        status: string;
        createdAt: Date;
    }[]>;
    me(eventId: string, req: any): Promise<{
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
        id: string;
        eventId: string;
        userId: string;
        status: string;
        createdAt: Date;
    } | null>;
    cancel(eventId: string, req: any): Promise<{
        user: {
            id: string;
            email: string;
            firstName: string;
            lastName: string;
            avatarUrl: string | null;
        };
    } & {
        id: string;
        eventId: string;
        userId: string;
        status: string;
        createdAt: Date;
    }>;
    setStatus(eventId: string, participationId: string, status: 'approved' | 'rejected' | 'cancelled', req: any): Promise<{
        user: {
            id: string;
            email: string;
            firstName: string;
            lastName: string;
            avatarUrl: string | null;
        };
    } & {
        id: string;
        eventId: string;
        userId: string;
        status: string;
        createdAt: Date;
    }>;
    rate(eventId: string, participationId: string, dto: RateParticipantDto, req: any): Promise<{
        event: {
            id: string;
            title: string;
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
}
