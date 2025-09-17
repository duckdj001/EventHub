import { Injectable } from '@nestjs/common';
import { PrismaService } from '../common/prisma.service';


@Injectable()
export class FollowsService {
constructor(private prisma: PrismaService) {}


follow(followerId: string, followeeId: string) {
return this.prisma.follow.upsert({
where: { followerId_followeeId: { followerId, followeeId } },
update: {},
create: { followerId, followeeId },
});
}
}
