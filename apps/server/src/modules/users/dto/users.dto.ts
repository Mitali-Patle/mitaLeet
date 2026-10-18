import { Equals, IsOptional, IsString, IsTimeZone, IsUrl, Length, MinLength, MaxLength, Matches } from 'class-validator';

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

  /** IANA zone, e.g. "Asia/Kolkata"; streaks and "today" follow it. */
  @IsOptional()
  @IsTimeZone()
  timezone?: string;

  @IsOptional()
  @IsString()
  @Length(1, 50)
  displayName?: string;

  /** Rendered by other users' clients, so only plain https image URLs. */
  @IsOptional()
  @IsUrl({ protocols: ['https'], require_protocol: true })
  @MaxLength(500)
  avatarUrl?: string;
}

export class RegisterDeviceDto {
  @IsString()
  @Length(10, 4096)
  token!: string;

  @IsString()
  @Matches(/^(android|ios|web)$/)
  platform!: string;
}

export class DeleteAccountDto {
  /** Must be exactly "DELETE" so an accidental call cannot erase an account. */
  @Equals('DELETE')
  confirm!: string;
}
