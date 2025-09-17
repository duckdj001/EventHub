import { Injectable } from '@nestjs/common';
import { PrismaService } from '../common/prisma.service';


@Injectable()
export class ParticipationsService {
constructor(private prisma: PrismaService) {}


request(eventId: string, userId: string) {
return this.prisma.participation.upsert({
where: { eventId_userId: { eventId, userId } },
update: { status: 'requested' },
create: { eventId, userId, status: 'requested' },
});
}
}
