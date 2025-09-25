// src/auth/dto.ts
import { Transform } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsBoolean,
  IsDateString,
  IsEmail,
  IsNotEmpty,
  IsOptional,
  IsString,
  Matches,
  MinLength,
} from 'class-validator';

export class RegisterDto {
  @IsString() @IsNotEmpty() firstName!: string;
  @IsString() @IsNotEmpty() lastName!: string;
  @IsEmail() email!: string;
  @IsString() @MinLength(6) password!: string;
  @IsDateString() birthDate!: string;       // ISO 8601
  @IsNotEmpty() avatarUrl!: string;
  @Transform(({ value }) => {
    if (typeof value === 'boolean') return value;
    if (typeof value === 'string') {
      const normalized = value.trim().toLowerCase();
      if (['true', '1', 'yes', 'on'].includes(normalized)) return true;
      if (['false', '0', 'no', 'off'].includes(normalized)) return false;
    }
    if (typeof value === 'number') {
      if (value === 1) return true;
      if (value === 0) return false;
      return Boolean(value);
    }
    return undefined;
  })
  @IsOptional()
  @IsBoolean()
  acceptedTerms?: boolean;

  @IsOptional()
  @IsArray()
  @ArrayMinSize(5)
  @ArrayMaxSize(5)
  @IsString({ each: true })
  categories?: string[];
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
