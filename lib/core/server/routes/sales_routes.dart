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
      final orders = await db.select(db.salesOrders).get();
      
      return Response.ok(jsonEncode({
        'success': true,
        'data': orders.map((o) => {
          'order_id': o.orderId,
          'order_no': o.orderNo,
          'order_date': o.orderDate.toIso8601String(),
          'customer_name': o.customerName,
          'total_amount': o.totalAmount,
          'status': o.status,
        }).toList(),
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
  
  /// GET /api/sales/:id - ดึงใบขาย 1 รายการ
  Future<Response> _getSalesOrderHandler(Request request, String id) async {
    try {
      final order = await (db.select(db.salesOrders)
            ..where((t) => t.orderId.equals(id)))
          .getSingleOrNull();
      
      if (order == null) {
        return Response.notFound(jsonEncode({
          'success': false,
          'message': 'ไม่พบใบขาย',
        }));
      }
      
      // ดึงรายการสินค้า
      final items = await (db.select(db.salesOrderItems)
            ..where((t) => t.orderId.equals(id)))
          .get();
      
      return Response.ok(jsonEncode({
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
          'items': items.map((i) => {
            'product_id': i.productId,
            'product_code': i.productCode,
            'product_name': i.productName,
            'quantity': i.quantity,
            'unit_price': i.unitPrice,
            'amount': i.amount,
          }).toList(),
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
  
  /// POST /api/sales - สร้างใบขายใหม่
  Future<Response> _createSalesOrderHandler(Request request) async {
    try {
      final payload = await request.readAsString();
      final data = jsonDecode(payload) as Map<String, dynamic>;
      
      // Generate Order ID & No
      final orderId = 'SO${DateTime.now().millisecondsSinceEpoch}';
      final orderNo = 'SO-${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
      
      // สร้าง Order Companion
      final orderCompanion = SalesOrdersCompanion(
        orderId: Value(orderId),
        orderNo: Value(orderNo),
        orderDate: Value(DateTime.now()),
        orderType: const Value('SALE'),
        customerId: Value(data['customer_id'] as String?),
        customerName: Value(data['customer_name'] as String?),
        branchId: Value(data['branch_id'] as String? ?? 'BR001'),
        warehouseId: Value(data['warehouse_id'] as String? ?? 'WH001'),
        userId: Value(data['user_id'] as String? ?? 'USR001'),
        subtotal: Value((data['subtotal'] as num?)?.toDouble() ?? 0),
        discountAmount: Value((data['discount_amount'] as num?)?.toDouble() ?? 0),
        amountBeforeVat: Value((data['amount_before_vat'] as num?)?.toDouble() ?? 0),
        vatAmount: Value((data['vat_amount'] as num?)?.toDouble() ?? 0),
        totalAmount: Value((data['total_amount'] as num?)?.toDouble() ?? 0),
        paymentType: Value(data['payment_type'] as String? ?? 'CASH'),
        paidAmount: Value((data['paid_amount'] as num?)?.toDouble() ?? 0),
        changeAmount: Value((data['change_amount'] as num?)?.toDouble() ?? 0),
        status: const Value('COMPLETED'),
      );
      
      await db.into(db.salesOrders).insert(orderCompanion);
      
      // สร้าง Order Items
      final items = data['items'] as List;
      for (var i = 0; i < items.length; i++) {
        final item = items[i] as Map<String, dynamic>;
        final itemId = '${orderId}_${i + 1}';
        
        final itemCompanion = SalesOrderItemsCompanion(
          itemId: Value(itemId),
          orderId: Value(orderId),
          lineNo: Value(i + 1),
          productId: Value(item['product_id'] as String),
          productCode: Value(item['product_code'] as String),
          productName: Value(item['product_name'] as String),
          unit: Value(item['unit'] as String),
          quantity: Value((item['quantity'] as num).toDouble()),
          unitPrice: Value((item['unit_price'] as num).toDouble()),
          discountPercent: Value((item['discount_percent'] as num?)?.toDouble() ?? 0),
          discountAmount: Value((item['discount_amount'] as num?)?.toDouble() ?? 0),
          amount: Value((item['amount'] as num).toDouble()),
          warehouseId: Value(data['warehouse_id'] as String? ?? 'WH001'),
        );
        
        await db.into(db.salesOrderItems).insert(itemCompanion);
      }
      
      return Response.ok(jsonEncode({
        'success': true,
        'message': 'สร้างใบขายสำเร็จ',
        'data': {
          'order_id': orderId,
          'order_no': orderNo,
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
  
  /// PUT /api/sales/:id - แก้ไขใบขาย
  Future<Response> _updateSalesOrderHandler(Request request, String id) async {
    try {
      final payload = await request.readAsString();
      final data = jsonDecode(payload) as Map<String, dynamic>;
      
      await (db.update(db.salesOrders)..where((t) => t.orderId.equals(id)))
          .write(SalesOrdersCompanion(
        status: Value(data['status'] as String),
        updatedAt: Value(DateTime.now()),
      ));
      
      return Response.ok(jsonEncode({
        'success': true,
        'message': 'แก้ไขใบขายสำเร็จ',
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
  
  /// DELETE /api/sales/:id - ลบใบขาย
  Future<Response> _deleteSalesOrderHandler(Request request, String id) async {
    try {
      await (db.delete(db.salesOrderItems)..where((t) => t.orderId.equals(id))).go();
      await (db.delete(db.salesOrders)..where((t) => t.orderId.equals(id))).go();
      
      return Response.ok(jsonEncode({
        'success': true,
        'message': 'ลบใบขายสำเร็จ',
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