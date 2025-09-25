import { Body, Controller, Post } from '@nestjs/common';
import { AuthService } from './auth.service';
import { RegisterDto, LoginDto, VerifyEmailDto } from './dto';
import { Public } from './public.decorator';

@Controller('auth')
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  @Public()
  @Post('register')
  register(@Body() dto: RegisterDto) {
    return this.auth.register(dto);
  }

  @Public()
  @Post('login')
  login(@Body() dto: LoginDto) {
    return this.auth.login(dto);
  }

@Public()
@Post('verify')
verify(@Body() dto: VerifyEmailDto) {
  return this.auth.verifyEmail(dto);
}

@Public()
@Post('resend')
resend(@Body('email') email: string) {
  return this.auth.resend(email);
}

@Public()
@Post('password/forgot')
forgot(@Body('email') email: string) {
  return this.auth.forgotPassword(email);
}
}
