import { PrismaService } from '../common/prisma.service';
type PushPayload = {
    title: string;
    body: string;
    data?: Record<string, string>;
    badge?: number;
};
export declare class PushService {
    private readonly prisma;
    private readonly logger;
    constructor(prisma: PrismaService);
    private get serverKey();
    private get enabled();
    registerDevice(userId: string, token: string, platform: string): Promise<void>;
    deregisterDevice(token: string): Promise<void>;
    sendToUser(userId: string, payload: PushPayload): Promise<void>;
    sendToUsers(userIds: string[], payload: PushPayload): Promise<void>;
    private dispatchBatch;
}
export {};
