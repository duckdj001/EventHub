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
    list(params) {
        const { city, categoryId, lat, lon, radiusKm = 50, isPaid, ownerId } = params;
        const baseWhere = { status: 'published' };
        if (categoryId)
            baseWhere.categoryId = categoryId;
        if (typeof isPaid === 'boolean')
            baseWhere.isPaid = isPaid;
        if (ownerId)
            baseWhere.ownerId = ownerId;
        if (lat != null && lon != null) {
            return this.prisma.event.findMany({
                where: { status: 'published', categoryId, lat: { not: null }, lon: { not: null } },
                orderBy: { startAt: 'asc' },
            }).then(list => {
                const withD = list.map(e => ({
                    ...e,
                    distanceKm: haversineKm({ lat, lon }, { lat: e.lat, lon: e.lon }),
                }))
                    .filter(e => e.distanceKm <= radiusKm)
                    .sort((a, b) => a.distanceKm - b.distanceKm);
                return withD;
            });
        }
        return this.prisma.event.findMany({
            where: { status: 'published', city, categoryId },
            orderBy: { startAt: 'asc' },
        });
    }
    async getOne(id, currentUserId) {
        const e = await this.prisma.event.findUnique({ where: { id } });
        if (!e)
            return null;
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
        var _a, _b, _c, _d, _e, _f, _g;
        const start = new Date(dto.startAt);
        const end = new Date(dto.endAt);
        if (isNaN(start.getTime()) || isNaN(end.getTime())) {
            throw new common_1.BadRequestException('Invalid startAt/endAt; must be ISO-8601');
        }
        let categoryId = dto.categoryId;
        if (!categoryId) {
            const cat = await this.prisma.category.upsert({
                where: { id: 'default-category' }, update: {}, create: { id: 'default-category', name: 'Встречи' },
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
                price: (_a = dto.price) !== null && _a !== void 0 ? _a : null,
                currency: (_b = dto.currency) !== null && _b !== void 0 ? _b : null,
                requiresApproval: !!dto.requiresApproval,
                startAt: start, endAt: end,
                city: dto.city,
                address: (_c = dto.address) !== null && _c !== void 0 ? _c : null,
                lat: (_d = dto.lat) !== null && _d !== void 0 ? _d : null, lon: (_e = dto.lon) !== null && _e !== void 0 ? _e : null,
                isAddressHidden: !!dto.isAddressHidden,
                capacity: (_f = dto.capacity) !== null && _f !== void 0 ? _f : null,
                coverUrl: (_g = dto.coverUrl) !== null && _g !== void 0 ? _g : null,
            },
        });
    }
};
exports.EventsService = EventsService;
exports.EventsService = EventsService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService])
], EventsService);
//# sourceMappingURL=events.service.js.map