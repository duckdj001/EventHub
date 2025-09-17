import { Module } from '@nestjs/common';
import { CategoriesController } from './categories.controller';
import { PrismaService } from '../common/prisma.service';

@Module({
  controllers: [CategoriesController],
  providers: [PrismaService],
})
export class CategoriesModule {}
