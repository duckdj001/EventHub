import { UsersService } from './users.service';
import { ConfirmEmailChangeDto, RequestEmailChangeDto, ReviewsFilterDto, UpdateProfileDto, UserEventsFilterDto } from './dto';
export declare class UsersController {
    private readonly users;
    constructor(users: UsersService);
    me(req: any): Promise<{
        email: string | undefined;
        stats: {
            ratingAvg: number;
            ratingCount: number;
            ratingDistribution: Record<number, number>;
            eventsUpcoming: number;
            eventsPast: number;
            participantRatingAvg: number;
            participantRatingCount: number;
        };
        social: {
            followers: number;
            following: number;
            isFollowedByViewer: boolean;
        };
        id: string;
        pendingEmail: string | null;
        firstName: string;
        lastName: string;
        birthDate: Date;
        avatarUrl: string | null;
        createdAt: Date;
        profile: {
            firstName: string | null;
            lastName: string | null;
            birthDate: Date | null;
            avatarUrl: string | null;
            bio: string | null;
        } | null;
    }>;
    update(req: any, dto: UpdateProfileDto): Promise<{
        email: string | undefined;
        stats: {
            ratingAvg: number;
            ratingCount: number;
            ratingDistribution: Record<number, number>;
            eventsUpcoming: number;
            eventsPast: number;
            participantRatingAvg: number;
            participantRatingCount: number;
        };
        social: {
            followers: number;
            following: number;
            isFollowedByViewer: boolean;
        };
        id: string;
        pendingEmail: string | null;
        firstName: string;
        lastName: string;
        birthDate: Date;
        avatarUrl: string | null;
        createdAt: Date;
        profile: {
            firstName: string | null;
            lastName: string | null;
            birthDate: Date | null;
            avatarUrl: string | null;
            bio: string | null;
        } | null;
    }>;
    requestEmail(req: any, dto: RequestEmailChangeDto): Promise<{
        ok: boolean;
    }>;
    confirmEmail(req: any, dto: ConfirmEmailChangeDto): Promise<{
        ok: boolean;
    }>;
    publicProfile(id: string, req: any): Promise<{
        email: string | undefined;
        stats: {
            ratingAvg: number;
            ratingCount: number;
            ratingDistribution: Record<number, number>;
            eventsUpcoming: number;
            eventsPast: number;
            participantRatingAvg: number;
            participantRatingCount: number;
        };
        social: {
            followers: number;
            following: number;
            isFollowedByViewer: boolean;
        };
        id: string;
        pendingEmail: string | null;
        firstName: string;
        lastName: string;
        birthDate: Date;
        avatarUrl: string | null;
        createdAt: Date;
        profile: {
            firstName: string | null;
            lastName: string | null;
            birthDate: Date | null;
            avatarUrl: string | null;
            bio: string | null;
        } | null;
    }>;
    search(q?: string, limit?: string): Promise<{
        id: string;
        email: string;
        firstName: string;
        lastName: string;
        avatarUrl: string | null;
    }[]>;
    reviews(id: string, query: ReviewsFilterDto): Promise<({
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
        rating: number;
        target: string;
        eventId: string;
        authorId: string;
        targetUserId: string | null;
        text: string | null;
    })[]>;
    events(id: string, query: UserEventsFilterDto): Promise<{
        id: string;
        title: string;
        startAt: Date;
        endAt: Date;
        city: string;
        status: string;
        coverUrl: string | null;
    }[]>;
}
