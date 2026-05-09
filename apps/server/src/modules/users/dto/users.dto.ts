import { IsOptional, IsString, MinLength, MaxLength, Matches } from 'class-validator';

export class UpdateProfileDto {
  @IsOptional()
  @IsString()
  @MinLength(3)
  @MaxLength(24)
  @Matches(/^[a-z0-9_]+$/, {
    message: 'Username must be lowercase alphanumeric with underscores only',
  })
  username?: string;

  @IsOptional()
  @IsString()
  @MaxLength(160)
  bio?: string;

  @IsOptional()
  @IsString()
  @Matches(/^[a-zA-Z0-9_-]+$/, {
    message: 'Invalid LeetCode username format',
  })
  leetcodeUsername?: string;

  @IsOptional()
  @IsString()
  displayName?: string;

  @IsOptional()
  @IsString()
  avatarUrl?: string;
}

export class RegisterDeviceDto {
  @IsString()
  token!: string;

  @IsString()
  @Matches(/^(android|ios|web)$/)
  platform!: string;
}
