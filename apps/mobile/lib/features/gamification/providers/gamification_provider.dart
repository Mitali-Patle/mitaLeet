import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/socket/socket_service.dart';
import '../../../core/socket/socket_events.dart';

// ── Models ─────────────────────────────────────────────────────────

const _rankOrder = ['INITIATE', 'OPERATOR', 'SPECIALIST', 'ELITE', 'TITAN', 'APEX'];

class Progression {
  const Progression({
    this.xp = 0,
    this.level = 1,
    this.rank = 'INITIATE',
    this.currentLevelXP = 0,
    this.nextLevelXP = 100,
    this.progress = 0.0,
  });

  final int xp;
  final int level;
  final String rank;
  final int currentLevelXP;
  final int nextLevelXP;
  final double progress;

  int get rankIndex => _rankOrder.indexOf(rank);
  String? get nextRank =>
      rankIndex < _rankOrder.length - 1 ? _rankOrder[rankIndex + 1] : null;

  factory Progression.fromJson(Map<String, dynamic> j) => Progression(
        xp: j['xp'] ?? 0,
        level: j['level'] ?? 1,
        rank: j['rank'] ?? 'INITIATE',
        currentLevelXP: j['currentLevelXP'] ?? 0,
        nextLevelXP: j['nextLevelXP'] ?? 100,
        progress: (j['progress'] as num?)?.toDouble() ?? 0.0,
      );
}

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    required this.xp,
    required this.level,
    required this.rankBadge,
    required this.totalSolves,
    required this.hardSolves,
    required this.currentStreak,
    this.delta,
  });

  final int rank;
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final int xp;
  final int level;
  final String rankBadge;
  final int totalSolves;
  final int hardSolves;
  final int currentStreak;
  final int? delta;

  factory LeaderboardEntry.fromJson(Map<String, dynamic> j) => LeaderboardEntry(
        rank: j['rank'] ?? 0,
        userId: j['userId'] ?? '',
        displayName: j['displayName'] ?? '',
        avatarUrl: j['avatarUrl'],
        xp: j['xp'] ?? 0,
        level: j['level'] ?? 1,
        rankBadge: j['rankBadge'] ?? 'INITIATE',
        totalSolves: j['totalSolves'] ?? 0,
        hardSolves: j['hardSolves'] ?? 0,
        currentStreak: j['currentStreak'] ?? 0,
        delta: j['delta'],
      );
}

class Achievement {
  const Achievement({
    required this.key,
    required this.type,
    required this.title,
    required this.description,
    required this.xpReward,
    required this.unlockedAt,
  });

  final String key;
  final String type;
  final String title;
  final String description;
  final int xpReward;
  final DateTime unlockedAt;

  factory Achievement.fromJson(Map<String, dynamic> j) => Achievement(
        key: j['key'] ?? '',
        type: j['type'] ?? '',
        title: j['title'] ?? '',
        description: j['description'] ?? '',
        xpReward: j['xpReward'] ?? 0,
        unlockedAt: DateTime.tryParse(j['unlockedAt'] ?? '') ?? DateTime.now(),
      );
}

class XPEvent {
  const XPEvent({
    required this.xpGained,
    required this.totalXP,
    required this.level,
    required this.rank,
    required this.reason,
    required this.at,
  });

  final int xpGained;
  final int totalXP;
  final int level;
  final String rank;
  final String reason;
  final DateTime at;
}

// ── State ──────────────────────────────────────────────────────────

class GamificationState {
  const GamificationState({
    this.progression = const Progression(),
    this.achievements = const [],
    this.globalLeaderboard = const [],
    this.friendsLeaderboard = const [],
    this.groupLeaderboard = const [],
    this.recentXPEvents = const [],
    this.isLoading = false,
    this.pendingAchievement,
  });

  final Progression progression;
  final List<Achievement> achievements;
  final List<LeaderboardEntry> globalLeaderboard;
  final List<LeaderboardEntry> friendsLeaderboard;
  final List<LeaderboardEntry> groupLeaderboard;
  final List<XPEvent> recentXPEvents;
  final bool isLoading;
  final Achievement? pendingAchievement; // toast queue

  GamificationState copyWith({
    Progression? progression,
    List<Achievement>? achievements,
    List<LeaderboardEntry>? globalLeaderboard,
    List<LeaderboardEntry>? friendsLeaderboard,
    List<LeaderboardEntry>? groupLeaderboard,
    List<XPEvent>? recentXPEvents,
    bool? isLoading,
    Achievement? pendingAchievement,
    bool clearPending = false,
  }) =>
      GamificationState(
        progression: progression ?? this.progression,
        achievements: achievements ?? this.achievements,
        globalLeaderboard: globalLeaderboard ?? this.globalLeaderboard,
        friendsLeaderboard: friendsLeaderboard ?? this.friendsLeaderboard,
        groupLeaderboard: groupLeaderboard ?? this.groupLeaderboard,
        recentXPEvents: recentXPEvents ?? this.recentXPEvents,
        isLoading: isLoading ?? this.isLoading,
        pendingAchievement: clearPending ? null : (pendingAchievement ?? this.pendingAchievement),
      );
}

