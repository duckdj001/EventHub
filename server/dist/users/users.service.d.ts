import { PrismaService } from "../common/prisma.service";
import { MailService } from "../common/mail.service";
import { ConfirmEmailChangeDto, RequestEmailChangeDto, ReviewsFilterDto, UpdateProfileDto, UserEventsFilterDto } from "./dto";
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
        categories: {
            id: string;
            name: string;
        }[];
        mustChangePassword: boolean;
        profile: {
            firstName: string | null;
            lastName: string | null;
            birthDate: Date | null;
            avatarUrl: string | null;
            bio: string | null;
        } | null;
        id: string;
        pendingEmail: string | null;
        firstName: string;
        lastName: string;
        birthDate: Date;
        avatarUrl: string | null;
        createdAt: Date;
        deletedAt: Date | null;
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
        categories: {
            id: string;
            name: string;
        }[];
        mustChangePassword: boolean;
        profile: {
            firstName: string | null;
            lastName: string | null;
            birthDate: Date | null;
            avatarUrl: string | null;
            bio: string | null;
        } | null;
        id: string;
        pendingEmail: string | null;
        firstName: string;
        lastName: string;
        birthDate: Date;
        avatarUrl: string | null;
        createdAt: Date;
        deletedAt: Date | null;
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
        categories: {
            id: string;
            name: string;
        }[];
        mustChangePassword: boolean;
        profile: {
            firstName: string | null;
            lastName: string | null;
            birthDate: Date | null;
            avatarUrl: string | null;
            bio: string | null;
        } | null;
        id: string;
        pendingEmail: string | null;
        firstName: string;
        lastName: string;
        birthDate: Date;
        avatarUrl: string | null;
        createdAt: Date;
        deletedAt: Date | null;
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
        eventId: string;
        authorId: string;
        targetUserId: string | null;
        target: string;
        rating: number;
        text: string | null;
    })[]>;
    getCategoryPreferences(userId: string): Promise<{
        id: string;
        name: string;
    }[]>;
    updateCategoryPreferences(userId: string, categoryIds: string[]): Promise<{
        id: string;
        name: string;
    }[]>;
    changePassword(userId: string, currentPassword: string, newPassword: string): Promise<{
        ok: boolean;
    }>;
    deleteAccount(userId: string, password: string): Promise<{
        ok: boolean;
    }>;
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
