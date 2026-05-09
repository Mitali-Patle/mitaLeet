import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/socket/socket_service.dart';
import '../../../core/socket/socket_events.dart';

/// Single activity event.
class ActivityEvent {
  const ActivityEvent({
    required this.id,
    required this.type,
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    this.data,
    required this.createdAt,
  });

  final String id;
  final String type;
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final Map<String, dynamic>? data;
  final DateTime createdAt;

  factory ActivityEvent.fromJson(Map<String, dynamic> json) => ActivityEvent(
        id: json['id'] ?? '',
        type: json['type'] ?? '',
        userId: json['user']?['id'] ?? json['userId'] ?? '',
        displayName: json['user']?['displayName'] ?? '',
        avatarUrl: json['user']?['avatarUrl'],
        data: json['data'] is Map ? Map<String, dynamic>.from(json['data']) : null,
        createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      );

  String get actionText {
    switch (type) {
      case 'SOLVE': return 'solved';
      case 'STREAK_EXTENDED': return 'extended streak to';
      case 'STREAK_BROKEN': return 'streak broken at';
      case 'CHALLENGE_JOINED': return 'joined challenge';
      case 'CHALLENGE_COMPLETED': return 'completed challenge';
      case 'GROUP_JOINED': return 'joined squad';
      case 'RANK_CHANGED': return 'rank changed to';
      case 'XP_GAINED': return 'gained XP';
      default: return type.toLowerCase().replaceAll('_', ' ');
    }
  }

  String get detail {
    return data?['problemSlug'] ?? data?['detail'] ?? data?['groupName'] ?? '';
  }

  String? get difficulty => data?['difficulty']?.toString();

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}

/// Activity feed state.
class ActivityFeedState {
  const ActivityFeedState({
    this.events = const [],
    this.isLoading = false,
    this.hasMore = true,
  });

  final List<ActivityEvent> events;
  final bool isLoading;
  final bool hasMore;

  ActivityFeedState copyWith({
    List<ActivityEvent>? events,
    bool? isLoading,
    bool? hasMore,
  }) => ActivityFeedState(
        events: events ?? this.events,
        isLoading: isLoading ?? this.isLoading,
        hasMore: hasMore ?? this.hasMore,
      );
}

class ActivityFeedNotifier extends StateNotifier<ActivityFeedState> {
  ActivityFeedNotifier(this._api, this._socket) : super(const ActivityFeedState()) {
    _setupSocketListeners();
  }

  final ApiClient _api;
  final SocketService _socket;

  void _setupSocketListeners() {
    _socket.on(SocketEvents.activityCreated, (data) {
      if (data is Map<String, dynamic>) {
        final event = ActivityEvent.fromJson(data);
        // Prepend to feed for realtime feel
        state = state.copyWith(
          events: [event, ...state.events],
        );
      }
    });
  }

  Future<void> loadFeed({bool refresh = false}) async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true);

    try {
      final cursor = refresh ? null : state.events.lastOrNull?.id;
      final res = await _api.get(
        ApiEndpoints.activitiesFeed,
        queryParameters: {
          'limit': 30,
          if (cursor != null) 'cursor': cursor,
        },
      );

      final newEvents = (res.data['data'] as List)
          .map((e) => ActivityEvent.fromJson(e))
          .toList();

      state = state.copyWith(
        events: refresh ? newEvents : [...state.events, ...newEvents],
        isLoading: false,
        hasMore: newEvents.length >= 30,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> refresh() => loadFeed(refresh: true);

  @override
  void dispose() {
    _socket.off(SocketEvents.activityCreated);
    super.dispose();
  }
}

final activityFeedProvider = StateNotifierProvider<ActivityFeedNotifier, ActivityFeedState>((ref) {
  return ActivityFeedNotifier(
    ref.watch(apiClientProvider),
    ref.watch(socketServiceProvider),
  );
});
