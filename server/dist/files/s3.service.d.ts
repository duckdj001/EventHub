export declare class S3Service {
    private client;
    private bucket;
    private publicBase;
    constructor();
    getPresignedUrl(key: string, contentType: string): Promise<{
        uploadUrl: string;
        publicUrl: string;
        key: string;
    }>;
}
