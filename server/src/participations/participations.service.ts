import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';

import { PrismaService } from '../common/prisma.service';
import { RateParticipantDto } from './dto';
import { NotificationsService } from '../notifications/notifications.service';

const OWNER_CAN_REQUEST_ERROR = 'Организатор уже участвует по умолчанию';
const SEAT_OCCUPYING_STATUSES = ['approved', 'attended'] as const;

type SeatOccupyingStatus = (typeof SEAT_OCCUPYING_STATUSES)[number];

@Injectable()
export class ParticipationsService {
  constructor(private prisma: PrismaService, private notifications: NotificationsService) {}

  private async getEventOrThrow(eventId: string) {
    const event = await this.prisma.event.findUnique({
      where: { id: eventId },
      select: { id: true, ownerId: true, requiresApproval: true, isAdultOnly: true, capacity: true },
    });
    if (!event) throw new NotFoundException('Событие не найдено');
    return event;
  }

  async request(eventId: string, userId: string) {
    const event = await this.getEventOrThrow(eventId);
    if (event.ownerId === userId) {
      throw new BadRequestException(OWNER_CAN_REQUEST_ERROR);
    }

    if (event.isAdultOnly) {
      const user = await this.prisma.user.findUnique({
        where: { id: userId },
        select: { birthDate: true },
      });
      if (!this.isAdult(user?.birthDate)) {
        throw new BadRequestException('Событие доступно только пользователям 18+');
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
            throw new BadRequestException('Свободных мест не осталось');
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

  async listForOwner(eventId: string, ownerId: string) {
    const event = await this.prisma.event.findUnique({
      where: { id: eventId },
      select: { ownerId: true },
    });
    if (!event) throw new NotFoundException('Событие не найдено');
    if (event.ownerId !== ownerId) throw new ForbiddenException('Нет доступа');

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
    const ratingMap = new Map<string, typeof ratings[number]>();
    ratings.forEach((r) => {
      if (r.targetUserId) ratingMap.set(r.targetUserId, r);
    });

    return participations.map((p) => ({
      ...p,
      participantReview: ratingMap.get(p.userId) ?? null,
    }));
  }

  async changeStatus(eventId: string, ownerId: string, participationId: string, status: 'approved' | 'rejected' | 'cancelled') {
    const participation = await this.prisma.participation.findUnique({
      where: { id: participationId },
      include: {
        event: { select: { ownerId: true, id: true, capacity: true } },
      },
    });
    if (!participation || participation.eventId !== eventId) {
      throw new NotFoundException('Заявка не найдена');
    }
    if (participation.event.ownerId !== ownerId) {
      throw new ForbiddenException('Нет доступа');
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
          throw new BadRequestException('Свободных мест не осталось');
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

  async getForUser(eventId: string, userId: string) {
    const participation = await this.prisma.participation.findUnique({
      where: {
        eventId_userId: { eventId, userId },
      },
    });
    if (!participation) return null;

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

  async cancel(eventId: string, userId: string) {
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
      throw new NotFoundException('Заявка не найдена');
    }

    const event = await this.prisma.event.findUnique({
      where: { id: eventId },
      select: { endAt: true, capacity: true },
    });
    if (event && event.endAt.getTime() <= Date.now()) {
      throw new BadRequestException('Нельзя отменить участие после завершения события');
    }

    if (participation.status === 'cancelled') {
      const availableSpots = await this.calculateRemainingSpots(eventId, event?.capacity);
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

    const availableSpots = await this.calculateRemainingSpots(eventId, event?.capacity);

    return { ...updated, availableSpots };
  }

  async rateParticipant(eventId: string, ownerId: string, participationId: string, dto: RateParticipantDto) {
    const participation = await this.prisma.participation.findUnique({
      where: { id: participationId },
      include: {
        event: { select: { ownerId: true, endAt: true, id: true } },
        user: { select: { id: true, firstName: true, lastName: true, avatarUrl: true, email: true } },
      },
    });
    if (!participation || participation.eventId !== eventId) {
      throw new NotFoundException('Заявка не найдена');
    }
    if (participation.event.ownerId !== ownerId) {
      throw new ForbiddenException('Нет доступа');
    }
    if (participation.event.endAt.getTime() > Date.now()) {
      throw new BadRequestException('Оценить участника можно после завершения события');
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

  private async calculateRemainingSpots(eventId: string, capacity?: number | null) {
    const eventCapacity =
      capacity ??
      (await this.prisma.event.findUnique({
        where: { id: eventId },
        select: { capacity: true },
      }))?.capacity ?? null;

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

  private isSeatOccupyingStatus(status?: string | null): status is SeatOccupyingStatus {
    if (!status) return false;
    return SEAT_OCCUPYING_STATUSES.includes(status as SeatOccupyingStatus);
  }

  private isAdult(birthDate?: Date | null): boolean {
    if (!birthDate) return true;
    const now = new Date();
    let age = now.getFullYear() - birthDate.getFullYear();
    const m = now.getMonth() - birthDate.getMonth();
    if (m < 0 || (m === 0 && now.getDate() < birthDate.getDate())) {
      age--;
    }
    return age >= 18;
  }
}
