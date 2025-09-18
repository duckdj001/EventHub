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
exports.EventsService = void 0;
const common_1 = require("@nestjs/common");
const prisma_service_1 = require("../common/prisma.service");
const CATEGORY_TITLES = {
    'default-category': 'Встречи',
    music: 'Музыка',
    sport: 'Спорт',
    education: 'Обучение',
    art: 'Искусство',
    business: 'Бизнес',
    family: 'Семья',
    health: 'Здоровье',
    travel: 'Путешествия',
    food: 'Еда',
    tech: 'Технологии',
    games: 'Игры',
};
const OWNER_SELECT = {
    id: true,
    firstName: true,
    lastName: true,
    avatarUrl: true,
};
function haversineKm(a, b) {
    const toRad = (x) => x * Math.PI / 180;
    const R = 6371;
    const dLat = toRad(b.lat - a.lat);
    const dLon = toRad(b.lon - a.lon);
    const s1 = Math.sin(dLat / 2) ** 2 + Math.cos(toRad(a.lat)) * Math.cos(toRad(b.lat)) * Math.sin(dLon / 2) ** 2;
    return 2 * R * Math.asin(Math.sqrt(s1));
}
let EventsService = class EventsService {
    constructor(prisma) {
        this.prisma = prisma;
    }
    async list(params, options = {}) {
        await this.archiveExpiredEvents();
        const { city, categoryId, lat, lon, radiusKm = 50, isPaid, ownerId, excludeMine } = params;
        const { viewerId } = options;
        let viewerIsAdult = true;
        if (!ownerId && viewerId) {
            const viewer = await this.prisma.user.findUnique({
                where: { id: viewerId },
                select: { birthDate: true },
            });
            if (viewer === null || viewer === void 0 ? void 0 : viewer.birthDate) {
                viewerIsAdult = this.isAdult(viewer.birthDate);
            }
        }
        const where = {};
        if (!ownerId) {
            where.status = 'published';
        }
        if (ownerId)
            where.ownerId = ownerId;
        if (city)
            where.city = city;
        if (categoryId)
            where.categoryId = categoryId;
        if (typeof isPaid === 'boolean')
            where.isPaid = isPaid;
        if (!ownerId && !viewerIsAdult) {
            where.isAdultOnly = false;
        }
        if (excludeMine && viewerId) {
            where.ownerId = { not: viewerId };
        }
        if (!ownerId) {
            where.endAt = { gte: new Date() };
        }
        if (lat != null && lon != null) {
            return this.prisma.event
                .findMany({
                where: {
                    ...where,
                    lat: { not: null },
                    lon: { not: null },
                    endAt: { gte: new Date() },
                },
                orderBy: { startAt: 'asc' },
                include: {
                    owner: { select: OWNER_SELECT },
                },
            })
                .then(list => {
                const withD = list
                    .map(e => ({
                    ...e,
                    distanceKm: haversineKm({ lat, lon }, { lat: e.lat, lon: e.lon }),
                }))
                    .filter(e => e.distanceKm <= radiusKm)
                    .sort((a, b) => a.distanceKm - b.distanceKm);
                return withD;
            });
        }
        return this.prisma.event.findMany({
            where,
            orderBy: { startAt: 'asc' },
            include: {
                owner: { select: OWNER_SELECT },
            },
        });
    }
    async getOne(id, currentUserId) {
        const e = await this.prisma.event.findUnique({
            where: { id },
            include: {
                owner: {
                    select: OWNER_SELECT,
                },
            },
        });
        if (!e)
            return null;
        if (e.isAdultOnly && currentUserId && e.ownerId !== currentUserId) {
            const viewer = await this.prisma.user.findUnique({
                where: { id: currentUserId },
                select: { birthDate: true },
            });
            if (!this.isAdult(viewer === null || viewer === void 0 ? void 0 : viewer.birthDate)) {
                throw new common_1.ForbiddenException('Событие доступно только пользователям 18+');
            }
        }
        if (e.requiresApproval) {
            const isOwner = currentUserId && e.ownerId === currentUserId;
            let approved = false;
            if (currentUserId) {
                const part = await this.prisma.participation.findUnique({
                    where: { eventId_userId: { eventId: id, userId: currentUserId } },
                    select: { status: true },
                });
                approved = (part === null || part === void 0 ? void 0 : part.status) === 'approved' || (part === null || part === void 0 ? void 0 : part.status) === 'attended';
            }
            if (!isOwner && !approved) {
                return { ...e, address: null, lat: null, lon: null, isAddressHidden: true };
            }
        }
        return e;
    }
    async setStatus(id, status, userId) {
        const e = await this.prisma.event.findUnique({ where: { id } });
        if (!e || e.ownerId !== userId)
            throw new common_1.ForbiddenException();
        return this.prisma.event.update({ where: { id }, data: { status } });
    }
    async remove(id, userId) {
        const e = await this.prisma.event.findUnique({ where: { id } });
        if (!e || e.ownerId !== userId)
            throw new common_1.ForbiddenException();
        return this.prisma.event.delete({ where: { id } });
    }
    async create(ownerId, dto) {
        var _a, _b, _c, _d, _e, _f, _g, _h, _j;
        const start = new Date(dto.startAt);
        const end = new Date(dto.endAt);
        if (isNaN(start.getTime()) || isNaN(end.getTime())) {
            throw new common_1.BadRequestException('Invalid startAt/endAt; must be ISO-8601');
        }
        let categoryId = (_a = dto.categoryId) === null || _a === void 0 ? void 0 : _a.trim();
        if (categoryId) {
            const categoryName = (_b = CATEGORY_TITLES[categoryId]) !== null && _b !== void 0 ? _b : categoryId;
            await this.prisma.category.upsert({
                where: { id: categoryId },
                update: {},
                create: { id: categoryId, name: categoryName },
            });
        }
        else {
            const cat = await this.prisma.category.upsert({
                where: { id: 'default-category' },
                update: {},
                create: { id: 'default-category', name: 'Встречи' },
            });
            categoryId = cat.id;
        }
        return this.prisma.event.create({
            data: {
                ownerId,
                title: dto.title,
                description: dto.description,
                categoryId,
                isPaid: !!dto.isPaid,
                price: (_c = dto.price) !== null && _c !== void 0 ? _c : null,
                currency: (_d = dto.currency) !== null && _d !== void 0 ? _d : null,
                requiresApproval: !!dto.requiresApproval,
                isAdultOnly: !!dto.isAdultOnly,
                startAt: start, endAt: end,
                city: dto.city,
                address: (_e = dto.address) !== null && _e !== void 0 ? _e : null,
                lat: (_f = dto.lat) !== null && _f !== void 0 ? _f : null, lon: (_g = dto.lon) !== null && _g !== void 0 ? _g : null,
                isAddressHidden: !!dto.isAddressHidden,
                capacity: (_h = dto.capacity) !== null && _h !== void 0 ? _h : null,
                coverUrl: (_j = dto.coverUrl) !== null && _j !== void 0 ? _j : null,
            },
        });
    }
    async update(id, ownerId, dto) {
        var _a, _b, _c, _d, _e, _f, _g, _h, _j, _k;
        const existing = await this.prisma.event.findUnique({ where: { id } });
        if (!existing || existing.ownerId !== ownerId) {
            throw new common_1.ForbiddenException();
        }
        const start = new Date(dto.startAt);
        const end = new Date(dto.endAt);
        if (isNaN(start.getTime()) || isNaN(end.getTime())) {
            throw new common_1.BadRequestException('Invalid startAt/endAt; must be ISO-8601');
        }
        const isPaid = !!dto.isPaid;
        let categoryId = (_a = dto.categoryId) === null || _a === void 0 ? void 0 : _a.trim();
        if (categoryId) {
            const categoryName = (_b = CATEGORY_TITLES[categoryId]) !== null && _b !== void 0 ? _b : categoryId;
            await this.prisma.category.upsert({
                where: { id: categoryId },
                update: {},
                create: { id: categoryId, name: categoryName },
            });
        }
        else {
            categoryId = existing.categoryId;
        }
        return this.prisma.event.update({
            where: { id },
            data: {
                title: dto.title,
                description: dto.description,
                categoryId,
                isPaid,
                price: isPaid ? (_c = dto.price) !== null && _c !== void 0 ? _c : null : null,
                currency: isPaid ? (_d = dto.currency) !== null && _d !== void 0 ? _d : null : null,
                requiresApproval: !!dto.requiresApproval,
                isAdultOnly: (_e = dto.isAdultOnly) !== null && _e !== void 0 ? _e : existing.isAdultOnly,
                startAt: start,
                endAt: end,
                city: dto.city,
                address: (_f = dto.address) !== null && _f !== void 0 ? _f : null,
                lat: (_g = dto.lat) !== null && _g !== void 0 ? _g : null,
                lon: (_h = dto.lon) !== null && _h !== void 0 ? _h : null,
                isAddressHidden: !!dto.isAddressHidden,
                capacity: (_j = dto.capacity) !== null && _j !== void 0 ? _j : null,
                coverUrl: (_k = dto.coverUrl) !== null && _k !== void 0 ? _k : null,
            },
        });
    }
    async listParticipating(userId) {
        await this.archiveExpiredEvents();
        const events = await this.prisma.event.findMany({
            where: {
                parts: {
                    some: {
                        userId,
                        status: { in: ['approved', 'requested'] },
                    },
                },
            },
            orderBy: { startAt: 'asc' },
            include: {
                parts: {
                    where: { userId },
                    select: { status: true },
                },
                owner: { select: OWNER_SELECT },
            },
        });
        return events.map(({ parts, ...rest }) => {
            var _a, _b;
            return ({
                ...rest,
                participationStatus: (_b = (_a = parts[0]) === null || _a === void 0 ? void 0 : _a.status) !== null && _b !== void 0 ? _b : null,
            });
        });
    }
    async createReview(eventId, authorId, dto) {
        const event = await this.prisma.event.findUnique({
            where: { id: eventId },
            select: {
                id: true,
                endAt: true,
                ownerId: true,
            },
        });
        if (!event)
            throw new common_1.NotFoundException('Событие не найдено');
        if (event.endAt.getTime() > Date.now()) {
            throw new common_1.BadRequestException('Оценить событие можно после завершения');
        }
        const participation = await this.prisma.participation.findUnique({
            where: { eventId_userId: { eventId, userId: authorId } },
        });
        if (!participation || participation.status !== 'approved') {
            throw new common_1.ForbiddenException('Оценка доступна только участникам события');
        }
        const existing = await this.prisma.review.findUnique({
            where: { eventId_authorId_target: { eventId, authorId, target: 'event' } },
        });
        if (existing) {
            throw new common_1.BadRequestException('Вы уже оставили отзыв для этого события');
        }
        try {
            return await this.prisma.review.create({
                data: {
                    eventId,
                    authorId,
                    target: 'event',
                    rating: dto.rating,
                    text: dto.text,
                },
                include: {
                    author: {
                        select: { id: true, firstName: true, lastName: true, avatarUrl: true, email: true },
                    },
                    event: { select: { id: true, title: true, startAt: true, endAt: true } },
                },
            });
        }
        catch (err) {
            throw new common_1.BadRequestException('Не удалось сохранить отзыв');
        }
    }
    async eventReviews(eventId, filter = {}) {
        const where = { eventId, target: 'event' };
        if (filter.rating)
            where.rating = filter.rating;
        return this.prisma.review.findMany({
            where,
            orderBy: { createdAt: 'desc' },
            include: {
                author: {
                    select: { id: true, firstName: true, lastName: true, avatarUrl: true, email: true },
                },
            },
        });
    }
    async myReview(eventId, userId) {
        return this.prisma.review.findUnique({
            where: { eventId_authorId_target: { eventId, authorId: userId, target: 'event' } },
        });
    }
    async archiveExpiredEvents() {
        await this.prisma.event.updateMany({
            where: { status: 'published', endAt: { lt: new Date() } },
            data: { status: 'draft' },
        });
    }
    calculateAge(birthDate) {
        const now = new Date();
        let age = now.getFullYear() - birthDate.getFullYear();
        const m = now.getMonth() - birthDate.getMonth();
        if (m < 0 || (m === 0 && now.getDate() < birthDate.getDate())) {
            age--;
        }
        return age;
    }
    isAdult(birthDate) {
        if (!birthDate)
            return true;
        return this.calculateAge(birthDate) >= 18;
    }
};
exports.EventsService = EventsService;
exports.EventsService = EventsService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService])
], EventsService);
//# sourceMappingURL=events.service.js.map