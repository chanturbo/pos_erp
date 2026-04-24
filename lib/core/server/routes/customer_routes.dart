import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:drift/drift.dart' hide JsonKey;
import '../../database/app_database.dart';
import '../../utils/input_validators.dart';
import 'package:flutter/foundation.dart';

class CustomerRoutes {
  final AppDatabase db;

  CustomerRoutes(this.db);

  Router get router {
    final router = Router();

    router.get('/', _getCustomersHandler);
    router.get('/<id>/check-delete', _checkDeleteCustomerHandler);
    router.get('/<id>', _getCustomerHandler);
    router.post('/', _createCustomerHandler);
    router.put('/<id>', _updateCustomerHandler);
    router.delete('/<id>', _deleteCustomerHandler);
    router.get('/code/<code>', _getCustomerByCodeHandler);
    router.get('/member/<memberNo>', _getCustomerByMemberNoHandler);
    router.put('/<id>/points', _updatePointsHandler);
    router.get('/<id>/points-history', _getPointsHistoryHandler); // ✅ ประวัติแต้ม
    router.get('/<id>/orders', _getCustomerOrdersHandler); // ✅ ประวัติการซื้อ

    return router;
  }

  // ─────────────────────────────────────────────────────────────
  // Helper: แปลง row จาก JOIN query → Map
  // ─────────────────────────────────────────────────────────────
  Map<String, dynamic> _rowToMap(QueryRow row) {
    return {
      'customer_id': row.read<String>('customer_id'),
      'customer_code': row.read<String>('customer_code'),
      'customer_name': row.read<String>('customer_name'),
      'customer_group_id': row.readNullable<String>('customer_group_id'),
      'address': row.readNullable<String>('address'),
      'phone': row.readNullable<String>('phone'),
      'email': row.readNullable<String>('email'),
      'tax_id': row.readNullable<String>('tax_id'),
      'credit_limit': row.read<double>('credit_limit'),
      'credit_days': row.read<int>('credit_days'),
      'current_balance': row.read<double>('current_balance'),
      'member_no': row.readNullable<String>('member_no'),
      'points': row.read<int>('points'),
      // ✅ price_level มาจาก JOIN ครั้งเดียว ไม่ใช่ N+1 queries
      'price_level': row.read<int>('price_level'),
      'is_active': row.read<bool>('is_active'),
    };
  }

