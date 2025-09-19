export declare class RegisterDeviceDto {
    token: string;
    platform: 'ios' | 'android';
}
export declare class DeregisterDeviceDto {
    token: string;
    platform?: string;
}
