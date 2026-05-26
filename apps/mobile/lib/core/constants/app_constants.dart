/// Application-wide constants.
abstract final class AppConstants {
  static const String appName = 'mitaLeet';

  // ── API ────────────────────────────────────────────────────────────
  // Update to your deployed server URL for production builds.
  // For local Android device testing, replace with your machine's LAN IP.
  static const String baseUrl = 'https://mitaleet.onrender.com/api/v1';
  static const String wsUrl = 'https://mitaleet.onrender.com';

  // ── Storage keys ───────────────────────────────────────────────────
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userIdKey = 'user_id';

  // ── Durations ──────────────────────────────────────────────────────
  static const Duration animationFast = Duration(milliseconds: 150);
  static const Duration animationMedium = Duration(milliseconds: 300);
  static const Duration animationSlow = Duration(milliseconds: 500);
  static const Duration connectionTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);
}
