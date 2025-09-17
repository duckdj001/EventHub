import { Controller, Get } from '@nestjs/common';
import { PrismaService } from '../common/prisma.service';

@Controller('categories')
export class CategoriesController {
  constructor(private prisma: PrismaService) {}

  @Get()
  async list() {
    // гарантируем дефолтные категории
    const defaults = [
      { id: 'default-category', name: 'Встречи' },
      { id: 'music', name: 'Музыка' },
      { id: 'sport', name: 'Спорт' },
      { id: 'education', name: 'Обучение' },
      { id: 'party', name: 'Вечеринки' },
    ];
    for (const c of defaults) {
      await this.prisma.category.upsert({ where: { id: c.id }, update: {}, create: c });
    }
    return this.prisma.category.findMany({ orderBy: { name: 'asc' } });
  }
}
