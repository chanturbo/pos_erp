// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:drift/drift.dart' hide JsonKey;
import '../../database/app_database.dart';
import '../middleware/auth_middleware.dart';
import '../../utils/input_validators.dart';

class SalesRoutes {
  final AppDatabase db;

  SalesRoutes(this.db);

  Router get router {
    final router = Router();

    router.get('/', _getSalesOrdersHandler);
    router.get('/<id>', _getSalesOrderHandler);
    router.post('/', _createSalesOrderHandler);
    router.put('/<id>', _updateSalesOrderHandler);
    router.delete('/<id>', _deleteSalesOrderHandler);

    return router;
  }

  /// GET /api/sales - รายการขายทั้งหมด
  Future<Response> _getSalesOrdersHandler(Request request) async {
    try {
      print('📡 GET /api/sales');

      final orders = await db.select(db.salesOrders).get();

      print('✅ Found ${orders.length} orders');

      return Response.ok(
        jsonEncode({
          'success': true,
          'data': orders
              .map(
                (o) => {
                  'order_id': o.orderId,
                  'order_no': o.orderNo,
                  'order_date': o.orderDate.toIso8601String(),
                  'customer_id': o.customerId,
                  'customer_name': o.customerName,
                  'total_amount': o.totalAmount,
                  'discount_amount': o.discountAmount,
                  'net_amount': o.totalAmount,
                  'payment_type': o.paymentType,
                  'status': o.status,
                },
              )
              .toList(),
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('❌ GET /api/sales error: $e');
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': 'เกิดข้อผิดพลาด: $e'}),
      );
    }
  }

  /// GET /api/sales/:id - ดึงใบขาย 1 รายการ
  Future<Response> _getSalesOrderHandler(Request request, String id) async {
    try {
      print('📡 GET /api/sales/$id');

      final order = await (db.select(
        db.salesOrders,
      )..where((t) => t.orderId.equals(id))).getSingleOrNull();

      if (order == null) {
        return Response.notFound(
          jsonEncode({'success': false, 'message': 'ไม่พบใบขาย'}),
        );
      }

      final items = await (db.select(
        db.salesOrderItems,
      )..where((t) => t.orderId.equals(id))).get();

      return Response.ok(
        jsonEncode({
          'success': true,
          'data': {
            'order_id': order.orderId,
            'order_no': order.orderNo,
            'order_date': order.orderDate.toIso8601String(),
            'customer_id': order.customerId,
            'customer_name': order.customerName,
            'subtotal': order.subtotal,
            'discount_amount': order.discountAmount,
            'total_amount': order.totalAmount,
            'payment_type': order.paymentType,
            'paid_amount': order.paidAmount,
            'change_amount': order.changeAmount,
            'status': order.status,
            'items': items
                .map(
                  (i) => {
                    'item_id': '${i.orderId}_${i.lineNo}',
                    'order_id': i.orderId,
                    'product_id': i.productId,
                    'product_code': i.productCode,
                    'product_name': i.productName,
                    'quantity': i.quantity,
                    'unit_price': i.unitPrice,
                    'amount': i.amount,
                  },
                )
                .toList(),
          },
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('❌ GET /api/sales/$id error: $e');
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': 'เกิดข้อผิดพลาด: $e'}),
      );
    }
  }

  /// POST /api/sales - สร้างใบขายใหม่
  Future<Response> _createSalesOrderHandler(Request request) async {
    try {
      // ✅ ดึง user จาก context — inject โดย authMiddleware
      final authUser = getAuthUser(request);
      if (authUser == null) {
        return Response(401,
            body: jsonEncode({'success': false, 'message': 'Unauthorized'}),
            headers: {'Content-Type': 'application/json'});
      }

      final payload = await request.readAsString();
      final data = jsonDecode(payload) as Map<String, dynamic>;

      if (data['items'] == null || (data['items'] as List).isEmpty) {
        return Response(400,
            body: jsonEncode({'success': false, 'message': 'ไม่มีรายการสินค้า'}),
            headers: {'Content-Type': 'application/json'});
      }

      final items = data['items'] as List;

      // ✅ Validate รูปแบบ items ก่อน (ไม่ต้องใช้ DB)
      final validationErrors = <String>[];
      for (var i = 0; i < items.length; i++) {
        final item = items[i];
        if (item is! Map) {
          validationErrors.add('รายการที่ ${i + 1}: รูปแบบข้อมูลไม่ถูกต้อง');
          continue;
        }
        validationErrors.addAll(
          InputValidators.validateOrderItem(item as Map<String, dynamic>, i + 1),
        );
      }
      if (validationErrors.isNotEmpty) {
        return Response(400,
            body: jsonEncode({'success': false, 'message': validationErrors.join(', ')}),
            headers: {'Content-Type': 'application/json'});
      }

      final ts = DateTime.now().millisecondsSinceEpoch;
      final now = DateTime.fromMillisecondsSinceEpoch(ts);
      final datePart =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';

      final orderId = 'SO$ts';
      final orderNo = 'SO-$datePart-$ts';
      final warehouseId = data['warehouse_id'] as String? ?? 'WH001';

      // ✅ ใช้ user จาก token แทน hardcode / client-supplied
      final userId = authUser.userId;
      final branchId = authUser.branchId ?? data['branch_id'] as String? ?? 'BR001';

      print('🆔 Generated order: $orderNo (user: $userId)');

      // ─────────────────────────────────────────────────────────────
      // CRITICAL FIX: stock check อยู่ภายใน transaction เดียวกับ insert
      //
      // เดิม: check → [race condition gap] → insert
      //   → 2 requests พร้อมกันผ่าน check ทั้งคู่ → stock ติดลบ
      //
      // ใหม่: BEGIN → check → insert → COMMIT (atomic)
      //   → ถ้า stock ไม่พอ throw → transaction rollback ทันที
      // ─────────────────────────────────────────────────────────────
      print('💾 Starting transaction...');

      await db.transaction(() async {
        // --- Stock check ภายใน transaction ---
        for (var i = 0; i < items.length; i++) {
          final item = items[i] as Map<String, dynamic>;
          final productId = item['product_id'] as String;
          final quantity = (item['quantity'] as num).toDouble();

          final product = await (db.select(db.products)
                ..where((t) => t.productId.equals(productId)))
              .getSingleOrNull();

          if (product == null) {
            throw _ValidationException('ไม่พบสินค้า $productId');
          }

          if (product.isStockControl && !product.allowNegativeStock) {
            final currentStock = await _getCurrentStock(productId, warehouseId);
            print('📊 Stock $productId: $currentStock (need: $quantity)');

            if (currentStock < quantity) {
              throw _ValidationException(
                'สต๊อกสินค้า ${product.productName} ไม่เพียงพอ '
                '(คงเหลือ: $currentStock, ต้องการ: $quantity)',
              );
            }
          }
        }

        // --- Insert Sales Order ---
        await db.into(db.salesOrders).insert(
              SalesOrdersCompanion(
                orderId: Value(orderId),
                orderNo: Value(orderNo),
                orderDate: Value(now),
                orderType: const Value('SALE'),
                customerId: Value(data['customer_id'] as String?),
                customerName: Value(data['customer_name'] as String?),
                branchId: Value(branchId),
                warehouseId: Value(warehouseId),
                userId: Value(userId),
                subtotal: Value((data['subtotal'] as num?)?.toDouble() ?? 0),
                discountAmount: Value((data['discount_amount'] as num?)?.toDouble() ?? 0),
                amountBeforeVat: Value((data['amount_before_vat'] as num?)?.toDouble() ?? 0),
                vatAmount: Value((data['vat_amount'] as num?)?.toDouble() ?? 0),
                totalAmount: Value((data['total_amount'] as num?)?.toDouble() ?? 0),
                paymentType: Value(data['payment_type'] as String? ?? 'CASH'),
                paidAmount: Value((data['paid_amount'] as num?)?.toDouble() ?? 0),
                changeAmount: Value((data['change_amount'] as num?)?.toDouble() ?? 0),
                status: const Value('COMPLETED'),
              ),
            );
        print('✅ Order inserted: $orderNo');

        // --- Insert Items + Stock Movements ---
        for (var i = 0; i < items.length; i++) {
          final item = items[i] as Map<String, dynamic>;
          final lineNo = i + 1;
          final itemId = '${orderId}_$lineNo';
          final productId = item['product_id'] as String;
          final quantity = (item['quantity'] as num).toDouble();

          await db.into(db.salesOrderItems).insert(
                SalesOrderItemsCompanion(
                  itemId: Value(itemId),
                  orderId: Value(orderId),
                  lineNo: Value(lineNo),
                  productId: Value(productId),
                  productCode: Value(item['product_code'] as String),
                  productName: Value(item['product_name'] as String),
                  unit: Value(item['unit'] as String),
                  quantity: Value(quantity),
                  unitPrice: Value((item['unit_price'] as num).toDouble()),
                  discountPercent: Value((item['discount_percent'] as num?)?.toDouble() ?? 0),
                  discountAmount: Value((item['discount_amount'] as num?)?.toDouble() ?? 0),
                  amount: Value((item['amount'] as num).toDouble()),
                  warehouseId: Value(warehouseId),
                ),
              );

          final product = await (db.select(db.products)
                ..where((t) => t.productId.equals(productId)))
              .getSingleOrNull();

          if (product != null && product.isStockControl) {
            final movementNo = 'SM-$datePart-$ts-$lineNo';
            await db.into(db.stockMovements).insert(
                  StockMovementsCompanion(
                    movementId: Value(itemId),
                    movementNo: Value(movementNo),
                    movementDate: Value(now),
                    movementType: const Value('SALE'),
                    productId: Value(productId),
                    warehouseId: Value(warehouseId),
                    userId: Value(userId),
                    quantity: Value(-quantity),
                    referenceNo: Value(orderNo),
                    remark: const Value('ขายสินค้า'),
                  ),
                );
            print('✅ Stock movement: $movementNo (-$quantity)');
          }
        }
      });

      print('✅ Transaction committed: $orderNo');

      // ✅ คำนวณและ update loyalty points (นอก transaction เพราะไม่ต้อง rollback)
      final customerId = data['customer_id'] as String?;
      final totalAmount = (data['total_amount'] as num?)?.toDouble() ?? 0;
      int earnedPoints = 0;

      if (customerId != null &&
          customerId != 'WALK_IN' &&
          customerId.isNotEmpty &&
          totalAmount > 0) {
        final customer = await (db.select(db.customers)
              ..where((t) => t.customerId.equals(customerId)))
            .getSingleOrNull();

        // ✅ ได้แต้มเฉพาะลูกค้าที่มี memberNo เท่านั้น
        if (customer != null && customer.memberNo != null) {
          // pointsPerBaht = 100 (ทุก 100 บาท ได้ 1 แต้ม)
          // TODO: ดึงจาก system_settings table เมื่อมีในอนาคต
          const double pointsPerBaht = 100.0;
          earnedPoints = (totalAmount / pointsPerBaht).floor();

          if (earnedPoints > 0) {
            final newPoints = customer.points + earnedPoints;
            await (db.update(db.customers)
                  ..where((t) => t.customerId.equals(customerId)))
                .write(CustomersCompanion(
              points: Value(newPoints),
              updatedAt: Value(DateTime.now()),
            ));
            print('⭐ Points: $customerId +$earnedPoints → $newPoints pts');
          }
        }
      }

      return Response.ok(
        jsonEncode({
          'success': true,
          'message': 'สร้างใบขายสำเร็จ',
          'data': {
            'order_id': orderId,
            'order_no': orderNo,
            'earned_points': earnedPoints, // ✅ แจ้ง client ว่าได้กี่แต้ม
          },
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } on _ValidationException catch (e) {
      // ✅ business validation error → 400 (ไม่ต้อง log stack trace)
      return Response(400,
          body: jsonEncode({'success': false, 'message': e.message}),
          headers: {'Content-Type': 'application/json'});
    } catch (e, stack) {
      print('❌ POST /api/sales error: $e');
      print('Stack trace: $stack');
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': 'เกิดข้อผิดพลาดภายใน กรุณาลองใหม่'}),
      );
    }
  }

  /// Helper: คำนวณสต๊อกปัจจุบันจาก stock_movements (single source of truth)
  Future<double> _getCurrentStock(String productId, String warehouseId) async {
    final result = await db
        .customSelect(
          '''
      SELECT COALESCE(SUM(quantity), 0) as balance
      FROM stock_movements
      WHERE product_id = ? AND warehouse_id = ?
      ''',
          variables: [
            Variable.withString(productId),
            Variable.withString(warehouseId),
          ],
        )
        .getSingle();

    return result.read<double>('balance');
  }

  /// PUT /api/sales/:id - แก้ไขสถานะใบขาย
  Future<Response> _updateSalesOrderHandler(Request request, String id) async {
    try {
      final payload = await request.readAsString();
      final data = jsonDecode(payload) as Map<String, dynamic>;

      await (db.update(
        db.salesOrders,
      )..where((t) => t.orderId.equals(id))).write(
        SalesOrdersCompanion(
          status: Value(data['status'] as String),
          updatedAt: Value(DateTime.now()),
        ),
      );

      return Response.ok(
        jsonEncode({'success': true, 'message': 'แก้ไขใบขายสำเร็จ'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('❌ PUT /api/sales/$id error: $e');
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': 'เกิดข้อผิดพลาดภายใน กรุณาลองใหม่'}),
      );
    }
  }

  /// DELETE /api/sales/:id - ลบใบขาย
  Future<Response> _deleteSalesOrderHandler(Request request, String id) async {
    try {
      // ✅ เฉพาะ ADMIN/MANAGER เท่านั้น
      return roleGuard(request, [AppRoles.admin, AppRoles.manager], () async {
        await (db.delete(db.salesOrderItems)
              ..where((t) => t.orderId.equals(id)))
            .go();
        await (db.delete(db.salesOrders)
              ..where((t) => t.orderId.equals(id)))
            .go();

        return Response.ok(
          jsonEncode({'success': true, 'message': 'ลบใบขายสำเร็จ'}),
          headers: {'Content-Type': 'application/json'},
        );
      });
    } catch (e) {
      print('❌ DELETE /api/sales/$id error: $e');
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': 'เกิดข้อผิดพลาดภายใน กรุณาลองใหม่'}),
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────────
// Internal exception — throw ภายใน transaction เพื่อ rollback
// catch ด้านนอกแปลงเป็น 400 response
// ─────────────────────────────────────────────────────────────────
class _ValidationException implements Exception {
  final String message;
  const _ValidationException(this.message);
}