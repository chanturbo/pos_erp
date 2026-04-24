
import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:drift/drift.dart' hide JsonKey;
import '../../database/app_database.dart';
import 'package:flutter/foundation.dart';

class PurchaseRoutes {
  final AppDatabase db;

  PurchaseRoutes(this.db) {
    if (kDebugMode) {
      debugPrint('🔧 PurchaseRoutes initialized');
    }
  }

  Router get router {
    if (kDebugMode) {
      debugPrint('🔧 Building PurchaseRoutes router...');
    }
    
    final router = Router();

    // Purchase Order routes
    router.get('/', _getPurchaseOrdersHandler);
    router.get('/<id>', _getPurchaseOrderHandler);
    router.post('/', _createPurchaseOrderHandler);
    router.put('/<id>', _updatePurchaseOrderHandler);
    router.delete('/<id>', _deletePurchaseOrderHandler);
    
    // Additional routes
    router.post('/<id>/approve', _approvePurchaseOrderHandler);
    router.post('/<id>/receive', _receivePurchaseOrderHandler);

    if (kDebugMode) {
      debugPrint('🔧 PurchaseRoutes configured:');
    }
    if (kDebugMode) {
      debugPrint('   GET  / → /api/purchases');
    }
    if (kDebugMode) {
      debugPrint('   GET  /<id> → /api/purchases/:id');
    }
    if (kDebugMode) {
      debugPrint('   POST / → /api/purchases');
    }
    if (kDebugMode) {
      debugPrint('   PUT  /<id> → /api/purchases/:id');
    }
    if (kDebugMode) {
      debugPrint('   DELETE /<id> → /api/purchases/:id');
    }
    if (kDebugMode) {
      debugPrint('   POST /<id>/approve → /api/purchases/:id/approve');
    }
    if (kDebugMode) {
      debugPrint('   POST /<id>/receive → /api/purchases/:id/receive');
    }

    return router;
  }

