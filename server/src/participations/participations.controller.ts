import { Body, Controller, Delete, Get, Param, Patch, Post, Req, UseGuards } from '@nestjs/common';

import { JwtAuthGuard } from '../auth/jwt.guard';
import { ParticipationsService } from './participations.service';
import { RateParticipantDto } from './dto';

@Controller()
@UseGuards(JwtAuthGuard)
export class ParticipationsController {
  constructor(private readonly participations: ParticipationsService) {}

  // подать заявку (или авто-апрув, если requiresApproval=false)
  @Post('events/:id/participations')
  async request(@Param('id') eventId: string, @Req() req: any) {
    return this.participations.request(eventId, req.user.sub);
  }

  @Get('events/:id/participations')
  async list(@Param('id') eventId: string, @Req() req: any) {
    return this.participations.listForOwner(eventId, req.user.sub);
  }

  @Get('events/:id/participations/me')
  async me(@Param('id') eventId: string, @Req() req: any) {
    return this.participations.getForUser(eventId, req.user.sub);
  }

  @Delete('events/:id/participations/me')
  async cancel(@Param('id') eventId: string, @Req() req: any) {
    return this.participations.cancel(eventId, req.user.sub);
  }

  // изменить статус заявки (только организатор)
  @Patch('events/:id/participations/:pid')
  async setStatus(
    @Param('id') eventId: string,
    @Param('pid') participationId: string,
    @Body('status') status: 'approved'|'rejected'|'cancelled',
    @Req() req: any,
  ) {
    return this.participations.changeStatus(eventId, req.user.sub, participationId, status);
  }

  @UseGuards(JwtAuthGuard)
  @Post('events/:id/participations/:pid/rating')
  async rate(
    @Param('id') eventId: string,
    @Param('pid') participationId: string,
    @Body() dto: RateParticipantDto,
    @Req() req: any,
  ) {
    return this.participations.rateParticipant(eventId, req.user.sub, participationId, dto);
  }
}
