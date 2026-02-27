import 'dart:convert';
import 'package:crypto/crypto.dart';

class CryptoUtils {
  /// Hash password ด้วย SHA256
  static String hashPassword(String password) {
    final bytes = utf8.encode(password);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }

  /// ตรวจสอบ password
  static bool verifyPassword(String password, String hashedPassword) {
    return hashPassword(password) == hashedPassword;
  }
}