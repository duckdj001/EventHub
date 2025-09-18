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
exports.ParticipationsController = void 0;
const common_1 = require("@nestjs/common");
const jwt_guard_1 = require("../auth/jwt.guard");
const participations_service_1 = require("./participations.service");
const dto_1 = require("./dto");
let ParticipationsController = class ParticipationsController {
    constructor(participations) {
        this.participations = participations;
    }
    async request(eventId, req) {
        return this.participations.request(eventId, req.user.sub);
    }
    async list(eventId, req) {
        return this.participations.listForOwner(eventId, req.user.sub);
    }
    async me(eventId, req) {
        return this.participations.getForUser(eventId, req.user.sub);
    }
    async cancel(eventId, req) {
        return this.participations.cancel(eventId, req.user.sub);
    }
    async setStatus(eventId, participationId, status, req) {
        return this.participations.changeStatus(eventId, req.user.sub, participationId, status);
    }
    async rate(eventId, participationId, dto, req) {
        return this.participations.rateParticipant(eventId, req.user.sub, participationId, dto);
    }
};
exports.ParticipationsController = ParticipationsController;
__decorate([
    (0, common_1.Post)('events/:id/participations'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", Promise)
], ParticipationsController.prototype, "request", null);
__decorate([
    (0, common_1.Get)('events/:id/participations'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", Promise)
], ParticipationsController.prototype, "list", null);
__decorate([
    (0, common_1.Get)('events/:id/participations/me'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", Promise)
], ParticipationsController.prototype, "me", null);
__decorate([
    (0, common_1.Delete)('events/:id/participations/me'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", Promise)
], ParticipationsController.prototype, "cancel", null);
__decorate([
    (0, common_1.Patch)('events/:id/participations/:pid'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Param)('pid')),
    __param(2, (0, common_1.Body)('status')),
    __param(3, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String, String, Object]),
    __metadata("design:returntype", Promise)
], ParticipationsController.prototype, "setStatus", null);
__decorate([
    (0, common_1.UseGuards)(jwt_guard_1.JwtAuthGuard),
    (0, common_1.Post)('events/:id/participations/:pid/rating'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Param)('pid')),
    __param(2, (0, common_1.Body)()),
    __param(3, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String, dto_1.RateParticipantDto, Object]),
    __metadata("design:returntype", Promise)
], ParticipationsController.prototype, "rate", null);
exports.ParticipationsController = ParticipationsController = __decorate([
    (0, common_1.Controller)(),
    (0, common_1.UseGuards)(jwt_guard_1.JwtAuthGuard),
    __metadata("design:paramtypes", [participations_service_1.ParticipationsService])
], ParticipationsController);
//# sourceMappingURL=participations.controller.js.map