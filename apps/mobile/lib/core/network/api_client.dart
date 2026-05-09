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
          if (error.response?.statusCode == 401) {
            final refreshToken = await storage.getRefreshToken();
            if (refreshToken == null) {
              await storage.clearAll();
              return handler.next(error);
            }

            try {
              // Use a plain Dio to avoid interceptor loops
              final refreshDio = Dio(BaseOptions(baseUrl: AppConstants.baseUrl));
              final res = await refreshDio.post<Map<String, dynamic>>(
                ApiEndpoints.authRefresh,
                data: {'refreshToken': refreshToken},
              );

              final data = res.data?['data'] as Map<String, dynamic>?;
              final newAccess = data?['accessToken'] as String?;
              final newRefresh = data?['refreshToken'] as String?;

              if (newAccess == null) {
                await storage.clearAll();
                return handler.next(error);
              }

              await storage.setAccessToken(newAccess);
              if (newRefresh != null) {
                await storage.setRefreshToken(newRefresh);
              }

              // Retry original request with new token
              final opts = error.requestOptions;
              opts.headers['Authorization'] = 'Bearer $newAccess';
              final retryRes = await _dio.fetch(opts);
              return handler.resolve(retryRes);
            } catch (_) {
              await storage.clearAll();
              return handler.next(error);
            }
          }
          return handler.next(error);
        },
      ),
    );
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

  Future<Response<T>> delete<T>(String path) {
    return _dio.delete<T>(path);
  }
}

/// Provider for the API client.
final apiClientProvider = Provider<ApiClient>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return ApiClient(storage: storage);
});
