import { PrismaService } from '../common/prisma.service';
export declare class FollowsService {
    private prisma;
    constructor(prisma: PrismaService);
    follow(followerId: string, followeeId: string): Promise<{
        id: string;
        createdAt: Date;
        followerId: string;
        followeeId: string;
    }>;
    unfollow(followerId: string, followeeId: string): Promise<{
        ok: boolean;
    }>;
    followersOf(userId: string): Promise<{
        followedAt: Date;
        id: string;
        firstName: string;
        lastName: string;
        avatarUrl: string | null;
    }[]>;
    followingOf(userId: string): Promise<{
        followedAt: Date;
        id: string;
        firstName: string;
        lastName: string;
        avatarUrl: string | null;
    }[]>;
}
