import { PrismaService } from '../common/prisma.service';
export declare class ParticipationsService {
    private prisma;
    constructor(prisma: PrismaService);
    request(eventId: string, userId: string): import(".prisma/client").Prisma.Prisma__ParticipationClient<{
        id: string;
        createdAt: Date;
        status: string;
        eventId: string;
        userId: string;
    }, never, import("@prisma/client/runtime/library").DefaultArgs>;
}
