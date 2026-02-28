import 'package:dio/dio.dart';

class ApiClient {
  final Dio _dio;
  final String baseUrl;
  String? _token;
  
  ApiClient({required this.baseUrl}) : _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {
      'Content-Type': 'application/json',
    },
  )) {
    // Add interceptor for logging
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
    ));
  }
  
  /// Set token
  void setToken(String? token) {
    _token = token;
  }
  
  /// Get with auth
  Future<Response> get(String path) async {
    try {
      final response = await _dio.get(
        path,
        options: Options(
          headers: _token != null ? {'Authorization': 'Bearer $_token'} : null,
        ),
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }
  
  /// Post with auth
  Future<Response> post(String path, {dynamic data}) async {
    try {
      final response = await _dio.post(
        path,
        data: data,
        options: Options(
          headers: _token != null ? {'Authorization': 'Bearer $_token'} : null,
        ),
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }
  
  /// Put with auth
  Future<Response> put(String path, {dynamic data}) async {
    try {
      final response = await _dio.put(
        path,
        data: data,
        options: Options(
          headers: _token != null ? {'Authorization': 'Bearer $_token'} : null,
        ),
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }
  
  /// Delete with auth
  Future<Response> delete(String path) async {
    try {
      final response = await _dio.delete(
        path,
        options: Options(
          headers: _token != null ? {'Authorization': 'Bearer $_token'} : null,
        ),
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }
}