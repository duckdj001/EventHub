export declare class UpdateProfileDto {
    firstName?: string;
    lastName?: string;
    avatarUrl?: string;
    bio?: string;
    birthDate?: string;
}
export declare class RequestEmailChangeDto {
    newEmail: string;
    password: string;
}
export declare class ConfirmEmailChangeDto {
    code: string;
}
export declare class ReviewsFilterDto {
    rating?: number;
    type?: 'event' | 'participant';
}
export declare class UserEventsFilterDto {
    filter?: 'all' | 'upcoming' | 'past';
}
