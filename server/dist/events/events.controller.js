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
exports.EventsController = void 0;
const common_1 = require("@nestjs/common");
const events_service_1 = require("./events.service");
const dto_1 = require("./dto");
const common_2 = require("@nestjs/common");
const jwt_guard_1 = require("../auth/jwt.guard");
let EventsController = class EventsController {
    constructor(events) {
        this.events = events;
    }
    list(city, categoryId, latStr, lonStr, radiusStr, isPaidStr, owner, excludeMineStr, req) {
        var _a, _b;
        const lat = latStr ? Number(latStr) : undefined;
        const lon = lonStr ? Number(lonStr) : undefined;
        const radiusKm = radiusStr ? Number(radiusStr) : undefined;
        const isPaid = typeof isPaidStr === 'string' ? isPaidStr === 'true' : undefined;
        const ownerId = owner === 'me' ? (_a = req === null || req === void 0 ? void 0 : req.user) === null || _a === void 0 ? void 0 : _a.sub : undefined;
        const viewerId = (_b = req === null || req === void 0 ? void 0 : req.user) === null || _b === void 0 ? void 0 : _b.sub;
        const excludeMine = excludeMineStr === 'true';
        return this.events.list({ city, categoryId, lat, lon, radiusKm, isPaid, ownerId, excludeMine }, { viewerId });
    }
    create(req, dto) {
        return this.events.create(req.user.sub, dto);
    }
    mine(req) {
        return this.events.list({ ownerId: req.user.sub });
    }
    participating(req) {
        return this.events.listParticipating(req.user.sub);
    }
    update(id, req, dto) {
        return this.events.update(id, req.user.sub, dto);
    }
    getOne(id, req) {
        var _a;
        return this.events.getOne(id, (_a = req === null || req === void 0 ? void 0 : req.user) === null || _a === void 0 ? void 0 : _a.sub);
    }
    createReview(id, req, dto) {
        return this.events.createReview(id, req.user.sub, dto);
    }
    listReviews(id, query) {
        return this.events.eventReviews(id, query);
    }
    myReview(id, req) {
        return this.events.myReview(id, req.user.sub);
    }
    setStatus(id, status, req) {
        return this.events.setStatus(id, status, req.user.sub);
    }
    remove(id, req) {
        return this.events.remove(id, req.user.sub);
    }
};
exports.EventsController = EventsController;
__decorate([
    (0, common_1.Get)(),
    __param(0, (0, common_1.Query)('city')),
    __param(1, (0, common_1.Query)('categoryId')),
    __param(2, (0, common_1.Query)('lat')),
    __param(3, (0, common_1.Query)('lon')),
    __param(4, (0, common_1.Query)('radiusKm')),
    __param(5, (0, common_1.Query)('isPaid')),
    __param(6, (0, common_1.Query)('owner')),
    __param(7, (0, common_1.Query)('excludeMine')),
    __param(8, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String, String, String, String, String, String, String, Object]),
    __metadata("design:returntype", void 0)
], EventsController.prototype, "list", null);
__decorate([
    (0, common_1.UseGuards)(jwt_guard_1.JwtAuthGuard),
    (0, common_1.Post)(),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, dto_1.CreateEventDto]),
    __metadata("design:returntype", void 0)
], EventsController.prototype, "create", null);
__decorate([
    (0, common_1.UseGuards)(jwt_guard_1.JwtAuthGuard),
    (0, common_1.Get)('mine'),
    __param(0, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", void 0)
], EventsController.prototype, "mine", null);
__decorate([
    (0, common_1.UseGuards)(jwt_guard_1.JwtAuthGuard),
    (0, common_1.Get)('participating'),
    __param(0, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", void 0)
], EventsController.prototype, "participating", null);
__decorate([
    (0, common_1.UseGuards)(jwt_guard_1.JwtAuthGuard),
    (0, common_2.Patch)(':id'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Req)()),
    __param(2, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object, dto_1.UpdateEventDto]),
    __metadata("design:returntype", void 0)
], EventsController.prototype, "update", null);
__decorate([
    (0, common_1.Get)(':id'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", void 0)
], EventsController.prototype, "getOne", null);
__decorate([
    (0, common_1.UseGuards)(jwt_guard_1.JwtAuthGuard),
    (0, common_1.Post)(':id/reviews'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Req)()),
    __param(2, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object, dto_1.CreateReviewDto]),
    __metadata("design:returntype", void 0)
], EventsController.prototype, "createReview", null);
__decorate([
    (0, common_1.Get)(':id/reviews'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Query)(new common_1.ValidationPipe({ transform: true }))),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, dto_1.EventReviewsFilterDto]),
    __metadata("design:returntype", void 0)
], EventsController.prototype, "listReviews", null);
__decorate([
    (0, common_1.UseGuards)(jwt_guard_1.JwtAuthGuard),
    (0, common_1.Get)(':id/reviews/me'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", void 0)
], EventsController.prototype, "myReview", null);
__decorate([
    (0, common_1.UseGuards)(jwt_guard_1.JwtAuthGuard),
    (0, common_2.Patch)(':id/status'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Body)('status')),
    __param(2, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String, Object]),
    __metadata("design:returntype", void 0)
], EventsController.prototype, "setStatus", null);
__decorate([
    (0, common_1.UseGuards)(jwt_guard_1.JwtAuthGuard),
    (0, common_2.Delete)(':id'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", void 0)
], EventsController.prototype, "remove", null);
exports.EventsController = EventsController = __decorate([
    (0, common_1.Controller)('events'),
    __metadata("design:paramtypes", [events_service_1.EventsService])
], EventsController);
//# sourceMappingURL=events.controller.js.map