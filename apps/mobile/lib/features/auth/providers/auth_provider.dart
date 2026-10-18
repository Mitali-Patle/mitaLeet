import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
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
  }) : super(const AuthState()) {
    // When the API can no longer renew the session, return to the login screen.
    apiClient.onSessionExpired = () {
      socketService.disconnect();
      state = const AuthState();
    };
  }

  final SecureStorage storage;
  final ApiClient apiClient;
  final SocketService socketService;

  // Single GoogleSignIn instance — avoids creating duplicates on rapid taps.
  // serverClientId: Web Application client ID used on Android/iOS to get an
  //   ID token the backend can verify. Public — safe in source.
  // clientId: Web Application client ID for browser sign-in (different OAuth
  //   client created in Google Cloud Console with Netlify origin authorised).
  static const _webClientId =
      '271726528316-k1aqb21aebe1nddshhnc79hiqdn2afft.apps.googleusercontent.com';
  static const _serverClientId =
      '271726528316-k1aqb21aebe1nddshhnc79hiqdn2afft.apps.googleusercontent.com';

  final _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    clientId: kIsWeb ? _webClientId : null,
    serverClientId: _serverClientId,
  );
  /// Check persisted auth on app launch.
  Future<void> checkAuth() async {
    state = state.copyWith(isLoading: true);
    try {
      // 10-second timeout as a safety net (e.g., catastrophic network hang).
      // SecureStorage PlatformException on web is handled inside _performAuthCheck.
      await _performAuthCheck().timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('[Auth] checkAuth timeout or error: $e');
      state = const AuthState();
    }
  }

  Future<void> _performAuthCheck() async {
    String? token;
    String? userId;

    // Isolate SecureStorage read so a PlatformException (web plugin missing)
    // doesn't swallow token-expiry or network errors below.
    try {
      token = await storage.getAccessToken();
      userId = await storage.getUserId();
    } on Exception catch (e) {
      debugPrint('[Auth] SecureStorage read failed: $e');
      state = const AuthState();
      return;
    }

    if (token != null && userId != null) {
      try {
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
          _syncTimezone();
          return;
        }
      } catch (_) {
        // Token invalid or expired — try refresh
        await _tryRefresh();
        return;
      }
    }

    state = const AuthState();
  }

  /// Sign in with Google — handles the full OAuth flow internally.
  Future<void> signInWithGoogle() async {
    // Guard against concurrent calls while a sign-in is already in progress.
    if (state.isLoading) return;

    // google_sign_in does not support Linux desktop.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.linux) {
      state = state.copyWith(
        isLoading: false,
        error: 'Google Sign-In is not supported on this platform. Use the dev bypass or a mobile device.',
      );
      return;
    }

    state = state.copyWith(isLoading: true, error: null);
    try {
      String? idToken;

      if (kIsWeb) {
        // On web, google_sign_in uses a deprecated implicit token flow that
        // Google now blocks. Use Firebase Auth popup instead, then send the
        // Firebase ID token (iss: securetoken.google.com). The backend
        // auto-detects the token type by issuer and verifies accordingly.
        final googleProvider = GoogleAuthProvider()
          ..addScope('email')
          ..addScope('profile');
        final userCredential =
            await FirebaseAuth.instance.signInWithPopup(googleProvider);
        idToken = await userCredential.user?.getIdToken();
      } else {
        // Mobile: use google_sign_in (native picker, returns ID token directly).
        final account = await _googleSignIn.signIn();
        if (account == null) {
          state = state.copyWith(isLoading: false);
          return;
        }
        final auth = await account.authentication;
        idToken = auth.idToken;
      }

      if (idToken == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'Google sign-in failed: no ID token.',
        );
        return;
      }
      await _signInWithIdToken(idToken);
    } catch (e) {
      debugPrint('[Auth] signInWithGoogle error: $e');
      final msg = e.toString();
      String userError;
      if (msg.contains('popup_closed') || msg.contains('user_cancelled')) {
        userError = 'Sign-in cancelled.';
      } else if (msg.contains('popup_blocked') || msg.contains('popup-blocked')) {
        userError = 'Popup blocked — allow popups for this site and try again.';
      } else if (msg.contains('origin') || msg.contains('not allowed')) {
        userError = 'Domain not authorised in Google Cloud Console. Contact support.';
      } else if (msg.contains('network') || msg.contains('NetworkError')) {
        userError = 'Network error — check your connection.';
      } else {
        userError = 'Google sign-in failed: $msg';
      }
      state = state.copyWith(isLoading: false, error: userError);
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
      _syncTimezone();
    } catch (e) {
      debugPrint('[Auth] _signInWithIdToken error: $e');
      String msg = e.toString();
      // Extract HTTP status / server message from DioException if available
      if (e is DioException) {
        final status = e.response?.statusCode;
        final serverMsg = e.response?.data?['message'] ?? e.response?.data;
        final type = e.type.name; // connectionError = CORS/network, connectionTimeout = server asleep
        msg = 'HTTP $status [$type] — $serverMsg';
        debugPrint('[Auth] DioException type: $type');
        debugPrint('[Auth] backend response: ${e.response?.data}');
      }
      state = state.copyWith(
        isLoading: false,
        error: 'Auth failed: $msg',
      );
    }
  }

  /// DEV ONLY: bypass auth for local UI testing.
  /// Calls backend /auth/dev-login and persists tokens.
  Future<void> devBypass() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // Use a default dev username; customize if needed.
      final response = await apiClient.post(
        ApiEndpoints.authDevLogin,
        data: {'username': 'mitali'},
      );
      final data = response.data['data'];
      final tokens = data['tokens'];
      final user = data['user'];

      await storage.setAccessToken(tokens['accessToken']);
      await storage.setRefreshToken(tokens['refreshToken']);
      await storage.setUserId(user['id']);

      state = AuthState(
        isAuthenticated: true,
        userId: user['id'],
        email: user['email'],
        displayName: user['displayName'],
      );

      await socketService.connect();
      _syncTimezone();
    } catch (e) {
      debugPrint('[Auth] devBypass failed: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Dev login failed: ${e.toString().replaceAll('Exception:', '').trim()}',
      );
    }
  }

  /// Onboarding finished: stop routing this user to the onboarding screen.
  void completeOnboarding() {
    state = state.copyWith(isNewUser: false);
  }

  /// Tell the server the device's IANA timezone so streaks and "today"
  /// follow the user's local midnight. Best effort; retried on next launch.
  Future<void> _syncTimezone() async {
    try {
      final tz = await FlutterTimezone.getLocalTimezone();
      await apiClient.put(ApiEndpoints.usersMeProfile, data: {'timezone': tz.identifier});
    } catch (e) {
      debugPrint('[Auth] timezone sync skipped: $e');
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

      // Validate new tokens and fetch user profile directly,
      // avoiding the isLoading toggle and timeout wrapper in checkAuth().
      await _performAuthCheck();
    } catch (_) {
      try {
        await storage.clearAll();
      } catch (_) {
        // Ignore if clearAll also fails (e.g., MissingPluginException on web)
      }
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
