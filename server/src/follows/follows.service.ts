import { BadRequestException, Injectable } from '@nestjs/common';
import { PrismaService } from '../common/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';

const USER_BRIEF_SELECT = {
  id: true,
  firstName: true,
  lastName: true,
  avatarUrl: true,
};

@Injectable()
export class FollowsService {
  constructor(private prisma: PrismaService, private notifications: NotificationsService) {}

  async follow(followerId: string, followeeId: string) {
    if (followerId === followeeId) {
      throw new BadRequestException('Нельзя подписаться на себя');
    }

    const existing = await this.prisma.follow.findUnique({
      where: { followerId_followeeId: { followerId, followeeId } },
    });
    if (existing) return existing;

    const created = await this.prisma.follow.create({
      data: { followerId, followeeId },
    });

    await this.notifications.notifyNewFollower(followeeId, followerId);

    return created;
  }

  async unfollow(followerId: string, followeeId: string) {
    await this.prisma.follow.deleteMany({ where: { followerId, followeeId } });
    return { ok: true };
  }

  async followersOf(userId: string) {
    const rows = await this.prisma.follow.findMany({
      where: { followeeId: userId },
      orderBy: { createdAt: 'desc' },
      select: {
        createdAt: true,
        follower: { select: USER_BRIEF_SELECT },
      },
    });
    return rows.map((row) => ({
      ...row.follower,
      followedAt: row.createdAt,
    }));
  }

  async followingOf(userId: string) {
    const rows = await this.prisma.follow.findMany({
      where: { followerId: userId },
      orderBy: { createdAt: 'desc' },
      select: {
        createdAt: true,
        followee: { select: USER_BRIEF_SELECT },
      },
    });
    return rows.map((row) => ({
      ...row.followee,
      followedAt: row.createdAt,
    }));
  }
}
