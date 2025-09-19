import { PrismaService } from '../common/prisma.service';
import { MailService } from '../common/mail.service';
import { ConfirmEmailChangeDto, RequestEmailChangeDto, ReviewsFilterDto, UpdateProfileDto, UserEventsFilterDto } from './dto';
export declare class UsersService {
    private prisma;
    private mail;
    constructor(prisma: PrismaService, mail: MailService);
    me(userId: string): Promise<{
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
    profile(userId: string, opts?: {
        viewerId?: string;
        includePrivate?: boolean;
    }): Promise<{
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
    search(query: string, limit?: number): Promise<{
        id: string;
        email: string;
        firstName: string;
        lastName: string;
        avatarUrl: string | null;
    }[]>;
    updateProfile(userId: string, dto: UpdateProfileDto): Promise<{
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
    requestEmailChange(userId: string, dto: RequestEmailChangeDto): Promise<{
        ok: boolean;
    }>;
    confirmEmailChange(userId: string, dto: ConfirmEmailChangeDto): Promise<{
        ok: boolean;
    }>;
    reviews(userId: string, filter: ReviewsFilterDto): Promise<({
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
    eventsCreated(userId: string, filter: UserEventsFilterDto): Promise<{
        id: string;
        title: string;
        startAt: Date;
        endAt: Date;
        city: string;
        status: string;
        coverUrl: string | null;
    }[]>;
}
