import { Injectable } from '@nestjs/common';
import { PrismaService } from '../common/prisma.service';


@Injectable()
export class UsersService {
constructor(private prisma: PrismaService) {}


me(userId: string) { return this.prisma.user.findUnique({ where: { id: userId }, include: { profile: true } }); }
}
