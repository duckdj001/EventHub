import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { ValidationPipe } from '@nestjs/common';
import * as dotenv from 'dotenv';
import { PrismaExceptionFilter } from './common/prisma-exception.filter'

dotenv.config();

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  app.enableCors(); // вместо импорта 'cors'
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
  app.useGlobalFilters(new PrismaExceptionFilter());
  const port = process.env.PORT || 3000;
  await app.listen(port);
  console.log(`API running on http://192.168.0.3:${port}`);
}
bootstrap();
