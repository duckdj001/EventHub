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
exports.FollowsController = void 0;
const common_1 = require("@nestjs/common");
const follows_service_1 = require("./follows.service");
const public_decorator_1 = require("../auth/public.decorator");
let FollowsController = class FollowsController {
    constructor(follows) {
        this.follows = follows;
    }
    follow(id, req) {
        var _a;
        const me = (_a = req.user) === null || _a === void 0 ? void 0 : _a.sub;
        if (!me)
            throw new common_1.UnauthorizedException();
        return this.follows.follow(me, id);
    }
    unfollow(id, req) {
        var _a;
        const me = (_a = req.user) === null || _a === void 0 ? void 0 : _a.sub;
        if (!me)
            throw new common_1.UnauthorizedException();
        return this.follows.unfollow(me, id);
    }
    followers(id) {
        return this.follows.followersOf(id);
    }
    following(id) {
        return this.follows.followingOf(id);
    }
};
exports.FollowsController = FollowsController;
__decorate([
    (0, common_1.Post)('follow'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", void 0)
], FollowsController.prototype, "follow", null);
__decorate([
    (0, common_1.Delete)('follow'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", void 0)
], FollowsController.prototype, "unfollow", null);
__decorate([
    (0, public_decorator_1.Public)(),
    (0, common_1.Get)('followers'),
    __param(0, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], FollowsController.prototype, "followers", null);
__decorate([
    (0, public_decorator_1.Public)(),
    (0, common_1.Get)('following'),
    __param(0, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], FollowsController.prototype, "following", null);
exports.FollowsController = FollowsController = __decorate([
    (0, common_1.Controller)('users/:id'),
    __metadata("design:paramtypes", [follows_service_1.FollowsService])
], FollowsController);
//# sourceMappingURL=follows.controller.js.map