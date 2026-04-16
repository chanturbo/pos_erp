// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:async';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:drift/drift.dart' hide JsonKey;
import '../../database/app_database.dart';

class PurchaseReturnRoutes {
  final AppDatabase db;
  static final Map<String, Future<void>> _confirmLocks = {};

  PurchaseReturnRoutes(this.db);

  Router get router {
    final router = Router();

    router.get('/', _getReturnsHandler);
    router.get('/<id>', _getReturnHandler);
    router.post('/', _createReturnHandler);
    router.put('/<id>', _updateReturnHandler);
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
      final validated = await _validateDraftPayload(data);

      final ts = DateTime.now().millisecondsSinceEpoch;
      final returnId = 'PRET$ts';

      await db.transaction(() async {
        await _insertDraftReturn(returnId, data, validated, ts);
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
    } on _PurchaseReturnValidationException catch (e) {
      return Response(
        400,
        body: jsonEncode({'success': false, 'message': e.message}),
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

  /// PUT /:id - แก้ไขใบคืนสินค้า (DRAFT เท่านั้น)
  Future<Response> _updateReturnHandler(Request request, String id) async {
    try {
      print('📡 PurchaseReturnRoutes: PUT /$id');

      final existing = await (db.select(db.purchaseReturns)
            ..where((ret) => ret.returnId.equals(id)))
          .getSingleOrNull();

      if (existing == null) {
        return Response.notFound(
          jsonEncode({'success': false, 'message': 'Return not found'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      if (existing.status == 'CONFIRMED') {
        return Response(
          400,
          body: jsonEncode({
            'success': false,
            'message': 'ไม่สามารถแก้ไขใบคืนสินค้าที่ยืนยันแล้ว',
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final payload = await request.readAsString();
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final validated = await _validateDraftPayload(data, excludeReturnId: id);

      await db.transaction(() async {
        await (db.update(db.purchaseReturns)
              ..where((ret) => ret.returnId.equals(id)))
            .write(
          PurchaseReturnsCompanion(
            returnNo: Value(data['return_no'] as String),
            returnDate: Value(DateTime.parse(data['return_date'] as String)),
            supplierId: Value(data['supplier_id'] as String),
            supplierName: Value(data['supplier_name'] as String),
            referenceType: Value(validated.referenceType),
            referenceId: Value(validated.referenceId),
            totalAmount: Value(validated.totalAmount),
            reason: Value(data['reason'] as String?),
            remark: Value(data['remark'] as String?),
            userId: Value(data['user_id'] as String),
            updatedAt: Value(DateTime.now()),
          ),
        );

        await (db.delete(db.purchaseReturnItems)
              ..where((item) => item.returnId.equals(id)))
            .go();

        await _insertDraftItems(
          returnId: id,
          items: validated.items,
          ts: DateTime.now().millisecondsSinceEpoch,
        );
      });

      print('✅ PurchaseReturnRoutes: Updated return: $id');

      return Response.ok(
        jsonEncode({'success': true, 'message': 'Return updated'}),
        headers: {'Content-Type': 'application/json'},
      );
    } on _PurchaseReturnValidationException catch (e) {
      return Response(
        400,
        body: jsonEncode({'success': false, 'message': e.message}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('❌ PurchaseReturnRoutes: PUT /$id error: $e');
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': '$e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// PUT /:id/confirm - ยืนยันใบคืนสินค้า (ลดสต๊อก)
  Future<Response> _confirmReturnHandler(Request request, String id) async {
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

    final lockKey = _confirmLockKey(returnDoc);

    try {
      return await _withConfirmLock(lockKey, () async {
        final freshReturnDoc = await (db.select(db.purchaseReturns)
              ..where((ret) => ret.returnId.equals(id)))
            .getSingleOrNull();

        if (freshReturnDoc == null) {
          return Response.notFound(
            jsonEncode({'success': false, 'message': 'Return not found'}),
            headers: {'Content-Type': 'application/json'},
          );
        }

        // re-check หลังเข้า lock เพื่อกัน double confirm ที่ชนกัน
        if (freshReturnDoc.status == 'CONFIRMED') {
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

        if (freshReturnDoc.referenceType == 'GOODS_RECEIPT' &&
            freshReturnDoc.referenceId != null) {
          await _validateDraftPayload({
            'supplier_id': freshReturnDoc.supplierId,
            'supplier_name': freshReturnDoc.supplierName,
            'reference_type': freshReturnDoc.referenceType,
            'reference_id': freshReturnDoc.referenceId,
            'items': items
                .map(
                  (item) => {
                    'line_no': item.lineNo,
                    'product_id': item.productId,
                    'product_code': item.productCode,
                    'product_name': item.productName,
                    'unit': item.unit,
                    'warehouse_id': item.warehouseId,
                    'warehouse_name': item.warehouseName,
                    'quantity': item.quantity,
                    'unit_price': item.unitPrice,
                    'reason': item.reason,
                    'remark': item.remark,
                  },
                )
                .toList(),
          }, excludeReturnId: id);
        }

        final ts = DateTime.now().millisecondsSinceEpoch;

        await db.transaction(() async {
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

          for (var item in items) {
            final movementId = 'PRTM${ts}_${item.lineNo}';
            final movementNo = 'PR-${freshReturnDoc.returnNo}-${item.lineNo}';

            await db.into(db.stockMovements).insert(
                  StockMovementsCompanion(
                    movementId: Value(movementId),
                    movementNo: Value(movementNo),
                    movementDate: Value(freshReturnDoc.returnDate),
                    movementType: const Value('PURCHASE_RETURN'),
                    productId: Value(item.productId),
                    warehouseId: Value(item.warehouseId),
                    userId: Value(freshReturnDoc.userId),
                    quantity: Value(-item.quantity),
                    unitCost: Value(item.unitPrice),
                    referenceNo: Value(freshReturnDoc.returnNo),
                    remark: Value('คืนสินค้า: ${freshReturnDoc.returnNo}'),
                  ),
                );

            await _upsertStockBalance(
              item.warehouseId,
              item.productId,
              -item.quantity,
              0,
            );

            print(
              '✅ Stock movement: $movementNo (-${item.quantity} ${item.productId})',
            );
          }

          final affectedRows = await (db.update(db.purchaseReturns)
                ..where(
                  (ret) =>
                      ret.returnId.equals(id) & ret.status.equals('DRAFT'),
                ))
              .write(
            PurchaseReturnsCompanion(
              status: const Value('CONFIRMED'),
              updatedAt: Value(DateTime.now()),
            ),
          );

          if (affectedRows == 0) {
            throw const _PurchaseReturnValidationException(
              'ใบคืนสินค้านี้ถูกยืนยันไปแล้ว',
            );
          }
        });

        print('✅ PurchaseReturnRoutes: Confirmed return: $id');

        return Response.ok(
          jsonEncode({
            'success': true,
            'message': 'ยืนยันการคืนสินค้าสำเร็จ สต๊อกได้รับการอัพเดทแล้ว',
          }),
          headers: {'Content-Type': 'application/json'},
        );
      });
    } on _PurchaseReturnValidationException catch (e) {
      return Response(
        400,
        body: jsonEncode({'success': false, 'message': e.message}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('❌ PurchaseReturnRoutes: PUT /$id/confirm error: $e');
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'เกิดข้อผิดพลาดภายใน กรุณาลองใหม่',
        }),
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

  Future<void> _insertDraftReturn(
    String returnId,
    Map<String, dynamic> data,
    _ValidatedDraftPayload validated,
    int ts,
  ) async {
    await db.into(db.purchaseReturns).insert(
          PurchaseReturnsCompanion(
            returnId: Value(returnId),
            returnNo: Value(data['return_no'] as String),
            returnDate: Value(DateTime.parse(data['return_date'] as String)),
            supplierId: Value(data['supplier_id'] as String),
            supplierName: Value(data['supplier_name'] as String),
            referenceType: Value(validated.referenceType),
            referenceId: Value(validated.referenceId),
            totalAmount: Value(validated.totalAmount),
            status: const Value('DRAFT'),
            reason: Value(data['reason'] as String?),
            remark: Value(data['remark'] as String?),
            userId: Value(data['user_id'] as String),
          ),
        );

    await _insertDraftItems(returnId: returnId, items: validated.items, ts: ts);
  }

  Future<void> _insertDraftItems({
    required String returnId,
    required List<_ValidatedReturnItem> items,
    required int ts,
  }) async {
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final itemId = 'PRETITEM$ts$i';

      await db.into(db.purchaseReturnItems).insert(
            PurchaseReturnItemsCompanion(
              itemId: Value(itemId),
              returnId: Value(returnId),
              lineNo: Value(item.lineNo),
              productId: Value(item.productId),
              productCode: Value(item.productCode),
              productName: Value(item.productName),
              unit: Value(item.unit),
              warehouseId: Value(item.warehouseId),
              warehouseName: Value(item.warehouseName),
              quantity: Value(item.quantity),
              unitPrice: Value(item.unitPrice),
              amount: Value(item.amount),
              reason: Value(item.reason),
              remark: Value(item.remark),
            ),
          );
    }
  }

  Future<_ValidatedDraftPayload> _validateDraftPayload(
    Map<String, dynamic> data, {
    String? excludeReturnId,
  }) async {
    final supplierId = data['supplier_id'] as String?;
    final supplierName = data['supplier_name'] as String?;
    final referenceType = data['reference_type'] as String?;
    final referenceId = data['reference_id'] as String?;
    final rawItems = data['items'] as List?;

    if (supplierId == null || supplierId.isEmpty) {
      throw const _PurchaseReturnValidationException('กรุณาเลือกซัพพลายเออร์');
    }
    if (supplierName == null || supplierName.isEmpty) {
      throw const _PurchaseReturnValidationException('ไม่พบชื่อซัพพลายเออร์');
    }
    if (referenceType != 'GOODS_RECEIPT' ||
        referenceId == null ||
        referenceId.isEmpty) {
      throw const _PurchaseReturnValidationException(
        'กรุณาเลือกใบรับสินค้าที่จะใช้อ้างอิง',
      );
    }
    if (rawItems == null || rawItems.isEmpty) {
      throw const _PurchaseReturnValidationException(
        'กรุณาเพิ่มรายการสินค้าอย่างน้อย 1 รายการ',
      );
    }

    final receipt = await (db.select(db.goodsReceipts)
          ..where((gr) => gr.grId.equals(referenceId)))
        .getSingleOrNull();

    if (receipt == null) {
      throw const _PurchaseReturnValidationException('ไม่พบใบรับสินค้าอ้างอิง');
    }
    if (receipt.status != 'CONFIRMED') {
      throw const _PurchaseReturnValidationException(
        'สามารถอ้างอิงได้เฉพาะใบรับสินค้าที่ยืนยันแล้ว',
      );
    }
    if (receipt.supplierId != supplierId) {
      throw const _PurchaseReturnValidationException(
        'ซัพพลายเออร์ไม่ตรงกับใบรับสินค้าอ้างอิง',
      );
    }

    final receiptItems = await (db.select(db.goodsReceiptItems)
          ..where((item) => item.grId.equals(referenceId)))
        .get();

    if (receiptItems.isEmpty) {
      throw const _PurchaseReturnValidationException(
        'ไม่พบรายการสินค้าในใบรับสินค้าอ้างอิง',
      );
    }

    final sourceByProduct = <String, _ReceiptSourceAggregate>{};
    for (final item in receiptItems) {
      final existing = sourceByProduct[item.productId];
      sourceByProduct[item.productId] = existing == null
          ? _ReceiptSourceAggregate.fromItem(item)
          : existing.accumulate(item);
    }

    final existingReturnedByProduct = await _getReturnedQtyByProduct(
      referenceId: referenceId,
      excludeReturnId: excludeReturnId,
    );

    final validatedItems = <_ValidatedReturnItem>[];
    final requestedQtyByProduct = <String, double>{};

    for (var i = 0; i < rawItems.length; i++) {
      final raw = rawItems[i] as Map<String, dynamic>;
      final productId = raw['product_id'] as String?;
      final productCode = raw['product_code'] as String?;
      final productName = raw['product_name'] as String?;
      final unit = raw['unit'] as String?;
      final quantity = (raw['quantity'] as num?)?.toDouble() ?? 0;
      final unitPrice = (raw['unit_price'] as num?)?.toDouble() ?? 0;
      final reason = raw['reason'] as String?;
      final remark = raw['remark'] as String?;

      if (productId == null || !sourceByProduct.containsKey(productId)) {
        throw _PurchaseReturnValidationException(
          'พบสินค้าที่ไม่ได้อยู่ในใบรับสินค้าอ้างอิง',
        );
      }
      if (quantity <= 0) {
        throw _PurchaseReturnValidationException(
          'จำนวนคืนของสินค้า ${productName ?? productCode ?? productId} ต้องมากกว่า 0',
        );
      }
      if (unitPrice <= 0) {
        throw _PurchaseReturnValidationException(
          'ราคา/หน่วยของสินค้า ${productName ?? productCode ?? productId} ต้องมากกว่า 0',
        );
      }

      if (raw['warehouse_id'] != receipt.warehouseId) {
        throw const _PurchaseReturnValidationException(
          'คลังสินค้าไม่ตรงกับใบรับสินค้าอ้างอิง',
        );
      }

      requestedQtyByProduct[productId] =
          (requestedQtyByProduct[productId] ?? 0) + quantity;

      validatedItems.add(
        _ValidatedReturnItem(
          lineNo: raw['line_no'] as int? ?? i + 1,
          productId: productId,
          productCode: productCode ?? sourceByProduct[productId]!.productCode,
          productName: productName ?? sourceByProduct[productId]!.productName,
          unit: unit ?? sourceByProduct[productId]!.unit,
          warehouseId: receipt.warehouseId,
          warehouseName: receipt.warehouseName,
          quantity: quantity,
          unitPrice: unitPrice,
          amount: quantity * unitPrice,
          reason: reason,
          remark: remark,
        ),
      );
    }

    for (final entry in requestedQtyByProduct.entries) {
      final source = sourceByProduct[entry.key]!;
      final alreadyReturned = existingReturnedByProduct[entry.key] ?? 0;
      final remaining = source.receivedQty - alreadyReturned;
      if (entry.value > remaining) {
        throw _PurchaseReturnValidationException(
          'สินค้า ${source.productName} คืนได้สูงสุด ${remaining.toStringAsFixed(2)} ${source.unit}',
        );
      }
    }

    final totalAmount = validatedItems.fold<double>(
      0,
      (sum, item) => sum + item.amount,
    );

    return _ValidatedDraftPayload(
      referenceType: referenceType!,
      referenceId: referenceId,
      totalAmount: totalAmount,
      items: validatedItems,
    );
  }

  Future<Map<String, double>> _getReturnedQtyByProduct({
    required String referenceId,
    String? excludeReturnId,
  }) async {
    final variables = <Variable<Object>>[
      Variable.withString(referenceId),
    ];
    final buffer = StringBuffer('''
      SELECT pri.product_id, COALESCE(SUM(pri.quantity), 0) AS returned_qty
      FROM purchase_return_items pri
      INNER JOIN purchase_returns pr ON pr.return_id = pri.return_id
      WHERE pr.reference_type = 'GOODS_RECEIPT'
        AND pr.reference_id = ?
        AND pr.status = 'CONFIRMED'
    ''');

    if (excludeReturnId != null) {
      buffer.write(' AND pr.return_id != ?');
      variables.add(Variable.withString(excludeReturnId));
    }

    buffer.write(' GROUP BY pri.product_id');

    final rows = await db.customSelect(
      buffer.toString(),
      variables: variables,
    ).get();

    return {
      for (final row in rows)
        row.read<String>('product_id'):
            (row.read<num>('returned_qty')).toDouble(),
    };
  }

  String _confirmLockKey(PurchaseReturn returnDoc) {
    if (returnDoc.referenceType == 'GOODS_RECEIPT' &&
        returnDoc.referenceId != null &&
        returnDoc.referenceId!.isNotEmpty) {
      return 'GOODS_RECEIPT:${returnDoc.referenceId!}';
    }
    return 'RETURN:${returnDoc.returnId}';
  }

  Future<T> _withConfirmLock<T>(
    String key,
    Future<T> Function() action,
  ) async {
    final previous = _confirmLocks[key];
    final completer = Completer<void>();
    _confirmLocks[key] = completer.future;

    if (previous != null) {
      await previous;
    }

    try {
      return await action();
    } finally {
      completer.complete();
      if (identical(_confirmLocks[key], completer.future)) {
        _confirmLocks.remove(key);
      }
    }
  }
}

class _PurchaseReturnValidationException implements Exception {
  final String message;
  const _PurchaseReturnValidationException(this.message);
}

class _ValidatedDraftPayload {
  final String referenceType;
  final String referenceId;
  final double totalAmount;
  final List<_ValidatedReturnItem> items;

  const _ValidatedDraftPayload({
    required this.referenceType,
    required this.referenceId,
    required this.totalAmount,
    required this.items,
  });
}

class _ValidatedReturnItem {
  final int lineNo;
  final String productId;
  final String productCode;
  final String productName;
  final String unit;
  final String warehouseId;
  final String warehouseName;
  final double quantity;
  final double unitPrice;
  final double amount;
  final String? reason;
  final String? remark;

  const _ValidatedReturnItem({
    required this.lineNo,
    required this.productId,
    required this.productCode,
    required this.productName,
    required this.unit,
    required this.warehouseId,
    required this.warehouseName,
    required this.quantity,
    required this.unitPrice,
    required this.amount,
    this.reason,
    this.remark,
  });
}

class _ReceiptSourceAggregate {
  final String productCode;
  final String productName;
  final String unit;
  final double receivedQty;

  const _ReceiptSourceAggregate({
    required this.productCode,
    required this.productName,
    required this.unit,
    required this.receivedQty,
  });

  factory _ReceiptSourceAggregate.fromItem(GoodsReceiptItem item) {
    return _ReceiptSourceAggregate(
      productCode: item.productCode,
      productName: item.productName,
      unit: item.unit,
      receivedQty: item.receivedQuantity,
    );
  }

  _ReceiptSourceAggregate accumulate(GoodsReceiptItem item) {
    return _ReceiptSourceAggregate(
      productCode: productCode,
      productName: productName,
      unit: unit,
      receivedQty: receivedQty + item.receivedQuantity,
    );
  }
}
