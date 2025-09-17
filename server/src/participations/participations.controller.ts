import { Controller, Param, Post, Req, UseGuards, Patch, Body, ForbiddenException } from '@nestjs/common';
import { PrismaService } from '../common/prisma.service';
import { JwtAuthGuard } from '../auth/jwt.guard';

@Controller()
@UseGuards(JwtAuthGuard)
export class ParticipationsController {
  constructor(private prisma: PrismaService) {}

  // подать заявку (или авто-апрув, если requiresApproval=false)
  @Post('events/:id/participations')
  async request(@Param('id') eventId: string, @Req() req: any) {
    const e = await this.prisma.event.findUnique({ where: { id: eventId } });
    const status = e?.requiresApproval ? 'requested' : 'approved';
    return this.prisma.participation.upsert({
      where: { eventId_userId: { eventId, userId: req.user.sub } },
      update: { status },
      create: { eventId, userId: req.user.sub, status },
    });
  }

  // изменить статус заявки (только организатор)
  @Patch('events/:id/participations/:pid')
  async setStatus(
    @Param('id') eventId: string,
    @Param('pid') participationId: string,
    @Body('status') status: 'approved'|'rejected'|'cancelled'
  ) {
    const p = await this.prisma.participation.findUnique({ where: { id: participationId } , include:{event:true}});
    if (!p || p.eventId !== eventId) throw new ForbiddenException();
    // проверим что вызывает владелец события
    if (p.event.ownerId !== (await this.prisma.event.findUnique({where:{id:eventId}, select:{ownerId:true}}))!.ownerId)
      throw new ForbiddenException();
    return this.prisma.participation.update({ where: { id: participationId }, data: { status } });
  }
}
