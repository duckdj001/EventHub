import { PrismaService } from '../common/prisma.service';
export declare class UsersService {
    private prisma;
    constructor(prisma: PrismaService);
    me(userId: string): import(".prisma/client").Prisma.Prisma__UserClient<({
        profile: {
            firstName: string | null;
            lastName: string | null;
            birthDate: Date | null;
            avatarUrl: string | null;
            userId: string;
            bio: string | null;
            ratingOrg: number;
            ratingAtt: number;
        } | null;
    } & {
        id: string;
        email: string;
        verifyToken: string | null;
        password: string | null;
        passwordHash: string | null;
        emailVerified: boolean;
        emailVerifyCode: string | null;
        emailVerifyExpires: Date | null;
        verifyExpires: Date | null;
        firstName: string;
        lastName: string;
        birthDate: Date;
        avatarUrl: string | null;
        createdAt: Date;
        emailVerifyToken: string | null;
        updatedAt: Date;
    }) | null, null, import("@prisma/client/runtime/library").DefaultArgs>;
}
