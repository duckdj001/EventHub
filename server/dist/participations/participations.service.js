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
const notifications_service_1 = require("../notifications/notifications.service");
const OWNER_CAN_REQUEST_ERROR = 'Организатор уже участвует по умолчанию';
const SEAT_OCCUPYING_STATUSES = ['approved', 'attended'];
let ParticipationsService = class ParticipationsService {
    constructor(prisma, notifications) {
        this.prisma = prisma;
        this.notifications = notifications;
    }
    async getEventOrThrow(eventId) {
        const event = await this.prisma.event.findUnique({
            where: { id: eventId },
            select: { id: true, ownerId: true, requiresApproval: true, isAdultOnly: true, capacity: true },
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
        const participation = await this.prisma.$transaction(async (tx) => {
            const existing = await tx.participation.findUnique({
                where: { eventId_userId: { eventId, userId } },
                select: { id: true, status: true },
            });
            if (status === 'approved' && event.capacity != null) {
                const alreadyApproved = existing ? this.isSeatOccupyingStatus(existing.status) : false;
                if (!alreadyApproved) {
                    const approvedCount = await tx.participation.count({
                        where: {
                            eventId,
                            status: { in: Array.from(SEAT_OCCUPYING_STATUSES) },
                        },
                    });
                    if (approvedCount >= event.capacity) {
                        throw new common_1.BadRequestException('Свободных мест не осталось');
                    }
                }
            }
            return tx.participation.upsert({
                where: { eventId_userId: { eventId, userId } },
                update: { status },
                create: { eventId, userId, status },
                include: { user: { select: { id: true, firstName: true, lastName: true, avatarUrl: true, email: true } } },
            });
        });
        const availableSpots = await this.calculateRemainingSpots(eventId, event.capacity);
        if (participation.status === 'approved') {
            await this.notifications.notifyParticipationApproved(eventId, userId);
        }
        return { ...participation, autoconfirmed: !event.requiresApproval, availableSpots };
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
                event: { select: { ownerId: true, id: true, capacity: true } },
            },
        });
        if (!participation || participation.eventId !== eventId) {
            throw new common_1.NotFoundException('Заявка не найдена');
        }
        if (participation.event.ownerId !== ownerId) {
            throw new common_1.ForbiddenException('Нет доступа');
        }
        const updated = await this.prisma.$transaction(async (tx) => {
            if (status === 'approved' && participation.event.capacity != null) {
                const approvedCount = await tx.participation.count({
                    where: {
                        eventId,
                        id: { not: participationId },
                        status: { in: Array.from(SEAT_OCCUPYING_STATUSES) },
                    },
                });
                if (approvedCount >= participation.event.capacity) {
                    throw new common_1.BadRequestException('Свободных мест не осталось');
                }
            }
            return tx.participation.update({
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
        });
        const availableSpots = await this.calculateRemainingSpots(eventId, participation.event.capacity);
        if (updated.status === 'approved') {
            await this.notifications.notifyParticipationApproved(eventId, updated.userId, ownerId);
        }
        return { ...updated, availableSpots };
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
        const availableSpots = await this.calculateRemainingSpots(eventId);
        return { ...participation, participantReview: review, availableSpots };
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
            select: { endAt: true, capacity: true },
        });
        if (event && event.endAt.getTime() <= Date.now()) {
            throw new common_1.BadRequestException('Нельзя отменить участие после завершения события');
        }
        if (participation.status === 'cancelled') {
            const availableSpots = await this.calculateRemainingSpots(eventId, event === null || event === void 0 ? void 0 : event.capacity);
            return { ...participation, availableSpots };
        }
        const updated = await this.prisma.participation.update({
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
        const availableSpots = await this.calculateRemainingSpots(eventId, event === null || event === void 0 ? void 0 : event.capacity);
        return { ...updated, availableSpots };
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
                event: { select: { id: true, title: true, startAt: true, endAt: true } },
            },
        });
        return review;
    }
    async calculateRemainingSpots(eventId, capacity) {
        var _a, _b;
        const eventCapacity = (_b = capacity !== null && capacity !== void 0 ? capacity : (_a = (await this.prisma.event.findUnique({
            where: { id: eventId },
            select: { capacity: true },
        }))) === null || _a === void 0 ? void 0 : _a.capacity) !== null && _b !== void 0 ? _b : null;
        if (eventCapacity == null) {
            return null;
        }
        const approvedCount = await this.prisma.participation.count({
            where: {
                eventId,
                status: { in: Array.from(SEAT_OCCUPYING_STATUSES) },
            },
        });
        return Math.max(eventCapacity - approvedCount, 0);
    }
    isSeatOccupyingStatus(status) {
        if (!status)
            return false;
        return SEAT_OCCUPYING_STATUSES.includes(status);
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
    __metadata("design:paramtypes", [prisma_service_1.PrismaService, notifications_service_1.NotificationsService])
], ParticipationsService);
//# sourceMappingURL=participations.service.js.map