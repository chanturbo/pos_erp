import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../../database/app_database.dart';
import '../../services/auth_service.dart';

class AuthRoutes {
  final AppDatabase db;
  late final AuthService authService;
  
  AuthRoutes(this.db) {
    authService = AuthService(db);
  }
  
  Router get router {
    final router = Router();
    
    router.post('/login', _loginHandler);
    router.post('/logout', _logoutHandler);
    router.get('/me', _meHandler);
    
    return router;
  }
  
  /// POST /api/auth/login
  Future<Response> _loginHandler(Request request) async {
    try {
      final payload = await request.readAsString();
      final data = jsonDecode(payload) as Map<String, dynamic>;
      
      final username = data['username'] as String?;
      final password = data['password'] as String?;
      
      if (username == null || password == null) {
        return Response(400, body: jsonEncode({
          'success': false,
          'message': 'กรุณาระบุ username และ password',
        }));
      }
      
      // Login
      final result = await authService.login(
        username: username,
        password: password,
      );
      
      if (result == null) {
        return Response(401, body: jsonEncode({
          'success': false,
          'message': 'Username หรือ Password ไม่ถูกต้อง',
        }));
      }
      
      return Response.ok(jsonEncode({
        'success': true,
        'message': 'เข้าสู่ระบบสำเร็จ',
        'data': {
          'user_id': result.user.userId,
          'username': result.user.username,
          'full_name': result.user.fullName,
          'token': result.token,
        },
      }), headers: {
        'Content-Type': 'application/json',
      });
      
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'เกิดข้อผิดพลาด: $e',
        }),
      );
    }
  }
  
  /// POST /api/auth/logout
  Future<Response> _logoutHandler(Request request) async {
    try {
      final token = request.headers['authorization']?.replaceFirst('Bearer ', '');
      
      if (token == null) {
        return Response(400, body: jsonEncode({
          'success': false,
          'message': 'ไม่พบ token',
        }));
      }
      
      await authService.logout(token);
      
      return Response.ok(jsonEncode({
        'success': true,
        'message': 'ออกจากระบบสำเร็จ',
      }), headers: {
        'Content-Type': 'application/json',
      });
      
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'เกิดข้อผิดพลาด: $e',
        }),
      );
    }
  }
  
  /// GET /api/auth/me
  Future<Response> _meHandler(Request request) async {
    try {
      final token = request.headers['authorization']?.replaceFirst('Bearer ', '');
      
      if (token == null) {
        return Response(401, body: jsonEncode({
          'success': false,
          'message': 'ไม่พบ token',
        }));
      }
      
      final user = await authService.verifyToken(token);
      
      if (user == null) {
        return Response(401, body: jsonEncode({
          'success': false,
          'message': 'Token ไม่ถูกต้องหรือหมดอายุ',
        }));
      }
      
      return Response.ok(jsonEncode({
        'success': true,
        'data': {
          'user_id': user.userId,
          'username': user.username,
          'full_name': user.fullName,
          'email': user.email,
          'role_id': user.roleId,
          'branch_id': user.branchId,
        },
      }), headers: {
        'Content-Type': 'application/json',
      });
      
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'เกิดข้อผิดพลาด: $e',
        }),
      );
    }
  }
}