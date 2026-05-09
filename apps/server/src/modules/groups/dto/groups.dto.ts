import { IsNotEmpty, IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

export class CreateGroupDto {
  @IsNotEmpty()
  @IsString()
  @MinLength(2)
  @MaxLength(48)
  name!: string;

  @IsOptional()
  @IsString()
  @MaxLength(256)
  description?: string;
}

export class JoinGroupDto {
  @IsNotEmpty()
  @IsString()
  code!: string;
}
