/// Application-wide constants.
abstract final class AppConstants {
  static const String appName = 'mitaLeet';

  // ── API ────────────────────────────────────────────────────────────
  // Server origin, chosen at build time:
  //   flutter run --dart-define=API_ORIGIN=http://10.0.2.2:3000        (emulator)
  //   flutter build apk --dart-define=API_ORIGIN=https://your-api.onrender.com
  static const String apiOrigin = String.fromEnvironment(
    'API_ORIGIN',
    defaultValue: 'https://mitaleet.onrender.com',
  );
  static const String baseUrl = '$apiOrigin/api/v1';
  static const String wsUrl = apiOrigin;

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
