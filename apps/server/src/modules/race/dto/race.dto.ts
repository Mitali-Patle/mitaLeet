import { IsIn, IsOptional, IsString, Length, Matches, MaxLength } from 'class-validator';
import { PROBLEM_SLUG } from '../../../common/validation/slug';

export class CreateRaceDto {
  @IsString() @MaxLength(120) @Matches(PROBLEM_SLUG, { message: 'problemSlug must be a LeetCode problem slug' })
  problemSlug!: string;

  @IsOptional() @IsString() @MaxLength(120)
  problemName?: string;
}

export class JoinRaceDto {
  @IsString() @Length(4, 12)
  code!: string;
}

/** Racers may report progress; ACCEPTED is only set by a verified finish. */
export const RACE_PROGRESS_STATUSES = ['WAITING', 'THINKING', 'CODING', 'TESTING'] as const;

export class UpdateRaceStatusDto {
  @IsIn(RACE_PROGRESS_STATUSES)
  status!: (typeof RACE_PROGRESS_STATUSES)[number];
}
