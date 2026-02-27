import 'dart:convert';
import 'package:shelf/shelf.dart';
import '../../database/app_database.dart';
import '../../services/auth_service.dart';

/// Middleware สำหรับตรวจสอบ Authentication
Middleware authMiddleware(AppDatabase db) {
  final authService = AuthService(db);
  
  return (Handler handler) {
    return (Request request) async {
      final path = request.url.path;
      
      // ✅ Skip ทั้ง /api/auth และ /api/health
      if (path.startsWith('api/auth') || path.startsWith('api/health')) {
        return handler(request);
      }
      
      // ตรวจสอบ token
      final authHeader = request.headers['authorization'];
      
      if (authHeader == null || !authHeader.startsWith('Bearer ')) {
        return Response(401, body: jsonEncode({
          'success': false,
          'message': 'Unauthorized - Missing token',
        }), headers: {
          'Content-Type': 'application/json',
        });
      }
      
      final token = authHeader.replaceFirst('Bearer ', '');
      final user = await authService.verifyToken(token);
      
      if (user == null) {
        return Response(401, body: jsonEncode({
          'success': false,
          'message': 'Unauthorized - Invalid token',
        }), headers: {
          'Content-Type': 'application/json',
        });
      }
      
      // เพิ่ม user ลง request context
      final updatedRequest = request.change(context: {
        'user': user,
      });
      
      return handler(updatedRequest);
    };
  };
}