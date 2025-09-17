import { Controller, Get, Req } from '@nestjs/common';


@Controller('users')
export class UsersController {
@Get('me')
me(@Req() req: any) { return { userId: req.user?.sub ?? null }; }
}
