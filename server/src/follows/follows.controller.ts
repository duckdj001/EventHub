import { Controller, Delete, Get, Param, Post, Req, UnauthorizedException } from '@nestjs/common';
import { FollowsService } from './follows.service';
import { Public } from '../auth/public.decorator';

@Controller('users/:id')
export class FollowsController {
  constructor(private follows: FollowsService) {}

  @Post('follow')
  follow(@Param('id') id: string, @Req() req: any) {
    const me = req.user?.sub;
    if (!me) throw new UnauthorizedException();
    return this.follows.follow(me, id);
  }

  @Delete('follow')
  unfollow(@Param('id') id: string, @Req() req: any) {
    const me = req.user?.sub;
    if (!me) throw new UnauthorizedException();
    return this.follows.unfollow(me, id);
  }

  @Public()
  @Get('followers')
  followers(@Param('id') id: string) {
    return this.follows.followersOf(id);
  }

  @Public()
  @Get('following')
  following(@Param('id') id: string) {
    return this.follows.followingOf(id);
  }
}
