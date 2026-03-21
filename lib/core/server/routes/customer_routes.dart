import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:drift/drift.dart' hide JsonKey;
import '../../database/app_database.dart';

class CustomerRoutes {
  final AppDatabase db;

  CustomerRoutes(this.db);

  Router get router {
    final router = Router();

    router.get('/', _getCustomersHandler);
    router.get('/<id>', _getCustomerHandler);
    router.post('/', _createCustomerHandler);
    router.put('/<id>', _updateCustomerHandler);
    router.delete('/<id>', _deleteCustomerHandler);
    router.get('/code/<code>', _getCustomerByCodeHandler);
    // ✅ Week 5: Member endpoints
    router.get('/member/<memberNo>', _getCustomerByMemberNoHandler);
    router.put('/<id>/points', _updatePointsHandler);

    return router;
  }

  // ─────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────
  Map<String, dynamic> _toMap(Customer c) => {
        'customer_id': c.customerId,
        'customer_code': c.customerCode,
        'customer_name': c.customerName,
        'customer_group_id': c.customerGroupId,
        'address': c.address,
        'phone': c.phone,
        'email': c.email,
        'tax_id': c.taxId,
        'credit_limit': c.creditLimit,
        'credit_days': c.creditDays,
        'current_balance': c.currentBalance,
        'member_no': c.memberNo,
        'points': c.points,
        'is_active': c.isActive,
      };

