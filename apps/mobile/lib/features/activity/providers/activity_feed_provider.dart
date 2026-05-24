// Activity Feed Provider — features/activity (filterable, batch-loaded feed)
//
// PURPOSE: Powers ActivityScreen (the tabbed activity feed with ALL/SOLVES/
//   STREAKS/CHALLENGES filters) and HomeScreen (homepage activity summary).
// MODEL: ActivityItem — includes a parsed `action`/`detail` pair and a
//   `filtered` getter keyed on `activeFilter`.
//
// DISTINCT FROM: features/social/providers/activity_feed_provider.dart, which
//   powers LiveActivityScreen and uses ActivityEvent (cursor-paged, hasMore).
//   Both files intentionally coexist — they serve different screens with
//   different data shapes and interaction patterns.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/socket/socket_service.dart';
import '../../../core/socket/socket_events.dart';

// ── Model ──────────────────────────────────────────────────────────

class ActivityItem {
  const ActivityItem({
    required this.id,
    required this.userId,
    required this.displayName,
    required this.action,
    required this.detail,
    required this.type,
    this.difficulty,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String displayName;
  final String action;
  final String detail;
  final String type;
  final String? difficulty;
  final DateTime createdAt;

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  factory ActivityItem.fromJson(Map<String, dynamic> j) {
    final type = (j['type'] ?? 'SOLVE') as String;
    final meta = j['metadata'] as Map<String, dynamic>? ?? {};
    final user = j['user'] as Map<String, dynamic>? ?? {};
    final problem = meta['problem'] as Map<String, dynamic>? ?? {};

    String action;
    String detail;
    String? difficulty;

    switch (type) {
      case 'SOLVE':
        action = 'solved';
        detail = problem['slug'] ?? meta['problemSlug'] ?? '';
        difficulty = problem['difficulty'] ?? meta['difficulty'];
        break;
      case 'STREAK_EXTENDED':
        action = 'extended streak to';
        detail = '${meta['currentStreak'] ?? ''} days';
        break;
      case 'STREAK_STARTED':
        action = 'started a streak';
        detail = 'Day 1';
        break;
      case 'CHALLENGE_JOINED':
        action = 'joined challenge';
        detail = meta['challengeName'] ?? '';
        break;
      case 'CHALLENGE_COMPLETED':
        action = 'completed challenge';
        detail = meta['challengeName'] ?? '';
        break;
      case 'LEVEL_UP':
        action = 'leveled up to';
        detail = 'Level ${meta['level'] ?? ''}';
        break;
      default:
        action = type.toLowerCase().replaceAll('_', ' ');
        detail = '';
    }

    return ActivityItem(
      id: j['id'] ?? '',
      userId: user['id'] ?? j['userId'] ?? '',
      displayName: user['displayName'] ?? user['username'] ?? '',
      action: action,
      detail: detail,
      type: type,
      difficulty: difficulty,
      createdAt: DateTime.tryParse(j['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
}

// ── State ──────────────────────────────────────────────────────────

class ActivityFeedState {
  const ActivityFeedState({
    this.items = const [],
    this.isLoading = false,
    this.activeFilter = 'ALL',
    this.error,
  });

  final List<ActivityItem> items;
  final bool isLoading;
  final String activeFilter;
  final String? error;

  ActivityFeedState copyWith({
    List<ActivityItem>? items,
    bool? isLoading,
    String? activeFilter,
    String? error,
  }) =>
      ActivityFeedState(
        items: items ?? this.items,
        isLoading: isLoading ?? this.isLoading,
        activeFilter: activeFilter ?? this.activeFilter,
        error: error ?? this.error,
      );

  List<ActivityItem> get filtered {
    if (activeFilter == 'ALL') return items;
    if (activeFilter == 'SOLVES') return items.where((i) => i.type == 'SOLVE').toList();
    if (activeFilter == 'STREAKS') {
      return items
          .where((i) =>
              i.type == 'STREAK_EXTENDED' || i.type == 'STREAK_STARTED')
          .toList();
    }
    if (activeFilter == 'CHALLENGES') {
      return items
          .where((i) =>
              i.type == 'CHALLENGE_JOINED' || i.type == 'CHALLENGE_COMPLETED')
          .toList();
    }
    return items;
  }
}

// ── Notifier ───────────────────────────────────────────────────────

class ActivityFeedNotifier extends StateNotifier<ActivityFeedState> {
  ActivityFeedNotifier(this._api, this._socket) : super(const ActivityFeedState()) {
    _socket.on(SocketEvents.activityCreated, (data) {
      if (data is! Map<String, dynamic>) return;
      try {
        final newItem = ActivityItem.fromJson(data);
        state = state.copyWith(items: [newItem, ...state.items]);
      } catch (_) {}
    });
  }

  final ApiClient _api;
  final SocketService _socket;

  Future<void> loadFeed({int limit = 50}) async {
    state = state.copyWith(isLoading: true);
    try {
      final res = await _api.get(ApiEndpoints.activitiesFeed,
          queryParameters: {'limit': limit});
      final data = res.data['data'] as List? ?? [];
      state = state.copyWith(
        items: data.map((e) => ActivityItem.fromJson(e as Map<String, dynamic>)).toList(),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void setFilter(String filter) {
    state = state.copyWith(activeFilter: filter);
  }

  @override
  void dispose() {
    _socket.off(SocketEvents.activityCreated);
    super.dispose();
  }
}

// ── Provider ───────────────────────────────────────────────────────

final activityFeedProvider =
    StateNotifierProvider<ActivityFeedNotifier, ActivityFeedState>((ref) {
  return ActivityFeedNotifier(
    ref.watch(apiClientProvider),
    ref.watch(socketServiceProvider),
  );
});
