export declare class CreateEventDto {
    title: string;
    description: string;
    categoryId?: string;
    isPaid?: boolean;
    price?: number;
    currency?: string;
    requiresApproval?: boolean;
    isAdultOnly?: boolean;
    allowStories?: boolean;
    startAt: string;
    endAt: string;
    city: string;
    address?: string;
    lat?: number;
    lon?: number;
    isAddressHidden?: boolean;
    capacity: number;
    coverUrl?: string;
}
export declare class UpdateEventDto extends CreateEventDto {
}
export declare class CreateReviewDto {
    rating: number;
    text?: string;
}
export declare class EventReviewsFilterDto {
    rating?: number;
}
export declare class CreateEventStoryDto {
    url: string;
}
export declare class CreateEventPhotoDto {
    url: string;
}
