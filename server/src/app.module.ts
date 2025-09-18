// src/app.module.ts
import { Module } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { AuthModule } from './auth/auth.module';
import { JwtAuthGuard } from './auth/jwt.guard';
import { FilesModule } from './files/files.module';
import { EventsModule } from './events/events.module';
import { UsersModule } from './users/users.module';
import { GeoModule } from './geo/geo.module';
import { ParticipationsModule } from './participations/participations.module';
import { CategoriesModule } from './categories/categories.module';

@Module({
  imports: [
    AuthModule,     // чтобы JwtStrategy зарегистрировалась
    FilesModule,
    EventsModule,
    UsersModule,
    GeoModule,
    ParticipationsModule,
    CategoriesModule,
  ],
  providers: [
    { provide: APP_GUARD, useClass: JwtAuthGuard }, // наш кастомный guard
  ],
})
export class AppModule {}
