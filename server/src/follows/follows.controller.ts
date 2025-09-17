import { Controller, Param, Post, Req } from '@nestjs/common';
import { FollowsService } from './follows.service';


@Controller('users/:id/follow')
export class FollowsController {
constructor(private follows: FollowsService) {}


@Post()
follow(@Param('id') id: string, @Req() req: any) {
const me = req.user?.sub ?? 'anonymous';
return this.follows.follow(me, id);
}
}
