import { FollowsService } from './follows.service';
export declare class FollowsController {
    private follows;
    constructor(follows: FollowsService);
    follow(id: string, req: any): import(".prisma/client").Prisma.Prisma__FollowClient<{
        id: string;
        createdAt: Date;
        followerId: string;
        followeeId: string;
    }, never, import("@prisma/client/runtime/library").DefaultArgs>;
}
