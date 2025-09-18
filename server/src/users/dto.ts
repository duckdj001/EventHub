import { Type } from 'class-transformer';
import { IsEmail, IsIn, IsInt, IsNotEmpty, IsOptional, IsString, Max, Min } from 'class-validator';

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
