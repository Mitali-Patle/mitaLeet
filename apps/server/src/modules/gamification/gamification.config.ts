import { Rank } from '@prisma/client';

// ── XP config ──────────────────────────────────────────────────────

export const XP_REWARDS = {
  EASY: 10,
  MEDIUM: 25,
  HARD: 50,
  STREAK_BONUS_MULTIPLIER: 0.1, // +10% XP per 10 streak days (capped at 2x)
  FIRST_SOLVE_OF_DAY: 15,       // bonus for first solve each day
  CHALLENGE_COMPLETE: 75,
  CHALLENGE_WIN: 150,
} as const;

// ── Level thresholds ────────────────────────────────────────────────

/**
 * XP required to REACH each level.
 * Level 1 starts at 0 XP.
 * Uses a progressive curve: level N costs ~N²×20 cumulative XP.
 */
export function xpForLevel(level: number): number {
  if (level <= 1) return 0;
  return Math.floor(20 * Math.pow(level - 1, 2));
}

/** Level that a given total XP corresponds to. */
export function levelForXP(xp: number): number {
  let level = 1;
  while (xpForLevel(level + 1) <= xp) level++;
  return level;
}

/** Progress toward next level [0, 1]. */
export function levelProgress(xp: number): {
  level: number;
  currentLevelXP: number;
  nextLevelXP: number;
  progress: number;
} {
  const level = levelForXP(xp);
  const currentLevelXP = xpForLevel(level);
  const nextLevelXP = xpForLevel(level + 1);
  const span = nextLevelXP - currentLevelXP;
  const earned = xp - currentLevelXP;
  return {
    level,
    currentLevelXP: earned,
    nextLevelXP: span,
    progress: span > 0 ? earned / span : 1,
  };
}

// ── Rank thresholds ─────────────────────────────────────────────────

/** XP floor for each rank. */
export const RANK_THRESHOLDS: Record<Rank, number> = {
  INITIATE:   0,
  OPERATOR:   500,
  SPECIALIST: 1_500,
  ELITE:      4_000,
  TITAN:      10_000,
  APEX:       25_000,
};

export const RANK_ORDER: Rank[] = [
  'INITIATE', 'OPERATOR', 'SPECIALIST', 'ELITE', 'TITAN', 'APEX',
];

export function rankForXP(xp: number): Rank {
  let current: Rank = 'INITIATE';
  for (const rank of RANK_ORDER) {
    if (xp >= RANK_THRESHOLDS[rank]) current = rank;
  }
  return current;
}

export function nextRank(rank: Rank): Rank | null {
  const idx = RANK_ORDER.indexOf(rank);
  return idx < RANK_ORDER.length - 1 ? RANK_ORDER[idx + 1] : null;
}

export function xpToNextRank(xp: number): number | null {
  const rank = rankForXP(xp);
  const next = nextRank(rank);
  if (!next) return null;
  return RANK_THRESHOLDS[next] - xp;
}

// ── Achievement catalog ─────────────────────────────────────────────

export interface AchievementDef {
  key: string;
  type: string;
  title: string;
  description: string;
  xpReward: number;
  check: (stats: AchievementStats) => boolean;
}

export interface AchievementStats {
  totalSolves: number;
  hardSolves: number;
  currentStreak: number;
  longestStreak: number;
  level: number;
  xp: number;
}

export const ACHIEVEMENTS: AchievementDef[] = [
  // Solve milestones
  { key: 'first_solve', type: 'FIRST_SOLVE', title: 'First Blood', description: 'Solved your first problem', xpReward: 25, check: (s) => s.totalSolves >= 1 },
  { key: 'solves_10', type: 'SOLVE_MILESTONE', title: 'Warming Up', description: 'Solved 10 problems', xpReward: 50, check: (s) => s.totalSolves >= 10 },
  { key: 'solves_50', type: 'SOLVE_MILESTONE', title: 'Operator', description: 'Solved 50 problems', xpReward: 100, check: (s) => s.totalSolves >= 50 },
  { key: 'solves_100', type: 'SOLVE_MILESTONE', title: 'Century', description: 'Solved 100 problems', xpReward: 200, check: (s) => s.totalSolves >= 100 },
  { key: 'solves_250', type: 'SOLVE_MILESTONE', title: 'Elite Coder', description: 'Solved 250 problems', xpReward: 400, check: (s) => s.totalSolves >= 250 },
  { key: 'solves_500', type: 'SOLVE_MILESTONE', title: 'TITAN', description: 'Solved 500 problems', xpReward: 750, check: (s) => s.totalSolves >= 500 },
  // Streak milestones
  { key: 'streak_3', type: 'STREAK_MILESTONE', title: 'Consistent', description: 'Maintained a 3-day streak', xpReward: 30, check: (s) => s.longestStreak >= 3 },
  { key: 'streak_7', type: 'STREAK_MILESTONE', title: 'Seven Days', description: 'Maintained a 7-day streak', xpReward: 75, check: (s) => s.longestStreak >= 7 },
  { key: 'streak_30', type: 'STREAK_MILESTONE', title: 'Iron Will', description: 'Maintained a 30-day streak', xpReward: 300, check: (s) => s.longestStreak >= 30 },
  { key: 'streak_100', type: 'STREAK_MILESTONE', title: 'Relentless', description: 'Maintained a 100-day streak', xpReward: 1000, check: (s) => s.longestStreak >= 100 },
  // Hard problem milestones
  { key: 'hard_1', type: 'HARD_PROBLEM', title: 'Hard Breaker', description: 'Solved your first hard problem', xpReward: 75, check: (s) => s.hardSolves >= 1 },
  { key: 'hard_10', type: 'HARD_PROBLEM', title: 'Hard Specialist', description: 'Solved 10 hard problems', xpReward: 200, check: (s) => s.hardSolves >= 10 },
  { key: 'hard_50', type: 'HARD_PROBLEM', title: 'Hard Elite', description: 'Solved 50 hard problems', xpReward: 500, check: (s) => s.hardSolves >= 50 },
  // Level milestones
  { key: 'level_5', type: 'LEVEL_MILESTONE', title: 'Level 5', description: 'Reached level 5', xpReward: 100, check: (s) => s.level >= 5 },
  { key: 'level_10', type: 'LEVEL_MILESTONE', title: 'Level 10', description: 'Reached level 10', xpReward: 250, check: (s) => s.level >= 10 },
  { key: 'level_25', type: 'LEVEL_MILESTONE', title: 'Level 25', description: 'Reached level 25', xpReward: 500, check: (s) => s.level >= 25 },
];
