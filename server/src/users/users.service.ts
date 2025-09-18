import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import * as bcrypt from 'bcrypt';
import * as crypto from 'crypto';

import { PrismaService } from '../common/prisma.service';
import { MailService } from '../common/mail.service';
import { ConfirmEmailChangeDto, RequestEmailChangeDto, ReviewsFilterDto, UpdateProfileDto, UserEventsFilterDto } from './dto';

const EMAIL_CHANGE_EXPIRES_MS = 24 * 60 * 60 * 1000; // 24 часа

function generateCode(): string {
  const n = crypto.randomInt(0, 1_000_000);
  return n.toString().padStart(6, '0');
}

@Injectable()
export class UsersService {
  constructor(private prisma: PrismaService, private mail: MailService) {}

  async me(userId: string) {
    return this.profile(userId, { viewerId: userId, includePrivate: true });
  }

  async profile(userId: string, opts?: { viewerId?: string; includePrivate?: boolean }) {
    const includePrivate = opts?.includePrivate ?? false;
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        email: true,
        firstName: true,
        lastName: true,
        avatarUrl: true,
        birthDate: true,
        createdAt: true,
        pendingEmail: includePrivate,
        profile: {
          select: {
            bio: true,
            firstName: true,
            lastName: true,
            avatarUrl: true,
            birthDate: true,
          },
        },
      },
    });
    if (!user) throw new NotFoundException('Пользователь не найден');

    const [ratingAgg, ratingGroups, upcomingCount, pastCount, participantAgg] = await Promise.all([
      this.prisma.review.aggregate({
        _avg: { rating: true },
        _count: { rating: true },
        where: { event: { ownerId: userId }, target: 'event' },
      }),
      this.prisma.review.groupBy({
        by: ['rating'],
        where: { event: { ownerId: userId }, target: 'event' },
        _count: { rating: true },
      }),
      this.prisma.event.count({ where: { ownerId: userId, startAt: { gte: new Date() } } }),
      this.prisma.event.count({ where: { ownerId: userId, endAt: { lt: new Date() } } }),
      this.prisma.review.aggregate({
        _avg: { rating: true },
        _count: { rating: true },
        where: { target: 'participant', targetUserId: userId },
      }),
    ]);

    const distribution: Record<number, number> = { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0 };
    ratingGroups.forEach((g) => {
      if (g.rating >= 1 && g.rating <= 5) {
        distribution[g.rating as 1 | 2 | 3 | 4 | 5] = g._count.rating;
      }
    });

    return {
      ...user,
      stats: {
        ratingAvg: ratingAgg._avg.rating ?? 0,
        ratingCount: ratingAgg._count.rating ?? 0,
        ratingDistribution: distribution,
        eventsUpcoming: upcomingCount,
        eventsPast: pastCount,
        participantRatingAvg: participantAgg._avg.rating ?? 0,
        participantRatingCount: participantAgg._count.rating ?? 0,
      },
    };
  }

  async updateProfile(userId: string, dto: UpdateProfileDto) {
    const data: any = {};
    if (dto.firstName !== undefined) data.firstName = dto.firstName.trim();
    if (dto.lastName !== undefined) data.lastName = dto.lastName.trim();
    if (dto.avatarUrl !== undefined) data.avatarUrl = dto.avatarUrl.trim();
    if (dto.birthDate) {
      const bd = new Date(dto.birthDate);
      if (Number.isNaN(bd.getTime())) {
        throw new BadRequestException('Некорректная дата рождения');
      }
      data.birthDate = bd;
    }

    const updates: Promise<any>[] = [];
    if (Object.keys(data).length > 0) {
      updates.push(this.prisma.user.update({ where: { id: userId }, data }));
    }

    if (dto.bio !== undefined) {
      updates.push(
        this.prisma.profile.upsert({
          where: { userId },
          update: { bio: dto.bio },
          create: { userId, bio: dto.bio },
        }),
      );
    }

    await Promise.all(updates);
    return this.profile(userId, { viewerId: userId, includePrivate: true });
  }

  async requestEmailChange(userId: string, dto: RequestEmailChangeDto) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, email: true, passwordHash: true, pendingEmail: true },
    });
    if (!user || !user.passwordHash) {
      throw new NotFoundException('Пользователь не найден');
    }

    const newEmail = dto.newEmail.toLowerCase().trim();
    if (!newEmail) {
      throw new BadRequestException('Укажите правильный e-mail');
    }

    const sameEmail = user.email.toLowerCase() === newEmail;
    if (sameEmail) {
      throw new BadRequestException('Укажите другой e-mail');
    }

    const existing = await this.prisma.user.findUnique({ where: { email: newEmail } });
    if (existing) {
      throw new BadRequestException('E-mail уже используется');
    }

    const ok = await bcrypt.compare(dto.password, user.passwordHash);
    if (!ok) {
      throw new BadRequestException('Неверный пароль');
    }

    const code = generateCode();
    const expires = new Date(Date.now() + EMAIL_CHANGE_EXPIRES_MS);

    await this.prisma.user.update({
      where: { id: userId },
      data: {
        pendingEmail: newEmail,
        pendingEmailToken: code,
        pendingEmailExpires: expires,
      },
    });

    await this.mail.send(
      newEmail,
      'Подтверждение изменения e-mail',
      `<p>Код подтверждения: <b>${code}</b></p><p>Если вы не запрашивали смену e-mail, проигнорируйте письмо.</p>`,
    );

    return { ok: true };
  }

  async confirmEmailChange(userId: string, dto: ConfirmEmailChangeDto) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        pendingEmail: true,
        pendingEmailToken: true,
        pendingEmailExpires: true,
      },
    });
    if (!user?.pendingEmail || !user.pendingEmailToken) {
      throw new BadRequestException('Нет активного запроса на смену e-mail');
    }

    if (user.pendingEmailToken !== dto.code) {
      throw new BadRequestException('Неверный код');
    }
    if (user.pendingEmailExpires && user.pendingEmailExpires.getTime() < Date.now()) {
      throw new BadRequestException('Код истёк, попробуйте снова');
    }

    await this.prisma.user.update({
      where: { id: userId },
      data: {
        email: user.pendingEmail,
        pendingEmail: null,
        pendingEmailToken: null,
        pendingEmailExpires: null,
        emailVerified: true,
      },
    });

    return { ok: true };
  }

  async reviews(userId: string, filter: ReviewsFilterDto) {
    const type: 'event' | 'participant' = filter.type ?? 'event';

    const where: any = type === 'participant'
        ? { target: 'participant', targetUserId: userId }
        : { event: { ownerId: userId }, target: 'event' };

    if (filter.rating) {
      where.rating = filter.rating;
    }

    return this.prisma.review.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      include: {
        author: {
          select: { id: true, firstName: true, lastName: true, avatarUrl: true, email: true },
        },
        event: { select: { id: true, title: true, startAt: true, endAt: true } },
      },
    });
  }

  async eventsCreated(userId: string, filter: UserEventsFilterDto) {
    const now = new Date();
    const where: any = { ownerId: userId };
    switch (filter.filter) {
      case 'upcoming':
        where.startAt = { gte: now };
        break;
      case 'past':
        where.endAt = { lt: now };
        break;
      default:
        break;
    }

    return this.prisma.event.findMany({
      where,
      orderBy: { startAt: 'desc' },
      select: {
        id: true,
        title: true,
        startAt: true,
        endAt: true,
        city: true,
        coverUrl: true,
        status: true,
      },
    });
  }
}
