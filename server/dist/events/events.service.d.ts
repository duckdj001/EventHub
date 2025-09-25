import { PrismaService } from "../common/prisma.service";
import { NotificationsService } from "../notifications/notifications.service";
import { CreateEventDto, CreateEventStoryDto, CreateEventPhotoDto, CreateReviewDto, EventReviewsFilterDto, UpdateEventDto } from "./dto";
export declare class EventsService {
    private prisma;
    private notifications;
    constructor(prisma: PrismaService, notifications: NotificationsService);
    private computeAvailability;
    list(params: {
        city?: string;
        categoryId?: string;
        lat?: number;
        lon?: number;
        radiusKm?: number;
        isPaid?: boolean;
        ownerId?: string;
        excludeMine?: boolean;
        timeframe?: "this-week" | "next-week" | "this-month";
        startDate?: string;
        endDate?: string;
    }, options?: {
        viewerId?: string;
    }): Promise<{
        availableSpots: number | null;
        owner: {
            id: string;
            firstName: string;
            lastName: string;
            avatarUrl: string | null;
        };
        id: string;
        createdAt: Date;
        updatedAt: Date;
        ownerId: string;
        title: string;
        description: string;
        isPaid: boolean;
        price: number | null;
        currency: string | null;
        requiresApproval: boolean;
        isAdultOnly: boolean;
        allowStories: boolean;
        startAt: Date;
        endAt: Date;
        city: string;
        address: string | null;
        lat: number | null;
        lon: number | null;
        isAddressHidden: boolean;
        capacity: number | null;
        status: string;
        coverUrl: string | null;
        reminderSentAt: Date | null;
        categoryId: string;
    }[]>;
    getOne(id: string, currentUserId?: string): Promise<{
        availableSpots: number | null;
        owner: {
            id: string;
            firstName: string;
            lastName: string;
            avatarUrl: string | null;
        };
        id: string;
        createdAt: Date;
        updatedAt: Date;
        ownerId: string;
        title: string;
        description: string;
        isPaid: boolean;
        price: number | null;
        currency: string | null;
        requiresApproval: boolean;
        isAdultOnly: boolean;
        allowStories: boolean;
        startAt: Date;
        endAt: Date;
        city: string;
        address: string | null;
        lat: number | null;
        lon: number | null;
        isAddressHidden: boolean;
        capacity: number | null;
        status: string;
        coverUrl: string | null;
        reminderSentAt: Date | null;
        categoryId: string;
    } | null>;
    setStatus(id: string, status: "published" | "draft", userId: string): Promise<{
        id: string;
        createdAt: Date;
        updatedAt: Date;
        ownerId: string;
        title: string;
        description: string;
        isPaid: boolean;
        price: number | null;
        currency: string | null;
        requiresApproval: boolean;
        isAdultOnly: boolean;
        allowStories: boolean;
        startAt: Date;
        endAt: Date;
        city: string;
        address: string | null;
        lat: number | null;
        lon: number | null;
        isAddressHidden: boolean;
        capacity: number | null;
        status: string;
        coverUrl: string | null;
        reminderSentAt: Date | null;
        categoryId: string;
    }>;
    remove(id: string, userId: string): Promise<{
        id: string;
        createdAt: Date;
        updatedAt: Date;
        ownerId: string;
        title: string;
        description: string;
        isPaid: boolean;
        price: number | null;
        currency: string | null;
        requiresApproval: boolean;
        isAdultOnly: boolean;
        allowStories: boolean;
        startAt: Date;
        endAt: Date;
        city: string;
        address: string | null;
        lat: number | null;
        lon: number | null;
        isAddressHidden: boolean;
        capacity: number | null;
        status: string;
        coverUrl: string | null;
        reminderSentAt: Date | null;
        categoryId: string;
    }>;
    create(ownerId: string, dto: CreateEventDto): Promise<{
        id: string;
        createdAt: Date;
        updatedAt: Date;
        ownerId: string;
        title: string;
        description: string;
        isPaid: boolean;
        price: number | null;
        currency: string | null;
        requiresApproval: boolean;
        isAdultOnly: boolean;
        allowStories: boolean;
        startAt: Date;
        endAt: Date;
        city: string;
        address: string | null;
        lat: number | null;
        lon: number | null;
        isAddressHidden: boolean;
        capacity: number | null;
        status: string;
        coverUrl: string | null;
        reminderSentAt: Date | null;
        categoryId: string;
    }>;
    update(id: string, ownerId: string, dto: UpdateEventDto): Promise<{
        id: string;
        createdAt: Date;
        updatedAt: Date;
        ownerId: string;
        title: string;
        description: string;
        isPaid: boolean;
        price: number | null;
        currency: string | null;
        requiresApproval: boolean;
        isAdultOnly: boolean;
        allowStories: boolean;
        startAt: Date;
        endAt: Date;
        city: string;
        address: string | null;
        lat: number | null;
        lon: number | null;
        isAddressHidden: boolean;
        capacity: number | null;
        status: string;
        coverUrl: string | null;
        reminderSentAt: Date | null;
        categoryId: string;
    }>;
    listParticipating(userId: string): Promise<{
        participationStatus: string;
        reviewed: boolean;
        availableSpots: number | null;
        owner: {
            id: string;
            firstName: string;
            lastName: string;
            avatarUrl: string | null;
        };
        id: string;
        createdAt: Date;
        updatedAt: Date;
        ownerId: string;
        title: string;
        description: string;
        isPaid: boolean;
        price: number | null;
        currency: string | null;
        requiresApproval: boolean;
        isAdultOnly: boolean;
        allowStories: boolean;
        startAt: Date;
        endAt: Date;
        city: string;
        address: string | null;
        lat: number | null;
        lon: number | null;
        isAddressHidden: boolean;
        capacity: number | null;
        status: string;
        coverUrl: string | null;
        reminderSentAt: Date | null;
        categoryId: string;
    }[]>;
    listStories(eventId: string): Promise<({
        author: {
            id: string;
            firstName: string;
            lastName: string;
            avatarUrl: string | null;
        };
    } & {
        id: string;
        createdAt: Date;
        eventId: string;
        authorId: string;
        url: string;
    })[]>;
    createStory(eventId: string, userId: string, dto: CreateEventStoryDto): Promise<{
        author: {
            id: string;
            firstName: string;
            lastName: string;
            avatarUrl: string | null;
        };
    } & {
        id: string;
        createdAt: Date;
        eventId: string;
        authorId: string;
        url: string;
    }>;
    deleteStory(eventId: string, storyId: string, userId: string): Promise<{
        ok: boolean;
    }>;
    listPhotos(eventId: string): Promise<({
        author: {
            id: string;
            firstName: string;
            lastName: string;
            avatarUrl: string | null;
        };
    } & {
        id: string;
        createdAt: Date;
        eventId: string;
        authorId: string;
        url: string;
        order: number;
    })[]>;
    createPhoto(eventId: string, userId: string, dto: CreateEventPhotoDto): Promise<{
        author: {
            id: string;
            firstName: string;
            lastName: string;
            avatarUrl: string | null;
        };
    } & {
        id: string;
        createdAt: Date;
        eventId: string;
        authorId: string;
        url: string;
        order: number;
    }>;
    deletePhoto(eventId: string, photoId: string, userId: string): Promise<{
        ok: boolean;
    }>;
    createReview(eventId: string, authorId: string, dto: CreateReviewDto): Promise<{
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
    eventReviews(eventId: string, filter?: EventReviewsFilterDto): Promise<({
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
    myReview(eventId: string, userId: string): Promise<{
        id: string;
        createdAt: Date;
        eventId: string;
        authorId: string;
        targetUserId: string | null;
        target: string;
        rating: number;
        text: string | null;
    } | null>;
    private archiveExpiredEvents;
    private calculateAge;
    private isAdult;
    private resolveTimeframe;
    private resolveCustomRange;
}
