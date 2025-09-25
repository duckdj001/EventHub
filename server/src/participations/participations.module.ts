import { Module } from '@nestjs/common';
import { ParticipationsService } from './participations.service';
import { ParticipationsController } from './participations.controller';
import { PrismaService } from '../common/prisma.service';
import { NotificationsModule } from '../notifications/notifications.module';


@Module({
  imports: [NotificationsModule],
  controllers: [ParticipationsController],
  providers: [ParticipationsService, PrismaService],
})
export class ParticipationsModule {}
