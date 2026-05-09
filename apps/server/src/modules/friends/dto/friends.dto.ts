import { IsNotEmpty, IsString, IsOptional, IsEnum } from 'class-validator';

export class SendFriendRequestDto {
  @IsNotEmpty()
  @IsString()
  receiverId!: string;
}

export class RespondFriendRequestDto {
  @IsNotEmpty()
  @IsEnum(['ACCEPTED', 'DECLINED'] as const)
  action!: 'ACCEPTED' | 'DECLINED';
}

export class SearchUsersDto {
  @IsNotEmpty()
  @IsString()
  query!: string;

  @IsOptional()
  limit?: number;
}
