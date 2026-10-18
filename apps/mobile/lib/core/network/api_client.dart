import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_constants.dart';
import '../storage/secure_storage.dart';
import 'api_endpoints.dart';

/// Centralized HTTP client for all API requests.
///
/// Automatically attaches JWT access token to requests
/// via an interceptor.
class ApiClient {
  ApiClient({required this.storage}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout: AppConstants.connectionTimeout,
        receiveTimeout: AppConstants.receiveTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await storage.getAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (error, handler) async {
          final opts = error.requestOptions;
          final alreadyRetried = opts.extra['retriedAfterRefresh'] == true;
          final isAuthCall = opts.path.startsWith('/auth/');
          if (error.response?.statusCode != 401 || alreadyRetried || isAuthCall) {
            return handler.next(error);
          }

          final newAccess = await _refreshAccessToken();
          if (newAccess == null) return handler.next(error);

          try {
            opts.headers['Authorization'] = 'Bearer $newAccess';
            opts.extra['retriedAfterRefresh'] = true;
            return handler.resolve(await _dio.fetch(opts));
          } on DioException catch (e) {
            return handler.next(e);
          }
        },
      ),
    );
  }

  /// Called when the session can no longer be renewed (user must sign in again).
  void Function()? onSessionExpired;

  /// The refresh in progress, shared by every request that hit a 401 meanwhile.
  /// The server rotates refresh tokens, so two parallel refreshes would make
  /// the second fail and log the user out.
  Future<String?>? _refreshing;

  Future<String?> _refreshAccessToken() {
    return _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
  }

  Future<String?> _doRefresh() async {
    final refreshToken = await storage.getRefreshToken();
    if (refreshToken == null) {
      await _expireSession();
      return null;
    }
    try {
      // Plain Dio so the refresh call itself never goes through this interceptor.
      final refreshDio = Dio(BaseOptions(baseUrl: AppConstants.baseUrl));
      final res = await refreshDio.post<Map<String, dynamic>>(
        ApiEndpoints.authRefresh,
        data: {'refreshToken': refreshToken},
      );
      final data = res.data?['data'] as Map<String, dynamic>?;
      final newAccess = data?['accessToken'] as String?;
      final newRefresh = data?['refreshToken'] as String?;
      if (newAccess == null) {
        await _expireSession();
        return null;
      }
      await storage.setAccessToken(newAccess);
      if (newRefresh != null) await storage.setRefreshToken(newRefresh);
      return newAccess;
    } on DioException catch (e) {
      // Only a rejected refresh ends the session; a network blip should not.
      if (e.response?.statusCode == 401) await _expireSession();
      return null;
    }
  }

  Future<void> _expireSession() async {
    await storage.clearAll();
    onSessionExpired?.call();
  }

  final SecureStorage storage;
  late final Dio _dio;

  Dio get dio => _dio;

  // ── Convenience methods ────────────────────────────────────────────

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) {
    return _dio.get<T>(path, queryParameters: queryParameters);
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
  }) {
    return _dio.post<T>(path, data: data);
  }

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
  }) {
    return _dio.put<T>(path, data: data);
  }

  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
  }) {
    return _dio.patch<T>(path, data: data);
  }

  Future<Response<T>> delete<T>(String path) {
    return _dio.delete<T>(path);
  }
}

/// Provider for the API client.
final apiClientProvider = Provider<ApiClient>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return ApiClient(storage: storage);
});
