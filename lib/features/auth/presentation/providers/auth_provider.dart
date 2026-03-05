import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/client/api_client.dart';
import '../../data/models/user_model.dart';

// API Client Provider
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(baseUrl: 'http://127.0.0.1:8080');
});

// Auth State
class AuthState {
  final bool isAuthenticated;
  final bool isLoading;
  final UserModel? user;
  final String? token;
  final String? error;
  
  AuthState({
    this.isAuthenticated = false,
    this.isLoading = false,
    this.user,
    this.token,
    this.error,
  });
  
  factory AuthState.initial() {
    return AuthState();
  }
  
  AuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    UserModel? user,
    String? token,
    String? error,
    bool clearError = false,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      user: user ?? this.user,
      token: token ?? this.token,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ✅ Auth Provider - ใช้ NotifierProvider (Riverpod 2.0+)
final authProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    // โหลด saved auth ตอนเริ่มต้น
    _loadSavedAuth();
    return AuthState.initial();
  }
  
  /// โหลด Auth จาก SharedPreferences
  Future<void> _loadSavedAuth() async {
    try {
      print('🔐 Loading saved auth...');
      
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final userJson = prefs.getString('user_data');
      
      if (token != null && userJson != null) {
        print('✅ Found saved auth');
        
        // Decode user
        final userMap = Map<String, dynamic>.from(
          jsonDecode(userJson) as Map,
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
        
        print('✅ Auth restored: ${user.fullName}');
      } else {
        print('ℹ️ No saved auth found');
      }
    } catch (e) {
      print('❌ Load saved auth error: $e');
    }
  }
  
  /// Login
  Future<bool> login({
    required String username,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    
    try {
      print('🔐 Logging in as $username...');
      
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
        
        // Extract user info
        final user = UserModel(
          userId: data['user_id'] as String,
          username: data['username'] as String,
          fullName: data['full_name'] as String,
          email: data['email'] as String?,
          roleId: data['role_id'] as String?,
          branchId: data['branch_id'] as String?,
        );
        
        final token = data['token'] as String? ?? 'dummy_token';
        
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
        
        print('✅ Login successful: ${user.fullName}');
        
        return true;
      } else {
        print('❌ Login failed: ${response.statusCode}');
        
        state = state.copyWith(
          isLoading: false,
          error: 'Username หรือ Password ไม่ถูกต้อง',
        );
        return false;
      }
    } catch (e) {
      print('❌ Login error: $e');
      
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
      print('👋 Logging out...');
      
      final apiClient = ref.read(apiClientProvider);
      
      // Call logout API (optional)
      try {
        await apiClient.post('/api/auth/logout');
      } catch (e) {
        print('⚠️ Logout API error: $e');
      }
      
      // Clear SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('user_data');
      
      // Clear token from API Client
      apiClient.setToken(null);
      
      // Reset state
      state = AuthState.initial();
      
      print('✅ Logged out');
    } catch (e) {
      print('❌ Logout error: $e');
    }
  }
  
  /// Clear Error
  void clearError() {
    state = state.copyWith(clearError: true);
  }
}