"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.UsersService = void 0;
const common_1 = require("@nestjs/common");
const bcrypt = __importStar(require("bcrypt"));
const crypto = __importStar(require("crypto"));
const prisma_service_1 = require("../common/prisma.service");
const mail_service_1 = require("../common/mail.service");
const EMAIL_CHANGE_EXPIRES_MS = 24 * 60 * 60 * 1000;
function generateCode() {
    const n = crypto.randomInt(0, 1000000);
    return n.toString().padStart(6, '0');
}
let UsersService = class UsersService {
    constructor(prisma, mail) {
        this.prisma = prisma;
        this.mail = mail;
    }
    async me(userId) {
        return this.profile(userId, { viewerId: userId, includePrivate: true });
    }
    async profile(userId, opts) {
        var _a, _b, _c, _d, _e;
        const includePrivate = (_a = opts === null || opts === void 0 ? void 0 : opts.includePrivate) !== null && _a !== void 0 ? _a : false;
        const viewerId = opts === null || opts === void 0 ? void 0 : opts.viewerId;
        const user = await this.prisma.user.findUnique({
            where: { id: userId },
            select: {
                id: true,
                email: includePrivate,
                firstName: true,
                lastName: true,
                avatarUrl: true,
                birthDate: true,
                createdAt: true,
                pendingEmail: includePrivate,
                profile: {
                    select: {
                        bio: true,
                        firstName: true,
                        lastName: true,
                        avatarUrl: true,
                        birthDate: true,
                    },
                },
            },
        });
        if (!user)
            throw new common_1.NotFoundException('Пользователь не найден');
        const [ratingAgg, ratingGroups, upcomingCount, pastCount, participantAgg, followersCount, followingCount, viewerFollow,] = await Promise.all([
            this.prisma.review.aggregate({
                _avg: { rating: true },
                _count: { rating: true },
                where: { event: { ownerId: userId }, target: 'event' },
            }),
            this.prisma.review.groupBy({
                by: ['rating'],
                where: { event: { ownerId: userId }, target: 'event' },
                _count: { rating: true },
            }),
            this.prisma.event.count({ where: { ownerId: userId, startAt: { gte: new Date() } } }),
            this.prisma.event.count({ where: { ownerId: userId, endAt: { lt: new Date() } } }),
            this.prisma.review.aggregate({
                _avg: { rating: true },
                _count: { rating: true },
                where: { target: 'participant', targetUserId: userId },
            }),
            this.prisma.follow.count({ where: { followeeId: userId } }),
            this.prisma.follow.count({ where: { followerId: userId } }),
            viewerId
                ? this.prisma.follow.findUnique({
                    where: {
                        followerId_followeeId: { followerId: viewerId, followeeId: userId },
                    },
                    select: { id: true },
                })
                : null,
        ]);
        const distribution = { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0 };
        ratingGroups.forEach((g) => {
            if (g.rating >= 1 && g.rating <= 5) {
                distribution[g.rating] = g._count.rating;
            }
        });
        return {
            ...user,
            email: includePrivate ? user.email : undefined,
            stats: {
                ratingAvg: (_b = ratingAgg._avg.rating) !== null && _b !== void 0 ? _b : 0,
                ratingCount: (_c = ratingAgg._count.rating) !== null && _c !== void 0 ? _c : 0,
                ratingDistribution: distribution,
                eventsUpcoming: upcomingCount,
                eventsPast: pastCount,
                participantRatingAvg: (_d = participantAgg._avg.rating) !== null && _d !== void 0 ? _d : 0,
                participantRatingCount: (_e = participantAgg._count.rating) !== null && _e !== void 0 ? _e : 0,
            },
            social: {
                followers: followersCount,
                following: followingCount,
                isFollowedByViewer: !!viewerFollow,
            },
        };
    }
    async search(query, limit = 10) {
        const trimmed = query.trim();
        if (!trimmed)
            return [];
        const take = Math.min(Math.max(limit, 1), 25);
        return this.prisma.user.findMany({
            where: {
                OR: [
                    { firstName: { contains: trimmed, mode: 'insensitive' } },
                    { lastName: { contains: trimmed, mode: 'insensitive' } },
                    { email: { contains: trimmed, mode: 'insensitive' } },
                ],
            },
            take,
            orderBy: { createdAt: 'desc' },
            select: {
                id: true,
                firstName: true,
                lastName: true,
                avatarUrl: true,
                email: true,
            },
        });
    }
    async updateProfile(userId, dto) {
        const data = {};
        if (dto.firstName !== undefined)
            data.firstName = dto.firstName.trim();
        if (dto.lastName !== undefined)
            data.lastName = dto.lastName.trim();
        if (dto.avatarUrl !== undefined)
            data.avatarUrl = dto.avatarUrl.trim();
        if (dto.birthDate) {
            const bd = new Date(dto.birthDate);
            if (Number.isNaN(bd.getTime())) {
                throw new common_1.BadRequestException('Некорректная дата рождения');
            }
            data.birthDate = bd;
        }
        const updates = [];
        if (Object.keys(data).length > 0) {
            updates.push(this.prisma.user.update({ where: { id: userId }, data }));
        }
        if (dto.bio !== undefined) {
            updates.push(this.prisma.profile.upsert({
                where: { userId },
                update: { bio: dto.bio },
                create: { userId, bio: dto.bio },
            }));
        }
        await Promise.all(updates);
        return this.profile(userId, { viewerId: userId, includePrivate: true });
    }
    async requestEmailChange(userId, dto) {
        const user = await this.prisma.user.findUnique({
            where: { id: userId },
            select: { id: true, email: true, passwordHash: true, pendingEmail: true },
        });
        if (!user || !user.passwordHash) {
            throw new common_1.NotFoundException('Пользователь не найден');
        }
        const newEmail = dto.newEmail.toLowerCase().trim();
        if (!newEmail) {
            throw new common_1.BadRequestException('Укажите правильный e-mail');
        }
        const sameEmail = user.email.toLowerCase() === newEmail;
        if (sameEmail) {
            throw new common_1.BadRequestException('Укажите другой e-mail');
        }
        const existing = await this.prisma.user.findUnique({ where: { email: newEmail } });
        if (existing) {
            throw new common_1.BadRequestException('E-mail уже используется');
        }
        const ok = await bcrypt.compare(dto.password, user.passwordHash);
        if (!ok) {
            throw new common_1.BadRequestException('Неверный пароль');
        }
        const code = generateCode();
        const expires = new Date(Date.now() + EMAIL_CHANGE_EXPIRES_MS);
        await this.prisma.user.update({
            where: { id: userId },
            data: {
                pendingEmail: newEmail,
                pendingEmailToken: code,
                pendingEmailExpires: expires,
            },
        });
        await this.mail.send(newEmail, 'Подтверждение изменения e-mail', `<p>Код подтверждения: <b>${code}</b></p><p>Если вы не запрашивали смену e-mail, проигнорируйте письмо.</p>`);
        return { ok: true };
    }
    async confirmEmailChange(userId, dto) {
        const user = await this.prisma.user.findUnique({
            where: { id: userId },
            select: {
                pendingEmail: true,
                pendingEmailToken: true,
                pendingEmailExpires: true,
            },
        });
        if (!(user === null || user === void 0 ? void 0 : user.pendingEmail) || !user.pendingEmailToken) {
            throw new common_1.BadRequestException('Нет активного запроса на смену e-mail');
        }
        if (user.pendingEmailToken !== dto.code) {
            throw new common_1.BadRequestException('Неверный код');
        }
        if (user.pendingEmailExpires && user.pendingEmailExpires.getTime() < Date.now()) {
            throw new common_1.BadRequestException('Код истёк, попробуйте снова');
        }
        await this.prisma.user.update({
            where: { id: userId },
            data: {
                email: user.pendingEmail,
                pendingEmail: null,
                pendingEmailToken: null,
                pendingEmailExpires: null,
                emailVerified: true,
            },
        });
        return { ok: true };
    }
    async reviews(userId, filter) {
        var _a;
        const type = (_a = filter.type) !== null && _a !== void 0 ? _a : 'event';
        const where = type === 'participant'
            ? { target: 'participant', targetUserId: userId }
            : { event: { ownerId: userId }, target: 'event' };
        if (filter.rating) {
            where.rating = filter.rating;
        }
        return this.prisma.review.findMany({
            where,
            orderBy: { createdAt: 'desc' },
            include: {
                author: {
                    select: { id: true, firstName: true, lastName: true, avatarUrl: true, email: true },
                },
                event: { select: { id: true, title: true, startAt: true, endAt: true } },
            },
        });
    }
    async eventsCreated(userId, filter) {
        const now = new Date();
        const where = { ownerId: userId };
        switch (filter.filter) {
            case 'upcoming':
                where.startAt = { gte: now };
                break;
            case 'past':
                where.endAt = { lt: now };
                break;
            default:
                break;
        }
        return this.prisma.event.findMany({
            where,
            orderBy: { startAt: 'desc' },
            select: {
                id: true,
                title: true,
                startAt: true,
                endAt: true,
                city: true,
                coverUrl: true,
                status: true,
            },
        });
    }
};
exports.UsersService = UsersService;
exports.UsersService = UsersService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService, mail_service_1.MailService])
], UsersService);
//# sourceMappingURL=users.service.js.map