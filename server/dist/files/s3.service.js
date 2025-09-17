"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.S3Service = void 0;
const common_1 = require("@nestjs/common");
const client_s3_1 = require("@aws-sdk/client-s3");
const s3_request_presigner_1 = require("@aws-sdk/s3-request-presigner");
let S3Service = class S3Service {
    constructor() {
        this.bucket = process.env.S3_BUCKET;
        const endpoint = process.env.S3_ENDPOINT;
        const region = process.env.S3_REGION || 'us-east-1';
        const forcePathStyle = String(process.env.S3_FORCE_PATH_STYLE || 'true') === 'true';
        const accessKeyId = process.env.S3_ACCESS_KEY;
        const secretAccessKey = process.env.S3_SECRET_KEY;
        this.client = new client_s3_1.S3Client({
            region,
            endpoint,
            forcePathStyle,
            credentials: { accessKeyId, secretAccessKey },
        });
        if (process.env.S3_PUBLIC_URL) {
            this.publicBase = process.env.S3_PUBLIC_URL.replace(/\/+$/, '');
        }
        else if (endpoint && forcePathStyle) {
            this.publicBase = `${endpoint.replace(/\/+$/, '')}/${this.bucket}`;
        }
        else {
            this.publicBase = `https://${this.bucket}.s3.${region}.amazonaws.com`;
        }
    }
    async getPresignedUrl(key, contentType) {
        const cmd = new client_s3_1.PutObjectCommand({
            Bucket: this.bucket,
            Key: key,
            ContentType: contentType,
            ACL: 'public-read',
        });
        const uploadUrl = await (0, s3_request_presigner_1.getSignedUrl)(this.client, cmd, { expiresIn: 60 * 5 });
        const publicUrl = `${this.publicBase}/${encodeURI(key)}`;
        return { uploadUrl, publicUrl, key };
    }
};
exports.S3Service = S3Service;
exports.S3Service = S3Service = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [])
], S3Service);
//# sourceMappingURL=s3.service.js.map