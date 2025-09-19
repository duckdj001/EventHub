import { FollowsService } from './follows.service';
export declare class FollowsController {
    private follows;
    constructor(follows: FollowsService);
    follow(id: string, req: any): Promise<{
        id: string;
        createdAt: Date;
        followerId: string;
        followeeId: string;
    }>;
    unfollow(id: string, req: any): Promise<{
        ok: boolean;
    }>;
    followers(id: string): Promise<{
        followedAt: Date;
        id: string;
        firstName: string;
        lastName: string;
        avatarUrl: string | null;
    }[]>;
    following(id: string): Promise<{
        followedAt: Date;
        id: string;
        firstName: string;
        lastName: string;
        avatarUrl: string | null;
    }[]>;
}
