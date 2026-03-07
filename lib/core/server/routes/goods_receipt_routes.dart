// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:drift/drift.dart' hide JsonKey;
import '../../database/app_database.dart';

class GoodsReceiptRoutes {
  final AppDatabase db;

  GoodsReceiptRoutes(this.db) {
    print('🔧 GoodsReceiptRoutes initialized');
  }

  Router get router {
    print('🔧 Building GoodsReceiptRoutes router...');

    final router = Router();

    // Goods Receipt routes
    router.get('/', _getGoodsReceiptsHandler);
    router.get('/<id>', _getGoodsReceiptHandler);
    router.post('/', _createGoodsReceiptHandler);
    router.put('/<id>', _updateGoodsReceiptHandler);
    router.delete('/<id>', _deleteGoodsReceiptHandler);

    // Additional routes
    router.post('/<id>/confirm', _confirmGoodsReceiptHandler);

    print('🔧 GoodsReceiptRoutes configured:');
    print('   GET  / → /api/goods-receipts');
    print('   GET  /<id> → /api/goods-receipts/:id');
    print('   POST / → /api/goods-receipts');
    print('   PUT  /<id> → /api/goods-receipts/:id');
    print('   DELETE /<id> → /api/goods-receipts/:id');
    print('   POST /<id>/confirm → /api/goods-receipts/:id/confirm');

    return router;
  }

