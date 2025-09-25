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
    return n.toString().padStart(6, "0");
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
                mustChangePassword: true,
                deletedAt: true,
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
        if (!user || user.deletedAt != null) {
            throw new common_1.NotFoundException("Пользователь не найден");
        }
        const [ratingAgg, ratingGroups, upcomingCount, pastCount, participantAgg, followersCount, followingCount, viewerFollow, categoryRows,] = await Promise.all([
            this.prisma.review.aggregate({
                _avg: { rating: true },
                _count: { rating: true },
                where: { event: { ownerId: userId }, target: "event" },
            }),
            this.prisma.review.groupBy({
                by: ["rating"],
                where: { event: { ownerId: userId }, target: "event" },
                _count: { rating: true },
            }),
            this.prisma.event.count({
                where: { ownerId: userId, startAt: { gte: new Date() } },
            }),
            this.prisma.event.count({
                where: { ownerId: userId, endAt: { lt: new Date() } },
            }),
            this.prisma.review.aggregate({
                _avg: { rating: true },
                _count: { rating: true },
                where: { target: "participant", targetUserId: userId },
            }),
            this.prisma.follow.count({ where: { followeeId: userId } }),
            this.prisma.follow.count({ where: { followerId: userId } }),
            viewerId
                ? this.prisma.follow.findUnique({
                    where: {
                        followerId_followeeId: {
                            followerId: viewerId,
                            followeeId: userId,
                        },
                    },
                    select: { id: true },
                })
                : null,
            this.prisma.userCategoryPreference.findMany({
                where: { userId },
                include: { category: { select: { id: true, name: true } } },
                orderBy: { category: { name: "asc" } },
            }),
        ]);
        const distribution = {
            1: 0,
            2: 0,
            3: 0,
            4: 0,
            5: 0,
        };
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
            categories: categoryRows.map((row) => ({
                id: row.categoryId,
                name: row.category.name,
            })),
            mustChangePassword: user.mustChangePassword,
        };
    }
    async search(query, limit = 10) {
        const trimmed = query.trim();
        if (!trimmed)
            return [];
        const take = Math.min(Math.max(limit, 1), 25);
        const tokens = trimmed
            .split(/\s+/)
            .map((token) => token.trim())
            .filter((token) => token.length > 0)
            .slice(0, 5);
        const conditions = [
            { firstName: { contains: trimmed, mode: "insensitive" } },
            { lastName: { contains: trimmed, mode: "insensitive" } },
            { email: { contains: trimmed, mode: "insensitive" } },
        ];
        if (tokens.length > 1) {
            conditions.push({
                AND: tokens.map((token) => ({
                    OR: [
                        { firstName: { contains: token, mode: "insensitive" } },
                        { lastName: { contains: token, mode: "insensitive" } },
                        { email: { contains: token, mode: "insensitive" } },
                    ],
                })),
            });
        }
        return this.prisma.user.findMany({
            where: {
                OR: conditions,
            },
            take,
            orderBy: { createdAt: "desc" },
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
                throw new common_1.BadRequestException("Некорректная дата рождения");
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
            throw new common_1.NotFoundException("Пользователь не найден");
        }
        const newEmail = dto.newEmail.toLowerCase().trim();
        if (!newEmail) {
            throw new common_1.BadRequestException("Укажите правильный e-mail");
        }
        const sameEmail = user.email.toLowerCase() === newEmail;
        if (sameEmail) {
            throw new common_1.BadRequestException("Укажите другой e-mail");
        }
        const existing = await this.prisma.user.findUnique({
            where: { email: newEmail },
        });
        if (existing) {
            throw new common_1.BadRequestException("E-mail уже используется");
        }
        const ok = await bcrypt.compare(dto.password, user.passwordHash);
        if (!ok) {
            throw new common_1.BadRequestException("Неверный пароль");
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
        await this.mail.send(newEmail, "Подтверждение изменения e-mail", `<p>Код подтверждения: <b>${code}</b></p><p>Если вы не запрашивали смену e-mail, проигнорируйте письмо.</p>`);
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
            throw new common_1.BadRequestException("Нет активного запроса на смену e-mail");
        }
        if (user.pendingEmailToken !== dto.code) {
            throw new common_1.BadRequestException("Неверный код");
        }
        if (user.pendingEmailExpires &&
            user.pendingEmailExpires.getTime() < Date.now()) {
            throw new common_1.BadRequestException("Код истёк, попробуйте снова");
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
        const type = (_a = filter.type) !== null && _a !== void 0 ? _a : "event";
        const where = type === "participant"
            ? { target: "participant", targetUserId: userId }
            : { event: { ownerId: userId }, target: "event" };
        if (filter.rating) {
            where.rating = filter.rating;
        }
        return this.prisma.review.findMany({
            where,
            orderBy: { createdAt: "desc" },
            include: {
                author: {
                    select: {
                        id: true,
                        firstName: true,
                        lastName: true,
                        avatarUrl: true,
                        email: true,
                    },
                },
                event: {
                    select: { id: true, title: true, startAt: true, endAt: true },
                },
            },
        });
    }
    async getCategoryPreferences(userId) {
        const rows = await this.prisma.userCategoryPreference.findMany({
            where: { userId },
            include: { category: { select: { id: true, name: true } } },
            orderBy: { category: { name: "asc" } },
        });
        return rows.map((row) => ({
            id: row.categoryId,
            name: row.category.name,
        }));
    }
    async updateCategoryPreferences(userId, categoryIds) {
        const unique = Array.from(new Set(categoryIds.map((id) => id.trim()).filter((id) => id.length > 0)));
        if (unique.length !== 5) {
            throw new common_1.BadRequestException("Необходимо выбрать ровно 5 категорий");
        }
        const categories = await this.prisma.category.findMany({
            where: { id: { in: unique } },
            select: { id: true, name: true },
            orderBy: { name: "asc" },
        });
        if (categories.length !== unique.length) {
            throw new common_1.BadRequestException("Некорректный идентификатор категории");
        }
        await this.prisma.$transaction(async (tx) => {
            await tx.userCategoryPreference.deleteMany({ where: { userId } });
            await tx.userCategoryPreference.createMany({
                data: unique.map((categoryId) => ({ userId, categoryId })),
            });
        });
        return categories.map((category) => ({
            id: category.id,
            name: category.name,
        }));
    }
    async changePassword(userId, currentPassword, newPassword) {
        const user = await this.prisma.user.findUnique({
            where: { id: userId },
            select: { passwordHash: true },
        });
        if (!(user === null || user === void 0 ? void 0 : user.passwordHash)) {
            throw new common_1.BadRequestException('Пароль не установлен');
        }
        const isValid = await bcrypt.compare(currentPassword, user.passwordHash);
        if (!isValid) {
            throw new common_1.BadRequestException('Неверный текущий пароль');
        }
        const hash = await bcrypt.hash(newPassword, 10);
        await this.prisma.user.update({
            where: { id: userId },
            data: { passwordHash: hash, mustChangePassword: false },
        });
        return { ok: true };
    }
    async deleteAccount(userId, password) {
        const user = await this.prisma.user.findUnique({
            where: { id: userId },
            select: { passwordHash: true, email: true },
        });
        if (!(user === null || user === void 0 ? void 0 : user.passwordHash)) {
            throw new common_1.BadRequestException('Неверный пароль');
        }
        const ok = await bcrypt.compare(password, user.passwordHash);
        if (!ok) {
            throw new common_1.BadRequestException('Неверный пароль');
        }
        const anonymizedEmail = `deleted_${userId}_${Date.now()}@deleted.local`;
        const randomHash = await bcrypt.hash(crypto.randomBytes(32).toString('hex'), 10);
        await this.prisma.$transaction(async (tx) => {
            await tx.deviceToken.deleteMany({ where: { userId } });
            await tx.notification.deleteMany({ where: { OR: [{ userId }, { actorId: userId }] } });
            await tx.notificationPreference.deleteMany({ where: { userId } });
            await tx.userCategoryPreference.deleteMany({ where: { userId } });
            await tx.profile.updateMany({
                where: { userId },
                data: { bio: null, firstName: '', lastName: '', avatarUrl: null },
            });
            await tx.user.update({
                where: { id: userId },
                data: {
                    email: anonymizedEmail,
                    passwordHash: randomHash,
                    firstName: 'Удалён',
                    lastName: '',
                    avatarUrl: null,
                    deletedAt: new Date(),
                    mustChangePassword: false,
                },
            });
        });
        return { ok: true };
    }
    async eventsCreated(userId, filter) {
        const now = new Date();
        const where = { ownerId: userId };
        switch (filter.filter) {
            case "upcoming":
                where.startAt = { gte: now };
                break;
            case "past":
                where.endAt = { lt: now };
                break;
            default:
                break;
        }
        return this.prisma.event.findMany({
            where,
            orderBy: { startAt: "desc" },
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
    __metadata("design:paramtypes", [prisma_service_1.PrismaService,
        mail_service_1.MailService])
], UsersService);
//# sourceMappingURL=users.service.js.map