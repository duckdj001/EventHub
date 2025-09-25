export declare class RegisterDto {
    firstName: string;
    lastName: string;
    email: string;
    password: string;
    birthDate: string;
    avatarUrl: string;
    acceptedTerms?: boolean;
    categories?: string[];
}
export declare class LoginDto {
    email: string;
    password: string;
}
export declare class VerifyEmailDto {
    email: string;
    code: string;
}