  /// GET / - ดึงรายการใบรับสินค้าทั้งหมด
  Future<Response> _getGoodsReceiptsHandler(Request request) async {
    try {
      print('📡 GoodsReceiptRoutes: GET /');

      final receipts = await db.select(db.goodsReceipts).get();

      final data = receipts
          .map(
            (gr) => {
              'gr_id': gr.grId,
              'gr_no': gr.grNo,
              'gr_date': gr.grDate.toIso8601String(),
              'po_id': gr.poId,
              'po_no': gr.poNo,
              'supplier_id': gr.supplierId,
              'supplier_name': gr.supplierName,
              'warehouse_id': gr.warehouseId,
              'warehouse_name': gr.warehouseName,
              'user_id': gr.userId,
              'status': gr.status,
              'remark': gr.remark,
              'created_at': gr.createdAt.toIso8601String(),
              'updated_at': gr.updatedAt.toIso8601String(),
            },
          )
          .toList();

      print('✅ GoodsReceiptRoutes: Found ${receipts.length} goods receipts');

      return Response.ok(
        jsonEncode({'success': true, 'data': data}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('❌ GoodsReceiptRoutes: GET / error: $e');
      print('Stack trace: $stack');
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': '$e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// GET /:id - ดึงใบรับสินค้าพร้อมรายการสินค้า
  Future<Response> _getGoodsReceiptHandler(Request request, String id) async {
    try {
      print('📡 GoodsReceiptRoutes: GET /$id');

      // Get goods receipt
      final gr = await (db.select(
        db.goodsReceipts,
      )..where((g) => g.grId.equals(id))).getSingleOrNull();

      if (gr == null) {
        return Response.notFound(
          jsonEncode({'success': false, 'message': 'Goods receipt not found'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // Get items
      final items = await (db.select(
        db.goodsReceiptItems,
      )..where((i) => i.grId.equals(id))).get();

      final data = {
        'gr_id': gr.grId,
        'gr_no': gr.grNo,
        'gr_date': gr.grDate.toIso8601String(),
        'po_id': gr.poId,
        'po_no': gr.poNo,
        'supplier_id': gr.supplierId,
        'supplier_name': gr.supplierName,
        'warehouse_id': gr.warehouseId,
        'warehouse_name': gr.warehouseName,
        'user_id': gr.userId,
        'status': gr.status,
        'remark': gr.remark,
        'created_at': gr.createdAt.toIso8601String(),
        'updated_at': gr.updatedAt.toIso8601String(),
        'items': items
            .map(
              (item) => {
                'item_id': item.itemId,
                'gr_id': item.grId,
                'line_no': item.lineNo,
                'po_item_id': item.poItemId,
                'product_id': item.productId,
                'product_code': item.productCode,
                'product_name': item.productName,
                'unit': item.unit,
                'ordered_quantity': item.orderedQuantity,
                'received_quantity': item.receivedQuantity,
                'unit_price': item.unitPrice,
                'amount': item.amount,
                'lot_number': item.lotNumber,
                'expiry_date': item.expiryDate?.toIso8601String(),
                'remark': item.remark,
              },
            )
            .toList(),
      };

      return Response.ok(
        jsonEncode({'success': true, 'data': data}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('❌ GoodsReceiptRoutes: GET /$id error: $e');
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': '$e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// POST / - สร้างใบรับสินค้าใหม่
  Future<Response> _createGoodsReceiptHandler(Request request) async {
    try {
      print('📡 GoodsReceiptRoutes: POST /');

      final payload = await request.readAsString();
      final data = jsonDecode(payload) as Map<String, dynamic>;

      // Generate GR ID and Number
      final grId = 'GR${DateTime.now().millisecondsSinceEpoch}';
      final grNo =
          'GR${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';

      // Create goods receipt
      final grCompanion = GoodsReceiptsCompanion(
        grId: Value(grId),
        grNo: Value(grNo),
        grDate: Value(DateTime.parse(data['gr_date'] as String)),
        poId: Value(data['po_id'] as String?),
        poNo: Value(data['po_no'] as String?),
        supplierId: Value(data['supplier_id'] as String),
        supplierName: Value(data['supplier_name'] as String),
        warehouseId: Value(data['warehouse_id'] as String),
        warehouseName: Value(data['warehouse_name'] as String),
        userId: Value(data['user_id'] as String),
        status: Value(data['status'] as String? ?? 'DRAFT'),
        remark: Value(data['remark'] as String?),
      );

      await db.into(db.goodsReceipts).insert(grCompanion);

      // Create items
      if (data['items'] != null) {
        final items = data['items'] as List;
        for (var i = 0; i < items.length; i++) {
          final item = items[i] as Map<String, dynamic>;
          final itemId = 'GRI${DateTime.now().millisecondsSinceEpoch}$i';

          final itemCompanion = GoodsReceiptItemsCompanion(
            itemId: Value(itemId),
            grId: Value(grId),
            lineNo: Value(i + 1),
            poItemId: Value(item['po_item_id'] as String?),
            productId: Value(item['product_id'] as String),
            productCode: Value(item['product_code'] as String),
            productName: Value(item['product_name'] as String),
            unit: Value(item['unit'] as String),
            orderedQuantity: Value(
              (item['ordered_quantity'] as num?)?.toDouble() ?? 0,
            ),
            receivedQuantity: Value(
              (item['received_quantity'] as num).toDouble(),
            ),
            unitPrice: Value((item['unit_price'] as num?)?.toDouble() ?? 0),
            amount: Value((item['amount'] as num?)?.toDouble() ?? 0),
            lotNumber: Value(item['lot_number'] as String?),
            expiryDate: item['expiry_date'] != null
                ? Value(DateTime.parse(item['expiry_date'] as String))
                : const Value.absent(),
            remark: Value(item['remark'] as String?),
          );

          await db.into(db.goodsReceiptItems).insert(itemCompanion);
        }
      }

      print('✅ GoodsReceiptRoutes: Created goods receipt: $grId');

      return Response.ok(
        jsonEncode({
          'success': true,
          'message': 'Goods receipt created',
          'data': {'gr_id': grId, 'gr_no': grNo},
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('❌ GoodsReceiptRoutes: POST / error: $e');
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': '$e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// PUT /:id - แก้ไขใบรับสินค้า
  Future<Response> _updateGoodsReceiptHandler(
    Request request,
    String id,
  ) async {
    try {
      print('📡 GoodsReceiptRoutes: PUT /$id');

      final payload = await request.readAsString();
      final data = jsonDecode(payload) as Map<String, dynamic>;

      final companion = GoodsReceiptsCompanion(
        grDate: Value(DateTime.parse(data['gr_date'] as String)),
        remark: Value(data['remark'] as String?),
        updatedAt: Value(DateTime.now()),
      );

      await (db.update(
        db.goodsReceipts,
      )..where((g) => g.grId.equals(id))).write(companion);

      print('✅ GoodsReceiptRoutes: Updated goods receipt: $id');

      return Response.ok(
        jsonEncode({'success': true, 'message': 'Goods receipt updated'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('❌ GoodsReceiptRoutes: PUT /$id error: $e');
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': '$e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// DELETE /:id - ลบใบรับสินค้า
  Future<Response> _deleteGoodsReceiptHandler(
    Request request,
    String id,
  ) async {
    try {
      print('📡 GoodsReceiptRoutes: DELETE /$id');

      // Delete items first
      await (db.delete(
        db.goodsReceiptItems,
      )..where((i) => i.grId.equals(id))).go();

      // Delete goods receipt
      await (db.delete(db.goodsReceipts)..where((g) => g.grId.equals(id))).go();

      print('✅ GoodsReceiptRoutes: Deleted goods receipt: $id');

      return Response.ok(
        jsonEncode({'success': true, 'message': 'Goods receipt deleted'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('❌ GoodsReceiptRoutes: DELETE /$id error: $e');
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': '$e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// POST /:id/confirm - ยืนยันใบรับสินค้า (บันทึกเข้าสต๊อก)
  Future<Response> _confirmGoodsReceiptHandler(
    Request request,
    String id,
  ) async {
    try {
      print('📡 GoodsReceiptRoutes: POST /$id/confirm');

      // Get goods receipt
      final gr = await (db.select(
        db.goodsReceipts,
      )..where((g) => g.grId.equals(id))).getSingleOrNull();

      if (gr == null) {
        return Response.notFound(
          jsonEncode({'success': false, 'message': 'Goods receipt not found'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // Get items
      final items = await (db.select(
        db.goodsReceiptItems,
      )..where((i) => i.grId.equals(id))).get();

      // Create stock movements for each item
      for (var item in items) {
        final movementId =
            'STK${DateTime.now().millisecondsSinceEpoch}${item.lineNo}';
        final movementNo = 'GR-${gr.grNo}';

        final stockMovement = StockMovementsCompanion(
          movementId: Value(movementId),
          movementNo: Value(movementNo),
          movementDate: Value(gr.grDate),
          movementType: const Value('GR'),
          productId: Value(item.productId),
          warehouseId: Value(gr.warehouseId),
          userId: Value(gr.userId),
          quantity: Value(item.receivedQuantity),
          referenceNo: Value(gr.grNo),
          remark: Value('รับสินค้าจาก ${gr.supplierName}'),
        );

        await db.into(db.stockMovements).insert(stockMovement);

        // Update or create stock balance
        final existingBalance =
            await (db.select(db.stockBalances)
                  ..where((s) => s.productId.equals(item.productId))
                  ..where((s) => s.warehouseId.equals(gr.warehouseId)))
                .getSingleOrNull();

        if (existingBalance != null) {
          // Update existing balance - ใช้ stockId
          final newBalance = existingBalance.quantity + item.receivedQuantity;
          await (db.update(
            db.stockBalances,
          )..where((s) => s.stockId.equals(existingBalance.stockId))).write(
            StockBalancesCompanion(
              quantity: Value(newBalance),
              updatedAt: Value(DateTime.now()),
            ),
          );
        } else {
          // Create new balance - ต้องมี stockId
          final stockId =
              'STK${DateTime.now().millisecondsSinceEpoch}${item.lineNo}';
          await db
              .into(db.stockBalances)
              .insert(
                StockBalancesCompanion(
                  stockId: Value(stockId),
                  productId: Value(item.productId),
                  warehouseId: Value(gr.warehouseId),
                  quantity: Value(item.receivedQuantity),
                ),
              );
        }
      }

      // Update goods receipt status
      await (db.update(
        db.goodsReceipts,
      )..where((g) => g.grId.equals(id))).write(
        const GoodsReceiptsCompanion(
          status: Value('CONFIRMED'),
          updatedAt: Value.absent(),
        ),
      );

      // Update PO item received quantities if linked to PO
      if (gr.poId != null) {
        for (var item in items) {
          if (item.poItemId != null) {
            final poItem = await (db.select(
              db.purchaseOrderItems,
            )..where((i) => i.itemId.equals(item.poItemId!))).getSingleOrNull();

            if (poItem != null) {
              final newReceivedQty =
                  poItem.receivedQuantity + item.receivedQuantity;
              final newRemainingQty = poItem.quantity - newReceivedQty;

              await (db.update(
                db.purchaseOrderItems,
              )..where((i) => i.itemId.equals(item.poItemId!))).write(
                PurchaseOrderItemsCompanion(
                  receivedQuantity: Value(newReceivedQty),
                  remainingQuantity: Value(
                    newRemainingQty > 0 ? newRemainingQty : 0,
                  ),
                ),
              );
            }
          }
        }

        // Check if all PO items are fully received
        final poItems = await (db.select(
          db.purchaseOrderItems,
        )..where((i) => i.poId.equals(gr.poId!))).get();

        final allReceived = poItems.every(
          (item) => item.remainingQuantity <= 0,
        );

        // Update PO status
        await (db.update(
          db.purchaseOrders,
        )..where((p) => p.poId.equals(gr.poId!))).write(
          PurchaseOrdersCompanion(
            status: Value(allReceived ? 'COMPLETED' : 'PARTIAL'),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }

      print('✅ GoodsReceiptRoutes: Confirmed goods receipt: $id');

      return Response.ok(
        jsonEncode({
          'success': true,
          'message': 'Goods receipt confirmed and stock updated',
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('❌ GoodsReceiptRoutes: POST /$id/confirm error: $e');
      print('Stack trace: $stack');
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': '$e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }
}
