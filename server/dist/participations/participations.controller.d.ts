import { PrismaService } from '../common/prisma.service';
export declare class ParticipationsController {
    private prisma;
    constructor(prisma: PrismaService);
    request(eventId: string, req: any): Promise<{
        id: string;
        eventId: string;
        userId: string;
        status: string;
        createdAt: Date;
    }>;
    setStatus(eventId: string, participationId: string, status: 'approved' | 'rejected' | 'cancelled'): Promise<{
        id: string;
        eventId: string;
        userId: string;
        status: string;
        createdAt: Date;
    }>;
}
