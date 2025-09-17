import { PrismaClient } from '@prisma/client';
const prisma = new PrismaClient();


async function main() {
const cat = await prisma.category.create({ data: { name: 'Встречи' } });
await prisma.tag.createMany({ data: [
{ name: 'спорт', slug: 'sport' },
{ name: 'музыка', slug: 'music' },
{ name: 'языки', slug: 'languages' },
], skipDuplicates: true });
console.log('Seed done', cat.id);
}


main().finally(() => prisma.$disconnect());
