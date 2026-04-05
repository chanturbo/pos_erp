import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:drift/drift.dart' hide JsonKey;
import '../../database/app_database.dart';
import '../middleware/auth_middleware.dart';

class StockRoutes {
  final AppDatabase db;

  StockRoutes(this.db);

  Router get router {
    final router = Router();

    router.get('/balance', _getStockBalanceHandler);
    router.get('/movements', _getStockMovementsHandler);
    router.get('/movements/product/<productId>', _getProductMovementsHandler);
    router.post('/in', _stockInHandler);
    router.post('/out', _stockOutHandler);
    router.post('/adjust', _stockAdjustHandler);
    router.post('/transfer', _stockTransferHandler);

    return router;
  }

  /// GET /api/stock/balance - ดูสต๊อกคงเหลือพร้อมราคาต้นทุน
  /// ใช้ stock_balances (cache) สำหรับ quantity + cost
  /// และ stock_movements (ledger) สำหรับ quantity ที่แม่นยำ
  Future<Response> _getStockBalanceHandler(Request request) async {
    try {
      final query = '''
        SELECT
          p.product_id,
          p.product_code,
          p.product_name,
          p.barcode,
          p.base_unit,
          w.warehouse_id,
          w.warehouse_name,
          COALESCE(SUM(sm.quantity), 0) as balance,
          COALESCE(sb.avg_cost, 0) as avg_cost,
          COALESCE(sb.last_cost, 0) as last_cost,
          COALESCE(sb.reserved_qty, 0) as reserved_qty
        FROM products p
        CROSS JOIN warehouses w
        LEFT JOIN stock_movements sm ON sm.product_id = p.product_id
          AND sm.warehouse_id = w.warehouse_id
        LEFT JOIN stock_balances sb ON sb.product_id = p.product_id
          AND sb.warehouse_id = w.warehouse_id
        WHERE p.is_stock_control = 1
        GROUP BY p.product_id, w.warehouse_id
        HAVING balance > 0 OR p.is_active = 1
        ORDER BY p.product_code, w.warehouse_code
      ''';

      final result = await db.customSelect(query).get();

      final stockData = result
          .map(
            (row) {
              final balance = row.read<double>('balance');
              final reservedQty = row.read<double>('reserved_qty');
              return {
                'product_id': row.read<String>('product_id'),
                'product_code': row.read<String>('product_code'),
                'product_name': row.read<String>('product_name'),
                'barcode': row.readNullable<String>('barcode'),
                'base_unit': row.read<String>('base_unit'),
                'warehouse_id': row.read<String>('warehouse_id'),
                'warehouse_name': row.read<String>('warehouse_name'),
                'balance': balance,
                'reserved_qty': reservedQty,
                'available_qty': (balance - reservedQty).clamp(0.0, double.infinity),
                'avg_cost': row.read<double>('avg_cost'),
                'last_cost': row.read<double>('last_cost'),
              };
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

  /// GET /api/stock/movements/product/:productId - ประวัติของสินค้าตัวนั้น
  Future<Response> _getProductMovementsHandler(
      Request request, String productId) async {
    try {
      final result = await db.customSelect(
        '''
        SELECT
          sm.movement_id,
          sm.movement_no,
          sm.movement_date,
          sm.movement_type,
          sm.product_id,
          p.product_name,
          p.product_code,
          p.base_unit,
          sm.warehouse_id,
          w.warehouse_name,
          sm.quantity,
          sm.reference_no,
          sm.remark
        FROM stock_movements sm
        LEFT JOIN products p ON p.product_id = sm.product_id
        LEFT JOIN warehouses w ON w.warehouse_id = sm.warehouse_id
        WHERE sm.product_id = ?
        ORDER BY sm.movement_date DESC
        ''',
        variables: [Variable.withString(productId)],
      ).get();

      final data = result
          .map((row) => {
                'movement_id': row.read<String>('movement_id'),
                'movement_no': row.readNullable<String>('movement_no'),
                'movement_date':
                    row.read<DateTime>('movement_date').toIso8601String(),
                'movement_type': row.read<String>('movement_type'),
                'product_id': row.read<String>('product_id'),
                'product_name': row.readNullable<String>('product_name'),
                'product_code': row.readNullable<String>('product_code'),
                'base_unit': row.readNullable<String>('base_unit'),
                'warehouse_id': row.read<String>('warehouse_id'),
                'warehouse_name': row.readNullable<String>('warehouse_name'),
                'quantity': row.read<double>('quantity'),
                'reference_no': row.readNullable<String>('reference_no'),
                'remark': row.readNullable<String>('remark'),
              })
          .toList();

      return Response.ok(
        jsonEncode({'success': true, 'data': data}),
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

      final ts = DateTime.now().millisecondsSinceEpoch;
      final movementId = 'STK$ts';
      final userId = getAuthUser(request)?.userId ?? 'USR001';

      final productId = data['product_id'] as String;
      final warehouseId = data['warehouse_id'] as String;
      final quantity = (data['quantity'] as num).toDouble();
      final unitCost = (data['unit_cost'] as num?)?.toDouble() ?? 0.0;

      await db.into(db.stockMovements).insert(
            StockMovementsCompanion(
              movementId: Value(movementId),
              movementNo: Value('IN-$ts'),
              movementDate: Value(DateTime.now()),
              movementType: const Value('IN'),
              productId: Value(productId),
              warehouseId: Value(warehouseId),
              quantity: Value(quantity),
              unitCost: Value(unitCost),
              referenceNo: Value(data['reference_no'] as String?),
              remark: Value(data['remark'] as String?),
              userId: Value(userId),
            ),
          );

      await _upsertStockBalance(warehouseId, productId, quantity, unitCost);

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

      final ts = DateTime.now().millisecondsSinceEpoch;
      final movementId = 'STK$ts';
      final userId = getAuthUser(request)?.userId ?? 'USR001';

      await db.into(db.stockMovements).insert(
            StockMovementsCompanion(
              movementId: Value(movementId),
              movementNo: Value('OUT-$ts'),
              movementDate: Value(DateTime.now()),
              movementType: const Value('OUT'),
              productId: Value(productId),
              warehouseId: Value(warehouseId),
              quantity: Value(-quantity),
              referenceNo: Value(data['reference_no'] as String?),
              remark: Value(data['remark'] as String?),
              userId: Value(userId),
            ),
          );

      await _upsertStockBalance(warehouseId, productId, -quantity, 0);

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

      final ts = DateTime.now().millisecondsSinceEpoch;
      final movementId = 'STK$ts';
      final userId = getAuthUser(request)?.userId ?? 'USR001';

      await db.into(db.stockMovements).insert(
            StockMovementsCompanion(
              movementId: Value(movementId),
              movementNo: Value('ADJ-$ts'),
              movementDate: Value(DateTime.now()),
              movementType: const Value('ADJUST'),
              productId: Value(productId),
              warehouseId: Value(warehouseId),
              quantity: Value(adjustQty),
              referenceNo: Value(data['reference_no'] as String?),
              remark: Value(data['remark'] as String?),
              userId: Value(userId),
            ),
          );

      await _upsertStockBalance(warehouseId, productId, adjustQty, 0);

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
      final userId = getAuthUser(request)?.userId ?? 'USR001';

      await db.transaction(() async {
        // OUT จากคลังต้นทาง
        await db.into(db.stockMovements).insert(
              StockMovementsCompanion(
                movementId: Value('${transferId}_OUT'),
                movementNo: Value('TRF-${ts}_OUT'),
                movementDate: Value(DateTime.now()),
                movementType: const Value('TRANSFER_OUT'),
                productId: Value(productId),
                warehouseId: Value(fromWarehouseId),
                quantity: Value(-quantity),
                referenceNo: Value(transferId),
                remark: Value(data['remark'] as String?),
                userId: Value(userId),
              ),
            );

        // IN เข้าคลังปลายทาง
        await db.into(db.stockMovements).insert(
              StockMovementsCompanion(
                movementId: Value('${transferId}_IN'),
                movementNo: Value('TRF-${ts}_IN'),
                movementDate: Value(DateTime.now()),
                movementType: const Value('TRANSFER_IN'),
                productId: Value(productId),
                warehouseId: Value(toWarehouseId),
                quantity: Value(quantity),
                referenceNo: Value(transferId),
                remark: Value(data['remark'] as String?),
                userId: Value(userId),
              ),
            );

        // อัปเดต stock_balances ทั้งสองคลัง (cost คงเดิมตอน transfer)
        await _upsertStockBalance(fromWarehouseId, productId, -quantity, 0);
        await _upsertStockBalance(toWarehouseId, productId, quantity, 0);
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

  /// Helper: upsert stock_balances พร้อม weighted average cost
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