// src/auth/dto.ts
import { IsEmail, IsNotEmpty, IsString, MinLength, IsDateString, Matches } from 'class-validator';

export class RegisterDto {
  @IsString() @IsNotEmpty() firstName!: string;
  @IsString() @IsNotEmpty() lastName!: string;
  @IsEmail() email!: string;
  @IsString() @MinLength(6) password!: string;
  @IsDateString() birthDate!: string;       // ISO 8601
  @IsNotEmpty() avatarUrl!: string;
}

export class LoginDto {
  @IsEmail() email!: string;
  @IsString() @MinLength(6) password!: string;
}

export class VerifyEmailDto {
  @IsEmail() email!: string;
  @Matches(/^\d{6}$/, { message: 'Код должен состоять из 6 цифр' })
  code!: string;
}
