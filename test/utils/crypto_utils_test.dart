import 'package:flutter_test/flutter_test.dart';
import 'package:pos_erp/core/utils/crypto_utils.dart';

void main() {
  group('CryptoUtils', () {
    // ─── hashPassword ─────────────────────
    group('hashPassword', () {
      test('returns a non-empty string', () {
        final hash = CryptoUtils.hashPassword('admin123');
        expect(hash, isNotEmpty);
      });

      test('returns 64-character SHA256 hex string', () {
        final hash = CryptoUtils.hashPassword('admin123');
        expect(hash.length, 64);
      });

      test('same password produces same hash (deterministic)', () {
        final hash1 = CryptoUtils.hashPassword('mypassword');
        final hash2 = CryptoUtils.hashPassword('mypassword');
        expect(hash1, equals(hash2));
      });

      test('different passwords produce different hashes', () {
        final hash1 = CryptoUtils.hashPassword('password1');
        final hash2 = CryptoUtils.hashPassword('password2');
        expect(hash1, isNot(equals(hash2)));
      });

      test('empty string produces a valid hash', () {
        final hash = CryptoUtils.hashPassword('');
        expect(hash.length, 64);
      });

      test('Thai characters hash correctly', () {
        final hash = CryptoUtils.hashPassword('รหัสผ่าน123');
        expect(hash.length, 64);
        expect(hash, isNotEmpty);
      });
    });

    // ─── verifyPassword ───────────────────
    group('verifyPassword', () {
      test('returns true for correct password', () {
        const password = 'admin123';
        final hash = CryptoUtils.hashPassword(password);
        expect(CryptoUtils.verifyPassword(password, hash), isTrue);
      });

      test('returns false for wrong password', () {
        final hash = CryptoUtils.hashPassword('correctpassword');
        expect(CryptoUtils.verifyPassword('wrongpassword', hash), isFalse);
      });

      test('is case-sensitive', () {
        final hash = CryptoUtils.hashPassword('Password');
        expect(CryptoUtils.verifyPassword('password', hash), isFalse);
        expect(CryptoUtils.verifyPassword('PASSWORD', hash), isFalse);
        expect(CryptoUtils.verifyPassword('Password', hash), isTrue);
      });

      test('returns false for empty password against non-empty hash', () {
        final hash = CryptoUtils.hashPassword('somepassword');
        expect(CryptoUtils.verifyPassword('', hash), isFalse);
      });
    });
  });
}