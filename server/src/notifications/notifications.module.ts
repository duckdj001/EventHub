import { Module } from '@nestjs/common';
import { NotificationsService } from './notifications.service';
import { NotificationsController } from './notifications.controller';
import { PrismaService } from '../common/prisma.service';
import { NotificationScheduler } from './notifications.scheduler';
import { PushService } from './push.service';

@Module({
  controllers: [NotificationsController],
  providers: [NotificationsService, NotificationScheduler, PrismaService, PushService],
  exports: [NotificationsService],
})
export class NotificationsModule {}
