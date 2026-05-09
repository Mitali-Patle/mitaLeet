import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/socket/socket_service.dart';
import '../../../core/socket/socket_events.dart';

/// Tracks realtime presence of friends and group members.
class PresenceState {
  const PresenceState({this.statuses = const {}});
  final Map<String, String> statuses; // userId -> status

  String statusOf(String userId) => statuses[userId] ?? 'OFFLINE';
  bool isOnline(String userId) => statusOf(userId) != 'OFFLINE';
}

class PresenceNotifier extends StateNotifier<PresenceState> {
  PresenceNotifier(this._socket) : super(const PresenceState()) {
    _setupListeners();
  }

  final SocketService _socket;

  void _setupListeners() {
    _socket.on(SocketEvents.presenceUpdate, (data) {
      if (data is Map<String, dynamic>) {
        final userId = data['userId'] as String?;
        final status = data['status'] as String?;
        if (userId != null && status != null) {
          state = PresenceState(
            statuses: {...state.statuses, userId: status},
          );
        }
      }
    });

    _socket.on(SocketEvents.memberStatus, (data) {
      if (data is Map<String, dynamic>) {
        final userId = data['userId'] as String?;
        final status = data['status'] as String?;
        if (userId != null && status != null) {
          state = PresenceState(
            statuses: {...state.statuses, userId: status},
          );
        }
      }
    });

    _socket.on(SocketEvents.onlineMembers, (data) {
      if (data is Map<String, dynamic>) {
        final members = data['members'] as List?;
        if (members != null) {
          final updated = Map<String, String>.from(state.statuses);
          for (final id in members) {
            updated[id.toString()] = 'ONLINE';
          }
          state = PresenceState(statuses: updated);
        }
      }
    });
  }

  void setStatus(String userId, String status) {
    state = PresenceState(
      statuses: {...state.statuses, userId: status},
    );
  }

  void setBulkOnline(List<String> userIds) {
    final updated = Map<String, String>.from(state.statuses);
    for (final id in userIds) {
      updated[id] = 'ONLINE';
    }
    state = PresenceState(statuses: updated);
  }

  @override
  void dispose() {
    _socket.off(SocketEvents.presenceUpdate);
    _socket.off(SocketEvents.memberStatus);
    _socket.off(SocketEvents.onlineMembers);
    super.dispose();
  }
}

final presenceProvider = StateNotifierProvider<PresenceNotifier, PresenceState>((ref) {
  return PresenceNotifier(ref.watch(socketServiceProvider));
});
