
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_config.dart';
import 'package:flutter/foundation.dart';

class ApiClient {
  final Dio _dio;
  String? _token;

  /// ✅ Callback เมื่อ server ตอบ 401 — ใช้ redirect ไป login page
  void Function()? onUnauthorized;

  ApiClient({String? baseUrl})
    : _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl ?? AppConfig.resolveApiBaseUrl(),
          connectTimeout: AppConfig.connectTimeout,
          receiveTimeout: AppConfig.receiveTimeout,
          headers: {'Content-Type': 'application/json'},
        ),
      ) {
    // Add interceptor for logging
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (kDebugMode) {
            debugPrint('📡 ${options.method} ${options.uri.path}');
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          if (kDebugMode) {
            debugPrint( '✅ Response [${response.statusCode}]: ${response.requestOptions.uri.path}', );
          }
          return handler.next(response);
        },
        onError: (error, handler) {
          final statusCode = error.response?.statusCode;
          if (kDebugMode) {
            debugPrint('❌ Error [$statusCode]: ${error.message}');
          }
          final path = error.requestOptions.path;

          // ✅ 401 — token หมดอายุ / ไม่มี token
          // resolve แทน throw ไม่ให้ app crash
          if (statusCode == 401 && path != '/api/auth/login') {
            if (kDebugMode) {
              debugPrint('🔒 401 Unauthorized — token may be expired or missing');
            }
            onUnauthorized?.call();
            return handler.resolve(
              Response(
                requestOptions: error.requestOptions,
                statusCode: 401,
                data: {'success': false, 'message': 'Unauthorized'},
              ),
            );
          }

          return handler.next(error);
        },
      ),
    );
  }

  String get baseUrl => _dio.options.baseUrl;

  void refreshBaseUrl() {
    final resolved = AppConfig.resolveApiBaseUrl();
    if (_dio.options.baseUrl != resolved) {
      _dio.options.baseUrl = resolved;
      if (kDebugMode) {
        debugPrint('🌐 API Base URL switched to $resolved');
      }
    }
  }

  /// Set authentication token
  void setToken(String? token) {
    _token = token;
    if (token != null) {
      _dio.options.headers['Authorization'] = 'Bearer $token';
      if (kDebugMode) {
        debugPrint('🔑 Token set');
      }
    } else {
      _dio.options.headers.remove('Authorization');
      if (kDebugMode) {
        debugPrint('🔓 Token removed');
      }
    }
  }

  /// Get current token
  String? getToken() => _token;

  /// Get with auth
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      refreshBaseUrl();
      final response = await _dio.get(path, queryParameters: queryParameters);
      return response;
    } on DioException catch (e) {
      if (kDebugMode) {
        debugPrint('❌ GET Error: ${e.message}');
      }
      rethrow;
    }
  }

  /// Post with auth
  Future<Response> post(String path, {dynamic data}) async {
    try {
      refreshBaseUrl();
      final response = await _dio.post(path, data: data);
      return response;
    } on DioException catch (e) {
      if (kDebugMode) {
        debugPrint('❌ POST Error: ${e.message}');
      }
      rethrow;
    }
  }

  /// Put with auth
  Future<Response> put(String path, {dynamic data}) async {
    try {
      refreshBaseUrl();
      final response = await _dio.put(path, data: data);
      return response;
    } on DioException catch (e) {
      if (kDebugMode) {
        debugPrint('❌ PUT Error: ${e.message}');
      }
      rethrow;
    }
  }

  /// Delete with auth
  Future<Response> delete(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      refreshBaseUrl();
      final response = await _dio.delete(
        path,
        queryParameters: queryParameters,
      );
      return response;
    } on DioException catch (e) {
      if (kDebugMode) {
        debugPrint('❌ DELETE Error: ${e.message}');
      }
      rethrow;
    }
  }
}

// ========================================
// RIVERPOD PROVIDER
// ========================================

/// API Client Provider - ใช้ที่เดียวทั้งโปรเจค
final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient();
  if (kDebugMode) {
    debugPrint('🌐 API Base URL: ${client.baseUrl}');
  }
  return client;
});
