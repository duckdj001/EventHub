import { Module } from '@nestjs/common';
import { EventsService } from './events.service';
import { EventsController } from './events.controller';
import { PrismaService } from '../common/prisma.service';
import { AuthModule } from '../auth/auth.module'; // ← добавь
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [AuthModule, NotificationsModule], // ← ДОБАВЛЕНО!
  controllers: [EventsController],
  providers: [EventsService, PrismaService],
})
export class EventsModule {}
