/// Centralized API endpoint paths.
/// All paths are relative to the base URL (e.g. http://localhost:3000/api/v1).
abstract final class ApiEndpoints {
  // ── Auth ────────────────────────────────────────────────────────────
  static const String authGoogle = '/auth/google';
  static const String authDevLogin = '/auth/dev-login';
  static const String authRefresh = '/auth/refresh';
  static const String authLogout = '/auth/logout';
  static const String authLogoutAll = '/auth/logout-all';

  // ── Users ───────────────────────────────────────────────────────────
  static const String usersMe = '/users/me';
  static const String usersMeProfile = '/users/me/profile';
  static const String usersMeDevices = '/users/me/devices';
  static String usersByUsername(String username) => '/users/$username';

  // ── Groups ──────────────────────────────────────────────────────────
  static const String groups = '/groups';
  static const String groupsJoin = '/groups/join';
  static String groupById(String id) => '/groups/$id';
  static String groupLeaderboard(String id) => '/groups/$id/leaderboard';
  static String groupActivity(String id) => '/groups/$id/activity';
  static String groupLeave(String id) => '/groups/$id/leave';
  static String groupPromote(String id, String memberId) => '/groups/$id/members/$memberId/promote';
  static String groupDemote(String id, String memberId) => '/groups/$id/members/$memberId/demote';
  static String groupRemoveMember(String id, String memberId) => '/groups/$id/members/$memberId';
  static String groupRegenerateCode(String id) => '/groups/$id/regenerate-code';

  // ── Friends ─────────────────────────────────────────────────────────
  static const String friends = '/friends';
  static const String friendRequests = '/friends/requests';
  static const String friendRequestsIncoming = '/friends/requests/incoming';
  static const String friendRequestsOutgoing = '/friends/requests/outgoing';
  static const String friendSearch = '/friends/search';
  static String friendMutual(String userId) => '/friends/mutual/$userId';

  // ── Activities ──────────────────────────────────────────────────────
  static const String activitiesFeed = '/activities/feed';
  static const String activitiesMe = '/activities/me';

  // ── Notifications ───────────────────────────────────────────────────
  static const String notifications = '/notifications';
  static const String notificationsUnreadCount = '/notifications/unread-count';
  static const String notificationsReadAll = '/notifications/read-all';
  static String notificationRead(String id) => '/notifications/$id/read';

  // ── LeetCode ─────────────────────────────────────────────────────
  static const String lcStatus = '/leetcode/status';
  static const String lcLink = '/leetcode/link';
  static const String lcSync = '/leetcode/sync';
  static const String lcSyncHistory = '/leetcode/sync/history';
  static const String lcSolves = '/leetcode/solves';
  static const String lcStats = '/leetcode/stats';
  static const String lcHeatmap = '/leetcode/heatmap';
  static const String lcStreak = '/leetcode/streak';
  static const String lcSessions = '/leetcode/sessions';
  static String lcSessionComplete(String id) => '/leetcode/sessions/$id/complete';
}
