import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';

/// Secure token and credential storage.
class SecureStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // ── Access Token ───────────────────────────────────────────────────

  Future<String?> getAccessToken() {
    return _storage.read(key: AppConstants.accessTokenKey);
  }

  Future<void> setAccessToken(String token) {
    return _storage.write(key: AppConstants.accessTokenKey, value: token);
  }

  // ── Refresh Token ──────────────────────────────────────────────────

  Future<String?> getRefreshToken() {
    return _storage.read(key: AppConstants.refreshTokenKey);
  }

  Future<void> setRefreshToken(String token) {
    return _storage.write(key: AppConstants.refreshTokenKey, value: token);
  }

  // ── User ID ────────────────────────────────────────────────────────

  Future<String?> getUserId() {
    return _storage.read(key: AppConstants.userIdKey);
  }

  Future<void> setUserId(String id) {
    return _storage.write(key: AppConstants.userIdKey, value: id);
  }

  // ── Clear all ──────────────────────────────────────────────────────

  Future<void> clearAll() {
    return _storage.deleteAll();
  }
}

/// Provider for secure storage.
final secureStorageProvider = Provider<SecureStorage>((ref) {
  return SecureStorage();
});
