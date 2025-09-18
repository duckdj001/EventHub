import { Type } from 'class-transformer';
import { IsBoolean, IsDateString, IsInt, IsOptional, IsString, Max, Min } from 'class-validator';

export class CreateEventDto {
  @IsString() title!: string;
  @IsString() description!: string;

  @IsString() @IsOptional() categoryId?: string;

  @IsBoolean() @IsOptional() isPaid?: boolean;
  @IsInt() @IsOptional() @Min(0) price?: number;
  @IsString() @IsOptional() currency?: string;

  @IsBoolean() @IsOptional() requiresApproval?: boolean;
  @IsBoolean() @IsOptional() isAdultOnly?: boolean;

  @IsDateString() startAt!: string;
  @IsDateString() endAt!: string;

  @IsString() city!: string;
  @IsString() @IsOptional() address?: string;
  @IsOptional() lat?: number;
  @IsOptional() lon?: number;
  @IsBoolean() @IsOptional() isAddressHidden?: boolean;
  @IsInt() @IsOptional() capacity?: number;
  @IsString() @IsOptional() coverUrl?: string;
}

export class UpdateEventDto extends CreateEventDto {}

export class CreateReviewDto {
  @IsInt()
  @Min(1)
  @Max(5)
  rating!: number;

  @IsOptional()
  @IsString()
  text?: string;
}

export class EventReviewsFilterDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(5)
  rating?: number;
}
