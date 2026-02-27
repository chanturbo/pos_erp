import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../utils/crypto_utils.dart';
import '../utils/jwt_utils.dart';

class AuthService {
  final AppDatabase db;
  
  AuthService(this.db);
  
  /// Login
  Future<AuthResult?> login({
    required String username,
    required String password,
  }) async {
    try {
      // 1. ค้นหา user
      final user = await (db.select(db.users)
            ..where((t) => t.username.equals(username)))
          .getSingleOrNull();
      
      if (user == null) {
        return null; // User not found
      }
      
      // 2. ตรวจสอบ password
      if (!CryptoUtils.verifyPassword(password, user.passwordHash)) {
        return null; // Wrong password
      }
      
      // 3. ตรวจสอบ active
      if (!user.isActive) {
        return null; // User inactive
      }
      
      // 4. สร้าง token
      final token = JwtUtils.generateToken(
        userId: user.userId,
        username: user.username,
      );
      
      // 5. Update last login
      await (db.update(db.users)
            ..where((t) => t.userId.equals(user.userId)))
          .write(UsersCompanion(
        lastLogin: Value(DateTime.now()),
      ));
      
      // 6. สร้าง session (ถ้าต้องการ)
      await _createSession(user.userId, token);
      
      return AuthResult(
        user: user,
        token: token,
      );
      
    } catch (e) {
      print('Login error: $e');
      return null;
    }
  }
  
  /// Logout
  Future<void> logout(String token) async {
    try {
      // ลบ session
      await (db.delete(db.activeSessions)
            ..where((t) => t.token.equals(token)))
          .go();
    } catch (e) {
      print('Logout error: $e');
    }
  }
  
  /// Verify Token
  Future<User?> verifyToken(String token) async {
    try {
      // 1. Verify token
      final payload = JwtUtils.verifyToken(token);
      if (payload == null) {
        return null;
      }
      
      // 2. ดึงข้อมูล user
      final userId = payload['user_id'] as String;
      final user = await (db.select(db.users)
            ..where((t) => t.userId.equals(userId)))
          .getSingleOrNull();
      
      return user;
    } catch (e) {
      print('Verify token error: $e');
      return null;
    }
  }
  
  /// สร้าง session
  Future<void> _createSession(String userId, String token) async {
    try {
      await db.into(db.activeSessions).insert(
        ActiveSessionsCompanion.insert(
          sessionId: 'SESS_${DateTime.now().millisecondsSinceEpoch}',
          token: token,
          userId: Value(userId),
        ),
      );
    } catch (e) {
      print('Create session error: $e');
    }
  }
}

/// Auth Result
class AuthResult {
  final User user;
  final String token;
  
  AuthResult({
    required this.user,
    required this.token,
  });
}