import { Module } from '@nestjs/common';
import { ParticipationsService } from './participations.service';
import { ParticipationsController } from './participations.controller';
import { PrismaService } from '../common/prisma.service';


@Module({ controllers: [ParticipationsController], providers: [ParticipationsService, PrismaService] })
export class ParticipationsModule {}
