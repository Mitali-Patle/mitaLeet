// Shared constants between server and extension

export const SOCKET_EVENTS = {
  // Client -> Server
  JOIN_CIRCLE: 'join_circle',
  LEAVE_CIRCLE: 'leave_circle',
  STATUS_UPDATE: 'status_update',

  // Server -> Client
  MEMBER_STATUS: 'member_status',
  NEW_SOLVE: 'new_solve',
  STREAK_UPDATE: 'streak_update',
  LEADERBOARD: 'leaderboard',
  CHALLENGE_UPDATE: 'challenge_update',
} as const;

export const XP_VALUES = {
  EASY: 10,
  MEDIUM: 25,
  HARD: 50,
} as const;
