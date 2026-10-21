import { Type } from 'class-transformer';
import { IsIn, IsInt, IsOptional, IsString, IsUUID, Length, Max, Min } from 'class-validator';

/** Shared, bounded query parameters so no endpoint can be asked for unbounded rows. */
export class LimitQueryDto {
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) @Max(100)
  limit?: number;
}

export class FeedQueryDto extends LimitQueryDto {
  /** id of the last activity already shown */
  @IsOptional() @IsUUID()
  cursor?: string;
}

export class HeatmapQueryDto {
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) @Max(366)
  days?: number;
}

export class LeaderboardQueryDto extends LimitQueryDto {
  @IsOptional() @IsIn(['daily', 'weekly', 'monthly', 'alltime'])
  period?: 'daily' | 'weekly' | 'monthly' | 'alltime';

  @IsOptional() @Type(() => Number) @IsInt() @Min(0) @Max(10_000)
  offset?: number;
}

export class SearchQueryDto {
  @IsString() @Length(2, 50)
  q!: string;

  @IsOptional() @Type(() => Number) @IsInt() @Min(1) @Max(50)
  limit?: number;
}
