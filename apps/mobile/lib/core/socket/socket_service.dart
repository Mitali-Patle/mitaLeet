import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../constants/app_constants.dart';
import '../storage/secure_storage.dart';
import 'socket_events.dart';

/// Manages the Socket.IO connection lifecycle, reconnection, and heartbeat.
class SocketService {
  io.Socket? _socket;
  Timer? _heartbeatTimer;
  bool _isConnected = false;

  final Map<String, List<Function(dynamic)>> _listeners = {};

  bool get isConnected => _isConnected;
  io.Socket? get socket => _socket;

  /// Connect to the WebSocket server.
  Future<void> connect() async {
    if (_isConnected) return;

    final storage = SecureStorage();
    final token = await storage.getAccessToken();
    if (token == null) return;

    _socket = io.io(
      AppConstants.wsUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(10)
          .setReconnectionDelay(2000)
          .setReconnectionDelayMax(10000)
          .build(),
    );

    _socket!.onConnect((_) {
      _isConnected = true;
      _startHeartbeat();
      debugPrint('[Socket] Connected');
    });

    _socket!.onDisconnect((_) {
      _isConnected = false;
      _stopHeartbeat();
      debugPrint('[Socket] Disconnected');
    });

    _socket!.onReconnect((_) {
      _isConnected = true;
      _startHeartbeat();
      debugPrint('[Socket] Reconnected');
    });

    _socket!.onError((err) {
      debugPrint('[Socket] Error: $err');
    });

    // Re-attach any registered listeners
    for (final entry in _listeners.entries) {
      for (final callback in entry.value) {
        _socket!.on(entry.key, callback);
      }
    }
  }

  /// Disconnect and cleanup.
  void disconnect() {
    _stopHeartbeat();
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
  }

  /// Emit an event.
  void emit(String event, [dynamic data]) {
    _socket?.emit(event, data);
  }

  /// Register a listener for a specific event.
  void on(String event, Function(dynamic) callback) {
    _listeners.putIfAbsent(event, () => []).add(callback);
    _socket?.on(event, callback);
  }

  /// Remove a specific listener.
  void off(String event, [Function(dynamic)? callback]) {
    if (callback != null) {
      _listeners[event]?.remove(callback);
      _socket?.off(event, callback);
    } else {
      _listeners.remove(event);
      _socket?.off(event);
    }
  }

  /// Join a group room.
  void joinGroup(String groupId) {
    emit(SocketEvents.joinGroup, {'groupId': groupId});
  }

  /// Leave a group room.
  void leaveGroup(String groupId) {
    emit(SocketEvents.leaveGroup, {'groupId': groupId});
  }

  /// Update user status.
  void updateStatus(String status) {
    emit(SocketEvents.statusUpdate, {'status': status});
  }

  // ── Private ────────────────────────────────────────────────────────

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => emit(SocketEvents.heartbeat),
    );
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }
}

/// Global SocketService provider.
final socketServiceProvider = Provider<SocketService>((ref) {
  return SocketService();
});
