import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/socket/socket_service.dart';
import '../../../core/socket/socket_events.dart';

// ── Models ─────────────────────────────────────────────────────────

class SolveRecord {
  const SolveRecord({
    required this.id,
    required this.problemSlug,
    required this.problemName,
    required this.difficulty,
    required this.language,
    this.runtime,
    this.memory,
    required this.solvedAt,
    this.topicTags = const [],
  });

  final String id;
  final String problemSlug;
  final String problemName;
  final String difficulty;
  final String language;
  final int? runtime;
  final double? memory;
  final DateTime solvedAt;
  final List<String> topicTags;

  String get timeAgo {
    final diff = DateTime.now().difference(solvedAt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  factory SolveRecord.fromJson(Map<String, dynamic> j) => SolveRecord(
        id: j['id'] ?? '',
        problemSlug: j['problemSlug'] ?? '',
        problemName: j['problemName'] ?? j['problemSlug'] ?? '',
        difficulty: j['difficulty'] ?? 'MEDIUM',
        language: j['language'] ?? '',
        runtime: j['runtime'],
        memory: (j['memory'] as num?)?.toDouble(),
        solvedAt: DateTime.tryParse(j['solvedAt'] ?? '') ?? DateTime.now(),
        topicTags: List<String>.from(j['problem']?['topicTags'] ?? []),
      );
}

class StreakData {
  const StreakData({
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.isSolvedToday = false,
    this.lastSolveDate,
  });

  final int currentStreak;
  final int longestStreak;
  final bool isSolvedToday;
  final DateTime? lastSolveDate;

  factory StreakData.fromJson(Map<String, dynamic> j) => StreakData(
        currentStreak: j['currentStreak'] ?? 0,
        longestStreak: j['longestStreak'] ?? 0,
        isSolvedToday: j['isSolvedToday'] ?? false,
        lastSolveDate: DateTime.tryParse(j['lastSolveDate'] ?? ''),
      );
}

class CodingStats {
  const CodingStats({
    this.xp = 0,
    this.totalSolves = 0,
    this.easySolves = 0,
    this.mediumSolves = 0,
    this.hardSolves = 0,
    this.todayCount = 0,
    this.streak = const StreakData(),
  });

  final int xp;
  final int totalSolves;
  final int easySolves;
  final int mediumSolves;
  final int hardSolves;
  final int todayCount;
  final StreakData streak;

  factory CodingStats.fromJson(Map<String, dynamic> j) {
    final p = j['profile'] ?? {};
    final s = j['streak'] ?? {};
    final t = j['today'] ?? {};
    return CodingStats(
      xp: p['xp'] ?? 0,
      totalSolves: p['totalSolves'] ?? 0,
      easySolves: p['easySolves'] ?? 0,
      mediumSolves: p['mediumSolves'] ?? 0,
      hardSolves: p['hardSolves'] ?? 0,
      todayCount: t['solveCount'] ?? 0,
      streak: StreakData.fromJson(s),
    );
  }
}

class LeetCodeLinkStatus {
  const LeetCodeLinkStatus({
    this.leetcodeUsername,
    this.isLinked = false,
    this.isVerified = false,
    this.lastSyncAt,
    this.isSyncing = false,
  });

  final String? leetcodeUsername;
  final bool isLinked;
  final bool isVerified;
  final DateTime? lastSyncAt;
  final bool isSyncing;

  factory LeetCodeLinkStatus.fromJson(Map<String, dynamic> j) => LeetCodeLinkStatus(
        leetcodeUsername: j['leetcodeUsername'],
        isLinked: j['leetcodeUsername'] != null,
        isVerified: j['leetcodeVerified'] ?? false,
        lastSyncAt: DateTime.tryParse(j['lastSyncAt'] ?? ''),
      );

  LeetCodeLinkStatus copyWith({bool? isSyncing}) => LeetCodeLinkStatus(
        leetcodeUsername: leetcodeUsername,
        isLinked: isLinked,
        isVerified: isVerified,
        lastSyncAt: lastSyncAt,
        isSyncing: isSyncing ?? this.isSyncing,
      );
}

// ── State ──────────────────────────────────────────────────────────

class LeetCodeState {
  const LeetCodeState({
    this.linkStatus = const LeetCodeLinkStatus(),
    this.stats = const CodingStats(),
    this.recentSolves = const [],
    this.heatmap = const {},
    this.isLoading = false,
    this.isLinking = false,
    this.error,
  });

  final LeetCodeLinkStatus linkStatus;
  final CodingStats stats;
  final List<SolveRecord> recentSolves;
  final Map<String, int> heatmap;
  final bool isLoading;
  final bool isLinking;
  final String? error;

  LeetCodeState copyWith({
    LeetCodeLinkStatus? linkStatus,
    CodingStats? stats,
    List<SolveRecord>? recentSolves,
    Map<String, int>? heatmap,
    bool? isLoading,
    bool? isLinking,
    String? error,
  }) =>
      LeetCodeState(
        linkStatus: linkStatus ?? this.linkStatus,
        stats: stats ?? this.stats,
        recentSolves: recentSolves ?? this.recentSolves,
        heatmap: heatmap ?? this.heatmap,
        isLoading: isLoading ?? this.isLoading,
        isLinking: isLinking ?? this.isLinking,
        error: error,
      );
}

// ── Notifier ───────────────────────────────────────────────────────

class LeetCodeNotifier extends StateNotifier<LeetCodeState> {
  LeetCodeNotifier(this._api, this._socket) : super(const LeetCodeState()) {
    _setupSocketListeners();
  }

  final ApiClient _api;
  final SocketService _socket;

  void _setupSocketListeners() {
    _socket.on(SocketEvents.streakUpdate, (data) {
      if (data is! Map<String, dynamic>) return;
      if (data['type'] == 'SYNC_COMPLETED') {
        loadStats();
        loadRecentSolves();
      }
      if ((data['currentStreak'] as int?) != null) {
        final updated = CodingStats(
          xp: state.stats.xp,
          totalSolves: state.stats.totalSolves,
          easySolves: state.stats.easySolves,
          mediumSolves: state.stats.mediumSolves,
          hardSolves: state.stats.hardSolves,
          todayCount: state.stats.todayCount,
          streak: StreakData(
            currentStreak: data['currentStreak'] ?? state.stats.streak.currentStreak,
            longestStreak: data['longestStreak'] ?? state.stats.streak.longestStreak,
            isSolvedToday: true,
          ),
        );
        state = state.copyWith(stats: updated);
      }
    });
  }

  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true);
    await Future.wait([
      loadLinkStatus(),
      loadStats(),
      loadRecentSolves(),
    ]);
    state = state.copyWith(isLoading: false);
  }

