// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:drift/drift.dart' hide JsonKey;
import '../../database/app_database.dart';

class PurchaseReturnRoutes {
  final AppDatabase db;

  PurchaseReturnRoutes(this.db);

  Router get router {
    final router = Router();

    router.get('/', _getReturnsHandler);
    router.get('/<id>', _getReturnHandler);
    router.post('/', _createReturnHandler);
    router.put('/<id>/confirm', _confirmReturnHandler);
    router.delete('/<id>', _deleteReturnHandler);

    return router;
  }

  /// GET / - รายการคืนสินค้าทั้งหมด
  Future<Response> _getReturnsHandler(Request request) async {
    try {
      print('📡 PurchaseReturnRoutes: GET /');

      final returns = await db.select(db.purchaseReturns).get();

      final data = returns
          .map(
            (ret) => {
              'return_id': ret.returnId,
              'return_no': ret.returnNo,
              'return_date': ret.returnDate.toIso8601String(),
              'supplier_id': ret.supplierId,
              'supplier_name': ret.supplierName,
              'reference_type': ret.referenceType,
              'reference_id': ret.referenceId,
              'total_amount': ret.totalAmount,
              'status': ret.status,
              'reason': ret.reason,
              'remark': ret.remark,
              'user_id': ret.userId,
              'created_at': ret.createdAt.toIso8601String(),
              'updated_at': ret.updatedAt.toIso8601String(),
            },
          )
          .toList();

      print('✅ PurchaseReturnRoutes: Found ${returns.length} returns');

      return Response.ok(
        jsonEncode({'success': true, 'data': data}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('❌ PurchaseReturnRoutes: GET / error: $e');
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': '$e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// GET /:id - รายละเอียดใบคืนสินค้าพร้อมรายการ
  Future<Response> _getReturnHandler(Request request, String id) async {
    try {
      print('📡 PurchaseReturnRoutes: GET /$id');

      final returnDoc = await (db.select(db.purchaseReturns)
            ..where((ret) => ret.returnId.equals(id)))
          .getSingleOrNull();

      if (returnDoc == null) {
        return Response.notFound(
          jsonEncode({'success': false, 'message': 'Return not found'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final items = await (db.select(db.purchaseReturnItems)
            ..where((item) => item.returnId.equals(id))
            ..orderBy([(item) => OrderingTerm(expression: item.lineNo)]))
          .get();

      final data = {
        'return_id': returnDoc.returnId,
        'return_no': returnDoc.returnNo,
        'return_date': returnDoc.returnDate.toIso8601String(),
        'supplier_id': returnDoc.supplierId,
        'supplier_name': returnDoc.supplierName,
        'reference_type': returnDoc.referenceType,
        'reference_id': returnDoc.referenceId,
        'total_amount': returnDoc.totalAmount,
        'status': returnDoc.status,
        'reason': returnDoc.reason,
        'remark': returnDoc.remark,
        'user_id': returnDoc.userId,
        'created_at': returnDoc.createdAt.toIso8601String(),
        'updated_at': returnDoc.updatedAt.toIso8601String(),
        'items': items
            .map(
              (item) => {
                'item_id': item.itemId,
                'return_id': item.returnId,
                'line_no': item.lineNo,
                'product_id': item.productId,
                'product_code': item.productCode,
                'product_name': item.productName,
                'unit': item.unit,
                'warehouse_id': item.warehouseId,
                'warehouse_name': item.warehouseName,
                'quantity': item.quantity,
                'unit_price': item.unitPrice,
                'amount': item.amount,
                'reason': item.reason,
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
      print('❌ PurchaseReturnRoutes: GET /$id error: $e');
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': '$e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// POST / - สร้างใบคืนสินค้า (DRAFT)
  Future<Response> _createReturnHandler(Request request) async {
    try {
      print('📡 PurchaseReturnRoutes: POST /');

      final payload = await request.readAsString();
      final data = jsonDecode(payload) as Map<String, dynamic>;

      final ts = DateTime.now().millisecondsSinceEpoch;
      final returnId = 'PRET$ts';

      // ─────────────────────────────────────────────────────────────
      // สร้าง header + items ใน transaction เดียว
      // ─────────────────────────────────────────────────────────────
      await db.transaction(() async {
        await db.into(db.purchaseReturns).insert(
              PurchaseReturnsCompanion(
                returnId: Value(returnId),
                returnNo: Value(data['return_no'] as String),
                returnDate: Value(DateTime.parse(data['return_date'] as String)),
                supplierId: Value(data['supplier_id'] as String),
                supplierName: Value(data['supplier_name'] as String),
                referenceType: Value(data['reference_type'] as String?),
                referenceId: Value(data['reference_id'] as String?),
                totalAmount: Value((data['total_amount'] as num).toDouble()),
                status: const Value('DRAFT'),
                reason: Value(data['reason'] as String?),
                remark: Value(data['remark'] as String?),
                userId: Value(data['user_id'] as String),
              ),
            );

        if (data['items'] != null) {
          final items = data['items'] as List;
          for (var i = 0; i < items.length; i++) {
            final item = items[i] as Map<String, dynamic>;
            final itemId = 'PRETITEM$ts$i';

            await db.into(db.purchaseReturnItems).insert(
                  PurchaseReturnItemsCompanion(
                    itemId: Value(itemId),
                    returnId: Value(returnId),
                    lineNo: Value(item['line_no'] as int? ?? i + 1),
                    productId: Value(item['product_id'] as String),
                    productCode: Value(item['product_code'] as String),
                    productName: Value(item['product_name'] as String),
                    unit: Value(item['unit'] as String),
                    warehouseId: Value(item['warehouse_id'] as String),
                    warehouseName: Value(item['warehouse_name'] as String),
                    quantity: Value((item['quantity'] as num).toDouble()),
                    unitPrice: Value((item['unit_price'] as num).toDouble()),
                    amount: Value((item['amount'] as num).toDouble()),
                    reason: Value(item['reason'] as String?),
                    remark: Value(item['remark'] as String?),
                  ),
                );
          }
        }
      });

      print('✅ PurchaseReturnRoutes: Created return: $returnId');

      return Response.ok(
        jsonEncode({
          'success': true,
          'message': 'Return created',
          'data': {'return_id': returnId},
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('❌ PurchaseReturnRoutes: POST / error: $e');
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': '$e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// PUT /:id/confirm - ยืนยันใบคืนสินค้า (ลดสต๊อก)
  Future<Response> _confirmReturnHandler(Request request, String id) async {
    try {
      print('📡 PurchaseReturnRoutes: PUT /$id/confirm');

      final returnDoc = await (db.select(db.purchaseReturns)
            ..where((ret) => ret.returnId.equals(id)))
          .getSingleOrNull();

      if (returnDoc == null) {
        return Response.notFound(
          jsonEncode({'success': false, 'message': 'Return not found'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // ✅ Guard: ป้องกัน double confirm
      if (returnDoc.status == 'CONFIRMED') {
        return Response(
          400,
          body: jsonEncode({
            'success': false,
            'message': 'ใบคืนสินค้านี้ยืนยันแล้ว ไม่สามารถยืนยันซ้ำได้',
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final items = await (db.select(db.purchaseReturnItems)
            ..where((item) => item.returnId.equals(id)))
          .get();

      if (items.isEmpty) {
        return Response(
          400,
          body: jsonEncode({
            'success': false,
            'message': 'ไม่มีรายการสินค้าในใบคืนสินค้า',
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final ts = DateTime.now().millisecondsSinceEpoch;

      // ─────────────────────────────────────────────────────────────
      // CRITICAL FIX: stock check + insert อยู่ใน transaction เดียว
      // ป้องกัน race condition ที่ 2 requests confirm พร้อมกัน
      //
      // ทุก operation:
      // 1) check stock ทุกรายการ (ถ้าไม่พอ → throw → rollback)
      // 2) insert stock_movements
      // 3) update status → CONFIRMED
      // ─────────────────────────────────────────────────────────────
      await db.transaction(() async {
        // --- 1) ตรวจสอบสต๊อก ภายใน transaction ---
        for (var item in items) {
          final currentStock = await _getCurrentStock(
            item.productId,
            item.warehouseId,
          );
          if (currentStock < item.quantity) {
            throw _PurchaseReturnValidationException(
              'สต๊อกสินค้า ${item.productName} ไม่เพียงพอ '
              '(คงเหลือ: $currentStock, ต้องการคืน: ${item.quantity})',
            );
          }
        }

        // --- 2) บันทึก stock movements (ลดสต๊อก) ---
        for (var item in items) {
          final movementId = 'PRTM${ts}_${item.lineNo}';
          final movementNo = 'PR-${returnDoc.returnNo}-${item.lineNo}';

          await db.into(db.stockMovements).insert(
                StockMovementsCompanion(
                  movementId: Value(movementId),
                  movementNo: Value(movementNo),
                  movementDate: Value(returnDoc.returnDate),
                  movementType: const Value('PURCHASE_RETURN'),
                  productId: Value(item.productId),
                  warehouseId: Value(item.warehouseId),
                  userId: Value(returnDoc.userId),
                  quantity: Value(-item.quantity), // ลบ = ลดสต๊อก
                  referenceNo: Value(returnDoc.returnNo),
                  remark: Value('คืนสินค้า: ${returnDoc.returnNo}'),
                ),
              );

          print(
            '✅ Stock movement: $movementNo (-${item.quantity} ${item.productId})',
          );
        }

        // --- 2) อัพเดทสถานะ → CONFIRMED ---
        await (db.update(db.purchaseReturns)
              ..where((ret) => ret.returnId.equals(id)))
            .write(
          PurchaseReturnsCompanion(
            status: const Value('CONFIRMED'),
            updatedAt: Value(DateTime.now()),
          ),
        );
      });

      print('✅ PurchaseReturnRoutes: Confirmed return: $id');

      return Response.ok(
        jsonEncode({
          'success': true,
          'message': 'ยืนยันการคืนสินค้าสำเร็จ สต๊อกได้รับการอัพเดทแล้ว',
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } on _PurchaseReturnValidationException catch (e) {
      return Response(400,
          body: jsonEncode({'success': false, 'message': e.message}),
          headers: {'Content-Type': 'application/json'});
    } catch (e) {
      print('❌ PurchaseReturnRoutes: PUT /$id/confirm error: $e');
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': 'เกิดข้อผิดพลาดภายใน กรุณาลองใหม่'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// DELETE /:id - ลบใบคืนสินค้า (DRAFT เท่านั้น)
  Future<Response> _deleteReturnHandler(Request request, String id) async {
    try {
      print('📡 PurchaseReturnRoutes: DELETE /$id');

      final returnDoc = await (db.select(db.purchaseReturns)
            ..where((ret) => ret.returnId.equals(id)))
          .getSingleOrNull();

      if (returnDoc == null) {
        return Response.notFound(
          jsonEncode({'success': false, 'message': 'Return not found'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      if (returnDoc.status == 'CONFIRMED') {
        return Response(
          400,
          body: jsonEncode({
            'success': false,
            'message': 'ไม่สามารถลบใบคืนสินค้าที่ยืนยันแล้ว',
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      await (db.delete(db.purchaseReturnItems)
            ..where((item) => item.returnId.equals(id)))
          .go();

      await (db.delete(db.purchaseReturns)
            ..where((ret) => ret.returnId.equals(id)))
          .go();

      print('✅ PurchaseReturnRoutes: Deleted return: $id');

      return Response.ok(
        jsonEncode({'success': true, 'message': 'Return deleted'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('❌ PurchaseReturnRoutes: DELETE /$id error: $e');
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': '$e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// Helper: คำนวณสต๊อกปัจจุบันจาก stock_movements (single source of truth)
  Future<double> _getCurrentStock(
    String productId,
    String warehouseId,
  ) async {
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

class _PurchaseReturnValidationException implements Exception {
  final String message;
  const _PurchaseReturnValidationException(this.message);
}