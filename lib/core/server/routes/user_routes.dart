// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:drift/drift.dart' hide JsonKey;
import '../../database/app_database.dart';
import '../../utils/crypto_utils.dart';
import '../middleware/auth_middleware.dart';

class UserRoutes {
  final AppDatabase db;

  UserRoutes(this.db);

  Router get router {
    final router = Router();
    router.get('/', _listHandler);
    router.post('/', _createHandler);
    router.put('/<id>', _updateHandler);
    router.put('/<id>/password', _changePasswordHandler);
    router.put('/<id>/toggle', _toggleActiveHandler);
    return router;
  }

  // ─────────────────────────────────────────────────────────────
  // GET /api/users  — รายการผู้ใช้ทั้งหมด (ADMIN/MANAGER)
  // ─────────────────────────────────────────────────────────────
  Future<Response> _listHandler(Request request) async {
    return roleGuard(request, [AppRoles.admin, AppRoles.manager], () async {
      try {
        final rows = await db.customSelect(
          '''
          SELECT
            u.user_id, u.username, u.full_name, u.email, u.phone,
            u.is_active, u.last_login, u.created_at,
            r.role_id, r.role_name,
            b.branch_id, b.branch_name
          FROM users u
          LEFT JOIN roles r ON r.role_id = u.role_id
          LEFT JOIN branches b ON b.branch_id = u.branch_id
          ORDER BY u.created_at DESC
          ''',
        ).get();

        final data = rows.map((row) => {
          'user_id':     row.read<String>('user_id'),
          'username':    row.read<String>('username'),
          'full_name':   row.read<String>('full_name'),
          'email':       row.readNullable<String>('email'),
          'phone':       row.readNullable<String>('phone'),
          'is_active':   row.read<bool>('is_active'),
          'last_login':  row.readNullable<DateTime>('last_login')?.toIso8601String(),
          'created_at':  row.read<DateTime>('created_at').toIso8601String(),
          'role_id':     row.readNullable<String>('role_id'),
          'role_name':   row.readNullable<String>('role_name'),
          'branch_id':   row.readNullable<String>('branch_id'),
          'branch_name': row.readNullable<String>('branch_name'),
        }).toList();

        return Response.ok(
          jsonEncode({'success': true, 'data': data}),
          headers: {'Content-Type': 'application/json'},
        );
      } catch (e) {
        return _serverError(e);
      }
    });
  }

  // ─────────────────────────────────────────────────────────────
  // POST /api/users  — สร้างผู้ใช้ใหม่ (ADMIN เท่านั้น)
  // Body: { username, password, full_name, email?, phone?, role_id?, branch_id? }
  // ─────────────────────────────────────────────────────────────
  Future<Response> _createHandler(Request request) async {
    return roleGuard(request, [AppRoles.admin], () async {
      try {
        final data =
            jsonDecode(await request.readAsString()) as Map<String, dynamic>;

        final username = (data['username'] as String?)?.trim() ?? '';
        final password = (data['password'] as String?)?.trim() ?? '';
        final fullName = (data['full_name'] as String?)?.trim() ?? '';

        if (username.isEmpty || password.isEmpty || fullName.isEmpty) {
          return _badRequest('กรุณาระบุ username, password และ full_name');
        }
        if (password.length < 6) {
          return _badRequest('password ต้องมีอย่างน้อย 6 ตัวอักษร');
        }

        // ตรวจ duplicate username
        final existing = await (db.select(db.users)
              ..where((u) => u.username.equals(username)))
            .getSingleOrNull();
        if (existing != null) {
          return _badRequest('Username "$username" มีอยู่แล้วในระบบ');
        }

        final userId = 'USR_${DateTime.now().millisecondsSinceEpoch}';
        await db.into(db.users).insert(UsersCompanion.insert(
          userId: userId,
          username: username,
          passwordHash: CryptoUtils.hashPassword(password),
          fullName: fullName,
          email: Value(data['email'] as String?),
          phone: Value(data['phone'] as String?),
          roleId: Value(data['role_id'] as String?),
          branchId: Value(data['branch_id'] as String?),
        ));

        return Response.ok(
          jsonEncode({'success': true, 'message': 'สร้างผู้ใช้สำเร็จ', 'data': {'user_id': userId}}),
          headers: {'Content-Type': 'application/json'},
        );
      } catch (e) {
        return _serverError(e);
      }
    });
  }

  // ─────────────────────────────────────────────────────────────
  // PUT /api/users/:id  — แก้ไขข้อมูลผู้ใช้ (ADMIN เท่านั้น)
  // Body: { full_name?, email?, phone?, role_id?, branch_id? }
  // ─────────────────────────────────────────────────────────────
  Future<Response> _updateHandler(Request request, String id) async {
    return roleGuard(request, [AppRoles.admin], () async {
      try {
        final data =
            jsonDecode(await request.readAsString()) as Map<String, dynamic>;

        final companion = UsersCompanion(
          fullName:  data.containsKey('full_name')  ? Value(data['full_name'] as String)   : const Value.absent(),
          email:     data.containsKey('email')       ? Value(data['email'] as String?)       : const Value.absent(),
          phone:     data.containsKey('phone')       ? Value(data['phone'] as String?)       : const Value.absent(),
          roleId:    data.containsKey('role_id')     ? Value(data['role_id'] as String?)     : const Value.absent(),
          branchId:  data.containsKey('branch_id')  ? Value(data['branch_id'] as String?)   : const Value.absent(),
          updatedAt: Value(DateTime.now()),
        );

        final count = await (db.update(db.users)
              ..where((u) => u.userId.equals(id)))
            .write(companion);

        if (count == 0) return _notFound('ไม่พบผู้ใช้ id: $id');

        return Response.ok(
          jsonEncode({'success': true, 'message': 'บันทึกข้อมูลสำเร็จ'}),
          headers: {'Content-Type': 'application/json'},
        );
      } catch (e) {
        return _serverError(e);
      }
    });
  }

