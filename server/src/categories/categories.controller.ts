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
      { id: 'art', name: 'Искусство' },
      { id: 'business', name: 'Бизнес' },
      { id: 'family', name: 'Семья' },
      { id: 'health', name: 'Здоровье' },
      { id: 'travel', name: 'Путешествия' },
      { id: 'food', name: 'Еда' },
      { id: 'tech', name: 'Технологии' },
      { id: 'games', name: 'Игры' },
      { id: 'party', name: 'Вечеринки' },
    ];
    const suggestedIds = new Set(defaults.slice(0, 5).map((c) => c.id));
    for (const c of defaults) {
      await this.prisma.category.upsert({ where: { id: c.id }, update: {}, create: c });
    }
    const categories = await this.prisma.category.findMany({ orderBy: { name: 'asc' } });
    return categories.map((category) => ({
      id: category.id,
      name: category.name,
      parentId: category.parentId,
      isSuggested: suggestedIds.has(category.id),
    }));
  }
}
