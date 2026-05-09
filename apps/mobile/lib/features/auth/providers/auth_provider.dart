import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/socket/socket_service.dart';

/// Authentication state.
class AuthState {
  const AuthState({
    this.isAuthenticated = false,
    this.isLoading = false,
    this.isNewUser = false,
    this.userId,
    this.email,
    this.displayName,
    this.error,
  });

  final bool isAuthenticated;
  final bool isLoading;
  final bool isNewUser;
  final String? userId;
  final String? email;
  final String? displayName;
  final String? error;

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    bool? isNewUser,
    String? userId,
    String? email,
    String? displayName,
    String? error,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      isNewUser: isNewUser ?? this.isNewUser,
      userId: userId ?? this.userId,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      error: error,
    );
  }
}

/// Auth state notifier — manages authentication lifecycle.
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier({
    required this.storage,
    required this.apiClient,
    required this.socketService,
  }) : super(const AuthState());

  final SecureStorage storage;
  final ApiClient apiClient;
  final SocketService socketService;

  /// Check persisted auth on app launch.
  Future<void> checkAuth() async {
    state = state.copyWith(isLoading: true);
    try {
      final token = await storage.getAccessToken();
      final userId = await storage.getUserId();
      if (token != null && userId != null) {
        // Validate token by fetching user profile
        final response = await apiClient.get(ApiEndpoints.usersMe);
        if (response.statusCode == 200) {
          final data = response.data['data'];
          state = AuthState(
            isAuthenticated: true,
            userId: userId,
            email: data['email'],
            displayName: data['displayName'],
          );
          // Connect WebSocket
          await socketService.connect();
          return;
        }
      }
    } catch (_) {
      // Token invalid or expired — try refresh
      await _tryRefresh();
      return;
    }
    state = const AuthState();
  }

  /// Sign in with Google — handles the full OAuth flow internally.
  Future<void> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // Trigger native Google Sign-In picker
      final googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );
      final account = await googleSignIn.signIn();
      if (account == null) {
        // User cancelled
        state = state.copyWith(isLoading: false);
        return;
      }
      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'Google sign-in failed: no ID token.',
        );
        return;
      }
      await _signInWithIdToken(idToken);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Google sign-in failed. Please try again.',
      );
    }
  }

  /// Exchange a Google ID token with the backend.
  Future<void> _signInWithIdToken(String idToken) async {
    try {
      final response = await apiClient.post(
        ApiEndpoints.authGoogle,
        data: {'idToken': idToken},
      );

      final data = response.data['data'];
      final tokens = data['tokens'];
      final user = data['user'];

      await storage.setAccessToken(tokens['accessToken']);
      await storage.setRefreshToken(tokens['refreshToken']);
      await storage.setUserId(user['id']);

      state = AuthState(
        isAuthenticated: true,
        isNewUser: user['isNewUser'] ?? false,
        userId: user['id'],
        email: user['email'],
        displayName: user['displayName'],
      );

      await socketService.connect();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Authentication failed. Please try again.',
      );
    }
  }

  /// Sign out and clear all persisted data.
  Future<void> signOut() async {
    try {
      final refreshToken = await storage.getRefreshToken();
      if (refreshToken != null) {
        await apiClient.post(
          ApiEndpoints.authLogout,
          data: {'refreshToken': refreshToken},
        );
      }
    } catch (_) {
      // Best-effort logout
    }
    socketService.disconnect();
    await storage.clearAll();
    state = const AuthState();
  }

  /// Try to refresh the access token.
  Future<void> _tryRefresh() async {
    try {
      final refreshToken = await storage.getRefreshToken();
      if (refreshToken == null) {
        state = const AuthState();
        return;
      }

      final response = await apiClient.post(
        ApiEndpoints.authRefresh,
        data: {'refreshToken': refreshToken},
      );

      final data = response.data['data'];
      await storage.setAccessToken(data['accessToken']);
      await storage.setRefreshToken(data['refreshToken']);

      // Re-check auth with new token
      await checkAuth();
    } catch (_) {
      await storage.clearAll();
      state = const AuthState();
    }
  }
}

/// Provider for authentication state.
final authStateProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final storage = ref.watch(secureStorageProvider);
  final apiClient = ref.watch(apiClientProvider);
  final socketService = ref.watch(socketServiceProvider);
  return AuthNotifier(
    storage: storage,
    apiClient: apiClient,
    socketService: socketService,
  );
});
