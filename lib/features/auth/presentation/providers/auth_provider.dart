import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/client/api_client.dart';
import '../../data/models/auth_state.dart';
import '../../data/models/user_model.dart';

// API Client Provider
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(baseUrl: 'http://127.0.0.1:8080');
});

// Auth Provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});

class AuthNotifier extends StateNotifier<AuthState> {
  final Ref ref;
  
  AuthNotifier(this.ref) : super(AuthState.initial()) {
    _loadSavedAuth();
  }
  
  /// โหลด Auth จาก SharedPreferences
  Future<void> _loadSavedAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final userJson = prefs.getString('user_data');
      
      if (token != null && userJson != null) {
        // Decode user
        final userMap = Map<String, dynamic>.from(
          const JsonCodec().decode(userJson) as Map
        );
        final user = UserModel.fromJson(userMap);
        
        // Set token to API Client
        ref.read(apiClientProvider).setToken(token);
        
        // Update state
        state = state.copyWith(
          isAuthenticated: true,
          user: user,
          token: token,
        );
      }
    } catch (e) {
      print('Load saved auth error: $e');
    }
  }
  
  /// Login
  Future<bool> login({
    required String username,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final apiClient = ref.read(apiClientProvider);
      
      final response = await apiClient.post(
        '/api/auth/login',
        data: {
          'username': username,
          'password': password,
        },
      );
      
      if (response.statusCode == 200) {
        final data = response.data['data'];
        final token = data['token'] as String;
        final user = UserModel(
          userId: data['user_id'] as String,
          username: data['username'] as String,
          fullName: data['full_name'] as String,
        );
        
        // Save to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', token);
        await prefs.setString('user_data', jsonEncode(user.toJson()));
        
        // Set token to API Client
        apiClient.setToken(token);
        
        // Update state
        state = state.copyWith(
          isAuthenticated: true,
          isLoading: false,
          user: user,
          token: token,
        );
        
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'เข้าสู่ระบบไม่สำเร็จ',
        );
        return false;
      }
      
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'เกิดข้อผิดพลาด: $e',
      );
      return false;
    }
  }
  
  /// Logout
  Future<void> logout() async {
    try {
      final apiClient = ref.read(apiClientProvider);
      
      // Call logout API (optional)
      try {
        await apiClient.post('/api/auth/logout');
      } catch (e) {
        print('Logout API error: $e');
      }
      
      // Clear SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('user_data');
      
      // Clear token from API Client
      apiClient.setToken(null);
      
      // Reset state
      state = AuthState.initial();
      
    } catch (e) {
      print('Logout error: $e');
    }
  }
}