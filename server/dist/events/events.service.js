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
const notifications_service_1 = require("../notifications/notifications.service");
const CATEGORY_TITLES = {
    "default-category": "Встречи",
    music: "Музыка",
    sport: "Спорт",
    education: "Обучение",
    art: "Искусство",
    business: "Бизнес",
    family: "Семья",
    health: "Здоровье",
    travel: "Путешествия",
    food: "Еда",
    tech: "Технологии",
    games: "Игры",
};
const OWNER_SELECT = {
    id: true,
    firstName: true,
    lastName: true,
    avatarUrl: true,
};
const CAPACITY_OCCUPYING_STATUSES = ["approved", "attended"];
function haversineKm(a, b) {
    const toRad = (x) => (x * Math.PI) / 180;
    const R = 6371;
    const dLat = toRad(b.lat - a.lat);
    const dLon = toRad(b.lon - a.lon);
    const s1 = Math.sin(dLat / 2) ** 2 +
        Math.cos(toRad(a.lat)) * Math.cos(toRad(b.lat)) * Math.sin(dLon / 2) ** 2;
    return 2 * R * Math.asin(Math.sqrt(s1));
}
let EventsService = class EventsService {
    constructor(prisma, notifications) {
        this.prisma = prisma;
        this.notifications = notifications;
    }
    async computeAvailability(events) {
        var _a;
        const availability = new Map();
        if (events.length === 0) {
            return availability;
        }
        const counts = await this.prisma.participation.groupBy({
            by: ["eventId"],
            where: {
                eventId: { in: events.map((event) => event.id) },
                status: { in: Array.from(CAPACITY_OCCUPYING_STATUSES) },
            },
            _count: { _all: true },
        });
        const countMap = new Map(counts.map((c) => {
            var _a, _b;
            return [
                c.eventId,
                (_b = (typeof c._count === "number" ? c._count : (_a = c._count) === null || _a === void 0 ? void 0 : _a._all)) !== null && _b !== void 0 ? _b : 0,
            ];
        }));
        for (const event of events) {
            if (event.capacity == null) {
                availability.set(event.id, null);
            }
            else {
                const taken = (_a = countMap.get(event.id)) !== null && _a !== void 0 ? _a : 0;
                availability.set(event.id, Math.max(event.capacity - taken, 0));
            }
        }
        return availability;
    }
    async list(params, options = {}) {
        var _a;
        await this.archiveExpiredEvents();
        const { city, categoryId, lat, lon, radiusKm = 50, isPaid, ownerId, excludeMine, timeframe, startDate, endDate, } = params;
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
            where.status = "published";
        }
        if (ownerId)
            where.ownerId = ownerId;
        if (city)
            where.city = city;
        if (categoryId)
            where.categoryId = categoryId;
        const preferredCategories = [];
        if (!categoryId && !ownerId && viewerId) {
            const preferences = await this.prisma.userCategoryPreference.findMany({
                where: { userId: viewerId },
                select: { categoryId: true },
            });
            if (preferences.length > 0) {
                preferredCategories.push(...preferences.map((p) => p.categoryId));
            }
        }
        if (typeof isPaid === "boolean")
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
        if (startDate || endDate || timeframe) {
            const range = startDate || endDate
                ? this.resolveCustomRange(startDate, endDate)
                : this.resolveTimeframe(timeframe);
            if (range) {
                where.startAt = {
                    ...((_a = where.startAt) !== null && _a !== void 0 ? _a : {}),
                    gte: range.start,
                    lt: range.end,
                };
            }
        }
        const events = await this.prisma.event.findMany({
            where: lat != null && lon != null
                ? {
                    ...where,
                    lat: { not: null },
                    lon: { not: null },
                    endAt: { gte: new Date() },
                }
                : where,
            orderBy: { startAt: "asc" },
            include: {
                owner: { select: OWNER_SELECT },
            },
        });
        const availabilityMap = await this.computeAvailability(events);
        const preferredSet = new Set(preferredCategories);
        const withAvailability = events.map((event) => {
            var _a;
            return ({
                ...event,
                availableSpots: (_a = availabilityMap.get(event.id)) !== null && _a !== void 0 ? _a : null,
            });
        });
        if (preferredSet.size > 0 && lat == null && lon == null) {
            withAvailability.sort((a, b) => {
                const aPreferred = preferredSet.has(a.categoryId);
                const bPreferred = preferredSet.has(b.categoryId);
                if (aPreferred !== bPreferred) {
                    return aPreferred ? -1 : 1;
                }
                return a.startAt.getTime() - b.startAt.getTime();
            });
        }
        if (lat != null && lon != null) {
            return withAvailability
                .map((event) => ({
                ...event,
                distanceKm: haversineKm({ lat, lon }, { lat: event.lat, lon: event.lon }),
            }))
                .filter((event) => { var _a; return ((_a = event.distanceKm) !== null && _a !== void 0 ? _a : Number.POSITIVE_INFINITY) <= radiusKm; })
                .sort((a, b) => { var _a, _b; return ((_a = a.distanceKm) !== null && _a !== void 0 ? _a : 0) - ((_b = b.distanceKm) !== null && _b !== void 0 ? _b : 0); });
        }
        return withAvailability;
    }
    async getOne(id, currentUserId) {
        var _a;
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
        const availabilityMap = await this.computeAvailability([e]);
        let result = { ...e, availableSpots: (_a = availabilityMap.get(e.id)) !== null && _a !== void 0 ? _a : null };
        if (e.isAdultOnly && currentUserId && e.ownerId !== currentUserId) {
            const viewer = await this.prisma.user.findUnique({
                where: { id: currentUserId },
                select: { birthDate: true },
            });
            if (!this.isAdult(viewer === null || viewer === void 0 ? void 0 : viewer.birthDate)) {
                throw new common_1.ForbiddenException("Событие доступно только пользователям 18+");
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
                approved = (part === null || part === void 0 ? void 0 : part.status) === "approved" || (part === null || part === void 0 ? void 0 : part.status) === "attended";
            }
            if (!isOwner && !approved) {
                result = {
                    ...result,
                    address: null,
                    lat: null,
                    lon: null,
                    isAddressHidden: true,
                };
            }
        }
        return result;
    }
    async setStatus(id, status, userId) {
        return this.prisma.$transaction(async (tx) => {
            const event = await tx.event.findUnique({ where: { id } });
            if (!event || event.ownerId !== userId)
                throw new common_1.ForbiddenException();
            if (status === "published" && event.status !== "published") {
                await tx.participation.deleteMany({ where: { eventId: id } });
            }
            return tx.event.update({ where: { id }, data: { status } });
        });
    }
    async remove(id, userId) {
        const e = await this.prisma.event.findUnique({ where: { id } });
        if (!e || e.ownerId !== userId)
            throw new common_1.ForbiddenException();
        return this.prisma.event.delete({ where: { id } });
    }
    async create(ownerId, dto) {
        var _a, _b, _c, _d, _e, _f, _g, _h, _j;
        if (dto.capacity == null || Number.isNaN(dto.capacity)) {
            throw new common_1.BadRequestException("Укажите количество участников (до 48).");
        }
        if (dto.capacity > 48 || dto.capacity < 1) {
            throw new common_1.BadRequestException("Максимальное количество участников — 48.");
        }
        const start = new Date(dto.startAt);
        const end = new Date(dto.endAt);
        if (isNaN(start.getTime()) || isNaN(end.getTime())) {
            throw new common_1.BadRequestException("Invalid startAt/endAt; must be ISO-8601");
        }
        if (dto.capacity == null || Number.isNaN(dto.capacity)) {
            throw new common_1.BadRequestException("Укажите количество участников (до 48).");
        }
        if (dto.capacity > 48 || dto.capacity < 1) {
            throw new common_1.BadRequestException("Максимальное количество участников — 48.");
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
                where: { id: "default-category" },
                update: {},
                create: { id: "default-category", name: "Встречи" },
            });
            categoryId = cat.id;
        }
        const event = await this.prisma.event.create({
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
                allowStories: (_e = dto.allowStories) !== null && _e !== void 0 ? _e : true,
                startAt: start,
                endAt: end,
                city: dto.city,
                address: (_f = dto.address) !== null && _f !== void 0 ? _f : null,
                lat: (_g = dto.lat) !== null && _g !== void 0 ? _g : null,
                lon: (_h = dto.lon) !== null && _h !== void 0 ? _h : null,
                isAddressHidden: !!dto.isAddressHidden,
                capacity: dto.capacity,
                coverUrl: (_j = dto.coverUrl) !== null && _j !== void 0 ? _j : null,
            },
        });
        await this.notifications.notifyFollowersAboutNewEvent(event.id);
        return event;
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
            throw new common_1.BadRequestException("Invalid startAt/endAt; must be ISO-8601");
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
        const updated = await this.prisma.event.update({
            where: { id },
            data: {
                title: dto.title,
                description: dto.description,
                categoryId,
                isPaid,
                price: isPaid ? ((_c = dto.price) !== null && _c !== void 0 ? _c : null) : null,
                currency: isPaid ? ((_d = dto.currency) !== null && _d !== void 0 ? _d : null) : null,
                requiresApproval: !!dto.requiresApproval,
                isAdultOnly: (_e = dto.isAdultOnly) !== null && _e !== void 0 ? _e : existing.isAdultOnly,
                allowStories: (_f = dto.allowStories) !== null && _f !== void 0 ? _f : existing.allowStories,
                startAt: start,
                endAt: end,
                city: dto.city,
                address: (_g = dto.address) !== null && _g !== void 0 ? _g : null,
                lat: (_h = dto.lat) !== null && _h !== void 0 ? _h : null,
                lon: (_j = dto.lon) !== null && _j !== void 0 ? _j : null,
                isAddressHidden: !!dto.isAddressHidden,
                capacity: dto.capacity,
                coverUrl: (_k = dto.coverUrl) !== null && _k !== void 0 ? _k : null,
            },
        });
        await this.notifications.notifyEventUpdated(id, ownerId);
        return updated;
    }
    async listParticipating(userId) {
        await this.archiveExpiredEvents();
        const events = await this.prisma.event.findMany({
            where: {
                parts: {
                    some: {
                        userId,
                        status: { in: ["approved", "attended", "requested"] },
                    },
                },
            },
            orderBy: { startAt: "asc" },
            include: {
                parts: {
                    where: { userId },
                    select: { status: true },
                },
                owner: { select: OWNER_SELECT },
            },
        });
        if (events.length === 0)
            return [];
        const availabilityMap = await this.computeAvailability(events);
        const reviewed = await this.prisma.review.findMany({
            where: {
                authorId: userId,
                target: "event",
                eventId: { in: events.map((e) => e.id) },
            },
            select: { eventId: true },
        });
        const reviewedSet = new Set(reviewed.map((r) => r.eventId));
        return events.map(({ parts, ...rest }) => {
            var _a, _b, _c;
            return ({
                ...rest,
                participationStatus: (_b = (_a = parts[0]) === null || _a === void 0 ? void 0 : _a.status) !== null && _b !== void 0 ? _b : null,
                reviewed: reviewedSet.has(rest.id),
                availableSpots: (_c = availabilityMap.get(rest.id)) !== null && _c !== void 0 ? _c : null,
            });
        });
    }
    async listStories(eventId) {
        const event = await this.prisma.event.findUnique({
            where: { id: eventId },
            select: { id: true },
        });
        if (!event) {
            throw new common_1.NotFoundException("Событие не найдено");
        }
        const cutoff = new Date(Date.now() - 24 * 60 * 60 * 1000);
        return this.prisma.eventStory.findMany({
            where: { eventId, createdAt: { gte: cutoff } },
            orderBy: { createdAt: "desc" },
            include: {
                author: {
                    select: {
                        id: true,
                        firstName: true,
                        lastName: true,
                        avatarUrl: true,
                    },
                },
            },
        });
    }
    async createStory(eventId, userId, dto) {
        var _a, _b;
        const event = await this.prisma.event.findUnique({
            where: { id: eventId },
            select: {
                id: true,
                ownerId: true,
                startAt: true,
                endAt: true,
                allowStories: true,
            },
        });
        if (!event) {
            throw new common_1.NotFoundException("Событие не найдено");
        }
        if (event.startAt.getTime() > Date.now()) {
            throw new common_1.BadRequestException("Добавлять истории можно после начала события");
        }
        if (((_a = event.endAt) === null || _a === void 0 ? void 0 : _a.getTime()) && event.endAt.getTime() < Date.now()) {
            throw new common_1.BadRequestException("Событие завершилось — истории больше нельзя добавлять");
        }
        if (!event.allowStories) {
            throw new common_1.BadRequestException("Организатор отключил истории для этого события");
        }
        const trimmedUrl = ((_b = dto.url) !== null && _b !== void 0 ? _b : "").trim();
        if (!trimmedUrl) {
            throw new common_1.BadRequestException("Укажите ссылку на изображение истории");
        }
        let canAdd = event.ownerId === userId;
        if (!canAdd) {
            const participation = await this.prisma.participation.findUnique({
                where: { eventId_userId: { eventId, userId } },
                select: { status: true },
            });
            canAdd =
                (participation === null || participation === void 0 ? void 0 : participation.status) === "approved" ||
                    (participation === null || participation === void 0 ? void 0 : participation.status) === "attended";
        }
        if (!canAdd) {
            throw new common_1.ForbiddenException("Только участники события могут добавлять истории");
        }
        const story = await this.prisma.eventStory.create({
            data: {
                eventId,
                authorId: userId,
                url: trimmedUrl,
            },
            include: {
                author: {
                    select: {
                        id: true,
                        firstName: true,
                        lastName: true,
                        avatarUrl: true,
                    },
                },
            },
        });
        await Promise.all([
            this.notifications.notifyOrganizerStoryAdded(eventId, event.ownerId, userId, story.id),
            this.notifications.notifyFollowersStoryAdded(eventId, userId, story.id),
        ]);
        return story;
    }
    async deleteStory(eventId, storyId, userId) {
        const [event, story] = await Promise.all([
            this.prisma.event.findUnique({
                where: { id: eventId },
                select: { ownerId: true },
            }),
            this.prisma.eventStory.findUnique({
                where: { id: storyId },
                select: { id: true, eventId: true, authorId: true },
            }),
        ]);
        if (!event) {
            throw new common_1.NotFoundException("Событие не найдено");
        }
        if (!story || story.eventId !== eventId) {
            throw new common_1.NotFoundException("История не найдена");
        }
        const isOwner = event.ownerId === userId;
        const isAuthor = story.authorId === userId;
        if (!isOwner && !isAuthor) {
            throw new common_1.ForbiddenException("Удалять историю может только организатор или автор");
        }
        await this.prisma.eventStory.delete({ where: { id: storyId } });
        return { ok: true };
    }
    async listPhotos(eventId) {
        return this.prisma.eventPhoto.findMany({
            where: { eventId },
            orderBy: { createdAt: "desc" },
            include: {
                author: {
                    select: {
                        id: true,
                        firstName: true,
                        lastName: true,
                        avatarUrl: true,
                    },
                },
            },
        });
    }
    async createPhoto(eventId, userId, dto) {
        var _a;
        const event = await this.prisma.event.findUnique({
            where: { id: eventId },
            select: { ownerId: true, endAt: true },
        });
        if (!event) {
            throw new common_1.NotFoundException("Событие не найдено");
        }
        if (!event.endAt || event.endAt.getTime() > Date.now()) {
            throw new common_1.BadRequestException("Фотоотчет доступен после завершения события");
        }
        let canAdd = event.ownerId === userId;
        if (!canAdd) {
            const participation = await this.prisma.participation.findUnique({
                where: { eventId_userId: { eventId, userId } },
                select: { status: true },
            });
            canAdd =
                (participation === null || participation === void 0 ? void 0 : participation.status) === "approved" ||
                    (participation === null || participation === void 0 ? void 0 : participation.status) === "attended";
        }
        if (!canAdd) {
            throw new common_1.ForbiddenException("Добавлять фото могут только участники и организатор");
        }
        const trimmedUrl = ((_a = dto.url) !== null && _a !== void 0 ? _a : "").trim();
        if (!trimmedUrl) {
            throw new common_1.BadRequestException("Укажите ссылку на изображение");
        }
        const photo = await this.prisma.eventPhoto.create({
            data: {
                eventId,
                authorId: userId,
                url: trimmedUrl,
            },
            include: {
                author: {
                    select: {
                        id: true,
                        firstName: true,
                        lastName: true,
                        avatarUrl: true,
                    },
                },
            },
        });
        await this.notifications.notifyOrganizerPhotoAdded(eventId, event.ownerId, userId, photo.id);
        return photo;
    }
    async deletePhoto(eventId, photoId, userId) {
        const [event, photo] = await Promise.all([
            this.prisma.event.findUnique({
                where: { id: eventId },
                select: { ownerId: true },
            }),
            this.prisma.eventPhoto.findUnique({
                where: { id: photoId },
                select: { id: true, eventId: true, authorId: true },
            }),
        ]);
        if (!event) {
            throw new common_1.NotFoundException("Событие не найдено");
        }
        if (!photo || photo.eventId !== eventId) {
            throw new common_1.NotFoundException("Фото не найдено");
        }
        const isOwner = event.ownerId === userId;
        const isAuthor = photo.authorId === userId;
        if (!isOwner && !isAuthor) {
            throw new common_1.ForbiddenException("Удалять фото может только организатор или автор");
        }
        await this.prisma.eventPhoto.delete({ where: { id: photoId } });
        return { ok: true };
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
            throw new common_1.NotFoundException("Событие не найдено");
        if (event.endAt.getTime() > Date.now()) {
            throw new common_1.BadRequestException("Оценить событие можно после завершения");
        }
        const participation = await this.prisma.participation.findUnique({
            where: { eventId_userId: { eventId, userId: authorId } },
        });
        if (!participation || participation.status !== "approved") {
            throw new common_1.ForbiddenException("Оценка доступна только участникам события");
        }
        const existing = await this.prisma.review.findFirst({
            where: { eventId, authorId, target: "event" },
        });
        if (existing) {
            throw new common_1.BadRequestException("Вы уже оставили отзыв для этого события");
        }
        try {
            return await this.prisma.review.create({
                data: {
                    eventId,
                    authorId,
                    target: "event",
                    rating: dto.rating,
                    text: dto.text,
                },
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
        catch (err) {
            throw new common_1.BadRequestException("Не удалось сохранить отзыв");
        }
    }
    async eventReviews(eventId, filter = {}) {
        const where = { eventId, target: "event" };
        if (filter.rating)
            where.rating = filter.rating;
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
            },
        });
    }
    async myReview(eventId, userId) {
        return this.prisma.review.findFirst({
            where: { eventId, authorId: userId, target: "event" },
        });
    }
    async archiveExpiredEvents() {
        await this.prisma.event.updateMany({
            where: { status: "published", endAt: { lt: new Date() } },
            data: { status: "draft" },
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
    resolveTimeframe(timeframe) {
        const now = new Date();
        const start = new Date(now);
        start.setHours(0, 0, 0, 0);
        if (timeframe === "this-week" || timeframe === "next-week") {
            const day = start.getDay();
            const diff = day === 0 ? -6 : 1 - day;
            start.setDate(start.getDate() + diff);
            if (timeframe === "next-week") {
                start.setDate(start.getDate() + 7);
            }
            const end = new Date(start);
            end.setDate(start.getDate() + 7);
            return { start, end };
        }
        if (timeframe === "this-month") {
            start.setDate(1);
            const end = new Date(start.getFullYear(), start.getMonth() + 1, 1);
            return { start, end };
        }
        return null;
    }
    resolveCustomRange(start, end) {
        let startDate;
        let endDate;
        if (start) {
            const parsed = new Date(start);
            if (!Number.isNaN(parsed.getTime())) {
                parsed.setHours(0, 0, 0, 0);
                startDate = parsed;
            }
        }
        if (end) {
            const parsedEnd = new Date(end);
            if (!Number.isNaN(parsedEnd.getTime())) {
                parsedEnd.setHours(0, 0, 0, 0);
                endDate = new Date(parsedEnd.getTime());
                endDate.setDate(endDate.getDate() + 1);
            }
        }
        if (!startDate && !endDate)
            return null;
        const startOrNow = startDate !== null && startDate !== void 0 ? startDate : new Date();
        const endOrStart = endDate !== null && endDate !== void 0 ? endDate : new Date(startOrNow.getFullYear(), startOrNow.getMonth(), startOrNow.getDate() + 1);
        return { start: startOrNow, end: endOrStart };
    }
};
exports.EventsService = EventsService;
exports.EventsService = EventsService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService,
        notifications_service_1.NotificationsService])
], EventsService);
//# sourceMappingURL=events.service.js.map