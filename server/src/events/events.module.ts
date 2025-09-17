import { Module } from '@nestjs/common';
import { EventsService } from './events.service';
import { EventsController } from './events.controller';
import { PrismaService } from '../common/prisma.service';
import { AuthModule } from '../auth/auth.module'; // ← добавь

@Module({
  imports: [AuthModule], // ← ДОБАВЛЕНО!
  controllers: [EventsController],
  providers: [EventsService, PrismaService],
})
export class EventsModule {}
