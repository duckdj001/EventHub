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
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.FilesController = void 0;
const common_1 = require("@nestjs/common");
const s3_service_1 = require("./s3.service");
const jwt_guard_1 = require("../auth/jwt.guard");
const public_decorator_1 = require("../common/public.decorator");
let FilesController = class FilesController {
    constructor(s3) {
        this.s3 = s3;
    }
    presign(type, ext) {
        const safeExt = (ext || "jpg").replace(".", "");
        const key = `${type}/${Date.now()}-${Math.random().toString(36).slice(2)}.${safeExt}`;
        const mime = this.mimeForExt(safeExt);
        return this.s3.getPresignedUrl(key, mime);
    }
    presignPublic(type, ext) {
        const safeExt = (ext || "jpg").replace(".", "");
        const key = `${type}/${Date.now()}-${Math.random().toString(36).slice(2)}.${safeExt}`;
        const mime = this.mimeForExt(safeExt);
        return this.s3.getPresignedUrl(key, mime);
    }
    mimeForExt(ext) {
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
};
exports.FilesController = FilesController;
__decorate([
    (0, common_1.UseGuards)(jwt_guard_1.JwtAuthGuard),
    (0, common_1.Get)("presign"),
    __param(0, (0, common_1.Query)("type")),
    __param(1, (0, common_1.Query)("ext")),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String]),
    __metadata("design:returntype", void 0)
], FilesController.prototype, "presign", null);
__decorate([
    (0, public_decorator_1.Public)(),
    (0, common_1.Get)("presign-public"),
    __param(0, (0, common_1.Query)("type")),
    __param(1, (0, common_1.Query)("ext")),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String]),
    __metadata("design:returntype", void 0)
], FilesController.prototype, "presignPublic", null);
exports.FilesController = FilesController = __decorate([
    (0, common_1.Controller)("files"),
    __metadata("design:paramtypes", [s3_service_1.S3Service])
], FilesController);
//# sourceMappingURL=files.controller.js.map