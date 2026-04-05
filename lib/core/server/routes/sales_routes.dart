// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:drift/drift.dart' hide JsonKey;
import '../../database/app_database.dart';
import '../middleware/auth_middleware.dart';
import '../../utils/input_validators.dart';

class SalesRoutes {
  final AppDatabase db;

  SalesRoutes(this.db);

  Router get router {
    final router = Router();

    router.get('/', _getSalesOrdersHandler);
    router.get('/<id>', _getSalesOrderHandler);
    router.post('/', _createSalesOrderHandler);
    router.post('/<id>/complete', _completeOrderHandler);
    router.post('/<id>/cancel', _cancelOrderHandler);
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

      final items = await (db.select(
        db.salesOrderItems,
      )..where((t) => t.orderId.equals(id))).get();

      // ── Fetch promotion names for free items ──────────────────────
      final promoIds = items
          .map((i) => i.promotionId)
          .whereType<String>()
          .toSet()
          .toList();

      final promoMap = <String, String>{};
      if (promoIds.isNotEmpty) {
        final promos = await (db.select(db.promotions)
              ..where((t) => t.promotionId.isIn(promoIds)))
            .get();
        for (final p in promos) {
          promoMap[p.promotionId] = p.promotionName;
        }
      }

      // ── Build coupon_promotion_names map ──────────────────────────
      final couponCodes = order.couponCodes != null
          ? (jsonDecode(order.couponCodes!) as List)
              .map((e) => e.toString())
              .toList()
          : <String>[];

      final couponPromoNames = <String, String>{};
      for (final code in couponCodes) {
        final coupon = await (db.select(db.coupons)
              ..where((t) => t.couponCode.equals(code)))
            .getSingleOrNull();
        if (coupon != null) {
          final name = promoMap[coupon.promotionId] ??
              await _getPromotionName(coupon.promotionId);
          if (name != null) couponPromoNames[code] = name;
        }
      }

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
            'coupon_discount': order.couponDiscount,
            'coupon_codes': couponCodes.isEmpty ? null : couponCodes,
            'coupon_promotion_names':
                couponPromoNames.isEmpty ? null : couponPromoNames,
            'total_amount': order.totalAmount,
            'payment_type': order.paymentType,
            'paid_amount': order.paidAmount,
            'change_amount': order.changeAmount,
            'points_used': order.pointsUsed,
            'status': order.status,
            'items': items
                .map((i) => {
                      'item_id': '${i.orderId}_${i.lineNo}',
                      'order_id': i.orderId,
                      'product_id': i.productId,
                      'product_code': i.productCode,
                      'product_name': i.productName,
                      'quantity': i.quantity,
                      'unit_price': i.unitPrice,
                      'amount': i.amount,
                      'is_free_item': i.isFreeItem,
                      'promotion_id': i.promotionId,
                      'promotion_name': i.promotionId != null
                          ? promoMap[i.promotionId]
                          : null,
                    })
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

  Future<String?> _getPromotionName(String promotionId) async {
    final promo = await (db.select(db.promotions)
          ..where((t) => t.promotionId.equals(promotionId)))
        .getSingleOrNull();
    return promo?.promotionName;
  }

  /// POST /api/sales - สร้างใบขายใหม่
  Future<Response> _createSalesOrderHandler(Request request) async {
    try {
      // ✅ ดึง user จาก context — inject โดย authMiddleware
      final authUser = getAuthUser(request);
      if (authUser == null) {
        return Response(401,
            body: jsonEncode({'success': false, 'message': 'Unauthorized'}),
            headers: {'Content-Type': 'application/json'});
      }

      final payload = await request.readAsString();
      final data = jsonDecode(payload) as Map<String, dynamic>;

      if (data['items'] == null || (data['items'] as List).isEmpty) {
        return Response(400,
            body: jsonEncode({'success': false, 'message': 'ไม่มีรายการสินค้า'}),
            headers: {'Content-Type': 'application/json'});
      }

      final items = data['items'] as List;

      // ✅ Validate รูปแบบ items ก่อน (ไม่ต้องใช้ DB)
      final validationErrors = <String>[];
      for (var i = 0; i < items.length; i++) {
        final item = items[i];
        if (item is! Map) {
          validationErrors.add('รายการที่ ${i + 1}: รูปแบบข้อมูลไม่ถูกต้อง');
          continue;
        }
        validationErrors.addAll(
          InputValidators.validateOrderItem(item as Map<String, dynamic>, i + 1),
        );
      }
      if (validationErrors.isNotEmpty) {
        return Response(400,
            body: jsonEncode({'success': false, 'message': validationErrors.join(', ')}),
            headers: {'Content-Type': 'application/json'});
      }

      final ts = DateTime.now().millisecondsSinceEpoch;
      final now = DateTime.fromMillisecondsSinceEpoch(ts);
      final datePart =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';

      final orderId = 'SO$ts';
      final orderNo = 'SO-$datePart-$ts';
      final warehouseId = data['warehouse_id'] as String? ?? 'WH001';

      // ✅ ใช้ user จาก token แทน hardcode / client-supplied
      final userId = authUser.userId;
      final branchId = authUser.branchId ?? data['branch_id'] as String? ?? 'BR001';

      print('🆔 Generated order: $orderNo (user: $userId)');

      // ─────────────────────────────────────────────────────────────
      // CRITICAL FIX: stock check อยู่ภายใน transaction เดียวกับ insert
      //
      // เดิม: check → [race condition gap] → insert
      //   → 2 requests พร้อมกันผ่าน check ทั้งคู่ → stock ติดลบ
      //
      // ใหม่: BEGIN → check → insert → COMMIT (atomic)
      //   → ถ้า stock ไม่พอ throw → transaction rollback ทันที
      // ─────────────────────────────────────────────────────────────
      print('💾 Starting transaction...');

      // กำหนดสถานะ order: 'OPEN' = จองสต๊อก, 'COMPLETED' = ตัดสต๊อกทันที (POS)
      final orderStatus = data['status'] as String? ?? 'COMPLETED';
      final isOpenOrder = orderStatus == 'OPEN';

      await db.transaction(() async {
        // --- Stock check ภายใน transaction (ใช้ available = balance - reserved) ---
        for (var i = 0; i < items.length; i++) {
          final item = items[i] as Map<String, dynamic>;
          final productId = item['product_id'] as String;
          final quantity = (item['quantity'] as num).toDouble();

          final product = await (db.select(db.products)
                ..where((t) => t.productId.equals(productId)))
              .getSingleOrNull();

          if (product == null) {
            throw _ValidationException('ไม่พบสินค้า $productId');
          }

          if (product.isStockControl && !product.allowNegativeStock) {
            final availableStock = await _getAvailableStock(productId, warehouseId);
            print('📊 Available stock $productId: $availableStock (need: $quantity)');

            if (availableStock < quantity) {
              throw _ValidationException(
                'สต๊อกสินค้า ${product.productName} ไม่เพียงพอ '
                '(คงเหลือ: $availableStock, ต้องการ: $quantity)',
              );
            }
          }
        }

        // --- Insert Sales Order ---
        await db.into(db.salesOrders).insert(
              SalesOrdersCompanion(
                orderId: Value(orderId),
                orderNo: Value(orderNo),
                orderDate: Value(now),
                orderType: const Value('SALE'),
                customerId: Value(data['customer_id'] as String?),
                customerName: Value(data['customer_name'] as String?),
                branchId: Value(branchId),
                warehouseId: Value(warehouseId),
                userId: Value(userId),
                subtotal: Value((data['subtotal'] as num?)?.toDouble() ?? 0),
                discountAmount: Value((data['discount_amount'] as num?)?.toDouble() ?? 0),
                couponDiscount: Value((data['coupon_discount'] as num?)?.toDouble() ?? 0),
                couponCodes: Value(data['coupon_codes'] != null
                    ? jsonEncode(data['coupon_codes'])
                    : null),
                promotionIds: Value(data['promotion_ids'] != null
                    ? jsonEncode(data['promotion_ids'])
                    : null),
                pointsUsed: Value((data['points_used'] as num?)?.toInt() ?? 0),
                amountBeforeVat: Value((data['amount_before_vat'] as num?)?.toDouble() ?? 0),
                vatAmount: Value((data['vat_amount'] as num?)?.toDouble() ?? 0),
                totalAmount: Value((data['total_amount'] as num?)?.toDouble() ?? 0),
                paymentType: Value(data['payment_type'] as String? ?? 'CASH'),
                paidAmount: Value((data['paid_amount'] as num?)?.toDouble() ?? 0),
                changeAmount: Value((data['change_amount'] as num?)?.toDouble() ?? 0),
                status: Value(orderStatus),
              ),
            );
        print('✅ Order inserted: $orderNo (status: $orderStatus)');

        // --- Insert Items ---
        for (var i = 0; i < items.length; i++) {
          final item = items[i] as Map<String, dynamic>;
          final lineNo = i + 1;
          final itemId = '${orderId}_$lineNo';
          final productId = item['product_id'] as String;
          final quantity = (item['quantity'] as num).toDouble();

          await db.into(db.salesOrderItems).insert(
                SalesOrderItemsCompanion(
                  itemId: Value(itemId),
                  orderId: Value(orderId),
                  lineNo: Value(lineNo),
                  productId: Value(productId),
                  productCode: Value(item['product_code'] as String),
                  productName: Value(item['product_name'] as String),
                  unit: Value(item['unit'] as String),
                  quantity: Value(quantity),
                  unitPrice: Value((item['unit_price'] as num).toDouble()),
                  discountPercent: Value((item['discount_percent'] as num?)?.toDouble() ?? 0),
                  discountAmount: Value((item['discount_amount'] as num?)?.toDouble() ?? 0),
                  amount: Value((item['amount'] as num).toDouble()),
                  warehouseId: Value(warehouseId),
                ),
              );

          final product = await (db.select(db.products)
                ..where((t) => t.productId.equals(productId)))
              .getSingleOrNull();

          if (product != null && product.isStockControl) {
            if (isOpenOrder) {
              // OPEN: จองสต๊อก (ยังไม่ตัด)
              await _reserveStock(warehouseId, productId, quantity);
              print('🔒 Reserved: $productId +$quantity');
            } else {
              // COMPLETED: ตัดสต๊อกทันที (POS flow เดิม)
              final movementNo = 'SM-$datePart-$ts-$lineNo';
              await db.into(db.stockMovements).insert(
                    StockMovementsCompanion(
                      movementId: Value(itemId),
                      movementNo: Value(movementNo),
                      movementDate: Value(now),
                      movementType: const Value('SALE'),
                      productId: Value(productId),
                      warehouseId: Value(warehouseId),
                      userId: Value(userId),
                      quantity: Value(-quantity),
                      referenceNo: Value(orderNo),
                      remark: const Value('ขายสินค้า'),
                    ),
                  );
              await _upsertStockBalance(warehouseId, productId, -quantity, 0);
              print('✅ Stock movement: $movementNo (-$quantity)');
            }
          }
        }

        // --- Insert Free Items (BUY_X_GET_Y) + Stock Movements ---
        final freeItemsList = data['free_items'] as List? ?? [];
        for (var i = 0; i < freeItemsList.length; i++) {
          final item = freeItemsList[i] as Map<String, dynamic>;
          final lineNo = items.length + i + 1;
          final itemId = '${orderId}_F$lineNo';
          final productId = item['product_id'] as String;
          final quantity = (item['quantity'] as num).toDouble();
          final promoId = item['promotion_id'] as String?;

          await db.into(db.salesOrderItems).insert(
                SalesOrderItemsCompanion(
                  itemId: Value(itemId),
                  orderId: Value(orderId),
                  lineNo: Value(lineNo),
                  productId: Value(productId),
                  productCode: Value(item['product_code'] as String),
                  productName: Value(item['product_name'] as String),
                  unit: Value(item['unit'] as String),
                  quantity: Value(quantity),
                  unitPrice: const Value(0),
                  discountPercent: const Value(0),
                  discountAmount: const Value(0),
                  amount: const Value(0),
                  warehouseId: Value(warehouseId),
                  isFreeItem: const Value(true),
                  promotionId: Value(promoId),
                ),
              );

          final product = await (db.select(db.products)
                ..where((t) => t.productId.equals(productId)))
              .getSingleOrNull();

          if (product != null && product.isStockControl) {
            if (isOpenOrder) {
              await _reserveStock(warehouseId, productId, quantity);
            } else {
              final movementNo = 'SM-$datePart-$ts-F$lineNo';
              await db.into(db.stockMovements).insert(
                    StockMovementsCompanion(
                      movementId: Value(itemId),
                      movementNo: Value(movementNo),
                      movementDate: Value(now),
                      movementType: const Value('SALE'),
                      productId: Value(productId),
                      warehouseId: Value(warehouseId),
                      userId: Value(userId),
                      quantity: Value(-quantity),
                      referenceNo: Value(orderNo),
                      remark: const Value('สินค้าแถมฟรี'),
                    ),
                  );
              await _upsertStockBalance(warehouseId, productId, -quantity, 0);
              print('✅ Free item stock movement: $movementNo (-$quantity)');
            }
          }
        }
      });

      print('✅ Transaction committed: $orderNo');

      // ── Increment currentUses for applied promotions ────────────
      final promotionIdList = data['promotion_ids'] as List? ?? [];
      final custIdForUsage = data['customer_id'] as String?;
      for (final promoId in promotionIdList) {
        if (promoId is String && promoId.isNotEmpty) {
          await db.customUpdate(
            'UPDATE promotions SET current_uses = current_uses + 1 WHERE promotion_id = ?',
            variables: [Variable.withString(promoId)],
          );
          // บันทึกประวัติการใช้งานโปรโมชั่น
          final usageId = 'PU-$ts-$promoId';
          await db.into(db.promotionUsages).insertOnConflictUpdate(
            PromotionUsagesCompanion(
              usageId:       Value(usageId),
              promotionId:   Value(promoId),
              orderId:       Value(orderId),
              customerId:    Value(custIdForUsage != null &&
                  custIdForUsage != 'WALK_IN' &&
                  custIdForUsage.isNotEmpty ? custIdForUsage : null),
              discountAmount: const Value(0), // BUY_X_GET_Y ไม่มีตัวเลขส่วนลด
            ),
          );
          print('✅ Promotion $promoId usage incremented');
        }
      }

      // ✅ จัดการ loyalty points (นอก transaction เพราะไม่ต้อง rollback)
      final customerId = data['customer_id'] as String?;
      final totalAmount = (data['total_amount'] as num?)?.toDouble() ?? 0;
      // ✅ ใช้ (as num?)?.toInt() ป้องกัน TypeError ถ้า JSON decode เป็น num
      final pointsUsed = (data['points_used'] as num?)?.toInt() ?? 0;
      int earnedPoints = 0;

      if (customerId != null &&
          customerId != 'WALK_IN' &&
          customerId.isNotEmpty) {
        final customer = await (db.select(db.customers)
              ..where((t) => t.customerId.equals(customerId)))
            .getSingleOrNull();

        if (customer != null) {
          var currentPoints = customer.points;

          // ── หักแต้มที่ใช้แลก (ไม่ต้องมี memberNo — ใครมีแต้มก็แลกได้) ──
          if (pointsUsed > 0 && currentPoints >= pointsUsed) {
            currentPoints -= pointsUsed;
            try {
              await db.into(db.pointsTransactions).insert(
                PointsTransactionsCompanion(
                  transactionId: Value('PTX-RDM-$ts'),
                  customerId:    Value(customerId),
                  type:          const Value('REDEEM'),
                  points:        Value(pointsUsed),
                  referenceNo:   Value(orderNo),
                  remark:        Value('แลกแต้มในการขาย $orderNo'),
                ),
              );
            } catch (e) {
              print('⚠️ Points transaction log failed (REDEEM): $e');
            }
            print('🔻 Points redeemed: $customerId -$pointsUsed');
          }

          // ── บวกแต้มที่ได้รับ (เฉพาะลูกค้าที่มี memberNo) ──────────
          if (customer.memberNo != null) {
            const double pointsPerBaht = 100.0;
            if (totalAmount > 0) {
              earnedPoints = (totalAmount / pointsPerBaht).floor();
            }
            if (earnedPoints > 0) {
              currentPoints += earnedPoints;
              try {
                await db.into(db.pointsTransactions).insert(
                  PointsTransactionsCompanion(
                    transactionId: Value('PTX-ERN-$ts'),
                    customerId:    Value(customerId),
                    type:          const Value('EARN'),
                    points:        Value(earnedPoints),
                    referenceNo:   Value(orderNo),
                    remark:        Value('สะสมแต้มจากการซื้อ $orderNo'),
                  ),
                );
              } catch (e) {
                print('⚠️ Points transaction log failed (EARN): $e');
              }
              print('⭐ Points earned: $customerId +$earnedPoints');
            }
          }

          // ── อัปเดตยอดแต้มในฐานข้อมูล ─────────────────────────────
          if (pointsUsed > 0 || earnedPoints > 0) {
            await (db.update(db.customers)
                  ..where((t) => t.customerId.equals(customerId)))
                .write(CustomersCompanion(
              points:    Value(currentPoints),
              updatedAt: Value(DateTime.now()),
            ));
            print('✅ Points balance: $customerId → $currentPoints pts');
          }
        }
      }

      return Response.ok(
        jsonEncode({
          'success': true,
          'message': 'สร้างใบขายสำเร็จ',
          'data': {
            'order_id':      orderId,
            'order_no':      orderNo,
            'earned_points': earnedPoints,
            'points_used':   pointsUsed,
          },
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } on _ValidationException catch (e) {
      // ✅ business validation error → 400 (ไม่ต้อง log stack trace)
      return Response(400,
          body: jsonEncode({'success': false, 'message': e.message}),
          headers: {'Content-Type': 'application/json'});
    } catch (e, stack) {
      print('❌ POST /api/sales error: $e');
      print('Stack trace: $stack');
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': 'เกิดข้อผิดพลาดภายใน กรุณาลองใหม่'}),
      );
    }
  }

  /// POST /api/sales/:id/complete - ชำระเงิน/สรุป order จาก OPEN → COMPLETED
  /// ตัดสต๊อกตาม items, คืนการจอง, อัปเดต payment info
  Future<Response> _completeOrderHandler(Request request, String id) async {
    try {
      final authUser = getAuthUser(request);
      if (authUser == null) {
        return Response(401,
            body: jsonEncode({'success': false, 'message': 'Unauthorized'}),
            headers: {'Content-Type': 'application/json'});
      }

      final order = await (db.select(db.salesOrders)
            ..where((t) => t.orderId.equals(id)))
          .getSingleOrNull();

      if (order == null) {
        return Response.notFound(
          jsonEncode({'success': false, 'message': 'ไม่พบใบขาย'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      if (order.status != 'OPEN') {
        return Response(400,
            body: jsonEncode({
              'success': false,
              'message': 'ใบขายต้องอยู่ในสถานะ OPEN เท่านั้น (ปัจจุบัน: ${order.status})',
            }),
            headers: {'Content-Type': 'application/json'});
      }

      final payload = await request.readAsString();
      final data = payload.isNotEmpty
          ? jsonDecode(payload) as Map<String, dynamic>
          : <String, dynamic>{};

      final items = await (db.select(db.salesOrderItems)
            ..where((t) => t.orderId.equals(id)))
          .get();

      final ts = DateTime.now().millisecondsSinceEpoch;
      final datePart =
          '${order.orderDate.year}${order.orderDate.month.toString().padLeft(2, '0')}${order.orderDate.day.toString().padLeft(2, '0')}';

      await db.transaction(() async {
        // ตัดสต๊อก + คืนการจอง ต่อรายการ
        for (final item in items) {
          final product = await (db.select(db.products)
                ..where((t) => t.productId.equals(item.productId)))
              .getSingleOrNull();

          if (product != null && product.isStockControl) {
            final movementNo = 'SM-$datePart-$ts-${item.lineNo}';
            await db.into(db.stockMovements).insert(
                  StockMovementsCompanion(
                    movementId: Value('${id}_C${item.lineNo}'),
                    movementNo: Value(movementNo),
                    movementDate: Value(DateTime.now()),
                    movementType: const Value('SALE'),
                    productId: Value(item.productId),
                    warehouseId: Value(order.warehouseId),
                    userId: Value(authUser.userId),
                    quantity: Value(-item.quantity),
                    referenceNo: Value(order.orderNo),
                    remark: const Value('ขายสินค้า (complete)'),
                  ),
                );

            // คืนการจอง + อัปเดต qty จริง
            await _releaseReservation(order.warehouseId, item.productId, item.quantity);
            await _upsertStockBalance(order.warehouseId, item.productId, -item.quantity, 0);
            print('✅ Complete: ${item.productId} -${item.quantity}, released reserve');
          }
        }

        // อัปเดตสถานะ order + payment info
        await (db.update(db.salesOrders)
              ..where((t) => t.orderId.equals(id)))
            .write(SalesOrdersCompanion(
          status: const Value('COMPLETED'),
          paymentType: Value(data['payment_type'] as String? ?? order.paymentType),
          paidAmount: Value((data['paid_amount'] as num?)?.toDouble() ?? order.paidAmount),
          changeAmount: Value((data['change_amount'] as num?)?.toDouble() ?? order.changeAmount),
          updatedAt: Value(DateTime.now()),
        ));
      });

      print('✅ SalesRoutes: Order $id completed');

      return Response.ok(
        jsonEncode({'success': true, 'message': 'ชำระเงินสำเร็จ สต๊อกได้รับการอัพเดทแล้ว'}),
        headers: {'Content-Type': 'application/json'},
      );
    } on _ValidationException catch (e) {
      return Response(400,
          body: jsonEncode({'success': false, 'message': e.message}),
          headers: {'Content-Type': 'application/json'});
    } catch (e) {
      print('❌ POST /api/sales/$id/complete error: $e');
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': 'เกิดข้อผิดพลาดภายใน'}),
      );
    }
  }

  /// POST /api/sales/:id/cancel - ยกเลิก OPEN order (คืนการจองสต๊อก)
  Future<Response> _cancelOrderHandler(Request request, String id) async {
    try {
      final order = await (db.select(db.salesOrders)
            ..where((t) => t.orderId.equals(id)))
          .getSingleOrNull();

      if (order == null) {
        return Response.notFound(
          jsonEncode({'success': false, 'message': 'ไม่พบใบขาย'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      if (order.status != 'OPEN') {
        return Response(400,
            body: jsonEncode({
              'success': false,
              'message': 'ยกเลิกได้เฉพาะ order ที่อยู่ในสถานะ OPEN เท่านั้น',
            }),
            headers: {'Content-Type': 'application/json'});
      }

      final items = await (db.select(db.salesOrderItems)
            ..where((t) => t.orderId.equals(id)))
          .get();

      await db.transaction(() async {
        // คืนการจองสต๊อกทุกรายการ
        for (final item in items) {
          final product = await (db.select(db.products)
                ..where((t) => t.productId.equals(item.productId)))
              .getSingleOrNull();

          if (product != null && product.isStockControl) {
            await _releaseReservation(order.warehouseId, item.productId, item.quantity);
            print('🔓 Released reserve: ${item.productId} -${item.quantity}');
          }
        }

        // อัปเดตสถานะ → CANCELLED
        await (db.update(db.salesOrders)
              ..where((t) => t.orderId.equals(id)))
            .write(SalesOrdersCompanion(
          status: const Value('CANCELLED'),
          updatedAt: Value(DateTime.now()),
        ));
      });

      print('✅ SalesRoutes: Order $id cancelled, reservations released');

      return Response.ok(
        jsonEncode({'success': true, 'message': 'ยกเลิก order สำเร็จ สต๊อกที่จองถูกคืนแล้ว'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('❌ POST /api/sales/$id/cancel error: $e');
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': 'เกิดข้อผิดพลาดภายใน'}),
      );
    }
  }

  /// Helper: available stock = balance (movements) - reserved_qty (stock_balances)
  Future<double> _getAvailableStock(String productId, String warehouseId) async {
    final balanceResult = await db.customSelect(
      'SELECT COALESCE(SUM(quantity), 0) as balance FROM stock_movements WHERE product_id = ? AND warehouse_id = ?',
      variables: [Variable.withString(productId), Variable.withString(warehouseId)],
    ).getSingle();

    final balance = balanceResult.read<double>('balance');
    final reserved = await _getReservedQty(productId, warehouseId);
    return balance - reserved;
  }

  /// Helper: ดึง reserved_qty จาก stock_balances
  Future<double> _getReservedQty(String productId, String warehouseId) async {
    final sb = await (db.select(db.stockBalances)
          ..where((s) => s.productId.equals(productId) & s.warehouseId.equals(warehouseId)))
        .getSingleOrNull();
    return sb?.reservedQty ?? 0.0;
  }

  /// Helper: จองสต๊อก (reserved_qty += qty)
  Future<void> _reserveStock(String warehouseId, String productId, double qty) async {
    final existing = await (db.select(db.stockBalances)
          ..where((s) => s.productId.equals(productId) & s.warehouseId.equals(warehouseId)))
        .getSingleOrNull();

    if (existing == null) {
      await db.into(db.stockBalances).insert(StockBalancesCompanion(
        stockId: Value('SB_${productId}_$warehouseId'),
        productId: Value(productId),
        warehouseId: Value(warehouseId),
        reservedQty: Value(qty),
        updatedAt: Value(DateTime.now()),
      ));
    } else {
      await (db.update(db.stockBalances)
            ..where((s) => s.stockId.equals(existing.stockId)))
          .write(StockBalancesCompanion(
        reservedQty: Value(existing.reservedQty + qty),
        updatedAt: Value(DateTime.now()),
      ));
    }
  }

  /// Helper: คืนการจองสต๊อก (reserved_qty -= qty, ไม่ต่ำกว่า 0)
  Future<void> _releaseReservation(String warehouseId, String productId, double qty) async {
    final existing = await (db.select(db.stockBalances)
          ..where((s) => s.productId.equals(productId) & s.warehouseId.equals(warehouseId)))
        .getSingleOrNull();

    if (existing != null) {
      final newReserved = (existing.reservedQty - qty).clamp(0.0, double.infinity);
      await (db.update(db.stockBalances)
            ..where((s) => s.stockId.equals(existing.stockId)))
          .write(StockBalancesCompanion(
        reservedQty: Value(newReserved),
        updatedAt: Value(DateTime.now()),
      ));
    }
  }

  /// Helper: upsert stock_balances quantity + weighted avg cost
  Future<void> _upsertStockBalance(
    String warehouseId,
    String productId,
    double qtyDelta,
    double unitCost,
  ) async {
    final existing = await (db.select(db.stockBalances)
          ..where((s) => s.productId.equals(productId) & s.warehouseId.equals(warehouseId)))
        .getSingleOrNull();

    if (existing == null) {
      final newAvg = (qtyDelta > 0 && unitCost > 0) ? unitCost : 0.0;
      await db.into(db.stockBalances).insert(StockBalancesCompanion(
        stockId: Value('SB_${productId}_$warehouseId'),
        productId: Value(productId),
        warehouseId: Value(warehouseId),
        quantity: Value(qtyDelta),
        avgCost: Value(newAvg),
        lastCost: Value(unitCost > 0 ? unitCost : 0.0),
        updatedAt: Value(DateTime.now()),
      ));
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
          .write(StockBalancesCompanion(
        quantity: Value(newQty),
        avgCost: Value(newAvg),
        lastCost: Value(newLast),
        updatedAt: Value(DateTime.now()),
      ));
    }
  }

  /// PUT /api/sales/:id - แก้ไขสถานะใบขาย
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
      print('❌ PUT /api/sales/$id error: $e');
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': 'เกิดข้อผิดพลาดภายใน กรุณาลองใหม่'}),
      );
    }
  }

  /// DELETE /api/sales/:id - ลบใบขาย
  Future<Response> _deleteSalesOrderHandler(Request request, String id) async {
    try {
      // ✅ เฉพาะ ADMIN/MANAGER เท่านั้น
      return roleGuard(request, [AppRoles.admin, AppRoles.manager], () async {
        await (db.delete(db.salesOrderItems)
              ..where((t) => t.orderId.equals(id)))
            .go();
        await (db.delete(db.salesOrders)
              ..where((t) => t.orderId.equals(id)))
            .go();

        return Response.ok(
          jsonEncode({'success': true, 'message': 'ลบใบขายสำเร็จ'}),
          headers: {'Content-Type': 'application/json'},
        );
      });
    } catch (e) {
      print('❌ DELETE /api/sales/$id error: $e');
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': 'เกิดข้อผิดพลาดภายใน กรุณาลองใหม่'}),
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────────
// Internal exception — throw ภายใน transaction เพื่อ rollback
// catch ด้านนอกแปลงเป็น 400 response
// ─────────────────────────────────────────────────────────────────
class _ValidationException implements Exception {
  final String message;
  const _ValidationException(this.message);
}