
import 'dart:convert';
import 'package:shelf/shelf.dart';
import '../../database/app_database.dart';
import '../../services/auth_service.dart';
import 'package:flutter/foundation.dart';

// ─────────────────────────────────────────────────────────────────
// Role constants — ตรงกับ roles ใน seed_data.dart
// ─────────────────────────────────────────────────────────────────
class AppRoles {
  static const admin = 'ADMIN';
  static const manager = 'MANAGER';
  static const cashier = 'CASHIER';
  static const warehouse = 'WAREHOUSE';
  static const accountant = 'ACCOUNTANT';
}

// ─────────────────────────────────────────────────────────────────
// Helper: ดึง authenticated user จาก request context
// ใช้ใน route handlers แทนการพึ่ง data['user_id'] จาก body
// ─────────────────────────────────────────────────────────────────
User? getAuthUser(Request request) {
  return request.context['user'] as User?;
}

// ─────────────────────────────────────────────────────────────────
// roleGuard — จำกัด route ให้เฉพาะ role ที่กำหนด
//
// ตัวอย่าง:
//   return roleGuard(request, [AppRoles.admin], () => _deleteHandler(...));
// ─────────────────────────────────────────────────────────────────
Future<Response> roleGuard(
  Request request,
  List<String> allowedRoles,
  Future<Response> Function() handler,
) async {
  final user = getAuthUser(request);

  if (user == null) {
    return Response(
      401,
      body: jsonEncode({'success': false, 'message': 'Unauthorized — กรุณาเข้าสู่ระบบก่อน'}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  if (!allowedRoles.contains(user.roleId ?? '')) {
    return Response(
      403,
      body: jsonEncode({
        'success': false,
        'message': 'Forbidden — สิทธิ์ ${user.roleId} ไม่สามารถดำเนินการนี้ได้',
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }

  return handler();
}

// ─────────────────────────────────────────────────────────────────
// authMiddleware
//
// ✅ Public paths: api/auth + api/health เท่านั้น
// ✅ ทุก business route ต้อง Bearer token — ไม่มีข้อยกเว้น
// ✅ inject User object เข้า request.context['user']
//    → route handlers ใช้ getAuthUser(request) ได้ทันที
// ─────────────────────────────────────────────────────────────────
Middleware authMiddleware(AppDatabase db) {
  final authService = AuthService(db);

  return (Handler handler) {
    return (Request request) async {
      final path = request.url.path;

      // ── Public paths — เฉพาะ 2 นี้เท่านั้น ──────────────────
      if (path == 'api/health' ||
          path.startsWith('api/auth/') ||
          path == 'api/auth') {
        return handler(request);
      }

      // ── ทุก path อื่น: ต้อง Bearer token ──────────────────────
      final authHeader = request.headers['authorization'];

      if (authHeader == null || !authHeader.startsWith('Bearer ')) {
        return Response(
          401,
          body: jsonEncode({
            'success': false,
            'message': 'Unauthorized — กรุณาเข้าสู่ระบบก่อน',
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      try {
        final token = authHeader.replaceFirst('Bearer ', '').trim();

        if (token.isEmpty) {
          return Response(
            401,
            body: jsonEncode({'success': false, 'message': 'Unauthorized — Token ไม่ถูกต้อง'}),
            headers: {'Content-Type': 'application/json'},
          );
        }

        final user = await authService.verifyToken(token);

        if (user == null) {
          return Response(
            401,
            body: jsonEncode({
              'success': false,
              'message': 'Unauthorized — Token หมดอายุหรือไม่ถูกต้อง',
            }),
            headers: {'Content-Type': 'application/json'},
          );
        }

        if (!user.isActive) {
          return Response(
            403,
            body: jsonEncode({
              'success': false,
              'message': 'Forbidden — บัญชีผู้ใช้นี้ถูกปิดการใช้งาน',
            }),
            headers: {'Content-Type': 'application/json'},
          );
        }

        // ✅ inject User เข้า context → route handlers ใช้ getAuthUser()
        return handler(request.change(context: {'user': user}));
      } catch (e) {
        if (kDebugMode) {
          debugPrint('❌ Auth middleware error: $e');
        }
        return Response(
          401,
          body: jsonEncode({'success': false, 'message': 'Unauthorized — ไม่สามารถยืนยันตัวตนได้'}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    };
  };
}