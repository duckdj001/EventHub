import { AuthService } from './auth.service';
import { RegisterDto, LoginDto, VerifyEmailDto } from './dto';
export declare class AuthController {
    private readonly auth;
    constructor(auth: AuthService);
    register(dto: RegisterDto): Promise<{
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
    verify(dto: VerifyEmailDto): Promise<{
        ok: boolean;
    }>;
    resend(email: string): Promise<{
        ok: boolean;
    }>;
    forgot(email: string): Promise<{
        ok: boolean;
    }>;
}
