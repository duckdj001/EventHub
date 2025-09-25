import { IsBoolean, IsOptional } from 'class-validator';

export class UpdateNotificationPreferencesDto {
  @IsOptional()
  @IsBoolean()
  newEvent?: boolean;

  @IsOptional()
  @IsBoolean()
  eventReminder?: boolean;

  @IsOptional()
  @IsBoolean()
  participationApproved?: boolean;

  @IsOptional()
  @IsBoolean()
  newFollower?: boolean;

  @IsOptional()
  @IsBoolean()
  organizerContent?: boolean;

  @IsOptional()
  @IsBoolean()
  followedStory?: boolean;

  @IsOptional()
  @IsBoolean()
  eventUpdated?: boolean;
}
