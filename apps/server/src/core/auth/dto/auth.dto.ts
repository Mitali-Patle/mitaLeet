import { IsNotEmpty, IsString } from 'class-validator';

export class GoogleAuthDto {
  @IsNotEmpty()
  @IsString()
  idToken!: string;
}

export class RefreshTokenDto {
  @IsNotEmpty()
  @IsString()
  refreshToken!: string;
}

export class LogoutDto {
  @IsNotEmpty()
  @IsString()
  refreshToken!: string;
}
