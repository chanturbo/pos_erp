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

    router.get('/', _getGoodsReceiptsHandler);
    router.get('/<id>', _getGoodsReceiptHandler);
    router.post('/', _createGoodsReceiptHandler);
    router.put('/<id>', _updateGoodsReceiptHandler);
    router.delete('/<id>', _deleteGoodsReceiptHandler);
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

      // JOIN กับ COUNT items เพื่อไม่ต้องโหลด items ทั้งหมด
      final rows = await db.customSelect('''
        SELECT
          gr.*,
          COUNT(gi.item_id) AS item_count
        FROM goods_receipts gr
        LEFT JOIN goods_receipt_items gi ON gi.gr_id = gr.gr_id
        GROUP BY gr.gr_id
        ORDER BY gr.gr_date DESC, gr.created_at DESC
      ''').get();

      final data = rows
          .map(
            (row) => {
              'gr_id': row.read<String>('gr_id'),
              'gr_no': row.read<String>('gr_no'),
              'gr_date': row.read<DateTime>('gr_date').toIso8601String(),
              'po_id': row.readNullable<String>('po_id'),
              'po_no': row.readNullable<String>('po_no'),
              'supplier_id': row.read<String>('supplier_id'),
              'supplier_name': row.read<String>('supplier_name'),
              'warehouse_id': row.read<String>('warehouse_id'),
              'warehouse_name': row.read<String>('warehouse_name'),
              'user_id': row.read<String>('user_id'),
              'status': row.read<String>('status'),
              'remark': row.readNullable<String>('remark'),
              'created_at': row.read<DateTime>('created_at').toIso8601String(),
              'updated_at': row.read<DateTime>('updated_at').toIso8601String(),
              'item_count': row.read<int>('item_count'),
            },
          )
          .toList();

      print('✅ GoodsReceiptRoutes: Found ${rows.length} goods receipts');

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

      final gr = await (db.select(
        db.goodsReceipts,
      )..where((g) => g.grId.equals(id))).getSingleOrNull();

      if (gr == null) {
        return Response.notFound(
          jsonEncode({'success': false, 'message': 'Goods receipt not found'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

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

  /// POST / - สร้างใบรับสินค้าใหม่ (DRAFT)
  Future<Response> _createGoodsReceiptHandler(Request request) async {
    try {
      print('📡 GoodsReceiptRoutes: POST /');

      final payload = await request.readAsString();
      final data = jsonDecode(payload) as Map<String, dynamic>;

      final ts = DateTime.now().millisecondsSinceEpoch;
      final now = DateTime.fromMillisecondsSinceEpoch(ts);

      final grId = 'GR$ts';
      final grNo =
          'GR${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${ts.toString().substring(8)}';

      // ─────────────────────────────────────────────────────────────
      // สร้าง GR header + items ใน transaction เดียว
      // ─────────────────────────────────────────────────────────────
      await db.transaction(() async {
        await db.into(db.goodsReceipts).insert(
              GoodsReceiptsCompanion(
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
              ),
            );

        if (data['items'] != null) {
          final items = data['items'] as List;
          for (var i = 0; i < items.length; i++) {
            final item = items[i] as Map<String, dynamic>;
            final itemId = 'GRI$ts$i';

            await db.into(db.goodsReceiptItems).insert(
                  GoodsReceiptItemsCompanion(
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
                    unitPrice: Value(
                      (item['unit_price'] as num?)?.toDouble() ?? 0,
                    ),
                    amount: Value((item['amount'] as num?)?.toDouble() ?? 0),
                    lotNumber: Value(item['lot_number'] as String?),
                    expiryDate: item['expiry_date'] != null
                        ? Value(DateTime.parse(item['expiry_date'] as String))
                        : const Value.absent(),
                    remark: Value(item['remark'] as String?),
                  ),
                );
          }
        }
      });

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

  /// PUT /:id - แก้ไขใบรับสินค้า (DRAFT เท่านั้น)
  Future<Response> _updateGoodsReceiptHandler(
    Request request,
    String id,
  ) async {
    try {
      print('📡 GoodsReceiptRoutes: PUT /$id');

      // ✅ ป้องกันแก้ไขหลัง confirm แล้ว
      final gr = await (db.select(
        db.goodsReceipts,
      )..where((g) => g.grId.equals(id))).getSingleOrNull();

      if (gr == null) {
        return Response.notFound(
          jsonEncode({'success': false, 'message': 'Goods receipt not found'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      if (gr.status == 'CONFIRMED') {
        return Response(
          400,
          body: jsonEncode({
            'success': false,
            'message': 'ไม่สามารถแก้ไขใบรับสินค้าที่ยืนยันแล้ว',
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final payload = await request.readAsString();
      final data = jsonDecode(payload) as Map<String, dynamic>;

      await (db.update(
        db.goodsReceipts,
      )..where((g) => g.grId.equals(id))).write(
        GoodsReceiptsCompanion(
          grDate: Value(DateTime.parse(data['gr_date'] as String)),
          remark: Value(data['remark'] as String?),
          updatedAt: Value(DateTime.now()),
        ),
      );

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

  /// DELETE /:id - ลบใบรับสินค้า (DRAFT เท่านั้น)
  Future<Response> _deleteGoodsReceiptHandler(
    Request request,
    String id,
  ) async {
    try {
      print('📡 GoodsReceiptRoutes: DELETE /$id');

      final gr = await (db.select(
        db.goodsReceipts,
      )..where((g) => g.grId.equals(id))).getSingleOrNull();

      if (gr == null) {
        return Response.notFound(
          jsonEncode({'success': false, 'message': 'Goods receipt not found'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // ✅ ป้องกันลบหลัง confirm แล้ว
      if (gr.status == 'CONFIRMED') {
        return Response(
          400,
          body: jsonEncode({
            'success': false,
            'message': 'ไม่สามารถลบใบรับสินค้าที่ยืนยันแล้ว',
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      await (db.delete(
        db.goodsReceiptItems,
      )..where((i) => i.grId.equals(id))).go();

      await (db.delete(
        db.goodsReceipts,
      )..where((g) => g.grId.equals(id))).go();

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

      final gr = await (db.select(
        db.goodsReceipts,
      )..where((g) => g.grId.equals(id))).getSingleOrNull();

      if (gr == null) {
        return Response.notFound(
          jsonEncode({'success': false, 'message': 'Goods receipt not found'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // ✅ Guard: ป้องกัน double confirm → สต๊อกถูกเพิ่มสองรอบ
      if (gr.status == 'CONFIRMED') {
        return Response(
          400,
          body: jsonEncode({
            'success': false,
            'message': 'ใบรับสินค้านี้ยืนยันแล้ว ไม่สามารถยืนยันซ้ำได้',
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final items = await (db.select(
        db.goodsReceiptItems,
      )..where((i) => i.grId.equals(id))).get();

      if (items.isEmpty) {
        return Response(
          400,
          body: jsonEncode({
            'success': false,
            'message': 'ไม่มีรายการสินค้าในใบรับสินค้า',
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final ts = DateTime.now().millisecondsSinceEpoch;

      // ─────────────────────────────────────────────────────────────
      // ทุก operation ใน transaction เดียว:
      // 1) insert stock_movements ทุกรายการ
      // 2) upsert stock_balances (quantity + weighted avg_cost)
      // 3) update สถานะ GR → CONFIRMED
      // 4) update PO item quantities (ถ้ามี)
      // 5) update PO status (ถ้ามี)
      // ─────────────────────────────────────────────────────────────
      await db.transaction(() async {
        // --- 1) บันทึก stock movements (source of truth) ---
        for (var item in items) {
          final movementId = 'GRM${ts}_${item.lineNo}';
          final movementNo = 'GR-${gr.grNo}-${item.lineNo}';

          await db.into(db.stockMovements).insert(
                StockMovementsCompanion(
                  movementId: Value(movementId),
                  movementNo: Value(movementNo),
                  movementDate: Value(gr.grDate),
                  movementType: const Value('GR'),
                  productId: Value(item.productId),
                  warehouseId: Value(gr.warehouseId),
                  userId: Value(gr.userId),
                  quantity: Value(item.receivedQuantity), // บวก = รับเข้า
                  unitCost: Value(item.unitPrice),
                  lotNumber: Value(item.lotNumber),
                  expiryDate: Value(item.expiryDate),
                  referenceNo: Value(gr.grNo),
                  remark: Value('รับสินค้าจาก ${gr.supplierName}'),
                ),
              );

          // --- 2) upsert stock_balances (weighted avg cost) ---
          await _upsertStockBalance(
            gr.warehouseId,
            item.productId,
            item.receivedQuantity,
            item.unitPrice,
          );

          print(
            '✅ Stock movement: $movementNo (+${item.receivedQuantity} ${item.productId} @${item.unitPrice})',
          );
        }

        // --- 2) อัพเดทสถานะ GR → CONFIRMED ---
        await (db.update(
          db.goodsReceipts,
        )..where((g) => g.grId.equals(id))).write(
          GoodsReceiptsCompanion(
            status: const Value('CONFIRMED'),
            updatedAt: Value(DateTime.now()),
          ),
        );

        // --- 3) อัพเดท PO item quantities (ถ้าผูกกับ PO) ---
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

          // --- 4) อัพเดทสถานะ PO ---
          final poItems = await (db.select(
            db.purchaseOrderItems,
          )..where((i) => i.poId.equals(gr.poId!))).get();

          final allReceived = poItems.every(
            (item) => item.remainingQuantity <= 0,
          );

          await (db.update(
            db.purchaseOrders,
          )..where((p) => p.poId.equals(gr.poId!))).write(
            PurchaseOrdersCompanion(
              status: Value(allReceived ? 'COMPLETED' : 'PARTIAL'),
              updatedAt: Value(DateTime.now()),
            ),
          );
        }
      });

      print('✅ GoodsReceiptRoutes: Confirmed goods receipt: $id');

      return Response.ok(
        jsonEncode({
          'success': true,
          'message': 'ยืนยันใบรับสินค้าสำเร็จ สต๊อกได้รับการอัพเดทแล้ว',
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

  /// Helper: upsert stock_balances พร้อม weighted average cost
  /// - รับสินค้า (+qty): คำนวณ avg_cost ใหม่
  /// - จ่ายสินค้า (-qty): avg_cost คงเดิม
  Future<void> _upsertStockBalance(
    String warehouseId,
    String productId,
    double qtyDelta,
    double unitCost,
  ) async {
    final existing = await (db.select(db.stockBalances)
          ..where(
            (s) =>
                s.productId.equals(productId) &
                s.warehouseId.equals(warehouseId),
          ))
        .getSingleOrNull();

    if (existing == null) {
      final newAvg = (qtyDelta > 0 && unitCost > 0) ? unitCost : 0.0;
      await db.into(db.stockBalances).insert(
            StockBalancesCompanion(
              stockId: Value('SB_${productId}_$warehouseId'),
              productId: Value(productId),
              warehouseId: Value(warehouseId),
              quantity: Value(qtyDelta),
              avgCost: Value(newAvg),
              lastCost: Value(unitCost > 0 ? unitCost : 0.0),
              updatedAt: Value(DateTime.now()),
            ),
          );
    } else {
      final oldQty = existing.quantity;
      final newQty = oldQty + qtyDelta;

      double newAvg = existing.avgCost;
      double newLast = existing.lastCost;

      if (qtyDelta > 0 && unitCost > 0) {
        // Weighted average cost เฉพาะตอนรับเข้า
        final totalQty = oldQty + qtyDelta;
        newAvg = totalQty > 0
            ? (oldQty * existing.avgCost + qtyDelta * unitCost) / totalQty
            : unitCost;
        newLast = unitCost;
      }

      await (db.update(db.stockBalances)
            ..where((s) => s.stockId.equals(existing.stockId)))
          .write(
        StockBalancesCompanion(
          quantity: Value(newQty),
          avgCost: Value(newAvg),
          lastCost: Value(newLast),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }
  }
}