  Future<void> loadLinkStatus() async {
    try {
      final res = await _api.get(ApiEndpoints.lcStatus);
      state = state.copyWith(
        linkStatus: LeetCodeLinkStatus.fromJson(res.data['data']),
      );
    } catch (_) {}
  }

  Future<void> loadStats() async {
    try {
      final res = await _api.get(ApiEndpoints.lcStats);
      state = state.copyWith(stats: CodingStats.fromJson(res.data['data']));
    } catch (_) {}
  }

  Future<void> loadRecentSolves({int limit = 20}) async {
    try {
      final res = await _api.get(ApiEndpoints.lcSolves,
          queryParameters: {'limit': limit});
      state = state.copyWith(
        recentSolves: (res.data['data'] as List)
            .map((e) => SolveRecord.fromJson(e))
            .toList(),
      );
    } catch (_) {}
  }

  Future<void> loadHeatmap() async {
    try {
      final res = await _api.get(ApiEndpoints.lcHeatmap,
          queryParameters: {'days': 90});
      final raw = res.data['data'] as List;
      final map = <String, int>{};
      for (final d in raw) {
        final date = d['date']?.toString().split('T').first ?? '';
        map[date] = d['solveCount'] ?? 0;
      }
      state = state.copyWith(heatmap: map);
    } catch (_) {}
  }

  Future<bool> linkAccount(String username) async {
    state = state.copyWith(isLinking: true, error: null);
    try {
      await _api.post(ApiEndpoints.lcLink,
          data: {'leetcodeUsername': username});
      await loadLinkStatus();
      state = state.copyWith(isLinking: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLinking: false, error: _extractError(e));
      return false;
    }
  }

  Future<void> unlinkAccount() async {
    await _api.delete(ApiEndpoints.lcLink);
    state = state.copyWith(
      linkStatus: const LeetCodeLinkStatus(),
      stats: const CodingStats(),
      recentSolves: [],
    );
  }

  Future<void> triggerSync() async {
    state = state.copyWith(
      linkStatus: state.linkStatus.copyWith(isSyncing: true),
    );
    try {
      await _api.post(ApiEndpoints.lcSync);
      // Real result comes via WebSocket STREAK_UPDATE event
    } catch (_) {
    } finally {
      state = state.copyWith(
        linkStatus: state.linkStatus.copyWith(isSyncing: false),
      );
    }
  }

  String _extractError(dynamic e) {
    if (e is DioException) {
      // Pull the message field from the server's JSON error body first.
      final msg = e.response?.data?['message'];
      if (msg != null && msg.toString().isNotEmpty) return msg.toString();
      // Fall back to HTTP status.
      final status = e.response?.statusCode;
      if (status != null) return 'Server error $status';
    }
    return e.toString().replaceAll('Exception:', '').trim();
  }

  @override
  void dispose() {
    _socket.off(SocketEvents.streakUpdate);
    super.dispose();
  }
}

// ── Provider ───────────────────────────────────────────────────────

final leetcodeProvider =
    StateNotifierProvider<LeetCodeNotifier, LeetCodeState>((ref) {
  return LeetCodeNotifier(
    ref.watch(apiClientProvider),
    ref.watch(socketServiceProvider),
  );
});
