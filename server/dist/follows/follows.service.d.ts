import { PrismaService } from '../common/prisma.service';
export declare class FollowsService {
    private prisma;
    constructor(prisma: PrismaService);
    follow(followerId: string, followeeId: string): import(".prisma/client").Prisma.Prisma__FollowClient<{
        id: string;
        createdAt: Date;
        followerId: string;
        followeeId: string;
    }, never, import("@prisma/client/runtime/library").DefaultArgs>;
}
