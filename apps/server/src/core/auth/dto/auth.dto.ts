import { IsNotEmpty, IsString, Matches, MaxLength } from 'class-validator';

export class GoogleAuthDto {
  @IsNotEmpty()
  @IsString()
  @MaxLength(4096)
  idToken!: string;
}

export class RefreshTokenDto {
  @IsNotEmpty()
  @IsString()
  @MaxLength(256)
  refreshToken!: string;
}

export class LogoutDto {
  @IsNotEmpty()
  @IsString()
  @MaxLength(256)
  refreshToken!: string;
}

export class DevLoginDto {
  @IsString()
  @MaxLength(24)
  @Matches(/^[a-z0-9_]+$/i)
  username!: string;
}
