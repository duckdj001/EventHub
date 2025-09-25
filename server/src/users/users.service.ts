import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import { Prisma } from "@prisma/client";
import * as bcrypt from "bcrypt";
import * as crypto from "crypto";

import { PrismaService } from "../common/prisma.service";
import { MailService } from "../common/mail.service";
import {
  ConfirmEmailChangeDto,
  RequestEmailChangeDto,
  ReviewsFilterDto,
  UpdateProfileDto,
  UserEventsFilterDto,
} from "./dto";

const EMAIL_CHANGE_EXPIRES_MS = 24 * 60 * 60 * 1000; // 24 часа

function generateCode(): string {
  const n = crypto.randomInt(0, 1_000_000);
  return n.toString().padStart(6, "0");
}

@Injectable()
export class UsersService {
  constructor(
    private prisma: PrismaService,
    private mail: MailService,
  ) {}

  async me(userId: string) {
    return this.profile(userId, { viewerId: userId, includePrivate: true });
  }

  async profile(
    userId: string,
    opts?: { viewerId?: string; includePrivate?: boolean },
  ) {
    const includePrivate = opts?.includePrivate ?? false;
    const viewerId = opts?.viewerId;
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        email: includePrivate,
        firstName: true,
        lastName: true,
        avatarUrl: true,
        birthDate: true,
        createdAt: true,
        pendingEmail: includePrivate,
        mustChangePassword: true,
        deletedAt: true,
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
    if (!user || user.deletedAt != null) {
      throw new NotFoundException("Пользователь не найден");
    }

    const [
      ratingAgg,
      ratingGroups,
      upcomingCount,
      pastCount,
      participantAgg,
      followersCount,
      followingCount,
      viewerFollow,
      categoryRows,
    ] = await Promise.all([
      this.prisma.review.aggregate({
        _avg: { rating: true },
        _count: { rating: true },
        where: { event: { ownerId: userId }, target: "event" },
      }),
      this.prisma.review.groupBy({
        by: ["rating"],
        where: { event: { ownerId: userId }, target: "event" },
        _count: { rating: true },
      }),
      this.prisma.event.count({
        where: { ownerId: userId, startAt: { gte: new Date() } },
      }),
      this.prisma.event.count({
        where: { ownerId: userId, endAt: { lt: new Date() } },
      }),
      this.prisma.review.aggregate({
        _avg: { rating: true },
        _count: { rating: true },
        where: { target: "participant", targetUserId: userId },
      }),
      this.prisma.follow.count({ where: { followeeId: userId } }),
      this.prisma.follow.count({ where: { followerId: userId } }),
      viewerId
        ? this.prisma.follow.findUnique({
            where: {
              followerId_followeeId: {
                followerId: viewerId,
                followeeId: userId,
              },
            },
            select: { id: true },
          })
        : null,
      this.prisma.userCategoryPreference.findMany({
        where: { userId },
        include: { category: { select: { id: true, name: true } } },
        orderBy: { category: { name: "asc" } },
      }),
    ]);

    const distribution: Record<number, number> = {
      1: 0,
      2: 0,
      3: 0,
      4: 0,
      5: 0,
    };
    ratingGroups.forEach((g) => {
      if (g.rating >= 1 && g.rating <= 5) {
        distribution[g.rating as 1 | 2 | 3 | 4 | 5] = g._count.rating;
      }
    });

    return {
      ...user,
      email: includePrivate ? user.email : undefined,
      stats: {
        ratingAvg: ratingAgg._avg.rating ?? 0,
        ratingCount: ratingAgg._count.rating ?? 0,
        ratingDistribution: distribution,
        eventsUpcoming: upcomingCount,
        eventsPast: pastCount,
        participantRatingAvg: participantAgg._avg.rating ?? 0,
        participantRatingCount: participantAgg._count.rating ?? 0,
      },
      social: {
        followers: followersCount,
        following: followingCount,
        isFollowedByViewer: !!viewerFollow,
      },
      categories: categoryRows.map((row) => ({
        id: row.categoryId,
        name: row.category.name,
      })),
      mustChangePassword: user.mustChangePassword,
    };
  }

  async search(query: string, limit = 10) {
    const trimmed = query.trim();
    if (!trimmed) return [];

    const take = Math.min(Math.max(limit, 1), 25);
    const tokens = trimmed
      .split(/\s+/)
      .map((token) => token.trim())
      .filter((token) => token.length > 0)
      .slice(0, 5);

    const conditions: Prisma.UserWhereInput[] = [
      { firstName: { contains: trimmed, mode: "insensitive" } },
      { lastName: { contains: trimmed, mode: "insensitive" } },
      { email: { contains: trimmed, mode: "insensitive" } },
    ];

    if (tokens.length > 1) {
      conditions.push({
        AND: tokens.map((token) => ({
          OR: [
            { firstName: { contains: token, mode: "insensitive" } },
            { lastName: { contains: token, mode: "insensitive" } },
            { email: { contains: token, mode: "insensitive" } },
          ],
        })),
      });
    }

    return this.prisma.user.findMany({
      where: {
        OR: conditions,
      },
      take,
      orderBy: { createdAt: "desc" },
      select: {
        id: true,
        firstName: true,
        lastName: true,
        avatarUrl: true,
        email: true,
      },
    });
  }

