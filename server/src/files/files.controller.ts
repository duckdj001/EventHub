// src/files/files.controller.ts
import { Controller, Get, Query, UseGuards } from "@nestjs/common";
import { S3Service } from "./s3.service";
import { JwtAuthGuard } from "../auth/jwt.guard";
import { Public } from "../common/public.decorator";

@Controller("files")
export class FilesController {
  constructor(private s3: S3Service) {}

  @UseGuards(JwtAuthGuard)
  @Get("presign")
  presign(@Query("type") type: string, @Query("ext") ext: string) {
    const safeExt = (ext || "jpg").replace(".", "");
    const key = `${type}/${Date.now()}-${Math.random().toString(36).slice(2)}.${safeExt}`;
    const mime = this.mimeForExt(safeExt);
    return this.s3.getPresignedUrl(key, mime);
  }

  @Public()
  @Get("presign-public")
  presignPublic(@Query("type") type: string, @Query("ext") ext: string) {
    const safeExt = (ext || "jpg").replace(".", "");
    const key = `${type}/${Date.now()}-${Math.random().toString(36).slice(2)}.${safeExt}`;
    const mime = this.mimeForExt(safeExt);
    return this.s3.getPresignedUrl(key, mime);
  }

  private mimeForExt(ext: string) {
    switch (ext.toLowerCase()) {
      case "png":
        return "image/png";
      case "webp":
        return "image/webp";
      case "mp4":
        return "video/mp4";
      case "mov":
        return "video/quicktime";
      case "m4v":
        return "video/x-m4v";
      case "webm":
        return "video/webm";
      default:
        return "image/jpeg";
    }
  }
}
