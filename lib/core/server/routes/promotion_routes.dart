// ignore_for_file: avoid_print
// promotion_routes.dart
// Day 41-45: Promotion & Coupon API Routes

import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:drift/drift.dart' hide JsonKey;
import '../../database/app_database.dart';

class PromotionRoutes {
  final AppDatabase db;

  PromotionRoutes(this.db);

  Router get router {
    final router = Router();

    // Promotions — specific routes ก่อน wildcard /<id>
    router.get('/', _getPromotionsHandler);
    router.get('/active', _getActivePromotionsHandler);
    router.post('/', _createPromotionHandler);
    router.post('/apply', _applyPromotionHandler);

    // Coupons — ต้องอยู่ก่อน /<id> เพราะ shelf_router match ตามลำดับ
    router.get('/coupons', _getCouponsHandler);
    router.post('/coupons', _createCouponHandler);
    router.post('/coupons/validate', _validateCouponHandler);
    router.put('/coupons/<code>/use', _useCouponHandler);

    // Wildcard routes — ต้องอยู่หลังสุด
    router.get('/<id>', _getPromotionHandler);
    router.put('/<id>', _updatePromotionHandler);
    router.delete('/<id>', _deletePromotionHandler);

    return router;
  }

  // ─── Helper ──────────────────────────────────────────────────────────────
  Map<String, dynamic> _promoToMap(Promotion p) => {
        'promotion_id': p.promotionId,
        'promotion_code': p.promotionCode,
        'promotion_name': p.promotionName,
        'promotion_type': p.promotionType,
        'discount_type': p.discountType,
        'discount_value': p.discountValue,
        'max_discount_amount': p.maxDiscountAmount,
        'buy_qty': p.buyQty,
        'get_qty': p.getQty,
        'get_product_id': p.getProductId,
        'min_amount': p.minAmount,
        'min_qty': p.minQty,
        'apply_to': p.applyTo,
        'apply_to_ids': p.applyToIds,
        'start_date': p.startDate.toIso8601String(),
        'end_date': p.endDate.toIso8601String(),
        'start_time': p.startTime,
        'end_time': p.endTime,
        'apply_days': p.applyDays,
        'max_uses': p.maxUses,
        'max_uses_per_customer': p.maxUsesPerCustomer,
        'current_uses': p.currentUses,
        'is_exclusive': p.isExclusive,
        'is_active': p.isActive,
        'created_at': p.createdAt.toIso8601String(),
        'updated_at': p.updatedAt.toIso8601String(),
      };

