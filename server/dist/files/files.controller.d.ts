import { S3Service } from './s3.service';
export declare class FilesController {
    private s3;
    constructor(s3: S3Service);
    presign(type: string, ext: string): Promise<{
        uploadUrl: string;
        publicUrl: string;
        key: string;
    }>;
    presignPublic(type: string, ext: string): Promise<{
        uploadUrl: string;
        publicUrl: string;
        key: string;
    }>;
}
