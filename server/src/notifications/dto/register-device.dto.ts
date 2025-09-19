import { IsIn, IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class RegisterDeviceDto {
  @IsString()
  @IsNotEmpty()
  token!: string;

  @IsString()
  @IsIn(['ios', 'android'])
  platform!: 'ios' | 'android';
}

export class DeregisterDeviceDto {
  @IsString()
  @IsNotEmpty()
  token!: string;

  @IsOptional()
  @IsString()
  platform?: string;
}
