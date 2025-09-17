// src/files/s3.service.ts
import { Injectable } from '@nestjs/common';
import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';

@Injectable()
export class S3Service {
  private client: S3Client;
  private bucket = process.env.S3_BUCKET!;
  private publicBase: string;

  constructor() {
    const endpoint = process.env.S3_ENDPOINT; // для MinIO
    const region = process.env.S3_REGION || 'us-east-1';
    const forcePathStyle = String(process.env.S3_FORCE_PATH_STYLE || 'true') === 'true';
    const accessKeyId = process.env.S3_ACCESS_KEY!;
    const secretAccessKey = process.env.S3_SECRET_KEY!;

    this.client = new S3Client({
      region,
      endpoint,                 // укажи, если это MinIO
      forcePathStyle,           // MinIO требует path-style
      credentials: { accessKeyId, secretAccessKey },
    });

    // База для публичных ссылок
    // приоритет: S3_PUBLIC_URL -> (endpoint + /bucket, если path-style) -> AWS формат
    if (process.env.S3_PUBLIC_URL) {
      this.publicBase = process.env.S3_PUBLIC_URL.replace(/\/+$/, '');
    } else if (endpoint && forcePathStyle) {
      this.publicBase = `${endpoint.replace(/\/+$/, '')}/${this.bucket}`;
    } else {
      // AWS виртуальный хост
      this.publicBase = `https://${this.bucket}.s3.${region}.amazonaws.com`;
    }
  }

  /**
   * Возвращает { uploadUrl, publicUrl, key }
   * uploadUrl — presigned PUT (5 минут)
   * publicUrl — готовая публичная ссылка для чтения (если бакет публичен)
   */
  async getPresignedUrl(key: string, contentType: string) {
    const cmd = new PutObjectCommand({
      Bucket: this.bucket,
      Key: key,
      ContentType: contentType,
      ACL: 'public-read', // для MinIO разреши ACL, если надо публичный доступ
    });
    const uploadUrl = await getSignedUrl(this.client, cmd, { expiresIn: 60 * 5 });

    // Собираем публичную ссылку
    const publicUrl = `${this.publicBase}/${encodeURI(key)}`;

    return { uploadUrl, publicUrl, key };
  }
}
