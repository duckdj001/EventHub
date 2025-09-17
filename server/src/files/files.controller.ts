// src/files/files.controller.ts
import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { S3Service } from './s3.service';
import { JwtAuthGuard } from '../auth/jwt.guard';
import { Public } from '../common/public.decorator';

@Controller('files')
export class FilesController {
  constructor(private s3: S3Service) {}

  @UseGuards(JwtAuthGuard)
  @Get('presign')
  presign(@Query('type') type: string, @Query('ext') ext: string) {
    const safeExt = (ext || 'jpg').replace('.', '');
    const key = `${type}/${Date.now()}-${Math.random().toString(36).slice(2)}.${safeExt}`;
    const mime = safeExt === 'png' ? 'image/png' : safeExt === 'webp' ? 'image/webp' : 'image/jpeg';
    return this.s3.getPresignedUrl(key, mime);
  }

  @Public()
  
  @Get('presign-public')
  presignPublic(@Query('type') type: string, @Query('ext') ext: string) {
    const safeExt = (ext || 'jpg').replace('.', '');
    const key = `${type}/${Date.now()}-${Math.random().toString(36).slice(2)}.${safeExt}`;
    const mime = safeExt === 'png' ? 'image/png' : safeExt === 'webp' ? 'image/webp' : 'image/jpeg';
    return this.s3.getPresignedUrl(key, mime);
  }
  
}
