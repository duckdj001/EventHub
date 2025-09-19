import { OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { NotificationsService } from './notifications.service';
export declare class NotificationScheduler implements OnModuleInit, OnModuleDestroy {
    private readonly notifications;
    private readonly logger;
    private timer;
    constructor(notifications: NotificationsService);
    onModuleInit(): void;
    onModuleDestroy(): void;
    private startTimer;
}
