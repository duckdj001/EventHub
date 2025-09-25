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
exports.FollowsService = void 0;
const common_1 = require("@nestjs/common");
const prisma_service_1 = require("../common/prisma.service");
const notifications_service_1 = require("../notifications/notifications.service");
const USER_BRIEF_SELECT = {
    id: true,
    firstName: true,
    lastName: true,
    avatarUrl: true,
};
let FollowsService = class FollowsService {
    constructor(prisma, notifications) {
        this.prisma = prisma;
        this.notifications = notifications;
    }
    async follow(followerId, followeeId) {
        if (followerId === followeeId) {
            throw new common_1.BadRequestException('Нельзя подписаться на себя');
        }
        const existing = await this.prisma.follow.findUnique({
            where: { followerId_followeeId: { followerId, followeeId } },
        });
        if (existing)
            return existing;
        const created = await this.prisma.follow.create({
            data: { followerId, followeeId },
        });
        await this.notifications.notifyNewFollower(followeeId, followerId);
        return created;
    }
    async unfollow(followerId, followeeId) {
        await this.prisma.follow.deleteMany({ where: { followerId, followeeId } });
        return { ok: true };
    }
    async followersOf(userId) {
        const rows = await this.prisma.follow.findMany({
            where: { followeeId: userId },
            orderBy: { createdAt: 'desc' },
            select: {
                createdAt: true,
                follower: { select: USER_BRIEF_SELECT },
            },
        });
        return rows.map((row) => ({
            ...row.follower,
            followedAt: row.createdAt,
        }));
    }
    async followingOf(userId) {
        const rows = await this.prisma.follow.findMany({
            where: { followerId: userId },
            orderBy: { createdAt: 'desc' },
            select: {
                createdAt: true,
                followee: { select: USER_BRIEF_SELECT },
            },
        });
        return rows.map((row) => ({
            ...row.followee,
            followedAt: row.createdAt,
        }));
    }
};
exports.FollowsService = FollowsService;
exports.FollowsService = FollowsService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService, notifications_service_1.NotificationsService])
], FollowsService);
//# sourceMappingURL=follows.service.js.map