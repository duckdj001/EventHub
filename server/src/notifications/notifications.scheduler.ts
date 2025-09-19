import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { NotificationsService } from './notifications.service';

const REMINDER_INTERVAL_MS = 60 * 60 * 1000; // 1 час

@Injectable()
export class NotificationScheduler implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(NotificationScheduler.name);
  private timer: NodeJS.Timeout | null = null;

  constructor(private readonly notifications: NotificationsService) {}

  onModuleInit() {
    this.startTimer();
  }

  onModuleDestroy() {
    if (this.timer) {
      clearInterval(this.timer);
      this.timer = null;
    }
  }

  private startTimer() {
    const run = async () => {
      try {
        await this.notifications.sendEventReminders();
      } catch (err) {
        this.logger.error('Failed to send event reminders', err instanceof Error ? err.stack : err);
      }
    };

    // запустить сразу, затем по расписанию
    run();
    this.timer = setInterval(run, REMINDER_INTERVAL_MS);
  }
}
