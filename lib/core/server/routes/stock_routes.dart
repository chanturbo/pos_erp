import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:drift/drift.dart' hide JsonKey;
import '../../database/app_database.dart';

class StockRoutes {
  final AppDatabase db;

  StockRoutes(this.db);

  Router get router {
    final router = Router();

    router.get('/balance', _getStockBalanceHandler);
    router.get('/movements', _getStockMovementsHandler);
    router.post('/in', _stockInHandler);
    router.post('/out', _stockOutHandler);
    router.post('/adjust', _stockAdjustHandler);
    router.post('/transfer', _stockTransferHandler);

    return router;
  }

  /// GET /api/stock/balance - ดูสต๊อกคงเหลือ (คำนวณจาก stock_movements)
  Future<Response> _getStockBalanceHandler(Request request) async {
    try {
      final query = '''
        SELECT 
          p.product_id,
          p.product_code,
          p.product_name,
          p.base_unit,
          w.warehouse_id,
          w.warehouse_name,
          COALESCE(SUM(sm.quantity), 0) as balance
        FROM products p
        CROSS JOIN warehouses w
        LEFT JOIN stock_movements sm ON sm.product_id = p.product_id 
          AND sm.warehouse_id = w.warehouse_id
        WHERE p.is_stock_control = 1
        GROUP BY p.product_id, w.warehouse_id
        HAVING balance > 0 OR p.is_active = 1
        ORDER BY p.product_code, w.warehouse_code
      ''';

      final result = await db.customSelect(query).get();

      final stockData = result
          .map(
            (row) => {
              'product_id': row.read<String>('product_id'),
              'product_code': row.read<String>('product_code'),
              'product_name': row.read<String>('product_name'),
              'base_unit': row.read<String>('base_unit'),
              'warehouse_id': row.read<String>('warehouse_id'),
              'warehouse_name': row.read<String>('warehouse_name'),
              'balance': row.read<double>('balance'),
            },
          )
          .toList();

      return Response.ok(
        jsonEncode({'success': true, 'data': stockData}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': 'เกิดข้อผิดพลาด: $e'}),
      );
    }
  }

  /// GET /api/stock/movements - ดูประวัติการเคลื่อนไหวสต๊อก
  Future<Response> _getStockMovementsHandler(Request request) async {
    try {
      final movements = await (db.select(
        db.stockMovements,
      )..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).get();

      return Response.ok(
        jsonEncode({
          'success': true,
          'data': movements
              .map(
                (m) => {
                  'movement_id': m.movementId,
                  'movement_date': m.movementDate.toIso8601String(),
                  'movement_type': m.movementType,
                  'product_id': m.productId,
                  'warehouse_id': m.warehouseId,
                  'quantity': m.quantity,
                  'reference_no': m.referenceNo,
                  'remark': m.remark,
                },
              )
              .toList(),
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': 'เกิดข้อผิดพลาด: $e'}),
      );
    }
  }

  /// POST /api/stock/in - รับสินค้าเข้า (manual)
  Future<Response> _stockInHandler(Request request) async {
    try {
      final payload = await request.readAsString();
      final data = jsonDecode(payload) as Map<String, dynamic>;

      final movementId = 'STK${DateTime.now().millisecondsSinceEpoch}';

      await db.into(db.stockMovements).insert(
            StockMovementsCompanion(
              movementId: Value(movementId),
              movementDate: Value(DateTime.now()),
              movementType: const Value('IN'),
              productId: Value(data['product_id'] as String),
              warehouseId: Value(data['warehouse_id'] as String),
              quantity: Value((data['quantity'] as num).toDouble()),
              referenceNo: Value(data['reference_no'] as String?),
              remark: Value(data['remark'] as String?),
            ),
          );

      return Response.ok(
        jsonEncode({
          'success': true,
          'message': 'รับสินค้าเข้าสต๊อกสำเร็จ',
          'data': {'movement_id': movementId},
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': 'เกิดข้อผิดพลาด: $e'}),
      );
    }
  }

  /// POST /api/stock/out - เบิกสินค้าออก (manual)
  Future<Response> _stockOutHandler(Request request) async {
    try {
      final payload = await request.readAsString();
      final data = jsonDecode(payload) as Map<String, dynamic>;

      final productId = data['product_id'] as String;
      final warehouseId = data['warehouse_id'] as String;
      final quantity = (data['quantity'] as num).toDouble();

      // ✅ ตรวจสอบสต๊อกก่อนเสมอ
      final currentStock = await _getCurrentStock(productId, warehouseId);

      if (currentStock < quantity) {
        return Response(
          400,
          body: jsonEncode({
            'success': false,
            'message': 'สต๊อกไม่เพียงพอ (คงเหลือ: $currentStock)',
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final movementId = 'STK${DateTime.now().millisecondsSinceEpoch}';

      await db.into(db.stockMovements).insert(
            StockMovementsCompanion(
              movementId: Value(movementId),
              movementDate: Value(DateTime.now()),
              movementType: const Value('OUT'),
              productId: Value(productId),
              warehouseId: Value(warehouseId),
              quantity: Value(-quantity), // ลบ = เบิกออก
              referenceNo: Value(data['reference_no'] as String?),
              remark: Value(data['remark'] as String?),
            ),
          );

      return Response.ok(
        jsonEncode({
          'success': true,
          'message': 'เบิกสินค้าออกสำเร็จ',
          'data': {'movement_id': movementId},
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': 'เกิดข้อผิดพลาด: $e'}),
      );
    }
  }

  /// POST /api/stock/adjust - ปรับสต๊อก
  Future<Response> _stockAdjustHandler(Request request) async {
    try {
      final payload = await request.readAsString();
      final data = jsonDecode(payload) as Map<String, dynamic>;

      final productId = data['product_id'] as String;
      final warehouseId = data['warehouse_id'] as String;
      final newBalance = (data['new_balance'] as num).toDouble();

      // คำนวณ quantity ที่ต้องปรับ
      final currentStock = await _getCurrentStock(productId, warehouseId);
      final adjustQty = newBalance - currentStock;

      final movementId = 'STK${DateTime.now().millisecondsSinceEpoch}';

      await db.into(db.stockMovements).insert(
            StockMovementsCompanion(
              movementId: Value(movementId),
              movementDate: Value(DateTime.now()),
              movementType: const Value('ADJUST'),
              productId: Value(productId),
              warehouseId: Value(warehouseId),
              quantity: Value(adjustQty), // บวก/ลบ ขึ้นกับผล
              referenceNo: Value(data['reference_no'] as String?),
              remark: Value(data['remark'] as String?),
            ),
          );

      return Response.ok(
        jsonEncode({
          'success': true,
          'message': 'ปรับสต๊อกสำเร็จ',
          'data': {
            'movement_id': movementId,
            'old_balance': currentStock,
            'new_balance': newBalance,
            'adjust_qty': adjustQty,
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

  /// POST /api/stock/transfer - โอนย้ายสินค้าระหว่างคลัง
  Future<Response> _stockTransferHandler(Request request) async {
    try {
      final payload = await request.readAsString();
      final data = jsonDecode(payload) as Map<String, dynamic>;

      final productId = data['product_id'] as String;
      final fromWarehouseId = data['from_warehouse_id'] as String;
      final toWarehouseId = data['to_warehouse_id'] as String;
      final quantity = (data['quantity'] as num).toDouble();

      // ✅ ตรวจสอบสต๊อกคลังต้นทางก่อน (นอก transaction)
      final currentStock = await _getCurrentStock(productId, fromWarehouseId);

      if (currentStock < quantity) {
        return Response(
          400,
          body: jsonEncode({
            'success': false,
            'message': 'สต๊อกคลังต้นทางไม่เพียงพอ (คงเหลือ: $currentStock)',
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final ts = DateTime.now().millisecondsSinceEpoch;
      final transferId = 'TRF$ts';

      // ─────────────────────────────────────────────────────────────
      // ✅ สร้าง OUT + IN ใน transaction เดียว
      //    ถ้า crash กลางทาง ทั้งคู่จะ rollback → สต๊อกไม่สูญหาย
      // ─────────────────────────────────────────────────────────────
      await db.transaction(() async {
        // OUT จากคลังต้นทาง
        await db.into(db.stockMovements).insert(
              StockMovementsCompanion(
                movementId: Value('${transferId}_OUT'),
                movementDate: Value(DateTime.now()),
                movementType: const Value('TRANSFER_OUT'),
                productId: Value(productId),
                warehouseId: Value(fromWarehouseId),
                quantity: Value(-quantity),
                referenceNo: Value(transferId),
                remark: Value(data['remark'] as String?),
              ),
            );

        // IN เข้าคลังปลายทาง
        await db.into(db.stockMovements).insert(
              StockMovementsCompanion(
                movementId: Value('${transferId}_IN'),
                movementDate: Value(DateTime.now()),
                movementType: const Value('TRANSFER_IN'),
                productId: Value(productId),
                warehouseId: Value(toWarehouseId),
                quantity: Value(quantity),
                referenceNo: Value(transferId),
                remark: Value(data['remark'] as String?),
              ),
            );
      });

      return Response.ok(
        jsonEncode({
          'success': true,
          'message': 'โอนย้ายสินค้าสำเร็จ',
          'data': {'transfer_id': transferId},
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': 'เกิดข้อผิดพลาด: $e'}),
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
}