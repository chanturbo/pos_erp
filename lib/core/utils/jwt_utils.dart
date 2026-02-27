import 'dart:convert';

class JwtUtils {
  static const String _secret = 'your-secret-key-change-in-production';
  
  /// สร้าง Token
  static String generateToken({
    required String userId,
    required String username,
    Duration validity = const Duration(hours: 24),
  }) {
    final payload = {
      'user_id': userId,
      'username': username,
      'exp': DateTime.now().add(validity).millisecondsSinceEpoch,
      'iat': DateTime.now().millisecondsSinceEpoch,
    };
    
    // Simple token (Base64 encode)
    // ในระบบจริงใช้ package jwt_decode หรือ dart_jsonwebtoken
    final token = base64Encode(utf8.encode(jsonEncode(payload)));
    return token;
  }
  
  /// Verify Token
  static Map<String, dynamic>? verifyToken(String token) {
    try {
      final decoded = utf8.decode(base64Decode(token));
      final payload = jsonDecode(decoded) as Map<String, dynamic>;
      
      // ตรวจสอบ expiry
      final exp = payload['exp'] as int;
      if (DateTime.now().millisecondsSinceEpoch > exp) {
        return null; // Token หมดอายุ
      }
      
      return payload;
    } catch (e) {
      return null;
    }
  }
  
  /// Extract User ID from token
  static String? getUserIdFromToken(String token) {
    final payload = verifyToken(token);
    return payload?['user_id'] as String?;
  }
}