// ignore_for_file: avoid_print

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_config.dart';

class ApiClient {
  final Dio _dio;
  final String baseUrl;
  String? _token;
  
  ApiClient({String? baseUrl}) 
      : baseUrl = baseUrl ?? AppConfig.apiBaseUrl,
        _dio = Dio(BaseOptions(
    baseUrl: baseUrl ?? AppConfig.apiBaseUrl,
    connectTimeout: AppConfig.connectTimeout,
    receiveTimeout: AppConfig.receiveTimeout,
    headers: {
      'Content-Type': 'application/json',
    },
  )) {
    // Add interceptor for logging
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          print('📡 ${options.method} ${options.uri.path}');
          return handler.next(options);
        },
        onResponse: (response, handler) {
          print('✅ Response [${response.statusCode}]: ${response.requestOptions.uri.path}');
          return handler.next(response);
        },
        onError: (error, handler) {
          print('❌ Error [${error.response?.statusCode}]: ${error.message}');
          return handler.next(error);
        },
      ),
    );
  }
  
  /// Set authentication token
  void setToken(String? token) {
    _token = token;
    if (token != null) {
      _dio.options.headers['Authorization'] = 'Bearer $token';
      print('🔑 Token set');
    } else {
      _dio.options.headers.remove('Authorization');
      print('🔓 Token removed');
    }
  }
  
  /// Get current token
  String? getToken() => _token;
  
  /// Get with auth
  Future<Response> get(String path) async {
    try {
      final response = await _dio.get(path);
      return response;
    } on DioException catch (e) {
      print('❌ GET Error: ${e.message}');
      rethrow;
    }
  }
  
  /// Post with auth
  Future<Response> post(String path, {dynamic data}) async {
    try {
      final response = await _dio.post(path, data: data);
      return response;
    } on DioException catch (e) {
      print('❌ POST Error: ${e.message}');
      rethrow;
    }
  }
  
  /// Put with auth
  Future<Response> put(String path, {dynamic data}) async {
    try {
      final response = await _dio.put(path, data: data);
      return response;
    } on DioException catch (e) {
      print('❌ PUT Error: ${e.message}');
      rethrow;
    }
  }
  
  /// Delete with auth
  Future<Response> delete(String path) async {
    try {
      final response = await _dio.delete(path);
      return response;
    } on DioException catch (e) {
      print('❌ DELETE Error: ${e.message}');
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
  print('🌐 API Base URL: ${client.baseUrl}');
  return client;
});