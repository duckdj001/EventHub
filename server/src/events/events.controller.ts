import { Body, Controller, Get, Param, Post, Query, Req, UseGuards } from '@nestjs/common';
import { EventsService } from './events.service';
import { CreateEventDto } from './dto';
import { Delete, Patch } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt.guard';

@Controller('events')
export class EventsController {
  constructor(private events: EventsService) {}

@Get()
list(
  @Query('city') city?: string,
  @Query('categoryId') categoryId?: string,
  @Query('lat') latStr?: string,
  @Query('lon') lonStr?: string,
  @Query('radiusKm') radiusStr?: string,
  @Query('isPaid') isPaidStr?: string,
  @Query('owner') owner?: string,
  @Req() req?: any
) {
  const lat = latStr ? Number(latStr) : undefined;
  const lon = lonStr ? Number(lonStr) : undefined;
  const radiusKm = radiusStr ? Number(radiusStr) : undefined;
  const isPaid = typeof isPaidStr === 'string' ? isPaidStr === 'true' : undefined;
  const ownerId = owner === 'me' ? req?.user?.sub : undefined;
  return this.events.list({ city, categoryId, lat, lon, radiusKm, isPaid, ownerId });
}

  @Get(':id')
  getOne(@Param('id') id: string, @Req() req: any) {
    return this.events.getOne(id, req?.user?.sub);
  }

  @UseGuards(JwtAuthGuard)
  @Post()
  create(@Req() req: any, @Body() dto: CreateEventDto) {
    return this.events.create(req.user.sub, dto);
  }
  @UseGuards(JwtAuthGuard)
@Get('mine')
mine(@Req() req: any) {
  return this.events.list({ ownerId: req.user.sub });
}

@UseGuards(JwtAuthGuard)
@Patch(':id/status')
setStatus(@Param('id') id: string, @Body('status') status: 'published'|'draft', @Req() req: any) {
  return this.events.setStatus(id, status, req.user.sub);
}

@UseGuards(JwtAuthGuard)
@Delete(':id')
remove(@Param('id') id: string, @Req() req: any) {
  return this.events.remove(id, req.user.sub);
}
}
