import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../common/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { CreateEventDto, CreateReviewDto, EventReviewsFilterDto, UpdateEventDto } from './dto';

const CATEGORY_TITLES: Record<string, string> = {
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

const CAPACITY_OCCUPYING_STATUSES = ['approved', 'attended'] as const;

function haversineKm(a: {lat:number, lon:number}, b: {lat:number, lon:number}) {
  const toRad = (x:number)=>x*Math.PI/180;
  const R = 6371;
  const dLat = toRad(b.lat - a.lat);
  const dLon = toRad(b.lon - a.lon);
  const s1 = Math.sin(dLat/2)**2 + Math.cos(toRad(a.lat))*Math.cos(toRad(b.lat))*Math.sin(dLon/2)**2;
  return 2 * R * Math.asin(Math.sqrt(s1));
}

@Injectable()
export class EventsService {
  constructor(private prisma: PrismaService, private notifications: NotificationsService) {}

  private async computeAvailability(
    events: Array<{ id: string; capacity: number | null | undefined }>,
  ): Promise<Map<string, number | null>> {
    const availability = new Map<string, number | null>();
    if (events.length === 0) {
      return availability;
    }

    const counts = await this.prisma.participation.groupBy({
      by: ['eventId'],
      where: {
        eventId: { in: events.map((event) => event.id) },
        status: { in: Array.from(CAPACITY_OCCUPYING_STATUSES) },
      },
      _count: { _all: true },
    });
    const countMap = new Map(
      counts.map((c) => [c.eventId, (typeof c._count === 'number' ? c._count : c._count?._all) ?? 0]),
    );

    for (const event of events) {
      if (event.capacity == null) {
        availability.set(event.id, null);
      } else {
        const taken = countMap.get(event.id) ?? 0;
        availability.set(event.id, Math.max(event.capacity - taken, 0));
      }
    }

    return availability;
  }

  async list(
    params: {
      city?: string;
      categoryId?: string;
      lat?: number;
      lon?: number;
      radiusKm?: number;
      isPaid?: boolean;
      ownerId?: string;
      excludeMine?: boolean;
      timeframe?: 'this-week' | 'next-week' | 'this-month';
      startDate?: string;
      endDate?: string;
    },
    options: { viewerId?: string } = {},
  ) {
    await this.archiveExpiredEvents();

    const {
      city,
      categoryId,
      lat,
      lon,
      radiusKm = 50,
      isPaid,
      ownerId,
      excludeMine,
      timeframe,
      startDate,
      endDate,
    } = params;
    const { viewerId } = options;

    let viewerIsAdult = true;
    if (!ownerId && viewerId) {
      const viewer = await this.prisma.user.findUnique({
        where: { id: viewerId },
        select: { birthDate: true },
      });
      if (viewer?.birthDate) {
        viewerIsAdult = this.isAdult(viewer.birthDate);
      }
    }

    const where: any = {};
    if (!ownerId) {
      where.status = 'published';
    }
    if (ownerId) where.ownerId = ownerId;
    if (city) where.city = city;
    if (categoryId) where.categoryId = categoryId;
    if (typeof isPaid === 'boolean') where.isPaid = isPaid;
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
      const range = startDate || endDate ? this.resolveCustomRange(startDate, endDate) : this.resolveTimeframe(timeframe!);
      if (range) {
        where.startAt = {
          ...(where.startAt ?? {}),
          gte: range.start,
          lt: range.end,
        };
      }
    }

    const events = await this.prisma.event.findMany({
      where:
        lat != null && lon != null
          ? {
              ...where,
              lat: { not: null },
              lon: { not: null },
              endAt: { gte: new Date() },
            }
          : where,
      orderBy: { startAt: 'asc' },
      include: {
        owner: { select: OWNER_SELECT },
      },
    });

    const availabilityMap = await this.computeAvailability(events);
    const withAvailability = events.map((event) => ({
      ...event,
      availableSpots: availabilityMap.get(event.id) ?? null,
    }));

    if (lat != null && lon != null) {
      return withAvailability
        .map((event) => ({
          ...event,
          distanceKm: haversineKm({ lat, lon }, { lat: event.lat!, lon: event.lon! }),
        }))
        .filter((event) => event.distanceKm <= radiusKm)
        .sort((a, b) => a.distanceKm - b.distanceKm);
    }

    return withAvailability;
  }

  async getOne(id: string, currentUserId?: string) {
    const e = await this.prisma.event.findUnique({
      where: { id },
      include: {
        owner: {
          select: OWNER_SELECT,
        },
      },
    });
    if (!e) return null;
    const availabilityMap = await this.computeAvailability([e]);
    let result = { ...e, availableSpots: availabilityMap.get(e.id) ?? null };
    if (e.isAdultOnly && currentUserId && e.ownerId !== currentUserId) {
      const viewer = await this.prisma.user.findUnique({
        where: { id: currentUserId },
        select: { birthDate: true },
      });
      if (!this.isAdult(viewer?.birthDate)) {
        throw new ForbiddenException('Событие доступно только пользователям 18+');
      }
    }
    // если событие «по заявке» — скрываем адрес для не-владельца/не-одобренного
    if (e.requiresApproval) {
      const isOwner = currentUserId && e.ownerId === currentUserId;
      let approved = false;
      if (currentUserId) {
        const part = await this.prisma.participation.findUnique({
          where: { eventId_userId: { eventId: id, userId: currentUserId } },
          select: { status: true },
        });
        approved = part?.status === 'approved' || part?.status === 'attended';
      }
      if (!isOwner && !approved) {
        result = { ...result, address: null, lat: null, lon: null, isAddressHidden: true };
      }
    }
    return result;
  }
  async setStatus(id: string, status: 'published'|'draft', userId: string) {
  const e = await this.prisma.event.findUnique({ where: { id } });
  if (!e || e.ownerId !== userId) throw new ForbiddenException();
  return this.prisma.event.update({ where: { id }, data: { status } });
}
async remove(id: string, userId: string) {
  const e = await this.prisma.event.findUnique({ where: { id } });
  if (!e || e.ownerId !== userId) throw new ForbiddenException();
  return this.prisma.event.delete({ where: { id } });
}
  async create(ownerId: string, dto: CreateEventDto) {
    if (dto.capacity == null || Number.isNaN(dto.capacity)) {
      throw new BadRequestException('Укажите количество участников (до 48).');
    }
    if (dto.capacity > 48 || dto.capacity < 1) {
      throw new BadRequestException('Максимальное количество участников — 48.');
    }

    const start = new Date(dto.startAt);
    const end = new Date(dto.endAt);
    if (isNaN(start.getTime()) || isNaN(end.getTime())) {
      throw new BadRequestException('Invalid startAt/endAt; must be ISO-8601');
    }
    if (dto.capacity == null || Number.isNaN(dto.capacity)) {
      throw new BadRequestException('Укажите количество участников (до 48).');
    }
    if (dto.capacity > 48 || dto.capacity < 1) {
      throw new BadRequestException('Максимальное количество участников — 48.');
    }

    let categoryId = dto.categoryId?.trim();
    if (categoryId) {
      const categoryName = CATEGORY_TITLES[categoryId] ?? categoryId;
      await this.prisma.category.upsert({
        where: { id: categoryId },
        update: {},
        create: { id: categoryId, name: categoryName },
      });
    } else {
      const cat = await this.prisma.category.upsert({
        where: { id: 'default-category' },
        update: {},
        create: { id: 'default-category', name: 'Встречи' },
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
        price: dto.price ?? null,
        currency: dto.currency ?? null,
        requiresApproval: !!dto.requiresApproval,
        isAdultOnly: !!dto.isAdultOnly,
        startAt: start, endAt: end,
        city: dto.city,
        address: dto.address ?? null,
        lat: dto.lat ?? null, lon: dto.lon ?? null,
        isAddressHidden: !!dto.isAddressHidden,
        capacity: dto.capacity,
        coverUrl: dto.coverUrl ?? null,
      },
    });
    await this.notifications.notifyFollowersAboutNewEvent(event.id);
    return event;
  }

  async update(id: string, ownerId: string, dto: UpdateEventDto) {
    const existing = await this.prisma.event.findUnique({ where: { id } });
    if (!existing || existing.ownerId !== ownerId) {
      throw new ForbiddenException();
    }

    const start = new Date(dto.startAt);
    const end = new Date(dto.endAt);
    if (isNaN(start.getTime()) || isNaN(end.getTime())) {
      throw new BadRequestException('Invalid startAt/endAt; must be ISO-8601');
    }

    const isPaid = !!dto.isPaid;
    let categoryId = dto.categoryId?.trim();
    if (categoryId) {
      const categoryName = CATEGORY_TITLES[categoryId] ?? categoryId;
      await this.prisma.category.upsert({
        where: { id: categoryId },
        update: {},
        create: { id: categoryId, name: categoryName },
      });
    } else {
      categoryId = existing.categoryId;
    }
    return this.prisma.event.update({
      where: { id },
      data: {
        title: dto.title,
        description: dto.description,
        categoryId,
        isPaid,
        price: isPaid ? dto.price ?? null : null,
        currency: isPaid ? dto.currency ?? null : null,
        requiresApproval: !!dto.requiresApproval,
        isAdultOnly: dto.isAdultOnly ?? existing.isAdultOnly,
        startAt: start,
        endAt: end,
        city: dto.city,
        address: dto.address ?? null,
        lat: dto.lat ?? null,
        lon: dto.lon ?? null,
        isAddressHidden: !!dto.isAddressHidden,
        capacity: dto.capacity,
        coverUrl: dto.coverUrl ?? null,
      },
    });
  }

  async listParticipating(userId: string) {
    await this.archiveExpiredEvents();
    const events = await this.prisma.event.findMany({
      where: {
        parts: {
          some: {
            userId,
            status: { in: ['approved', 'attended', 'requested'] },
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

    if (events.length === 0) return [];

    const availabilityMap = await this.computeAvailability(events);
    const reviewed = await this.prisma.review.findMany({
      where: {
        authorId: userId,
        target: 'event',
        eventId: { in: events.map((e) => e.id) },
      },
      select: { eventId: true },
    });
    const reviewedSet = new Set(reviewed.map((r) => r.eventId));

    return events.map(({ parts, ...rest }) => ({
      ...rest,
      participationStatus: parts[0]?.status ?? null,
      reviewed: reviewedSet.has(rest.id),
      availableSpots: availabilityMap.get(rest.id) ?? null,
    }));
  }

  async createReview(eventId: string, authorId: string, dto: CreateReviewDto) {
    const event = await this.prisma.event.findUnique({
      where: { id: eventId },
      select: {
        id: true,
        endAt: true,
        ownerId: true,
      },
    });
    if (!event) throw new NotFoundException('Событие не найдено');
    if (event.endAt.getTime() > Date.now()) {
      throw new BadRequestException('Оценить событие можно после завершения');
    }

    const participation = await this.prisma.participation.findUnique({
      where: { eventId_userId: { eventId, userId: authorId } },
    });
    if (!participation || participation.status !== 'approved') {
      throw new ForbiddenException('Оценка доступна только участникам события');
    }

    const existing = await this.prisma.review.findFirst({
      where: { eventId, authorId, target: 'event' },
    });
    if (existing) {
      throw new BadRequestException('Вы уже оставили отзыв для этого события');
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
    } catch (err) {
      throw new BadRequestException('Не удалось сохранить отзыв');
    }
  }

  async eventReviews(eventId: string, filter: EventReviewsFilterDto = {}) {
    const where: any = { eventId, target: 'event' };
    if (filter.rating) where.rating = filter.rating;

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

  async myReview(eventId: string, userId: string) {
    return this.prisma.review.findFirst({
      where: { eventId, authorId: userId, target: 'event' },
    });
  }

  private async archiveExpiredEvents() {
    await this.prisma.event.updateMany({
      where: { status: 'published', endAt: { lt: new Date() } },
      data: { status: 'draft' },
    });
  }

  private calculateAge(birthDate: Date): number {
    const now = new Date();
    let age = now.getFullYear() - birthDate.getFullYear();
    const m = now.getMonth() - birthDate.getMonth();
    if (m < 0 || (m === 0 && now.getDate() < birthDate.getDate())) {
      age--;
    }
    return age;
  }

  private isAdult(birthDate?: Date | null): boolean {
    if (!birthDate) return true;
    return this.calculateAge(birthDate) >= 18;
  }

  private resolveTimeframe(timeframe: 'this-week' | 'next-week' | 'this-month') {
    const now = new Date();
    const start = new Date(now);
    start.setHours(0, 0, 0, 0);

    if (timeframe === 'this-week' || timeframe === 'next-week') {
      const day = start.getDay();
      // convert to Monday start (0 => Sunday)
      const diff = day === 0 ? -6 : 1 - day;
      start.setDate(start.getDate() + diff);
      if (timeframe === 'next-week') {
        start.setDate(start.getDate() + 7);
      }
      const end = new Date(start);
      end.setDate(start.getDate() + 7);
      return { start, end };
    }

    if (timeframe === 'this-month') {
      start.setDate(1);
      const end = new Date(start.getFullYear(), start.getMonth() + 1, 1);
      return { start, end };
    }

    return null;
  }

  private resolveCustomRange(start?: string, end?: string) {
    let startDate: Date | undefined;
    let endDate: Date | undefined;
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
    if (!startDate && !endDate) return null;
    const startOrNow = startDate ?? new Date();
    const endOrStart = endDate ?? new Date(startOrNow.getFullYear(), startOrNow.getMonth(), startOrNow.getDate() + 1);
    return { start: startOrNow, end: endOrStart };
  }
}