  // ─────────────────────────────────────────────────────────────
  // GET /api/customers
  // รองรับ query params:
  //   ?limit=50&offset=0   → pagination
  //   ?search=xxx          → full-text filter ฝั่ง server
  //   ?active_only=true    → กรองเฉพาะ active
  // ─────────────────────────────────────────────────────────────
  Future<Response> _getCustomersHandler(Request request) async {
    try {
      final params = request.url.queryParameters;

      // ── Pagination params ──
      final limit = int.tryParse(params['limit'] ?? '500') ?? 500;
      final offset = int.tryParse(params['offset'] ?? '0') ?? 0;

      // ── Optional filters ──
      final search = (params['search'] ?? '').trim().toLowerCase();
      final activeOnly = params['active_only'] == 'true';

      // ── Build WHERE clause ──
      final conditions = <String>[];
      final variables = <Variable>[];

      if (activeOnly) {
        conditions.add('c.is_active = 1');
      }
      if (search.isNotEmpty) {
        conditions.add(
          '(LOWER(c.customer_name) LIKE ? OR LOWER(c.customer_code) LIKE ? OR c.phone LIKE ? OR c.member_no LIKE ?)',
        );
        final pattern = '%$search%';
        variables.addAll([
          Variable.withString(pattern),
          Variable.withString(pattern),
          Variable.withString(pattern),
          Variable.withString(pattern),
        ]);
      }

      final where =
          conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';

      // ── COUNT query (สำหรับ total ใน pagination) ──
      final countResult = await db
          .customSelect(
            '''
            SELECT COUNT(*) as total
            FROM customers c
            LEFT JOIN customer_groups cg ON c.customer_group_id = cg.customer_group_id
            $where
            ''',
            variables: variables,
          )
          .getSingle();
      final total = countResult.read<int>('total');

      // ── ✅ Single JOIN query แทน N+1 ──
      // LEFT JOIN customer_groups เพื่อดึง price_level ในครั้งเดียว
      // ไม่ว่าจะมีลูกค้า 1 หรือ 10,000 คน ใช้แค่ 1 query เสมอ
      variables.addAll([
        Variable.withInt(limit),
        Variable.withInt(offset),
      ]);

      final rows = await db
          .customSelect(
            '''
            SELECT
              c.customer_id,
              c.customer_code,
              c.customer_name,
              c.customer_group_id,
              c.address,
              c.phone,
              c.email,
              c.tax_id,
              c.credit_limit,
              c.credit_days,
              c.current_balance,
              c.member_no,
              c.points,
              c.is_active,
              COALESCE(cg.price_level, 1) AS price_level
            FROM customers c
            LEFT JOIN customer_groups cg
              ON c.customer_group_id = cg.customer_group_id
            $where
            ORDER BY c.customer_code ASC
            LIMIT ? OFFSET ?
            ''',
            variables: variables,
          )
          .get();

      final data = rows.map(_rowToMap).toList();

      return Response.ok(
        jsonEncode({
          'success': true,
          'data': data,
          'pagination': {
            'total': total,
            'limit': limit,
            'offset': offset,
            'has_more': (offset + limit) < total,
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

  // ─────────────────────────────────────────────────────────────
  // GET /api/customers/:id
  // ─────────────────────────────────────────────────────────────
  Future<Response> _getCustomerHandler(Request request, String id) async {
    try {
      final rows = await db
          .customSelect(
            '''
            SELECT
              c.customer_id,
              c.customer_code,
              c.customer_name,
              c.customer_group_id,
              c.address,
              c.phone,
              c.email,
              c.tax_id,
              c.credit_limit,
              c.credit_days,
              c.current_balance,
              c.member_no,
              c.points,
              c.is_active,
              COALESCE(cg.price_level, 1) AS price_level
            FROM customers c
            LEFT JOIN customer_groups cg
              ON c.customer_group_id = cg.customer_group_id
            WHERE c.customer_id = ?
            LIMIT 1
            ''',
            variables: [Variable.withString(id)],
          )
          .get();

      if (rows.isEmpty) {
        return Response.notFound(
          jsonEncode({'success': false, 'message': 'ไม่พบลูกค้า'}),
        );
      }
      return Response.ok(
        jsonEncode({'success': true, 'data': _rowToMap(rows.first)}),
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

      // ✅ Validate — email format, phone format, credit bounds
      final errors = InputValidators.validateCustomer(data);
      if (errors.isNotEmpty) {
        return InputValidators.badRequest(errors.join(', '));
      }

      // ✅ ตรวจสอบ customer_code ซ้ำ
      final existingCode = await (db.select(db.customers)
            ..where((t) =>
                t.customerCode.equals(data['customer_code'] as String)))
          .getSingleOrNull();
      if (existingCode != null) {
        return InputValidators.badRequest(
            'รหัสลูกค้า ${data['customer_code']} มีอยู่ในระบบแล้ว');
      }

      final customerId = 'CUS${DateTime.now().millisecondsSinceEpoch}';

      // ✅ Resolve customer_group_id จาก price_level (ถ้าส่งมา)
      String? resolvedGroupId = data['customer_group_id'] as String?;
      final requestedLevel = data['price_level'] as int?;
      if (requestedLevel != null) {
        final groups = await db.select(db.customerGroups).get();
        final matched =
            groups.where((g) => g.priceLevel == requestedLevel).firstOrNull;
        if (matched != null) resolvedGroupId = matched.customerGroupId;
      }

      await db.into(db.customers).insert(
            CustomersCompanion.insert(
              customerId: customerId,
              customerCode: data['customer_code'] as String,
              customerName: data['customer_name'] as String,
              customerGroupId: Value(resolvedGroupId),
              address: Value(data['address'] as String?),
              phone: Value(data['phone'] as String?),
              email: Value(data['email'] as String?),
              taxId: Value(data['tax_id'] as String?),
              creditLimit:
                  Value((data['credit_limit'] as num?)?.toDouble() ?? 0),
              creditDays: Value((data['credit_days'] as num?)?.toInt() ?? 0),
              memberNo: Value(data['member_no'] as String?),
              points: Value((data['points'] as num?)?.toInt() ?? 0),
            ),
          );

      return Response.ok(
        jsonEncode({
          'success': true,
          'message': 'สร้างลูกค้าสำเร็จ',
          'data': {'customer_id': customerId},
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ POST /api/customers error: $e');
      }
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': 'เกิดข้อผิดพลาดภายใน กรุณาลองใหม่'}),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────
  // PUT /api/customers/:id
  // ─────────────────────────────────────────────────────────────
  Future<Response> _updateCustomerHandler(Request request, String id) async {
    if (id == 'WALK_IN') {
      return Response.forbidden(
        jsonEncode({'success': false, 'message': 'ไม่สามารถแก้ไขลูกค้าระบบได้'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
    try {
      final payload = await request.readAsString();
      final data = jsonDecode(payload) as Map<String, dynamic>;

      // ✅ Validate — email format, phone format, credit bounds
      final errors = InputValidators.validateCustomer(data, isUpdate: true);
      if (errors.isNotEmpty) {
        return InputValidators.badRequest(errors.join(', '));
      }

      // ✅ ตรวจสอบ customer_code ซ้ำ (เฉพาะเมื่อเปลี่ยน code)
      if (data.containsKey('customer_code')) {
        final dupe = await (db.select(db.customers)
              ..where((t) =>
                  t.customerCode.equals(data['customer_code'] as String) &
                  t.customerId.isNotValue(id)))
            .getSingleOrNull();
        if (dupe != null) {
          return InputValidators.badRequest(
              'รหัสลูกค้า ${data['customer_code']} มีอยู่ในระบบแล้ว');
        }
      }

      String? resolvedGroupId = data['customer_group_id'] as String?;
      final requestedLevel = data['price_level'] as int?;
      if (requestedLevel != null) {
        final groups = await db.select(db.customerGroups).get();
        final matched =
            groups.where((g) => g.priceLevel == requestedLevel).firstOrNull;
        if (matched != null) resolvedGroupId = matched.customerGroupId;
      }

      await (db.update(db.customers)..where((t) => t.customerId.equals(id)))
          .write(
        CustomersCompanion(
          customerCode: data.containsKey('customer_code')
              ? Value(data['customer_code'] as String)
              : const Value.absent(),
          customerName: data.containsKey('customer_name')
              ? Value(data['customer_name'] as String)
              : const Value.absent(),
          customerGroupId: Value(resolvedGroupId),
          address: Value(data['address'] as String?),
          phone: Value(data['phone'] as String?),
          email: Value(data['email'] as String?),
          taxId: Value(data['tax_id'] as String?),
          creditLimit:
              Value((data['credit_limit'] as num?)?.toDouble() ?? 0),
          // ✅ safe cast ผ่าน num? — ป้องกัน crash จาก double input
          creditDays:
              Value((data['credit_days'] as num?)?.toInt() ?? 0),
          memberNo: Value(data['member_no'] as String?),
          isActive: data.containsKey('is_active')
              ? Value(data['is_active'] as bool)
              : const Value.absent(),
          updatedAt: Value(DateTime.now()),
        ),
      );

      return Response.ok(
        jsonEncode({'success': true, 'message': 'แก้ไขลูกค้าสำเร็จ'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ PUT /api/customers/$id error: $e');
      }
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': 'เกิดข้อผิดพลาดภายใน กรุณาลองใหม่'}),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────
  // ─── GET /:id/check-delete ────────────────────────────────────────────────
  Future<Response> _checkDeleteCustomerHandler(
      Request request, String id) async {
    try {
      final orderRow = await db.customSelect(
        'SELECT COUNT(*) AS cnt FROM sales_orders WHERE customer_id = ?',
        variables: [Variable.withString(id)],
      ).getSingle();
      final orderCount = (orderRow.data['cnt'] as int?) ?? 0;

      final pointsRow = await db.customSelect(
        'SELECT COUNT(*) AS cnt FROM points_transactions WHERE customer_id = ?',
        variables: [Variable.withString(id)],
      ).getSingle();
      final hasPoints = ((pointsRow.data['cnt'] as int?) ?? 0) > 0;

      return Response.ok(
        jsonEncode({
          'success': true,
          'has_history': orderCount > 0 || hasPoints,
          'has_orders': orderCount > 0,
          'order_count': orderCount,
          'has_points': hasPoints,
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': '$e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // DELETE /api/customers/:id  (Soft Delete — ตรวจก่อนลบ)
  // ─────────────────────────────────────────────────────────────
  Future<Response> _deleteCustomerHandler(Request request, String id) async {
    if (id == 'WALK_IN') {
      return Response.forbidden(
        jsonEncode({'success': false, 'message': 'ไม่สามารถลบลูกค้าระบบได้'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
    try {
      // ── ตรวจสอบประวัติการใช้งาน ──────────────────────────────
      final hasOrders = await (db.select(db.salesOrders)
            ..where((t) => t.customerId.equals(id))
            ..limit(1))
          .getSingleOrNull() != null;

      final hasPoints = await (db.select(db.pointsTransactions)
            ..where((t) => t.customerId.equals(id))
            ..limit(1))
          .getSingleOrNull() != null;

      final hasHistory = hasOrders || hasPoints;

      if (hasHistory) {
        // ── Soft Delete — มีประวัติ → ปิดการใช้งานแทน ────────
        await (db.update(db.customers)
              ..where((t) => t.customerId.equals(id)))
            .write(CustomersCompanion(
          isActive: const Value(false),
          updatedAt: Value(DateTime.now()),
        ));
        return Response.ok(
          jsonEncode({
            'success': true,
            'soft_delete': true,
            'message': 'ปิดการใช้งานลูกค้าสำเร็จ\n(มีประวัติการซื้อ จึงเก็บข้อมูลไว้)',
          }),
          headers: {'Content-Type': 'application/json'},
        );
      } else {
        // ── Hard Delete — ไม่มีประวัติ ลบได้เลย ──────────────
        await (db.delete(db.customers)
              ..where((t) => t.customerId.equals(id)))
            .go();
        return Response.ok(
          jsonEncode({
            'success': true,
            'soft_delete': false,
            'message': 'ลบลูกค้าสำเร็จ',
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }
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
      final rows = await db
          .customSelect(
            '''
            SELECT
              c.customer_id, c.customer_code, c.customer_name,
              c.customer_group_id, c.address, c.phone, c.email, c.tax_id,
              c.credit_limit, c.credit_days, c.current_balance,
              c.member_no, c.points, c.is_active,
              COALESCE(cg.price_level, 1) AS price_level
            FROM customers c
            LEFT JOIN customer_groups cg
              ON c.customer_group_id = cg.customer_group_id
            WHERE c.customer_code = ?
            LIMIT 1
            ''',
            variables: [Variable.withString(code)],
          )
          .get();

      if (rows.isEmpty) {
        return Response.notFound(
          jsonEncode({'success': false, 'message': 'ไม่พบลูกค้า'}),
        );
      }
      return Response.ok(
        jsonEncode({'success': true, 'data': _rowToMap(rows.first)}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': 'เกิดข้อผิดพลาด: $e'}),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────
  // GET /api/customers/member/:memberNo
  // ─────────────────────────────────────────────────────────────
  Future<Response> _getCustomerByMemberNoHandler(
      Request request, String memberNo) async {
    try {
      final rows = await db
          .customSelect(
            '''
            SELECT
              c.customer_id, c.customer_code, c.customer_name,
              c.customer_group_id, c.address, c.phone, c.email, c.tax_id,
              c.credit_limit, c.credit_days, c.current_balance,
              c.member_no, c.points, c.is_active,
              COALESCE(cg.price_level, 1) AS price_level
            FROM customers c
            LEFT JOIN customer_groups cg
              ON c.customer_group_id = cg.customer_group_id
            WHERE c.member_no = ?
            LIMIT 1
            ''',
            variables: [Variable.withString(memberNo)],
          )
          .get();

      if (rows.isEmpty) {
        return Response.notFound(
          jsonEncode({'success': false, 'message': 'ไม่พบสมาชิก'}),
        );
      }
      return Response.ok(
        jsonEncode({'success': true, 'data': _rowToMap(rows.first)}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': 'เกิดข้อผิดพลาด: $e'}),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────
  // PUT /api/customers/:id/points
  // ─────────────────────────────────────────────────────────────
  Future<Response> _updatePointsHandler(Request request, String id) async {
    try {
      final payload = await request.readAsString();
      final data = jsonDecode(payload) as Map<String, dynamic>;

      final action = data['action'] as String? ?? 'add';
      final delta = data['points'] as int? ?? 0;

      if (delta <= 0) {
        return Response(
          400,
          body: jsonEncode(
              {'success': false, 'message': 'points ต้องมากกว่า 0'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final customer = await (db.select(db.customers)
            ..where((t) => t.customerId.equals(id)))
          .getSingleOrNull();

      if (customer == null) {
        return Response.notFound(
          jsonEncode({'success': false, 'message': 'ไม่พบลูกค้า'}),
        );
      }

      final currentPoints = customer.points;
      int newPoints;

      if (action == 'add') {
        newPoints = currentPoints + delta;
      } else if (action == 'deduct') {
        newPoints = currentPoints - delta;
        if (newPoints < 0) {
          return Response(
            400,
            body: jsonEncode(
                {'success': false, 'message': 'คะแนนไม่เพียงพอ'}),
            headers: {'Content-Type': 'application/json'},
          );
        }
      } else {
        return Response(
          400,
          body: jsonEncode({
            'success': false,
            'message': 'action ไม่ถูกต้อง (add/deduct)',
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      await (db.update(db.customers)..where((t) => t.customerId.equals(id)))
          .write(
        CustomersCompanion(
          points: Value(newPoints),
          updatedAt: Value(DateTime.now()),
        ),
      );

      // ── บันทึก PointsTransaction ─────────────────────────────
      final txId = 'PTX-${DateTime.now().millisecondsSinceEpoch}';
      await db.into(db.pointsTransactions).insert(
        PointsTransactionsCompanion(
          transactionId: Value(txId),
          customerId:    Value(id),
          type:          Value(action == 'add' ? 'EARN' : 'REDEEM'),
          points:        Value(delta),
          referenceNo:   Value(data['reference_no'] as String?),
          remark:        Value(data['remark'] as String?),
        ),
      );

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

  // ─────────────────────────────────────────────────────────────
  // GET /api/customers/:id/points-history — ประวัติแต้มสะสม
  // ─────────────────────────────────────────────────────────────
  Future<Response> _getPointsHistoryHandler(
      Request request, String id) async {
    try {
      final txs = await (db.select(db.pointsTransactions)
            ..where((t) => t.customerId.equals(id))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();

      return Response.ok(
        jsonEncode({
          'success': true,
          'data': txs.map((t) => {
            'transaction_id': t.transactionId,
            'customer_id':    t.customerId,
            'type':           t.type,
            'points':         t.points,
            'reference_no':   t.referenceNo,
            'remark':         t.remark,
            'created_at':     t.createdAt.toIso8601String(),
          }).toList(),
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
  // GET /api/customers/:id/orders — ประวัติการซื้อของลูกค้า
  // ─────────────────────────────────────────────────────────────
  Future<Response> _getCustomerOrdersHandler(
      Request request, String id) async {
    try {
      // ดึง orders เรียงจากใหม่ไปเก่า
      final orders = await (db.select(db.salesOrders)
            ..where((t) => t.customerId.equals(id))
            ..orderBy([(t) => OrderingTerm.desc(t.orderDate)]))
          .get();

      final orderIds = orders.map((o) => o.orderId).toList();

      // ดึง items ของทุก order พร้อมกัน
      final Map<String, List<Map<String, dynamic>>> itemsMap = {};
      if (orderIds.isNotEmpty) {
        final allItems = await (db.select(db.salesOrderItems)
              ..where((t) => t.orderId.isIn(orderIds))
              ..orderBy([(t) => OrderingTerm.asc(t.lineNo)]))
            .get();

        for (final item in allItems) {
          itemsMap.putIfAbsent(item.orderId, () => []);
          itemsMap[item.orderId]!.add({
            'item_id':         item.itemId,
            'line_no':         item.lineNo,
            'product_name':    item.productName,
            'unit':            item.unit,
            'quantity':        item.quantity,
            'unit_price':      item.unitPrice,
            'discount_amount': item.discountAmount,
            'amount':          item.amount,
          });
        }
      }

      final totalSpent = orders.fold<double>(
          0, (sum, o) => sum + o.totalAmount);

      final data = orders.map((o) => {
        'order_id':        o.orderId,
        'order_no':        o.orderNo,
        'order_date':      o.orderDate.toIso8601String(),
        'payment_type':    o.paymentType,
        'subtotal':        o.subtotal,
        'discount_amount': o.discountAmount,
        'total_amount':    o.totalAmount,
        'status':          o.status,
        'items':           itemsMap[o.orderId] ?? [],
      }).toList();

      return Response.ok(
        jsonEncode({
          'success': true,
          'data': {
            'orders':       data,
            'total_orders': orders.length,
            'total_spent':  totalSpent,
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