export declare class CreateEventDto {
    title: string;
    description: string;
    categoryId?: string;
    isPaid?: boolean;
    price?: number;
    currency?: string;
    requiresApproval?: boolean;
    startAt: string;
    endAt: string;
    city: string;
    address?: string;
    lat?: number;
    lon?: number;
    isAddressHidden?: boolean;
    capacity?: number;
    coverUrl?: string;
}
