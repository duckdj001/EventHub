import { PrismaService } from '../common/prisma.service';
import { JwtService } from '@nestjs/jwt';
import { RegisterDto, LoginDto, VerifyEmailDto } from './dto';
import { MailService } from '../common/mail.service';
export declare class AuthService {
    private readonly prisma;
    private readonly mail;
    private readonly jwt;
    constructor(prisma: PrismaService, mail: MailService, jwt: JwtService);
    register(dto: RegisterDto): Promise<{
        ok: boolean;
    }>;
    resend(email: string): Promise<{
        ok: boolean;
    }>;
    login(dto: LoginDto): Promise<{
        accessToken: string;
        user: {
            id: string;
            email: string;
            firstName: string;
            lastName: string;
            emailVerified: boolean;
            mustChangePassword: boolean;
        };
    }>;
    verifyEmail(dto: VerifyEmailDto): Promise<{
        ok: boolean;
    }>;
    forgotPassword(email: string): Promise<{
        ok: boolean;
    }>;
}