  /// GET / - ดึงรายการใบสั่งซื้อทั้งหมด
  Future<Response> _getPurchaseOrdersHandler(Request request) async {
    try {
      if (kDebugMode) {
        debugPrint('📡 PurchaseRoutes: GET /');
      }

      final orders = await db.select(db.purchaseOrders).get();

      final data = orders.map((po) => {
            'po_id': po.poId,
            'po_no': po.poNo,
            'po_date': po.poDate.toIso8601String(),
            'supplier_id': po.supplierId,
            'supplier_name': po.supplierName,
            'warehouse_id': po.warehouseId,
            'warehouse_name': po.warehouseName,
            'user_id': po.userId,
            'subtotal': po.subtotal,
            'discount_amount': po.discountAmount,
            'vat_amount': po.vatAmount,
            'total_amount': po.totalAmount,
            'status': po.status,
            'payment_status': po.paymentStatus,
            'delivery_date': po.deliveryDate?.toIso8601String(),
            'remark': po.remark,
            'created_at': po.createdAt.toIso8601String(),
            'updated_at': po.updatedAt.toIso8601String(),
          }).toList();

      if (kDebugMode) {
        debugPrint('✅ PurchaseRoutes: Found ${orders.length} purchase orders');
      }

      return Response.ok(
        jsonEncode({'success': true, 'data': data}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('❌ PurchaseRoutes: GET / error: $e');
      }
      if (kDebugMode) {
        debugPrint('Stack trace: $stack');
      }
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': '$e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// GET /:id - ดึงใบสั่งซื้อพร้อมรายการสินค้า
  Future<Response> _getPurchaseOrderHandler(Request request, String id) async {
    try {
      if (kDebugMode) {
        debugPrint('📡 PurchaseRoutes: GET /$id');
      }

      // Get purchase order
      final po = await (db.select(db.purchaseOrders)
            ..where((p) => p.poId.equals(id)))
          .getSingleOrNull();

      if (po == null) {
        return Response.notFound(
          jsonEncode({'success': false, 'message': 'Purchase order not found'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // Get items
      final items = await (db.select(db.purchaseOrderItems)
            ..where((i) => i.poId.equals(id)))
          .get();

      final data = {
        'po_id': po.poId,
        'po_no': po.poNo,
        'po_date': po.poDate.toIso8601String(),
        'supplier_id': po.supplierId,
        'supplier_name': po.supplierName,
        'warehouse_id': po.warehouseId,
        'warehouse_name': po.warehouseName,
        'user_id': po.userId,
        'subtotal': po.subtotal,
        'discount_amount': po.discountAmount,
        'vat_amount': po.vatAmount,
        'total_amount': po.totalAmount,
        'status': po.status,
        'payment_status': po.paymentStatus,
        'delivery_date': po.deliveryDate?.toIso8601String(),
        'remark': po.remark,
        'created_at': po.createdAt.toIso8601String(),
        'updated_at': po.updatedAt.toIso8601String(),
        'items': items.map((item) => {
              'item_id': item.itemId,
              'po_id': item.poId,
              'line_no': item.lineNo,
              'product_id': item.productId,
              'product_code': item.productCode,
              'product_name': item.productName,
              'unit': item.unit,
              'quantity': item.quantity,
              'unit_price': item.unitPrice,
              'discount_percent': item.discountPercent,
              'discount_amount': item.discountAmount,
              'amount': item.amount,
              'received_quantity': item.receivedQuantity,
              'remaining_quantity': item.remainingQuantity,
            }).toList(),
      };

      return Response.ok(
        jsonEncode({'success': true, 'data': data}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ PurchaseRoutes: GET /$id error: $e');
      }
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': '$e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// POST / - สร้างใบสั่งซื้อใหม่
  Future<Response> _createPurchaseOrderHandler(Request request) async {
    try {
      if (kDebugMode) {
        debugPrint('📡 PurchaseRoutes: POST /');
      }

      final payload = await request.readAsString();
      final data = jsonDecode(payload) as Map<String, dynamic>;

      // Generate PO ID and Number
      final poId = 'PO${DateTime.now().millisecondsSinceEpoch}';
      final poNo = 'PO${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';

      // Create purchase order
      final poCompanion = PurchaseOrdersCompanion(
        poId: Value(poId),
        poNo: Value(poNo),
        poDate: Value(DateTime.parse(data['po_date'] as String)),
        supplierId: Value(data['supplier_id'] as String),
        supplierName: Value(data['supplier_name'] as String),
        warehouseId: Value(data['warehouse_id'] as String),
        warehouseName: Value(data['warehouse_name'] as String),
        userId: Value(data['user_id'] as String),
        subtotal: Value((data['subtotal'] as num?)?.toDouble() ?? 0),
        discountAmount: Value((data['discount_amount'] as num?)?.toDouble() ?? 0),
        vatAmount: Value((data['vat_amount'] as num?)?.toDouble() ?? 0),
        totalAmount: Value((data['total_amount'] as num?)?.toDouble() ?? 0),
        status: Value(data['status'] as String? ?? 'DRAFT'),
        paymentStatus: Value(data['payment_status'] as String? ?? 'UNPAID'),
        deliveryDate: data['delivery_date'] != null
            ? Value(DateTime.parse(data['delivery_date'] as String))
            : const Value.absent(),
        remark: Value(data['remark'] as String?),
      );

      await db.into(db.purchaseOrders).insert(poCompanion);

      // Create items
      if (data['items'] != null) {
        final items = data['items'] as List;
        for (var i = 0; i < items.length; i++) {
          final item = items[i] as Map<String, dynamic>;
          final itemId = 'POI${DateTime.now().millisecondsSinceEpoch}$i';

          final itemCompanion = PurchaseOrderItemsCompanion(
            itemId: Value(itemId),
            poId: Value(poId),
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
            receivedQuantity: const Value(0),
            remainingQuantity: Value((item['quantity'] as num).toDouble()),
          );

          await db.into(db.purchaseOrderItems).insert(itemCompanion);
        }
      }

      if (kDebugMode) {
        debugPrint('✅ PurchaseRoutes: Created purchase order: $poId');
      }

      return Response.ok(
        jsonEncode({
          'success': true,
          'message': 'Purchase order created',
          'data': {'po_id': poId, 'po_no': poNo}
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ PurchaseRoutes: POST / error: $e');
      }
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': '$e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// PUT /:id - แก้ไขใบสั่งซื้อ
  Future<Response> _updatePurchaseOrderHandler(Request request, String id) async {
    try {
      if (kDebugMode) {
        debugPrint('📡 PurchaseRoutes: PUT /$id');
      }

      final payload = await request.readAsString();
      final data = jsonDecode(payload) as Map<String, dynamic>;

      final companion = PurchaseOrdersCompanion(
        poDate: Value(DateTime.parse(data['po_date'] as String)),
        supplierId: Value(data['supplier_id'] as String),
        supplierName: Value(data['supplier_name'] as String),
        warehouseId: Value(data['warehouse_id'] as String),
        warehouseName: Value(data['warehouse_name'] as String),
        subtotal: Value((data['subtotal'] as num?)?.toDouble() ?? 0),
        discountAmount: Value((data['discount_amount'] as num?)?.toDouble() ?? 0),
        vatAmount: Value((data['vat_amount'] as num?)?.toDouble() ?? 0),
        totalAmount: Value((data['total_amount'] as num?)?.toDouble() ?? 0),
        status: Value(data['status'] as String? ?? 'DRAFT'),
        paymentStatus: Value(data['payment_status'] as String? ?? 'UNPAID'),
        deliveryDate: data['delivery_date'] != null
            ? Value(DateTime.parse(data['delivery_date'] as String))
            : const Value.absent(),
        remark: Value(data['remark'] as String?),
        updatedAt: Value(DateTime.now()),
      );

      await (db.update(db.purchaseOrders)..where((p) => p.poId.equals(id)))
          .write(companion);

      if (kDebugMode) {
        debugPrint('✅ PurchaseRoutes: Updated purchase order: $id');
      }

      return Response.ok(
        jsonEncode({'success': true, 'message': 'Purchase order updated'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ PurchaseRoutes: PUT /$id error: $e');
      }
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': '$e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// DELETE /:id - ลบใบสั่งซื้อ
  Future<Response> _deletePurchaseOrderHandler(Request request, String id) async {
    try {
      if (kDebugMode) {
        debugPrint('📡 PurchaseRoutes: DELETE /$id');
      }

      // Delete items first
      await (db.delete(db.purchaseOrderItems)..where((i) => i.poId.equals(id)))
          .go();

      // Delete purchase order
      await (db.delete(db.purchaseOrders)..where((p) => p.poId.equals(id)))
          .go();

      if (kDebugMode) {
        debugPrint('✅ PurchaseRoutes: Deleted purchase order: $id');
      }

      return Response.ok(
        jsonEncode({'success': true, 'message': 'Purchase order deleted'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ PurchaseRoutes: DELETE /$id error: $e');
      }
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': '$e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// POST /:id/approve - อนุมัติใบสั่งซื้อ
  Future<Response> _approvePurchaseOrderHandler(Request request, String id) async {
    try {
      if (kDebugMode) {
        debugPrint('📡 PurchaseRoutes: POST /$id/approve');
      }

      await (db.update(db.purchaseOrders)..where((p) => p.poId.equals(id)))
          .write(const PurchaseOrdersCompanion(
            status: Value('APPROVED'),
            updatedAt: Value.absent(),
          ));

      if (kDebugMode) {
        debugPrint('✅ PurchaseRoutes: Approved purchase order: $id');
      }

      return Response.ok(
        jsonEncode({'success': true, 'message': 'Purchase order approved'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ PurchaseRoutes: POST /$id/approve error: $e');
      }
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': '$e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// POST /:id/receive - รับสินค้า
  Future<Response> _receivePurchaseOrderHandler(Request request, String id) async {
    try {
      if (kDebugMode) {
        debugPrint('📡 PurchaseRoutes: POST /$id/receive');
      }

      final payload = await request.readAsString();
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final receivedItems = data['items'] as List;

      // Update received quantities
      for (var item in receivedItems) {
        final itemId = item['item_id'] as String;
        final receivedQty = (item['received_quantity'] as num).toDouble();

        // Get current item
        final currentItem = await (db.select(db.purchaseOrderItems)
              ..where((i) => i.itemId.equals(itemId)))
            .getSingleOrNull();

        if (currentItem != null) {
          final newReceivedQty = currentItem.receivedQuantity + receivedQty;
          final newRemainingQty = currentItem.quantity - newReceivedQty;

          await (db.update(db.purchaseOrderItems)
                ..where((i) => i.itemId.equals(itemId)))
              .write(PurchaseOrderItemsCompanion(
            receivedQuantity: Value(newReceivedQty),
            remainingQuantity: Value(newRemainingQty > 0 ? newRemainingQty : 0),
          ));
        }
      }

      // Check if all items are fully received
      final items = await (db.select(db.purchaseOrderItems)
            ..where((i) => i.poId.equals(id)))
          .get();

      final allReceived = items.every((item) => item.remainingQuantity <= 0);

      // Update PO status
      await (db.update(db.purchaseOrders)..where((p) => p.poId.equals(id)))
          .write(PurchaseOrdersCompanion(
            status: Value(allReceived ? 'COMPLETED' : 'PARTIAL'),
            updatedAt: Value(DateTime.now()),
          ));

      if (kDebugMode) {
        debugPrint('✅ PurchaseRoutes: Received items for PO: $id');
      }

      return Response.ok(
        jsonEncode({
          'success': true,
          'message': 'Items received',
          'data': {'all_received': allReceived}
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ PurchaseRoutes: POST /$id/receive error: $e');
      }
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': '$e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }
}