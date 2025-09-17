import { BadRequestException, ForbiddenException, Injectable } from '@nestjs/common';
import { PrismaService } from '../common/prisma.service';
import { CreateEventDto } from './dto';

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

  list(params: { city?: string; categoryId?: string; lat?: number; lon?: number; radiusKm?: number; isPaid?: boolean; ownerId?: string }) {
  const { city, categoryId, lat, lon, radiusKm = 50, isPaid, ownerId } = params;
  const baseWhere: any = { status: 'published' };
  if (categoryId) baseWhere.categoryId = categoryId;
  if (typeof isPaid === 'boolean') baseWhere.isPaid = isPaid;
  if (ownerId) baseWhere.ownerId = ownerId;
    if (lat != null && lon != null) {
      // тянем только события с координатами, дальше считаем расстояние в JS (MVP)
      return this.prisma.event.findMany({
        where: { status: 'published', categoryId, lat: { not: null }, lon: { not: null } },
        orderBy: { startAt: 'asc' },
      }).then(list => {
        const withD = list.map(e => ({
          ...e,
          distanceKm: haversineKm({lat, lon}, {lat: e.lat!, lon: e.lon!}),
        }))
        .filter(e => e.distanceKm <= radiusKm)
        .sort((a,b)=> a.distanceKm - b.distanceKm);
        return withD;
      });
    }
    return this.prisma.event.findMany({
      where: { status: 'published', city, categoryId },
      orderBy: { startAt: 'asc' },
    });
  }

  async getOne(id: string, currentUserId?: string) {
    const e = await this.prisma.event.findUnique({ where: { id } });
    if (!e) return null;
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
        price: dto.price ?? null,
        currency: dto.currency ?? null,
        requiresApproval: !!dto.requiresApproval,
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
}
