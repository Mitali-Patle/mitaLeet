/// Typed socket event constants matching the backend.
abstract final class SocketEvents {
  // ── Client → Server ────────────────────────────────────
  static const String joinGroup = 'join_group';
  static const String leaveGroup = 'leave_group';
  static const String statusUpdate = 'status_update';
  static const String heartbeat = 'heartbeat';

  // ── Server → Client ────────────────────────────────────
  static const String memberStatus = 'member_status';
  static const String presenceUpdate = 'presence_update';
  static const String newSolve = 'new_solve';
  static const String problemSolved = 'problem_solved';
  static const String syncCompleted = 'sync_completed';
  static const String dailyUpdated = 'daily_updated';
  static const String streakUpdate = 'streak_update';
  static const String xpGained = 'xp_gained';
  static const String levelUp = 'level_up';
  static const String rankUpdated = 'rank_updated';
  static const String achievementUnlocked = 'achievement_unlocked';
  static const String leaderboardChanged = 'leaderboard_changed';
  static const String challengeStarted = 'challenge_started';
  static const String challengeCompleted = 'challenge_completed';
  static const String racePlayerJoined = 'race_player_joined';
  static const String raceCountdown = 'race_countdown';
  static const String raceStarted = 'race_started';
  static const String raceParticipantStatus = 'race_participant_status';
  static const String raceFinished = 'race_finished';
  static const String leaderboard = 'leaderboard';
  static const String challengeUpdate = 'challenge_update';
  static const String activityCreated = 'activity_created';
  static const String notification = 'notification';
  static const String friendRequestSent = 'friend_request_sent';
  static const String friendRequestAccepted = 'friend_request_accepted';
  static const String groupMemberJoined = 'group_member_joined';
  static const String groupMemberLeft = 'group_member_left';
  static const String groupUpdated = 'group_updated';
  static const String onlineMembers = 'online_members';
}
