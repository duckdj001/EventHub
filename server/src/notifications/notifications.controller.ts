import { Body, Controller, Get, Param, Post, Req, ValidationPipe } from '@nestjs/common';
import { NotificationsService } from './notifications.service';
import { DeregisterDeviceDto, RegisterDeviceDto } from './dto/register-device.dto';

@Controller('notifications')
export class NotificationsController {
  constructor(private readonly notifications: NotificationsService) {}

  @Get()
  list(@Req() req: any) {
    return this.notifications.listForUser(req.user.sub);
  }

  @Post('read-all')
  markAll(@Req() req: any) {
    return this.notifications.markAllRead(req.user.sub);
  }

  @Post(':id/read')
  markOne(@Param('id') id: string, @Req() req: any) {
    return this.notifications.markRead(req.user.sub, id);
  }

  @Get('unread-count')
  unreadCount(@Req() req: any) {
    return this.notifications.unreadCount(req.user.sub).then((count) => ({ count }));
  }

  @Post('device/register')
  registerDevice(
    @Req() req: any,
    @Body(new ValidationPipe({ transform: true })) dto: RegisterDeviceDto,
  ) {
    return this.notifications
      .registerDevice(req.user.sub, dto.token, dto.platform)
      .then(() => ({ ok: true }));
  }

  @Post('device/deregister')
  deregisterDevice(@Body(new ValidationPipe({ transform: true })) dto: DeregisterDeviceDto) {
    return this.notifications.deregisterDevice(dto.token).then(() => ({ ok: true }));
  }
}
