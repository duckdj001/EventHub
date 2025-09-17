// src/app.module.ts
import { Module } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { AuthModule } from './auth/auth.module';
import { JwtAuthGuard } from './auth/jwt.guard';
import { FilesModule } from './files/files.module';
import { EventsModule } from './events/events.module';

@Module({
  imports: [
    AuthModule,     // чтобы JwtStrategy зарегистрировалась
    FilesModule,
    EventsModule,
  ],
  providers: [
    { provide: APP_GUARD, useClass: JwtAuthGuard }, // наш кастомный guard
  ],
})
export class AppModule {}