  // ─────────────────────────────────────────────────────────────
  // PATCH /api/users/:id/password  — เปลี่ยนรหัสผ่าน
  // ADMIN เปลี่ยนให้คนอื่นได้ / ผู้ใช้เปลี่ยนของตัวเองได้ (ต้องใส่ old_password)
  // Body: { new_password, old_password? }
  // ─────────────────────────────────────────────────────────────
  Future<Response> _changePasswordHandler(Request request, String id) async {
    try {
      final caller = getAuthUser(request);
      if (caller == null) return _unauthorized();

      final data =
          jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final newPassword = (data['new_password'] as String?)?.trim() ?? '';
      if (newPassword.length < 6) {
        return _badRequest('รหัสผ่านใหม่ต้องมีอย่างน้อย 6 ตัวอักษร');
      }

      final isAdmin = caller.roleId == AppRoles.admin;
      final isSelf  = caller.userId == id;

      if (!isAdmin && !isSelf) {
        return Response(403,
            body: jsonEncode({'success': false, 'message': 'ไม่มีสิทธิ์เปลี่ยนรหัสผ่านผู้ใช้อื่น'}),
            headers: {'Content-Type': 'application/json'});
      }

      // ผู้ใช้เปลี่ยนของตัวเอง → ต้องใส่ old_password ยืนยัน
      if (isSelf && !isAdmin) {
        final oldPassword = (data['old_password'] as String?)?.trim() ?? '';
        final user = await (db.select(db.users)
              ..where((u) => u.userId.equals(id)))
            .getSingleOrNull();
        if (user == null) return _notFound('ไม่พบผู้ใช้');
        if (!CryptoUtils.verifyPassword(oldPassword, user.passwordHash)) {
          return _badRequest('รหัสผ่านเดิมไม่ถูกต้อง');
        }
      }

      final count = await (db.update(db.users)
            ..where((u) => u.userId.equals(id)))
          .write(UsersCompanion(
        passwordHash: Value(CryptoUtils.hashPassword(newPassword)),
        updatedAt: Value(DateTime.now()),
      ));

      if (count == 0) return _notFound('ไม่พบผู้ใช้ id: $id');

      return Response.ok(
        jsonEncode({'success': true, 'message': 'เปลี่ยนรหัสผ่านสำเร็จ'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return _serverError(e);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // PATCH /api/users/:id/toggle  — เปิด/ปิดใช้งาน (ADMIN เท่านั้น)
  // ─────────────────────────────────────────────────────────────
  Future<Response> _toggleActiveHandler(Request request, String id) async {
    return roleGuard(request, [AppRoles.admin], () async {
      try {
        final caller = getAuthUser(request);
        if (caller?.userId == id) {
          return _badRequest('ไม่สามารถปิดใช้งานบัญชีของตัวเองได้');
        }

        final user = await (db.select(db.users)
              ..where((u) => u.userId.equals(id)))
            .getSingleOrNull();
        if (user == null) return _notFound('ไม่พบผู้ใช้ id: $id');

        await (db.update(db.users)..where((u) => u.userId.equals(id)))
            .write(UsersCompanion(
          isActive: Value(!user.isActive),
          updatedAt: Value(DateTime.now()),
        ));

        return Response.ok(
          jsonEncode({
            'success': true,
            'message': !user.isActive ? 'เปิดใช้งานแล้ว' : 'ปิดใช้งานแล้ว',
            'data': {'is_active': !user.isActive},
          }),
          headers: {'Content-Type': 'application/json'},
        );
      } catch (e) {
        return _serverError(e);
      }
    });
  }

  // ── helpers ───────────────────────────────────────────────────
  Response _badRequest(String msg) => Response(400,
      body: jsonEncode({'success': false, 'message': msg}),
      headers: {'Content-Type': 'application/json'});

  Response _notFound(String msg) => Response(404,
      body: jsonEncode({'success': false, 'message': msg}),
      headers: {'Content-Type': 'application/json'});

  Response _unauthorized() => Response(401,
      body: jsonEncode({'success': false, 'message': 'Unauthorized'}),
      headers: {'Content-Type': 'application/json'});

  Response _serverError(Object e) {
    print('❌ UserRoutes error: $e');
    return Response.internalServerError(
      body: jsonEncode({'success': false, 'message': 'เกิดข้อผิดพลาด: $e'}),
      headers: {'Content-Type': 'application/json'},
    );
  }
}
