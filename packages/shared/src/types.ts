// Shared type definitions between server and extension

export enum UserStatus {
  ONLINE = 'ONLINE',
  SOLVING = 'SOLVING',
  IDLE = 'IDLE',
  OFFLINE = 'OFFLINE',
}

export enum Difficulty {
  EASY = 'EASY',
  MEDIUM = 'MEDIUM',
  HARD = 'HARD',
}

export enum CircleRole {
  OWNER = 'OWNER',
  ADMIN = 'ADMIN',
  MEMBER = 'MEMBER',
}

export enum InviteStatus {
  PENDING = 'PENDING',
  ACCEPTED = 'ACCEPTED',
  DECLINED = 'DECLINED',
}

export interface SolveEvent {
  userId: string;
  problemSlug: string;
  difficulty: Difficulty;
  language: string;
  runtime?: number;
  memory?: number;
  solvedAt: string;
}

export interface StatusUpdate {
  userId: string;
  status: UserStatus;
}

export interface LeaderboardEntry {
  userId: string;
  displayName: string;
  avatarUrl?: string;
  totalSolves: number;
  currentStreak: number;
  score: number;
  rank: number;
}