  async updateProfile(userId: string, dto: UpdateProfileDto) {
    const data: any = {};
    if (dto.firstName !== undefined) data.firstName = dto.firstName.trim();
    if (dto.lastName !== undefined) data.lastName = dto.lastName.trim();
    if (dto.avatarUrl !== undefined) data.avatarUrl = dto.avatarUrl.trim();
    if (dto.birthDate) {
      const bd = new Date(dto.birthDate);
      if (Number.isNaN(bd.getTime())) {
        throw new BadRequestException("Некорректная дата рождения");
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
      throw new NotFoundException("Пользователь не найден");
    }

    const newEmail = dto.newEmail.toLowerCase().trim();
    if (!newEmail) {
      throw new BadRequestException("Укажите правильный e-mail");
    }

    const sameEmail = user.email.toLowerCase() === newEmail;
    if (sameEmail) {
      throw new BadRequestException("Укажите другой e-mail");
    }

    const existing = await this.prisma.user.findUnique({
      where: { email: newEmail },
    });
    if (existing) {
      throw new BadRequestException("E-mail уже используется");
    }

    const ok = await bcrypt.compare(dto.password, user.passwordHash);
    if (!ok) {
      throw new BadRequestException("Неверный пароль");
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
      "Подтверждение изменения e-mail",
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
      throw new BadRequestException("Нет активного запроса на смену e-mail");
    }

    if (user.pendingEmailToken !== dto.code) {
      throw new BadRequestException("Неверный код");
    }
    if (
      user.pendingEmailExpires &&
      user.pendingEmailExpires.getTime() < Date.now()
    ) {
      throw new BadRequestException("Код истёк, попробуйте снова");
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
    const type: "event" | "participant" = filter.type ?? "event";

    const where: any =
      type === "participant"
        ? { target: "participant", targetUserId: userId }
        : { event: { ownerId: userId }, target: "event" };

    if (filter.rating) {
      where.rating = filter.rating;
    }

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
        event: {
          select: { id: true, title: true, startAt: true, endAt: true },
        },
      },
    });
  }

  async getCategoryPreferences(userId: string) {
    const rows = await this.prisma.userCategoryPreference.findMany({
      where: { userId },
      include: { category: { select: { id: true, name: true } } },
      orderBy: { category: { name: "asc" } },
    });
    return rows.map((row) => ({
      id: row.categoryId,
      name: row.category.name,
    }));
  }

  async updateCategoryPreferences(userId: string, categoryIds: string[]) {
    const unique = Array.from(
      new Set(categoryIds.map((id) => id.trim()).filter((id) => id.length > 0)),
    );
    if (unique.length !== 5) {
      throw new BadRequestException("Необходимо выбрать ровно 5 категорий");
    }

    const categories = await this.prisma.category.findMany({
      where: { id: { in: unique } },
      select: { id: true, name: true },
      orderBy: { name: "asc" },
    });
    if (categories.length !== unique.length) {
      throw new BadRequestException("Некорректный идентификатор категории");
    }

    await this.prisma.$transaction(async (tx) => {
      await tx.userCategoryPreference.deleteMany({ where: { userId } });
      await tx.userCategoryPreference.createMany({
        data: unique.map((categoryId) => ({ userId, categoryId })),
      });
    });

    return categories.map((category) => ({
      id: category.id,
      name: category.name,
    }));
  }

  async changePassword(userId: string, currentPassword: string, newPassword: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { passwordHash: true },
    });

    if (!user?.passwordHash) {
      throw new BadRequestException('Пароль не установлен');
    }

    const isValid = await bcrypt.compare(currentPassword, user.passwordHash);
    if (!isValid) {
      throw new BadRequestException('Неверный текущий пароль');
    }

    const hash = await bcrypt.hash(newPassword, 10);
    await this.prisma.user.update({
      where: { id: userId },
      data: { passwordHash: hash, mustChangePassword: false },
    });

    return { ok: true };
  }

  async deleteAccount(userId: string, password: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { passwordHash: true, email: true },
    });
    if (!user?.passwordHash) {
      throw new BadRequestException('Неверный пароль');
    }

    const ok = await bcrypt.compare(password, user.passwordHash);
    if (!ok) {
      throw new BadRequestException('Неверный пароль');
    }

    const anonymizedEmail = `deleted_${userId}_${Date.now()}@deleted.local`;
    const randomHash = await bcrypt.hash(crypto.randomBytes(32).toString('hex'), 10);

    await this.prisma.$transaction(async (tx) => {
      await tx.deviceToken.deleteMany({ where: { userId } });
      await tx.notification.deleteMany({ where: { OR: [{ userId }, { actorId: userId }] } });
      await tx.notificationPreference.deleteMany({ where: { userId } });
      await tx.userCategoryPreference.deleteMany({ where: { userId } });
      await tx.profile.updateMany({
        where: { userId },
        data: { bio: null, firstName: '', lastName: '', avatarUrl: null },
      });
      await tx.user.update({
        where: { id: userId },
        data: {
          email: anonymizedEmail,
          passwordHash: randomHash,
          firstName: 'Удалён',
          lastName: '',
          avatarUrl: null,
          deletedAt: new Date(),
          mustChangePassword: false,
        },
      });
    });

    return { ok: true };
  }

  async eventsCreated(userId: string, filter: UserEventsFilterDto) {
    const now = new Date();
    const where: any = { ownerId: userId };
    switch (filter.filter) {
      case "upcoming":
        where.startAt = { gte: now };
        break;
      case "past":
        where.endAt = { lt: now };
        break;
      default:
        break;
    }

    return this.prisma.event.findMany({
      where,
      orderBy: { startAt: "desc" },
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
