import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../common/prisma.service';
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
  constructor(private prisma: PrismaService) {}

  async list(
    params: { city?: string; categoryId?: string; lat?: number; lon?: number; radiusKm?: number; isPaid?: boolean; ownerId?: string; excludeMine?: boolean },
    options: { viewerId?: string } = {},
  ) {
    await this.archiveExpiredEvents();

    const { city, categoryId, lat, lon, radiusKm = 50, isPaid, ownerId, excludeMine } = params;
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
              distanceKm: haversineKm({ lat, lon }, { lat: e.lat!, lon: e.lon! }),
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
        return { ...e, address: null, lat: null, lon: null, isAddressHidden: true };
      }
    }
    return e;
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
    const start = new Date(dto.startAt);
    const end = new Date(dto.endAt);
    if (isNaN(start.getTime()) || isNaN(end.getTime())) {
      throw new BadRequestException('Invalid startAt/endAt; must be ISO-8601');
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
    return this.prisma.event.create({
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
        capacity: dto.capacity ?? null,
        coverUrl: dto.coverUrl ?? null,
      },
    });
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
        capacity: dto.capacity ?? null,
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

    return events.map(({ parts, ...rest }) => ({
      ...rest,
      participationStatus: parts[0]?.status ?? null,
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

    const existing = await this.prisma.review.findUnique({
      where: { eventId_authorId_target: { eventId, authorId, target: 'event' } },
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
    return this.prisma.review.findUnique({
      where: { eventId_authorId_target: { eventId, authorId: userId, target: 'event' } },
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
}
