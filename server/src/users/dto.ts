import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  ArrayUnique,
  IsArray,
  IsEmail,
  IsIn,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  Max,
  Min,
  MinLength,
} from 'class-validator';

export class UpdateProfileDto {
  @IsOptional()
  @IsString()
  firstName?: string;

  @IsOptional()
  @IsString()
  lastName?: string;

  @IsOptional()
  @IsString()
  avatarUrl?: string;

  @IsOptional()
  @IsString()
  bio?: string;

  @IsOptional()
  @IsString()
  birthDate?: string;
}

export class RequestEmailChangeDto {
  @IsNotEmpty()
  @IsEmail()
  newEmail!: string;

  @IsNotEmpty()
  @IsString()
  password!: string;
}

export class ConfirmEmailChangeDto {
  @IsNotEmpty()
  @IsString()
  code!: string;
}

export class ReviewsFilterDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(5)
  rating?: number;

  @IsOptional()
  @IsIn(['event', 'participant'])
  type?: 'event' | 'participant';
}

export class UserEventsFilterDto {
  @IsOptional()
  @IsIn(['all', 'upcoming', 'past'])
  filter?: 'all' | 'upcoming' | 'past';
}

export class UpdateCategoryPreferencesDto {
  @IsArray()
  @ArrayMinSize(5)
  @ArrayMaxSize(5)
  @ArrayUnique()
  @IsString({ each: true })
  categories!: string[];
}

export class ChangePasswordDto {
  @IsString()
  @MinLength(6)
  currentPassword!: string;

  @IsString()
  @MinLength(6)
  newPassword!: string;
}

export class DeleteAccountDto {
  @IsString()
  @MinLength(6)
  password!: string;
}
