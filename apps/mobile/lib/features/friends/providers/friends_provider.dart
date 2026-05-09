import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/socket/socket_service.dart';
import '../../../core/socket/socket_events.dart';

/// Friend with presence info.
class Friend {
  const Friend({
    required this.userId,
    required this.displayName,
    this.username,
    this.avatarUrl,
    this.status = 'OFFLINE',
    this.isOnline = false,
    this.xp = 0,
  });

  final String userId;
  final String displayName;
  final String? username;
  final String? avatarUrl;
  final String status;
  final bool isOnline;
  final int xp;

  Friend copyWith({String? status, bool? isOnline}) => Friend(
        userId: userId,
        displayName: displayName,
        username: username,
        avatarUrl: avatarUrl,
        status: status ?? this.status,
        isOnline: isOnline ?? this.isOnline,
        xp: xp,
      );

  factory Friend.fromJson(Map<String, dynamic> json) => Friend(
        userId: json['id'] ?? json['userId'] ?? '',
        displayName: json['displayName'] ?? '',
        username: json['profile']?['username'] ?? json['username'],
        avatarUrl: json['avatarUrl'],
        status: json['status'] ?? 'OFFLINE',
        isOnline: json['isOnline'] ?? false,
        xp: json['profile']?['xp'] ?? json['xp'] ?? 0,
      );
}

/// Friend request.
class FriendRequest {
  const FriendRequest({
    required this.id,
    required this.userId,
    required this.displayName,
    this.username,
    this.avatarUrl,
  });

  final String id;
  final String userId;
  final String displayName;
  final String? username;
  final String? avatarUrl;

  factory FriendRequest.fromJson(Map<String, dynamic> json, String key) {
    final user = json[key] ?? {};
    return FriendRequest(
      id: json['id'] ?? '',
      userId: user['id'] ?? '',
      displayName: user['displayName'] ?? '',
      username: user['profile']?['username'],
      avatarUrl: user['avatarUrl'],
    );
  }
}

/// Friends state.
class FriendsState {
  const FriendsState({
    this.friends = const [],
    this.incoming = const [],
    this.outgoing = const [],
    this.searchResults = const [],
    this.isLoading = false,
    this.isSearching = false,
    this.error,
  });

  final List<Friend> friends;
  final List<FriendRequest> incoming;
  final List<FriendRequest> outgoing;
  final List<Map<String, dynamic>> searchResults;
  final bool isLoading;
  final bool isSearching;
  final String? error;

  FriendsState copyWith({
    List<Friend>? friends,
    List<FriendRequest>? incoming,
    List<FriendRequest>? outgoing,
    List<Map<String, dynamic>>? searchResults,
    bool? isLoading,
    bool? isSearching,
    String? error,
  }) => FriendsState(
        friends: friends ?? this.friends,
        incoming: incoming ?? this.incoming,
        outgoing: outgoing ?? this.outgoing,
        searchResults: searchResults ?? this.searchResults,
        isLoading: isLoading ?? this.isLoading,
        isSearching: isSearching ?? this.isSearching,
        error: error,
      );
}

class FriendsNotifier extends StateNotifier<FriendsState> {
  FriendsNotifier(this._api, this._socket) : super(const FriendsState()) {
    _setupSocketListeners();
  }

  final ApiClient _api;
  final SocketService _socket;

  void _setupSocketListeners() {
    _socket.on(SocketEvents.presenceUpdate, (data) {
      if (data is Map<String, dynamic>) {
        final userId = data['userId'] as String?;
        final status = data['status'] as String?;
        if (userId != null && status != null) {
          state = state.copyWith(
            friends: state.friends.map((f) {
              if (f.userId == userId) {
                return f.copyWith(
                  status: status,
                  isOnline: status != 'OFFLINE',
                );
              }
              return f;
            }).toList(),
          );
        }
      }
    });

    _socket.on(SocketEvents.friendRequestSent, (_) => loadIncoming());
    _socket.on(SocketEvents.friendRequestAccepted, (_) => loadFriends());
  }

  Future<void> loadFriends() async {
    state = state.copyWith(isLoading: true);
    try {
      final res = await _api.get(ApiEndpoints.friends);
      final list = (res.data['data'] as List)
          .map((e) => Friend.fromJson(e))
          .toList()
        ..sort((a, b) {
          // Online first, then by name
          if (a.isOnline != b.isOnline) return a.isOnline ? -1 : 1;
          return a.displayName.compareTo(b.displayName);
        });
      state = state.copyWith(friends: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadIncoming() async {
    try {
      final res = await _api.get(ApiEndpoints.friendRequestsIncoming);
      state = state.copyWith(
        incoming: (res.data['data'] as List)
            .map((e) => FriendRequest.fromJson(e, 'sender'))
            .toList(),
      );
    } catch (_) {}
  }

  Future<void> loadOutgoing() async {
    try {
      final res = await _api.get(ApiEndpoints.friendRequestsOutgoing);
      state = state.copyWith(
        outgoing: (res.data['data'] as List)
            .map((e) => FriendRequest.fromJson(e, 'receiver'))
            .toList(),
      );
    } catch (_) {}
  }

  Future<void> sendRequest(String receiverId) async {
    await _api.post(ApiEndpoints.friendRequests, data: {'receiverId': receiverId});
    await loadOutgoing();
  }

  Future<void> acceptRequest(String requestId) async {
    await _api.put('${ApiEndpoints.friendRequests}/$requestId', data: {'action': 'ACCEPTED'});
    await Future.wait([loadFriends(), loadIncoming()]);
  }

  Future<void> declineRequest(String requestId) async {
    await _api.put('${ApiEndpoints.friendRequests}/$requestId', data: {'action': 'DECLINED'});
    await loadIncoming();
  }

  Future<void> cancelRequest(String requestId) async {
    await _api.delete('${ApiEndpoints.friendRequests}/$requestId');
    await loadOutgoing();
  }

  Future<void> removeFriend(String friendId) async {
    await _api.delete('${ApiEndpoints.friends}/$friendId');
    state = state.copyWith(
      friends: state.friends.where((f) => f.userId != friendId).toList(),
    );
  }

  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      state = state.copyWith(searchResults: [], isSearching: false);
      return;
    }
    state = state.copyWith(isSearching: true);
    try {
      final res = await _api.get(ApiEndpoints.friendSearch, queryParameters: {'q': query});
      state = state.copyWith(
        searchResults: List<Map<String, dynamic>>.from(res.data['data']),
        isSearching: false,
      );
    } catch (_) {
      state = state.copyWith(isSearching: false);
    }
  }

  @override
  void dispose() {
    _socket.off(SocketEvents.presenceUpdate);
    _socket.off(SocketEvents.friendRequestSent);
    _socket.off(SocketEvents.friendRequestAccepted);
    super.dispose();
  }
}

final friendsProvider = StateNotifierProvider<FriendsNotifier, FriendsState>((ref) {
  return FriendsNotifier(
    ref.watch(apiClientProvider),
    ref.watch(socketServiceProvider),
  );
});
