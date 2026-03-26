// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/client/api_client.dart';
import '../../../../core/utils/jwt_utils.dart';
import '../../data/models/user_model.dart';

// Auth State
class AuthState {
  final bool isAuthenticated;
  final bool isLoading;
  final bool isRestoring; // ✅ true ขณะกำลัง restore token จาก storage
  final UserModel? user;
  final String? token;
  final String? error;
  
  AuthState({
    this.isAuthenticated = false,
    this.isLoading       = false,
    this.isRestoring     = true,  // ✅ default true — รอจนกว่าจะ restore เสร็จ
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
    bool? isRestoring,
    UserModel? user,
    String? token,
    String? error,
    bool clearError = false,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading:       isLoading       ?? this.isLoading,
      isRestoring:     isRestoring     ?? this.isRestoring,
      user:            user            ?? this.user,
      token:           token           ?? this.token,
      error:           clearError ? null : (error ?? this.error),
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
    // ✅ ใช้ Future.microtask เพื่อให้ provider tree พร้อมก่อน
    // แล้วค่อย restore token — ป้องกัน race condition กับ provider อื่น
    Future.microtask(_loadSavedAuth);

    // ✅ ถ้า apiClientProvider สร้าง instance ใหม่ → sync token ทันที
    // ป้องกัน instance ใหม่ไม่มี token ทำให้ 401
    ref.listen(apiClientProvider, (_, client) {
      final token = state.token;
      if (token != null) {
        client.setToken(token);
        print('🔄 Token re-synced to new ApiClient instance');
      }
    });

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
        // ✅ ตรวจ token ก่อนว่ายังไม่หมดอายุ
        final payload = JwtUtils.verifyToken(token);
        if (payload == null) {
          print('⚠️ Saved token expired — clearing auth');
          await prefs.remove('auth_token');
          await prefs.remove('user_data');
          state = state.copyWith(isRestoring: false);
          return;
        }

        print('✅ Found saved auth');

        // Decode user
        final userMap = Map<String, dynamic>.from(
          jsonDecode(userJson) as Map,
        );
        final user = UserModel.fromJson(userMap);
        
        // ✅ set token ก่อน update state
        ref.read(apiClientProvider).setToken(token);

        // ✅ รอให้ Dio header flush ก่อน trigger Riverpod rebuild
        // ป้องกัน provider อื่น rebuild และยิง API ในขณะที่ header ยังไม่พร้อม
        await Future.delayed(Duration.zero);

        state = state.copyWith(
          isAuthenticated: true,
          isRestoring:     false, // ✅ restore เสร็จ → provider อื่น rebuild พร้อม token แล้ว
          user:            user,
          token:           token,
        );
        
        print('✅ Auth restored: ${user.fullName}');
      } else {
        print('ℹ️ No saved auth found');
        state = state.copyWith(isRestoring: false); // ✅ ไม่มี token → redirect login
      }
    } catch (e) {
      print('❌ Load saved auth error: $e');
      state = state.copyWith(isRestoring: false); // ✅ error → ก็ต้อง redirect login
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