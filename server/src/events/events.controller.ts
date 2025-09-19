import { Body, Controller, Get, Param, Post, Query, Req, UseGuards, ValidationPipe } from '@nestjs/common';
import { EventsService } from './events.service';
import { CreateEventDto, CreateReviewDto, EventReviewsFilterDto, UpdateEventDto } from './dto';
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
  @Query('excludeMine') excludeMineStr?: string,
  @Query('timeframe') timeframe?: 'this-week' | 'next-week' | 'this-month',
  @Query('startDate') startDate?: string,
  @Query('endDate') endDate?: string,
  @Req() req?: any,
) {
  const lat = latStr ? Number(latStr) : undefined;
  const lon = lonStr ? Number(lonStr) : undefined;
  const radiusKm = radiusStr ? Number(radiusStr) : undefined;
  const isPaid = typeof isPaidStr === 'string' ? isPaidStr === 'true' : undefined;
  const ownerId = owner === 'me' ? req?.user?.sub : undefined;
  const viewerId = req?.user?.sub;
  const excludeMine = excludeMineStr === 'true';
  return this.events.list(
    {
      city,
      categoryId,
      lat,
      lon,
      radiusKm,
      isPaid,
      ownerId,
      excludeMine,
      timeframe,
      startDate,
      endDate,
    },
    { viewerId },
  );
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
  @Get('participating')
  participating(@Req() req: any) {
    return this.events.listParticipating(req.user.sub);
  }

  @UseGuards(JwtAuthGuard)
  @Patch(':id')
  update(@Param('id') id: string, @Req() req: any, @Body() dto: UpdateEventDto) {
    return this.events.update(id, req.user.sub, dto);
  }

  @Get(':id')
  getOne(@Param('id') id: string, @Req() req: any) {
    return this.events.getOne(id, req?.user?.sub);
  }

  @UseGuards(JwtAuthGuard)
  @Post(':id/reviews')
  createReview(@Param('id') id: string, @Req() req: any, @Body() dto: CreateReviewDto) {
    return this.events.createReview(id, req.user.sub, dto);
  }

  @Get(':id/reviews')
  listReviews(
    @Param('id') id: string,
    @Query(new ValidationPipe({ transform: true })) query: EventReviewsFilterDto,
  ) {
    return this.events.eventReviews(id, query);
  }

  @UseGuards(JwtAuthGuard)
  @Get(':id/reviews/me')
  myReview(@Param('id') id: string, @Req() req: any) {
    return this.events.myReview(id, req.user.sub);
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
