import {
  IsDateString, IsIn, IsInt, IsOptional, IsString, Length, Matches, Max, MaxLength, Min,
} from 'class-validator';
import { PROBLEM_SLUG } from '../../../common/validation/slug';

export class CreateChallengeDto {
  @IsString() @Length(1, 80)
  title!: string;

  @IsOptional() @IsString() @MaxLength(280)
  description?: string;

  @IsString() @MaxLength(120) @Matches(PROBLEM_SLUG, { message: 'problemSlug must be a LeetCode problem slug' })
  problemSlug!: string;

  @IsOptional() @IsIn(['daily', 'squad', 'weekly'])
  type?: string;

  /** Bounded so a squad admin cannot mint arbitrary XP. */
  @IsOptional() @IsInt() @Min(10) @Max(150)
  xpReward?: number;

  @IsDateString()
  startsAt!: string;

  @IsDateString()
  endsAt!: string;
}
