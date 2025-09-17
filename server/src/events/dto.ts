import { IsBoolean, IsDateString, IsInt, IsOptional, IsString, Min } from 'class-validator';

export class CreateEventDto {
  @IsString() title!: string;
  @IsString() description!: string;

  @IsString() @IsOptional() categoryId?: string;

  @IsBoolean() @IsOptional() isPaid?: boolean;
  @IsInt() @IsOptional() @Min(0) price?: number;
  @IsString() @IsOptional() currency?: string;

  @IsBoolean() @IsOptional() requiresApproval?: boolean;

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
