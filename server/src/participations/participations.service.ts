import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';

import { PrismaService } from '../common/prisma.service';
import { RateParticipantDto } from './dto';

const OWNER_CAN_REQUEST_ERROR = 'Организатор уже участвует по умолчанию';

@Injectable()
export class ParticipationsService {
  constructor(private prisma: PrismaService) {}

  private async getEventOrThrow(eventId: string) {
    const event = await this.prisma.event.findUnique({
      where: { id: eventId },
      select: { id: true, ownerId: true, requiresApproval: true, isAdultOnly: true },
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
    const participation = await this.prisma.participation.upsert({
      where: { eventId_userId: { eventId, userId } },
      update: { status },
      create: { eventId, userId, status },
      include: { user: { select: { id: true, firstName: true, lastName: true, avatarUrl: true, email: true } } },
    });

    return { ...participation, autoconfirmed: !event.requiresApproval };
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
        event: { select: { ownerId: true, id: true } },
      },
    });
    if (!participation || participation.eventId !== eventId) {
      throw new NotFoundException('Заявка не найдена');
    }
    if (participation.event.ownerId !== ownerId) {
      throw new ForbiddenException('Нет доступа');
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

    return { ...participation, participantReview: review };
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
      select: { endAt: true },
    });
    if (event && event.endAt.getTime() <= Date.now()) {
      throw new BadRequestException('Нельзя отменить участие после завершения события');
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
        event: { select: { id: true, title: true } },
      },
    });

    return review;
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