// ── Notifier ───────────────────────────────────────────────────────

class GamificationNotifier extends StateNotifier<GamificationState> {
  GamificationNotifier(this._api, this._socket) : super(const GamificationState()) {
    _setupListeners();
  }

  final ApiClient _api;
  final SocketService _socket;

  void _setupListeners() {
    _socket.on(SocketEvents.xpGained, (data) {
      if (data is! Map<String, dynamic>) return;
      final event = XPEvent(
        xpGained: data['xpGained'] ?? 0,
        totalXP: data['totalXP'] ?? 0,
        level: data['level'] ?? 1,
        rank: data['rank'] ?? 'INITIATE',
        reason: data['reason'] ?? '',
        at: DateTime.now(),
      );
      final updated = Progression(
        xp: event.totalXP,
        level: event.level,
        rank: event.rank,
        currentLevelXP: state.progression.currentLevelXP,
        nextLevelXP: state.progression.nextLevelXP,
        progress: state.progression.progress,
      );
      state = state.copyWith(
        progression: updated,
        recentXPEvents: [event, ...state.recentXPEvents.take(9)],
      );
    });

    _socket.on(SocketEvents.achievementUnlocked, (data) {
      if (data is! Map<String, dynamic>) return;
      final achievement = Achievement(
        key: data['key'] ?? '',
        type: data['type'] ?? '',
        title: data['title'] ?? '',
        description: data['description'] ?? '',
        xpReward: data['xpReward'] ?? 0,
        unlockedAt: DateTime.now(),
      );
      state = state.copyWith(
        achievements: [achievement, ...state.achievements],
        pendingAchievement: achievement,
      );
    });

    _socket.on(SocketEvents.leaderboardChanged, (data) {
      if (data is! Map<String, dynamic>) return;
      // Refresh leaderboard for affected group
      loadGroupLeaderboard(data['groupId'] ?? '');
    });

    _socket.on(SocketEvents.levelUp, (data) {
      if (data is! Map<String, dynamic>) return;
      loadProgression(); // refresh full progression after level-up
    });
  }

  Future<void> loadAll({String? groupId}) async {
    state = state.copyWith(isLoading: true);
    await Future.wait([
      loadProgression(),
      loadAchievements(),
      loadGlobalLeaderboard(),
      loadFriendsLeaderboard(),
      if (groupId != null) loadGroupLeaderboard(groupId),
    ]);
    state = state.copyWith(isLoading: false);
  }

  Future<void> loadProgression() async {
    try {
      final res = await _api.get('/gamification/progression');
      state = state.copyWith(progression: Progression.fromJson(res.data['data']));
    } catch (_) {}
  }

  Future<void> loadAchievements() async {
    try {
      final res = await _api.get('/gamification/achievements');
      state = state.copyWith(
        achievements: (res.data['data'] as List).map((e) => Achievement.fromJson(e)).toList(),
      );
    } catch (_) {}
  }

  Future<void> loadGlobalLeaderboard({String period = 'alltime'}) async {
    try {
      final res = await _api.get('/gamification/leaderboard/global',
          queryParameters: {'period': period, 'limit': 50});
      state = state.copyWith(
        globalLeaderboard: (res.data['data'] as List)
            .map((e) => LeaderboardEntry.fromJson(e))
            .toList(),
      );
    } catch (_) {}
  }

  Future<void> loadFriendsLeaderboard() async {
    try {
      final res = await _api.get('/gamification/leaderboard/friends');
      state = state.copyWith(
        friendsLeaderboard: (res.data['data'] as List)
            .map((e) => LeaderboardEntry.fromJson(e))
            .toList(),
      );
    } catch (_) {}
  }

  Future<void> loadGroupLeaderboard(String groupId) async {
    if (groupId.isEmpty) return;
    try {
      final res = await _api.get('/gamification/leaderboard/groups/$groupId');
      state = state.copyWith(
        groupLeaderboard: (res.data['data'] as List)
            .map((e) => LeaderboardEntry.fromJson(e))
            .toList(),
      );
    } catch (_) {}
  }

  void clearPendingAchievement() {
    state = state.copyWith(clearPending: true);
  }

  @override
  void dispose() {
    _socket.off(SocketEvents.xpGained);
    _socket.off(SocketEvents.achievementUnlocked);
    _socket.off(SocketEvents.leaderboardChanged);
    _socket.off(SocketEvents.levelUp);
    super.dispose();
  }
}

// ── Provider ───────────────────────────────────────────────────────

final gamificationProvider =
    StateNotifierProvider<GamificationNotifier, GamificationState>((ref) {
  return GamificationNotifier(
    ref.watch(apiClientProvider),
    ref.watch(socketServiceProvider),
  );
});

// Convenience providers
final progressionProvider = Provider<Progression>(
  (ref) => ref.watch(gamificationProvider).progression,
);
final achievementsProvider = Provider<List<Achievement>>(
  (ref) => ref.watch(gamificationProvider).achievements,
);
