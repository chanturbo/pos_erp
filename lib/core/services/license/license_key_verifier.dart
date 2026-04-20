// ignore_for_file: avoid_print
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:pointycastle/export.dart';
import 'package:pointycastle/asn1.dart';

import 'license_models.dart';

/// ตรวจสอบ License Key ด้วย RSA-SHA256-PKCS1v15
///
/// Format ของ key: {base64url_payload}.{base64url_signature}
/// Payload = UTF-8 JSON bytes ที่ sign ด้วย Private Key บน PHP Server
///
/// วิธีสร้าง key pair (PHP side):
/// ```bash
/// openssl genrsa -out private.pem 2048
/// openssl rsa -in private.pem -pubout -out public.pem
/// ```
///
/// วิธี sign บน PHP:
/// ```php
/// openssl_sign($payloadJson, $sig, $privateKey, OPENSSL_ALGO_SHA256);
/// $key = base64url($payloadJson) . '.' . base64url($sig);
/// ```
class LicenseKeyVerifier {
  // ═══════════════════════════════════════════════════════════════════
  // RSA-2048 Public Key — แทนที่ด้วย key จริงก่อน build production!
  // ═══════════════════════════════════════════════════════════════════
  // สร้าง key pair:
  //   openssl genrsa -out private.pem 2048
  //   openssl rsa -in private.pem -pubout -out public.pem
  // นำ public.pem มาวางที่นี่
  static const _publicKeyPem = '''
-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAwYOObGORFFdLvZDtRApd
NjSCiownCImQG69zQZo/yz4kVqD9nWvrmyETuexFxWpUa89/0QspsNQ0i6Oj7hv8
DRekGHSeJ9qshFPDni0plr2JV724pC9EuOBQqhqT5xOvEcqdgyJpeD8dIc0yrGG/
DMsM334hCJtocQjY0htp0vNtj+C4cZg7M8Dvw4n5GBDGSq5sdvAXuggh1ywdG53w
m9XsH7quJW+uvTQlrTHtsFasUuLd8msXTwuU+33ME8pVf2ZlWAYILF0Tc3h8Ts7w
aIcPTuXTWLLnZp5JmIrzvoTbESl2UeKr0iNSq8i7jClnbKF6fuVDQ+HKmAknHO41
iQIDAQAB
-----END PUBLIC KEY-----
''';

  /// ตรวจสอบ License Key
  /// คืน [LicensePayload] ถ้า key valid, null ถ้าไม่ valid
  static LicensePayload? verify({
    required String licenseKey,
    required String deviceId,
  }) {
    try {
      final parts = licenseKey.trim().split('.');
      if (parts.length != 2) return null;

      final payloadBytes = _base64UrlDecode(parts[0]);
      final signatureBytes = _base64UrlDecode(parts[1]);

      if (payloadBytes == null || signatureBytes == null) return null;

      // Debug mode: ข้ามการตรวจ RSA signature (ใช้สำหรับพัฒนาเท่านั้น)
      if (!kDebugMode) {
        if (!_verifyRsaSignature(
          message: Uint8List.fromList(payloadBytes),
          signature: Uint8List.fromList(signatureBytes),
        )) {
          print('[License] RSA signature invalid');
          return null;
        }
      }

      return _parseAndValidate(payloadBytes, deviceId);
    } catch (e) {
      print('[License] verify error: $e');
      return null;
    }
  }

  static bool _verifyRsaSignature({
    required Uint8List message,
    required Uint8List signature,
  }) {
    try {
      final publicKey = _parseSubjectPublicKeyInfo(_publicKeyPem);
      final signer = Signer('SHA-256/RSA')
        ..init(false, PublicKeyParameter<RSAPublicKey>(publicKey));
      return signer.verifySignature(message, RSASignature(signature));
    } catch (e) {
      print('[License] RSA verify error: $e');
      return false;
    }
  }

  static RSAPublicKey _parseSubjectPublicKeyInfo(String pem) {
    final base64Str = pem
        .replaceAll('-----BEGIN PUBLIC KEY-----', '')
        .replaceAll('-----END PUBLIC KEY-----', '')
        .replaceAll('\r', '')
        .replaceAll('\n', '')
        .trim();
    final derBytes = base64.decode(base64Str);

    // SubjectPublicKeyInfo ::= SEQUENCE { AlgorithmIdentifier, BIT STRING }
    final parser = ASN1Parser(Uint8List.fromList(derBytes));
    final outerSeq = parser.nextObject() as ASN1Sequence;

    // BIT STRING valueBytes includes 1 unused-bits-indicator byte → skip it
    final bitStringBytes = outerSeq.elements![1].valueBytes!;
    final rsaKeyBytes = Uint8List.fromList(bitStringBytes.sublist(1));

    // RSAPublicKey ::= SEQUENCE { modulus INTEGER, publicExponent INTEGER }
    final innerParser = ASN1Parser(rsaKeyBytes);
    final innerSeq = innerParser.nextObject() as ASN1Sequence;

    final modulus = (innerSeq.elements![0] as ASN1Integer).integer!;
    final exponent = (innerSeq.elements![1] as ASN1Integer).integer!;

    return RSAPublicKey(modulus, exponent);
  }

  static LicensePayload? _parseAndValidate(
    List<int> payloadBytes,
    String deviceId,
  ) {
    final jsonStr = utf8.decode(payloadBytes);
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    final payload = LicensePayload.fromJson(json);

    // ตรวจ device_id — "ANY" ใช้ได้ใน debug mode เท่านั้น
    if (payload.deviceId != deviceId) {
      if (kDebugMode && payload.deviceId == 'ANY') return payload;
      print('[License] device_id mismatch: ${payload.deviceId} vs $deviceId');
      return null;
    }

    return payload;
  }

  static List<int>? _base64UrlDecode(String s) {
    try {
      return base64Url.decode(base64Url.normalize(s));
    } catch (_) {
      return null;
    }
  }

  /// สร้าง test license key สำหรับ debug (ใช้ใน unit test เท่านั้น)
  /// key นี้ไม่ผ่าน RSA verify ใน release mode
  static String buildDebugKey({
    required String email,
    required String deviceId,
    required DateTime expireDate,
  }) {
    assert(kDebugMode, 'buildDebugKey ใช้ใน debug mode เท่านั้น');
    final payload = {
      'email': email,
      'device_id': deviceId,
      'expire_date': expireDate.toIso8601String().substring(0, 10),
      'issued_at': DateTime.now().toIso8601String().substring(0, 10),
    };
    final payloadBytes = utf8.encode(jsonEncode(payload));
    final payloadB64 = base64Url.encode(payloadBytes);
    // Signature placeholder (จะไม่ผ่าน RSA ใน release)
    final sigB64 = base64Url.encode(List.filled(256, 0));
    return '$payloadB64.$sigB64';
  }
}