  // ─────────────────────────────────────────────────────────────
  // GET /api/customers
  // ─────────────────────────────────────────────────────────────
  Future<Response> _getCustomersHandler(Request request) async {
    try {
      final customers = await db.select(db.customers).get();
      return Response.ok(
        jsonEncode({'success': true, 'data': customers.map(_toMap).toList()}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': 'เกิดข้อผิดพลาด: $e'}),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────
  // GET /api/customers/:id
  // ─────────────────────────────────────────────────────────────
  Future<Response> _getCustomerHandler(Request request, String id) async {
    try {
      final customer = await (db.select(db.customers)
            ..where((t) => t.customerId.equals(id)))
          .getSingleOrNull();
      if (customer == null) {
        return Response.notFound(jsonEncode(
            {'success': false, 'message': 'ไม่พบลูกค้า'}));
      }
      return Response.ok(
        jsonEncode({'success': true, 'data': _toMap(customer)}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': 'เกิดข้อผิดพลาด: $e'}),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────
  // POST /api/customers
  // ─────────────────────────────────────────────────────────────
  Future<Response> _createCustomerHandler(Request request) async {
    try {
      final payload = await request.readAsString();
      final data = jsonDecode(payload) as Map<String, dynamic>;

      final customerId = 'CUS${DateTime.now().millisecondsSinceEpoch}';

      await db.into(db.customers).insert(CustomersCompanion.insert(
            customerId: customerId,
            customerCode: data['customer_code'] as String,
            customerName: data['customer_name'] as String,
            customerGroupId: Value(data['customer_group_id'] as String?),
            address: Value(data['address'] as String?),
            phone: Value(data['phone'] as String?),
            email: Value(data['email'] as String?),
            taxId: Value(data['tax_id'] as String?),
            creditLimit: Value((data['credit_limit'] as num?)?.toDouble() ?? 0),
            creditDays: Value(data['credit_days'] as int? ?? 0),
            memberNo: Value(data['member_no'] as String?),
            // ✅ รองรับ points ตอนสร้าง (optional)
            points: Value(data['points'] as int? ?? 0),
          ));

      return Response.ok(
        jsonEncode({
          'success': true,
          'message': 'สร้างลูกค้าสำเร็จ',
          'data': {'customer_id': customerId},
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': 'เกิดข้อผิดพลาด: $e'}),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────
  // PUT /api/customers/:id
  // ─────────────────────────────────────────────────────────────
  Future<Response> _updateCustomerHandler(Request request, String id) async {
    // ✅ ป้องกันแก้ไขลูกค้าระบบ
    if (id == 'WALK_IN') {
      return Response.forbidden(
        jsonEncode({'success': false, 'message': 'ไม่สามารถแก้ไขลูกค้าระบบได้'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
    try {
      final payload = await request.readAsString();
      final data = jsonDecode(payload) as Map<String, dynamic>;

      await (db.update(db.customers)..where((t) => t.customerId.equals(id)))
          .write(CustomersCompanion(
        customerCode: Value(data['customer_code'] as String),
        customerName: Value(data['customer_name'] as String),
        customerGroupId: Value(data['customer_group_id'] as String?),
        address: Value(data['address'] as String?),
        phone: Value(data['phone'] as String?),
        email: Value(data['email'] as String?),
        taxId: Value(data['tax_id'] as String?),
        creditLimit: Value((data['credit_limit'] as num?)?.toDouble() ?? 0),
        creditDays: Value(data['credit_days'] as int? ?? 0),
        memberNo: Value(data['member_no'] as String?),
        updatedAt: Value(DateTime.now()),
      ));

      return Response.ok(
        jsonEncode({'success': true, 'message': 'แก้ไขลูกค้าสำเร็จ'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': 'เกิดข้อผิดพลาด: $e'}),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────
  // DELETE /api/customers/:id
  // ─────────────────────────────────────────────────────────────
  Future<Response> _deleteCustomerHandler(Request request, String id) async {
    // ✅ ป้องกันลบลูกค้าระบบ
    if (id == 'WALK_IN') {
      return Response.forbidden(
        jsonEncode({'success': false, 'message': 'ไม่สามารถลบลูกค้าระบบได้'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
    try {
      await (db.delete(db.customers)
            ..where((t) => t.customerId.equals(id)))
          .go();
      return Response.ok(
        jsonEncode({'success': true, 'message': 'ลบลูกค้าสำเร็จ'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': 'เกิดข้อผิดพลาด: $e'}),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────
  // GET /api/customers/code/:code
  // ─────────────────────────────────────────────────────────────
  Future<Response> _getCustomerByCodeHandler(
      Request request, String code) async {
    try {
      final customer = await (db.select(db.customers)
            ..where((t) => t.customerCode.equals(code)))
          .getSingleOrNull();
      if (customer == null) {
        return Response.notFound(
            jsonEncode({'success': false, 'message': 'ไม่พบลูกค้า'}));
      }
      return Response.ok(
        jsonEncode({'success': true, 'data': _toMap(customer)}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': 'เกิดข้อผิดพลาด: $e'}),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────
  // ✅ Week 5: GET /api/customers/member/:memberNo
  // ─────────────────────────────────────────────────────────────
  Future<Response> _getCustomerByMemberNoHandler(
      Request request, String memberNo) async {
    try {
      final customer = await (db.select(db.customers)
            ..where((t) => t.memberNo.equals(memberNo)))
          .getSingleOrNull();
      if (customer == null) {
        return Response.notFound(
            jsonEncode({'success': false, 'message': 'ไม่พบสมาชิก'}));
      }
      return Response.ok(
        jsonEncode({'success': true, 'data': _toMap(customer)}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': 'เกิดข้อผิดพลาด: $e'}),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────
  // ✅ Week 5: PUT /api/customers/:id/points
  // Body: { "action": "add"|"deduct", "points": 10, "remark": "..." }
  // ─────────────────────────────────────────────────────────────
  Future<Response> _updatePointsHandler(Request request, String id) async {
    try {
      final payload = await request.readAsString();
      final data = jsonDecode(payload) as Map<String, dynamic>;

      final action = data['action'] as String? ?? 'add';
      final delta = data['points'] as int? ?? 0;

      if (delta <= 0) {
        return Response(400,
            body: jsonEncode(
                {'success': false, 'message': 'points ต้องมากกว่า 0'}),
            headers: {'Content-Type': 'application/json'});
      }

      // ดึงค่า points ปัจจุบัน
      final customer = await (db.select(db.customers)
            ..where((t) => t.customerId.equals(id)))
          .getSingleOrNull();

      if (customer == null) {
        return Response.notFound(
            jsonEncode({'success': false, 'message': 'ไม่พบลูกค้า'}));
      }

      final currentPoints = customer.points;
      int newPoints;

      if (action == 'add') {
        newPoints = currentPoints + delta;
      } else if (action == 'deduct') {
        newPoints = currentPoints - delta;
        if (newPoints < 0) {
          return Response(400,
              body: jsonEncode(
                  {'success': false, 'message': 'คะแนนไม่เพียงพอ'}),
              headers: {'Content-Type': 'application/json'});
        }
      } else {
        return Response(400,
            body: jsonEncode(
                {'success': false, 'message': 'action ไม่ถูกต้อง (add/deduct)'}),
            headers: {'Content-Type': 'application/json'});
      }

      // อัปเดต points
      await (db.update(db.customers)
            ..where((t) => t.customerId.equals(id)))
          .write(CustomersCompanion(
        points: Value(newPoints),
        updatedAt: Value(DateTime.now()),
      ));

      return Response.ok(
        jsonEncode({
          'success': true,
          'message': action == 'add'
              ? 'บวกคะแนนสำเร็จ (+$delta)'
              : 'หักคะแนนสำเร็จ (-$delta)',
          'data': {
            'customer_id': id,
            'previous_points': currentPoints,
            'delta': action == 'add' ? delta : -delta,
            'new_points': newPoints,
          },
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': 'เกิดข้อผิดพลาด: $e'}),
      );
    }
  }
}