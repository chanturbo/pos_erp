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

      final data = returns.map((ret) => {
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
          }).toList();

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

      // ดึงรายการสินค้า
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
        'items': items.map((item) => {
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
            }).toList(),
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

      final returnId = 'PRET${DateTime.now().millisecondsSinceEpoch}';

      // สร้างใบคืนสินค้า
      final returnCompanion = PurchaseReturnsCompanion(
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
      );

      await db.into(db.purchaseReturns).insert(returnCompanion);

      // สร้างรายการสินค้า
      if (data['items'] != null) {
        final items = data['items'] as List;
        for (var i = 0; i < items.length; i++) {
          final item = items[i] as Map<String, dynamic>;
          final itemId = 'PRETITEM${DateTime.now().millisecondsSinceEpoch}$i';

          final itemCompanion = PurchaseReturnItemsCompanion(
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
          );

          await db.into(db.purchaseReturnItems).insert(itemCompanion);
        }
      }

      print('✅ PurchaseReturnRoutes: Created return: $returnId');

      return Response.ok(
        jsonEncode({
          'success': true,
          'message': 'Return created',
          'data': {'return_id': returnId}
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

      // ดึงข้อมูลใบคืน
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
        return Response.ok(
          jsonEncode({'success': false, 'message': 'Already confirmed'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // ดึงรายการสินค้า
      final items = await (db.select(db.purchaseReturnItems)
            ..where((item) => item.returnId.equals(id)))
          .get();

      // ลดสต๊อก
      for (var item in items) {
        // ค้นหา StockBalance
        final stockBalance = await (db.select(db.stockBalances)
              ..where((s) =>
                  s.productId.equals(item.productId) &
                  s.warehouseId.equals(item.warehouseId)))
            .getSingleOrNull();

        if (stockBalance != null) {
          // ลดสต๊อก
          final newQty = stockBalance.quantity - item.quantity;
          await (db.update(db.stockBalances)
                ..where((s) => s.stockId.equals(stockBalance.stockId)))
              .write(StockBalancesCompanion(
            quantity: Value(newQty),
          ));

          // บันทึก StockMovement
          final movementId = 'MOV${DateTime.now().millisecondsSinceEpoch}${item.lineNo}';
          await db.into(db.stockMovements).insert(StockMovementsCompanion(
            movementId: Value(movementId),
            productId: Value(item.productId),
            warehouseId: Value(item.warehouseId),
            movementType: const Value('PURCHASE_RETURN'),
            quantity: Value(-item.quantity), // ลบ
            referenceType: const Value('PURCHASE_RETURN'),
            referenceId: Value(returnDoc.returnId),
            movementDate: Value(returnDoc.returnDate),
            remark: Value('คืนสินค้า: ${returnDoc.returnNo}'),
          ));
        }
      }

      // อัพเดทสถานะ
      await (db.update(db.purchaseReturns)
            ..where((ret) => ret.returnId.equals(id)))
          .write(const PurchaseReturnsCompanion(
        status: Value('CONFIRMED'),
        updatedAt: Value.absent(),
      ));

      print('✅ PurchaseReturnRoutes: Confirmed return: $id');

      return Response.ok(
        jsonEncode({'success': true, 'message': 'Return confirmed'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('❌ PurchaseReturnRoutes: PUT /$id/confirm error: $e');
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': '$e'}),
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
        return Response.ok(
          jsonEncode({'success': false, 'message': 'Cannot delete confirmed return'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // ลบรายการสินค้าก่อน
      await (db.delete(db.purchaseReturnItems)
            ..where((item) => item.returnId.equals(id)))
          .go();

      // ลบใบคืนสินค้า
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
}