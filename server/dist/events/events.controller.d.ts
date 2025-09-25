import { EventsService } from "./events.service";
import { CreateEventDto, CreateEventStoryDto, CreateEventPhotoDto, CreateReviewDto, EventReviewsFilterDto, UpdateEventDto } from "./dto";
export declare class EventsController {
    private events;
    constructor(events: EventsService);
    list(city?: string, categoryId?: string, latStr?: string, lonStr?: string, radiusStr?: string, isPaidStr?: string, owner?: string, excludeMineStr?: string, timeframe?: "this-week" | "next-week" | "this-month", startDate?: string, endDate?: string, req?: any): Promise<{
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
    create(req: any, dto: CreateEventDto): Promise<{
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
    mine(req: any): Promise<{
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
    participating(req: any): Promise<{
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
    update(id: string, req: any, dto: UpdateEventDto): Promise<{
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
    getOne(id: string, req: any): Promise<{
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
    createReview(id: string, req: any, dto: CreateReviewDto): Promise<{
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
    listReviews(id: string, query: EventReviewsFilterDto): Promise<({
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
    stories(id: string): Promise<({
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
    myReview(id: string, req: any): Promise<{
        id: string;
        createdAt: Date;
        eventId: string;
        authorId: string;
        targetUserId: string | null;
        target: string;
        rating: number;
        text: string | null;
    } | null>;
    addStory(id: string, req: any, dto: CreateEventStoryDto): Promise<{
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
    deleteStory(id: string, storyId: string, req: any): Promise<{
        ok: boolean;
    }>;
    photos(id: string): Promise<({
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
    addPhoto(id: string, req: any, dto: CreateEventPhotoDto): Promise<{
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
    deletePhoto(id: string, photoId: string, req: any): Promise<{
        ok: boolean;
    }>;
    setStatus(id: string, status: "published" | "draft", req: any): Promise<{
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
    remove(id: string, req: any): Promise<{
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
}
