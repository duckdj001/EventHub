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
exports.ParticipationsService = void 0;
const common_1 = require("@nestjs/common");
const prisma_service_1 = require("../common/prisma.service");
const OWNER_CAN_REQUEST_ERROR = 'Организатор уже участвует по умолчанию';
let ParticipationsService = class ParticipationsService {
    constructor(prisma) {
        this.prisma = prisma;
    }
    async getEventOrThrow(eventId) {
        const event = await this.prisma.event.findUnique({
            where: { id: eventId },
            select: { id: true, ownerId: true, requiresApproval: true, isAdultOnly: true },
        });
        if (!event)
            throw new common_1.NotFoundException('Событие не найдено');
        return event;
    }
    async request(eventId, userId) {
        const event = await this.getEventOrThrow(eventId);
        if (event.ownerId === userId) {
            throw new common_1.BadRequestException(OWNER_CAN_REQUEST_ERROR);
        }
        if (event.isAdultOnly) {
            const user = await this.prisma.user.findUnique({
                where: { id: userId },
                select: { birthDate: true },
            });
            if (!this.isAdult(user === null || user === void 0 ? void 0 : user.birthDate)) {
                throw new common_1.BadRequestException('Событие доступно только пользователям 18+');
            }
        }
        const status = event.requiresApproval ? 'requested' : 'approved';
        const participation = await this.prisma.participation.upsert({
            where: { eventId_userId: { eventId, userId } },
            update: { status },
            create: { eventId, userId, status },
            include: { user: { select: { id: true, firstName: true, lastName: true, avatarUrl: true, email: true } } },
        });
        return { ...participation, autoconfirmed: !event.requiresApproval };
    }
    async listForOwner(eventId, ownerId) {
        const event = await this.prisma.event.findUnique({
            where: { id: eventId },
            select: { ownerId: true },
        });
        if (!event)
            throw new common_1.NotFoundException('Событие не найдено');
        if (event.ownerId !== ownerId)
            throw new common_1.ForbiddenException('Нет доступа');
        const participations = await this.prisma.participation.findMany({
            where: { eventId },
            orderBy: [
                { status: 'asc' },
                { createdAt: 'asc' },
            ],
            include: {
                user: {
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
        const ratings = await this.prisma.review.findMany({
            where: {
                eventId,
                target: 'participant',
                targetUserId: { in: participations.map((p) => p.userId) },
            },
            select: {
                id: true,
                rating: true,
                text: true,
                targetUserId: true,
                createdAt: true,
            },
        });
        const ratingMap = new Map();
        ratings.forEach((r) => {
            if (r.targetUserId)
                ratingMap.set(r.targetUserId, r);
        });
        return participations.map((p) => {
            var _a;
            return ({
                ...p,
                participantReview: (_a = ratingMap.get(p.userId)) !== null && _a !== void 0 ? _a : null,
            });
        });
    }
    async changeStatus(eventId, ownerId, participationId, status) {
        const participation = await this.prisma.participation.findUnique({
            where: { id: participationId },
            include: {
                event: { select: { ownerId: true, id: true } },
            },
        });
        if (!participation || participation.eventId !== eventId) {
            throw new common_1.NotFoundException('Заявка не найдена');
        }
        if (participation.event.ownerId !== ownerId) {
            throw new common_1.ForbiddenException('Нет доступа');
        }
        return this.prisma.participation.update({
            where: { id: participationId },
            data: { status },
            include: {
                user: {
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
    async getForUser(eventId, userId) {
        const participation = await this.prisma.participation.findUnique({
            where: {
                eventId_userId: { eventId, userId },
            },
        });
        if (!participation)
            return null;
        const review = await this.prisma.review.findUnique({
            where: {
                eventId_targetUserId_target: {
                    eventId,
                    targetUserId: userId,
                    target: 'participant',
                },
            },
        });
        return { ...participation, participantReview: review };
    }
    async cancel(eventId, userId) {
        const participation = await this.prisma.participation.findUnique({
            where: { eventId_userId: { eventId, userId } },
            include: {
                user: {
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
        if (!participation) {
            throw new common_1.NotFoundException('Заявка не найдена');
        }
        const event = await this.prisma.event.findUnique({
            where: { id: eventId },
            select: { endAt: true },
        });
        if (event && event.endAt.getTime() <= Date.now()) {
            throw new common_1.BadRequestException('Нельзя отменить участие после завершения события');
        }
        if (participation.status === 'cancelled') {
            return participation;
        }
        return this.prisma.participation.update({
            where: { id: participation.id },
            data: { status: 'cancelled' },
            include: {
                user: {
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
    async rateParticipant(eventId, ownerId, participationId, dto) {
        const participation = await this.prisma.participation.findUnique({
            where: { id: participationId },
            include: {
                event: { select: { ownerId: true, endAt: true, id: true } },
                user: { select: { id: true, firstName: true, lastName: true, avatarUrl: true, email: true } },
            },
        });
        if (!participation || participation.eventId !== eventId) {
            throw new common_1.NotFoundException('Заявка не найдена');
        }
        if (participation.event.ownerId !== ownerId) {
            throw new common_1.ForbiddenException('Нет доступа');
        }
        if (participation.event.endAt.getTime() > Date.now()) {
            throw new common_1.BadRequestException('Оценить участника можно после завершения события');
        }
        const review = await this.prisma.review.upsert({
            where: {
                eventId_targetUserId_target: {
                    eventId,
                    targetUserId: participation.userId,
                    target: 'participant',
                },
            },
            update: { rating: dto.rating, text: dto.text },
            create: {
                eventId,
                authorId: ownerId,
                target: 'participant',
                targetUserId: participation.userId,
                rating: dto.rating,
                text: dto.text,
            },
            include: {
                author: {
                    select: { id: true, firstName: true, lastName: true, avatarUrl: true, email: true },
                },
                event: { select: { id: true, title: true } },
            },
        });
        return review;
    }
    isAdult(birthDate) {
        if (!birthDate)
            return true;
        const now = new Date();
        let age = now.getFullYear() - birthDate.getFullYear();
        const m = now.getMonth() - birthDate.getMonth();
        if (m < 0 || (m === 0 && now.getDate() < birthDate.getDate())) {
            age--;
        }
        return age >= 18;
    }
};
exports.ParticipationsService = ParticipationsService;
exports.ParticipationsService = ParticipationsService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService])
], ParticipationsService);
//# sourceMappingURL=participations.service.js.map