  // ─── GET / — รายการ Promotion ทั้งหมด ────────────────────────────────────
  Future<Response> _getPromotionsHandler(Request request) async {
    try {
      final promos = await (db.select(db.promotions)
            ..orderBy([(p) => OrderingTerm.desc(p.createdAt)]))
          .get();

      return Response.ok(
        jsonEncode({'success': true, 'data': promos.map(_promoToMap).toList()}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': '$e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // ─── GET /active — Promotion ที่กำลัง Active ──────────────────────────────
  Future<Response> _getActivePromotionsHandler(Request request) async {
    try {
      final now = DateTime.now();
      final promos = await (db.select(db.promotions)
            ..where((p) =>
                p.isActive.equals(true) &
                p.startDate.isSmallerOrEqualValue(now) &
                p.endDate.isBiggerOrEqualValue(now)))
          .get();

      return Response.ok(
        jsonEncode({'success': true, 'data': promos.map(_promoToMap).toList()}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': '$e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // ─── GET /:id ─────────────────────────────────────────────────────────────
  Future<Response> _getPromotionHandler(Request request, String id) async {
    try {
      final promo = await (db.select(db.promotions)
            ..where((p) => p.promotionId.equals(id)))
          .getSingleOrNull();

      if (promo == null) {
        return Response.notFound(
          jsonEncode({'success': false, 'message': 'Promotion not found'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      return Response.ok(
        jsonEncode({'success': true, 'data': _promoToMap(promo)}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': '$e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // ─── POST / — สร้าง Promotion ─────────────────────────────────────────────
  Future<Response> _createPromotionHandler(Request request) async {
    try {
      final payload = await request.readAsString();
      final data = jsonDecode(payload) as Map<String, dynamic>;

      final promotionId = 'PROMO${DateTime.now().millisecondsSinceEpoch}';

      await db.into(db.promotions).insert(PromotionsCompanion(
            promotionId: Value(promotionId),
            promotionCode: Value(data['promotion_code'] as String),
            promotionName: Value(data['promotion_name'] as String),
            promotionType: Value(data['promotion_type'] as String),
            discountType: Value(data['discount_type'] as String?),
            discountValue:
                Value((data['discount_value'] as num?)?.toDouble() ?? 0),
            maxDiscountAmount:
                Value((data['max_discount_amount'] as num?)?.toDouble()),
            buyQty: Value(data['buy_qty'] as int?),
            getQty: Value(data['get_qty'] as int?),
            getProductId: Value(data['get_product_id'] as String?),
            minAmount:
                Value((data['min_amount'] as num?)?.toDouble() ?? 0),
            minQty: Value((data['min_qty'] as num?)?.toDouble() ?? 0),
            applyTo: Value(data['apply_to'] as String? ?? 'ALL'),
            applyToIds: Value(data['apply_to_ids']),
            startDate:
                Value(DateTime.parse(data['start_date'] as String)),
            endDate: Value(DateTime.parse(data['end_date'] as String)),
            startTime: Value(data['start_time'] as String?),
            endTime: Value(data['end_time'] as String?),
            applyDays: Value(data['apply_days']),
            maxUses: Value(data['max_uses'] as int?),
            maxUsesPerCustomer:
                Value(data['max_uses_per_customer'] as int?),
            isExclusive:
                Value(data['is_exclusive'] as bool? ?? false),
            isActive: Value(data['is_active'] as bool? ?? true),
            createdBy: Value(data['created_by'] as String?),
          ));

      print('✅ PromotionRoutes: Created $promotionId');

      return Response.ok(
        jsonEncode({
          'success': true,
          'message': 'Promotion created',
          'data': {'promotion_id': promotionId}
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('❌ PromotionRoutes: POST / error: $e');
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': '$e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // ─── PUT /:id — แก้ไข Promotion ──────────────────────────────────────────
  Future<Response> _updatePromotionHandler(Request request, String id) async {
    try {
      final payload = await request.readAsString();
      final data = jsonDecode(payload) as Map<String, dynamic>;

      await (db.update(db.promotions)
            ..where((p) => p.promotionId.equals(id)))
          .write(PromotionsCompanion(
        promotionCode: Value(data['promotion_code'] as String),
        promotionName: Value(data['promotion_name'] as String),
        promotionType: Value(data['promotion_type'] as String),
        discountType: Value(data['discount_type'] as String?),
        discountValue:
            Value((data['discount_value'] as num?)?.toDouble() ?? 0),
        maxDiscountAmount:
            Value((data['max_discount_amount'] as num?)?.toDouble()),
        buyQty: Value(data['buy_qty'] as int?),
        getQty: Value(data['get_qty'] as int?),
        getProductId: Value(data['get_product_id'] as String?),
        minAmount: Value((data['min_amount'] as num?)?.toDouble() ?? 0),
        minQty: Value((data['min_qty'] as num?)?.toDouble() ?? 0),
        applyTo: Value(data['apply_to'] as String? ?? 'ALL'),
        applyToIds: Value(data['apply_to_ids']),
        startDate: Value(DateTime.parse(data['start_date'] as String)),
        endDate: Value(DateTime.parse(data['end_date'] as String)),
        startTime: Value(data['start_time'] as String?),
        endTime: Value(data['end_time'] as String?),
        applyDays: Value(data['apply_days']),
        maxUses: Value(data['max_uses'] as int?),
        maxUsesPerCustomer:
            Value(data['max_uses_per_customer'] as int?),
        isExclusive: Value(data['is_exclusive'] as bool? ?? false),
        isActive: Value(data['is_active'] as bool? ?? true),
        updatedAt: Value(DateTime.now()),
      ));

      return Response.ok(
        jsonEncode({'success': true, 'message': 'Promotion updated'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': '$e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // ─── DELETE /:id ──────────────────────────────────────────────────────────
  // Logic:
  //   1. ถ้าเคยมีออเดอร์หรือคูปองที่ใช้แล้ว → block (HAS_ORDERS)
  //   2. ถ้ามีคูปองที่ยังไม่ใช้ และไม่ได้ส่ง force_delete_coupons=true → ถามก่อน
  //   3. ลบได้ทันที (+ ลบคูปองที่ยังไม่ใช้ถ้า force_delete_coupons=true)
  Future<Response> _deletePromotionHandler(Request request, String id) async {
    try {
      final params = request.url.queryParameters;
      final forceDeleteCoupons = params['force_delete_coupons'] == 'true';

      // ── Step 1: ตรวจสอบการใช้งานจริง ──────────────────────────────────
      final usageRow = await db.customSelect(
        'SELECT COUNT(*) AS cnt FROM promotion_usages WHERE promotion_id = ?',
        variables: [Variable.withString(id)],
      ).getSingle();
      final usageCount = (usageRow.data['cnt'] as int?) ?? 0;

      final usedCouponRow = await db.customSelect(
        'SELECT COUNT(*) AS cnt FROM coupons WHERE promotion_id = ? AND is_used = 1',
        variables: [Variable.withString(id)],
      ).getSingle();
      final usedCouponCount = (usedCouponRow.data['cnt'] as int?) ?? 0;

      final totalUsageCount = usageCount + usedCouponCount;

      if (totalUsageCount > 0) {
        return Response.ok(
          jsonEncode({
            'success': false,
            'code': 'HAS_ORDERS',
            'order_count': usageCount,
            'used_coupon_count': usedCouponCount,
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // ── Step 2: ตรวจสอบคูปองที่ยังไม่ถูกใช้ ───────────────────────────
      final unusedCouponRow = await db.customSelect(
        'SELECT COUNT(*) AS cnt FROM coupons WHERE promotion_id = ? AND is_used = 0',
        variables: [Variable.withString(id)],
      ).getSingle();
      final unusedCount = (unusedCouponRow.data['cnt'] as int?) ?? 0;

      if (unusedCount > 0 && !forceDeleteCoupons) {
        return Response.ok(
          jsonEncode({
            'success': false,
            'code': 'HAS_UNUSED_COUPONS',
            'coupon_count': unusedCount,
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // ── Step 3: ลบคูปองที่ยังไม่ใช้ (ถ้า force) แล้วลบโปรโมชั่น ───────
      if (forceDeleteCoupons && unusedCount > 0) {
        await db.customStatement(
          'DELETE FROM coupons WHERE promotion_id = ? AND is_used = 0',
          [id],
        );
      }

      await (db.delete(db.promotions)
            ..where((p) => p.promotionId.equals(id)))
          .go();

      return Response.ok(
        jsonEncode({
          'success': true,
          'message': 'Promotion deleted',
          'coupons_cancelled': forceDeleteCoupons ? unusedCount : 0,
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': '$e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // ─── POST /apply — คำนวณส่วนลด Promotion ─────────────────────────────────
  /// Body: { subtotal, customer_id, items: [{product_id, qty, amount}] }
  Future<Response> _applyPromotionHandler(Request request) async {
    try {
      final payload = await request.readAsString();
      final data = jsonDecode(payload) as Map<String, dynamic>;

      final subtotal = (data['subtotal'] as num).toDouble();
      final now = DateTime.now();

      // ดึง Active Promotions
      final promos = await (db.select(db.promotions)
            ..where((p) =>
                p.isActive.equals(true) &
                p.startDate.isSmallerOrEqualValue(now) &
                p.endDate.isBiggerOrEqualValue(now)))
          .get();

      double totalDiscount = 0;
      final appliedPromos = <Map<String, dynamic>>[];

      for (final promo in promos) {
        // ตรวจ min amount
        if (subtotal < promo.minAmount) continue;

        // ตรวจ usage limit
        if (promo.maxUses != null && promo.currentUses >= promo.maxUses!) {
          continue;
        }

        double discount = 0;

        switch (promo.promotionType) {
          case 'DISCOUNT_PERCENT':
            discount = subtotal * (promo.discountValue / 100);
            if (promo.maxDiscountAmount != null) {
              discount = discount.clamp(0, promo.maxDiscountAmount!);
            }
            break;
          case 'DISCOUNT_AMOUNT':
            discount = promo.discountValue;
            break;
        }

        if (discount > 0) {
          totalDiscount += discount;
          appliedPromos.add({
            'promotion_id': promo.promotionId,
            'promotion_name': promo.promotionName,
            'discount': discount,
          });

          // ถ้า exclusive หยุดทำ promo อื่น
          if (promo.isExclusive) break;
        }
      }

      return Response.ok(
        jsonEncode({
          'success': true,
          'data': {
            'subtotal': subtotal,
            'total_discount': totalDiscount,
            'final_total': subtotal - totalDiscount,
            'applied_promotions': appliedPromos,
          }
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': '$e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // ─── GET /coupons ─────────────────────────────────────────────────────────
  // Query params: page (int), limit (int), status (ALL|VALID|USED|EXPIRED), search (string)
  Future<Response> _getCouponsHandler(Request request) async {
    try {
      final params = request.url.queryParameters;
      final page  = (int.tryParse(params['page']  ?? '1')  ?? 1).clamp(1, 99999);
      final limit = (int.tryParse(params['limit'] ?? '50') ?? 50).clamp(1, 500);
      final status = params['status'] ?? 'ALL';
      // Sanitize search: strip single-quotes to prevent SQL injection
      final search = (params['search'] ?? '').trim().replaceAll("'", "''").toUpperCase();
      final offset = (page - 1) * limit;

      // Unix seconds ณ ปัจจุบัน (Drift เก็บเป็น seconds)
      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // Build filter WHERE clause for paginated query
      final filterParts = <String>[];
      if (search.isNotEmpty) {
        filterParts.add("c.coupon_code LIKE '%$search%'");
      }
      switch (status) {
        case 'VALID':
          filterParts.add(
              "c.is_used = 0 AND (c.expires_at IS NULL OR c.expires_at > $nowSec)");
          break;
        case 'USED':
          filterParts.add("c.is_used = 1");
          break;
        case 'EXPIRED':
          filterParts.add(
              "c.is_used = 0 AND c.expires_at IS NOT NULL AND c.expires_at <= $nowSec");
          break;
      }
      final filterWhere =
          filterParts.isEmpty ? '' : 'WHERE ${filterParts.join(' AND ')}';

      // Drift เก็บ DateTime เป็น integer SECONDS → ต้อง ×1000 ก่อน
      String? secToIso(int? sec) => sec != null
          ? DateTime.fromMillisecondsSinceEpoch(sec * 1000).toIso8601String()
          : null;

      // Count total (filtered)
      final countRow = await db.customSelect(
        'SELECT COUNT(*) AS cnt FROM coupons c $filterWhere',
      ).getSingle();
      final total = countRow.read<int>('cnt');
      final totalPages = total == 0 ? 1 : ((total + limit - 1) ~/ limit);

      // Summary counts (always over ALL coupons, not filtered)
      final sumRow = await db.customSelect('''
        SELECT
          COUNT(*) AS total,
          SUM(CASE WHEN is_used = 1 THEN 1 ELSE 0 END) AS used,
          SUM(CASE WHEN is_used = 0 AND (expires_at IS NULL OR expires_at > $nowSec) THEN 1 ELSE 0 END) AS valid,
          SUM(CASE WHEN is_used = 0 AND expires_at IS NOT NULL AND expires_at <= $nowSec THEN 1 ELSE 0 END) AS expired
        FROM coupons
      ''').getSingle();
      final summary = {
        'total':   sumRow.read<int>('total'),
        'valid':   sumRow.read<int>('valid'),
        'used':    sumRow.read<int>('used'),
        'expired': sumRow.read<int>('expired'),
      };

      // Paginated data
      final results = await db.customSelect('''
        SELECT c.*, p.promotion_name
        FROM coupons c
        LEFT JOIN promotions p ON c.promotion_id = p.promotion_id
        $filterWhere
        ORDER BY c.created_at DESC
        LIMIT $limit OFFSET $offset
      ''').get();

      final data = results.map((row) => {
            'coupon_id':      row.read<String>('coupon_id'),
            'coupon_code':    row.read<String>('coupon_code'),
            'promotion_id':   row.read<String>('promotion_id'),
            'promotion_name': row.read<String?>('promotion_name'),
            'is_used':        row.read<bool>('is_used'),
            'used_by':        row.read<String?>('used_by'),
            'used_at':        secToIso(row.read<int?>('used_at')),
            'expires_at':     secToIso(row.read<int?>('expires_at')),
            'created_at':     secToIso(row.read<int?>('created_at')),
          }).toList();

      return Response.ok(
        jsonEncode({
          'success': true,
          'data': data,
          'page': page,
          'limit': limit,
          'total': total,
          'total_pages': totalPages,
          'summary': summary,
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': '$e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // ─── POST /coupons — สร้าง Coupon ────────────────────────────────────────
  Future<Response> _createCouponHandler(Request request) async {
    try {
      final payload = await request.readAsString();
      final data = jsonDecode(payload) as Map<String, dynamic>;

      final count = data['count'] as int? ?? 1;
      final promotionId = data['promotion_id'] as String;

      // ถ้าไม่ได้ระบุวันหมดอายุ → ใช้ endDate ของโปรโมชั่นเป็น fallback
      DateTime? expiresAt;
      if (data['expires_at'] != null) {
        expiresAt = DateTime.parse(data['expires_at'] as String);
      } else {
        final promo = await (db.select(db.promotions)
              ..where((p) => p.promotionId.equals(promotionId)))
            .getSingleOrNull();
        expiresAt = promo?.endDate;
      }

      final createdCodes = <String>[];

      for (var i = 0; i < count; i++) {
        final couponId = 'CPN${DateTime.now().millisecondsSinceEpoch}$i';
        final couponCode = data['coupon_code'] as String? ??
            _generateCouponCode(promotionId, i);

        await db.into(db.coupons).insert(CouponsCompanion(
              couponId: Value(couponId),
              couponCode: Value(couponCode),
              promotionId: Value(promotionId),
              expiresAt: Value(expiresAt),
            ));

        createdCodes.add(couponCode);
      }

      return Response.ok(
        jsonEncode({
          'success': true,
          'message': 'Coupons created',
          'data': {'codes': createdCodes}
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': '$e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // ─── POST /coupons/validate — ตรวจสอบ Coupon ─────────────────────────────
  Future<Response> _validateCouponHandler(Request request) async {
    try {
      final payload = await request.readAsString();
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final code = (data['coupon_code'] as String).toUpperCase();

      final coupon = await (db.select(db.coupons)
            ..where((c) => c.couponCode.equals(code)))
          .getSingleOrNull();

      if (coupon == null) {
        return Response.ok(
          jsonEncode({'success': false, 'message': 'ไม่พบคูปองนี้'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      if (coupon.isUsed) {
        return Response.ok(
          jsonEncode({'success': false, 'message': 'คูปองนี้ถูกใช้แล้ว'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      if (coupon.expiresAt != null &&
          DateTime.now().isAfter(coupon.expiresAt!)) {
        return Response.ok(
          jsonEncode({'success': false, 'message': 'คูปองหมดอายุแล้ว'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // ดึง Promotion ที่ผูกกับ Coupon
      final promo = await (db.select(db.promotions)
            ..where((p) => p.promotionId.equals(coupon.promotionId)))
          .getSingleOrNull();

      return Response.ok(
        jsonEncode({
          'success': true,
          'message': 'คูปองใช้งานได้',
          'data': {
            'coupon_id': coupon.couponId,
            'coupon_code': coupon.couponCode,
            'promotion_id': coupon.promotionId,
            'promotion_name': promo?.promotionName,
            'promotion_type': promo?.promotionType,
            'discount_type': promo?.discountType,
            'discount_value': promo?.discountValue,
            'max_discount_amount': promo?.maxDiscountAmount,
            'is_exclusive': promo?.isExclusive ?? false,
            'min_amount': promo?.minAmount ?? 0,
          }
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': '$e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // ─── PUT /coupons/:code/use — ใช้งาน Coupon ─────────────────────────────
  Future<Response> _useCouponHandler(Request request, String code) async {
    try {
      final payload = await request.readAsString();
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final customerId = data['customer_id'] as String?;

      await (db.update(db.coupons)
            ..where((c) => c.couponCode.equals(code.toUpperCase())))
          .write(CouponsCompanion(
        isUsed: const Value(true),
        usedBy: Value(customerId),
        usedAt: Value(DateTime.now()),
      ));

      return Response.ok(
        jsonEncode({'success': true, 'message': 'Coupon used'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': '$e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  String _generateCouponCode(String promotionId, int index) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = DateTime.now().millisecondsSinceEpoch + index;
    final code = StringBuffer();
    var seed = random;
    for (var i = 0; i < 8; i++) {
      code.write(chars[seed % chars.length]);
      seed = (seed ~/ chars.length) + (index * 7) + i;
    }
    return code.toString();
  }
}