// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:drift/drift.dart' hide JsonKey;
import '../../database/app_database.dart';

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

      // ดึงรายการสินค้า
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
      print('📡 POST /api/sales');

      final payload = await request.readAsString();
      print('📦 Payload: $payload');

      final data = jsonDecode(payload) as Map<String, dynamic>;
      print('✅ Parsed data: $data');

      // ✅ ตรวจสอบข้อมูลที่จำเป็น
      if (data['items'] == null || (data['items'] as List).isEmpty) {
        print('❌ Error: No items in order');
        return Response(
          400,
          body: jsonEncode({'success': false, 'message': 'ไม่มีรายการสินค้า'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // ✅ ใช้ timestamp เดียวตลอด request เพื่อความ consistent และ unique
      final ts = DateTime.now().millisecondsSinceEpoch;
      final now = DateTime.fromMillisecondsSinceEpoch(ts);
      final datePart =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';

      final orderId = 'SO$ts';
      final orderNo = 'SO-$datePart-$ts';
      final warehouseId = data['warehouse_id'] as String? ?? 'WH001';

      print('🆔 Generated order: $orderNo');

      // เช็คสต๊อกก่อนขาย
      final items = data['items'] as List;
      for (var item in items) {
        final productId = item['product_id'] as String;
        final quantity = (item['quantity'] as num).toDouble();

        print('🔍 Checking stock for $productId: $quantity');

        final product = await (db.select(
          db.products,
        )..where((t) => t.productId.equals(productId))).getSingleOrNull();

        if (product == null) {
          print('❌ Product not found: $productId');
          return Response(
            400,
            body: jsonEncode({
              'success': false,
              'message': 'ไม่พบสินค้า $productId',
            }),
            headers: {'Content-Type': 'application/json'},
          );
        }

        if (product.isStockControl) {
          final currentStock = await _getCurrentStock(productId, warehouseId);
          print('📊 Current stock: $currentStock');

          if (!product.allowNegativeStock && currentStock < quantity) {
            print('❌ Insufficient stock');
            return Response(
              400,
              body: jsonEncode({
                'success': false,
                'message':
                    'สต๊อกสินค้า ${product.productName} ไม่เพียงพอ (คงเหลือ: $currentStock)',
              }),
              headers: {'Content-Type': 'application/json'},
            );
          }
        }
      }

      // สร้าง Order
      print('💾 Creating order...');

      final orderCompanion = SalesOrdersCompanion(
        orderId: Value(orderId),
        orderNo: Value(orderNo),
        orderDate: Value(now),
        orderType: const Value('SALE'),
        customerId: Value(data['customer_id'] as String?),
        customerName: Value(data['customer_name'] as String?),
        branchId: Value(data['branch_id'] as String? ?? 'BR001'),
        warehouseId: Value(warehouseId),
        userId: Value(data['user_id'] as String? ?? 'USR001'),
        subtotal: Value((data['subtotal'] as num?)?.toDouble() ?? 0),
        discountAmount: Value(
          (data['discount_amount'] as num?)?.toDouble() ?? 0,
        ),
        amountBeforeVat: Value(
          (data['amount_before_vat'] as num?)?.toDouble() ?? 0,
        ),
        vatAmount: Value((data['vat_amount'] as num?)?.toDouble() ?? 0),
        totalAmount: Value((data['total_amount'] as num?)?.toDouble() ?? 0),
        paymentType: Value(data['payment_type'] as String? ?? 'CASH'),
        paidAmount: Value((data['paid_amount'] as num?)?.toDouble() ?? 0),
        changeAmount: Value((data['change_amount'] as num?)?.toDouble() ?? 0),
        status: const Value('COMPLETED'),
      );

      await db.into(db.salesOrders).insert(orderCompanion);
      print('✅ Order created');

      // สร้าง Order Items และตัดสต๊อก
      print('💾 Creating order items...');

      for (var i = 0; i < items.length; i++) {
        final item = items[i] as Map<String, dynamic>;
        final lineNo = i + 1;
        final itemId = '${orderId}_$lineNo';
        final productId = item['product_id'] as String;
        final quantity = (item['quantity'] as num).toDouble();

        // สร้าง Order Item
        final itemCompanion = SalesOrderItemsCompanion(
          itemId: Value(itemId),
          orderId: Value(orderId),
          lineNo: Value(lineNo),
          productId: Value(productId),
          productCode: Value(item['product_code'] as String),
          productName: Value(item['product_name'] as String),
          unit: Value(item['unit'] as String),
          quantity: Value(quantity),
          unitPrice: Value((item['unit_price'] as num).toDouble()),
          discountPercent: Value(
            (item['discount_percent'] as num?)?.toDouble() ?? 0,
          ),
          discountAmount: Value(
            (item['discount_amount'] as num?)?.toDouble() ?? 0,
          ),
          amount: Value((item['amount'] as num).toDouble()),
          warehouseId: Value(warehouseId),
        );

        await db.into(db.salesOrderItems).insert(itemCompanion);

        // ตัดสต๊อกอัตโนมัติ
        final product = await (db.select(
          db.products,
        )..where((t) => t.productId.equals(productId))).getSingleOrNull();

        if (product != null && product.isStockControl) {
          // ✅ movementId ใช้ itemId (unique อยู่แล้ว)
          // ✅ movementNo = SM-{date}-{ts}-{lineNo} → unique ทุก row ทุก order
          final movementNo = 'SM-$datePart-$ts-$lineNo';

          await db.into(db.stockMovements).insert(
                StockMovementsCompanion(
                  movementId: Value(itemId),
                  movementNo: Value(movementNo),
                  movementDate: Value(now),
                  movementType: const Value('SALE'),
                  productId: Value(productId),
                  warehouseId: Value(warehouseId),
                  userId: Value(data['user_id'] as String? ?? 'USR001'),
                  quantity: Value(-quantity),
                  referenceNo: Value(orderNo),
                  remark: const Value('ขายสินค้า'),
                ),
              );

          print('✅ Stock movement: $movementNo');
        }
      }

      print('✅ Created order: $orderNo');

      return Response.ok(
        jsonEncode({
          'success': true,
          'message': 'สร้างใบขายสำเร็จ',
          'data': {'order_id': orderId, 'order_no': orderNo},
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('❌ POST /api/sales error: $e');
      print('Stack trace: $stack');

      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': 'เกิดข้อผิดพลาด: $e'}),
      );
    }
  }

  /// Helper: คำนวณสต๊อกปัจจุบัน
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

  /// PUT /api/sales/:id - แก้ไขใบขาย
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
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': 'เกิดข้อผิดพลาด: $e'}),
      );
    }
  }

  /// DELETE /api/sales/:id - ลบใบขาย
  Future<Response> _deleteSalesOrderHandler(Request request, String id) async {
    try {
      await (db.delete(
        db.salesOrderItems,
      )..where((t) => t.orderId.equals(id))).go();
      await (db.delete(
        db.salesOrders,
      )..where((t) => t.orderId.equals(id))).go();

      return Response.ok(
        jsonEncode({'success': true, 'message': 'ลบใบขายสำเร็จ'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': 'เกิดข้อผิดพลาด: $e'}),
      );
    }
  }
}