// promotion_provider.dart
// Day 41-45: Promotion Provider

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/promotion_model.dart';
import '../../../../core/client/api_client.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../settings/presentation/pages/settings_page.dart';

// ─── Promotion List Provider ──────────────────────────────────────────────────
final promotionListProvider =
    AsyncNotifierProvider<PromotionNotifier, List<PromotionModel>>(
  PromotionNotifier.new,
);

class PromotionNotifier extends AsyncNotifier<List<PromotionModel>> {
  @override
  Future<List<PromotionModel>> build() async {
    // ✅ รอ token ก่อน — ป้องกัน 401
    final authState = ref.watch(authProvider);
    if (authState.isRestoring || !authState.isAuthenticated) return [];
    return _load();
  }

  Future<List<PromotionModel>> _load() async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get('/api/promotions');
      if (res.statusCode == 200 && res.data != null) {
        final list = res.data['data'] as List;
        return list
            .map((j) => PromotionModel.fromJson(j as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error loading promotions: $e');
      }
      return [];
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_load);
  }

  Future<bool> createPromotion(PromotionModel promo) async {
    try {
      final api = ref.read(apiClientProvider);
      final res =
          await api.post('/api/promotions', data: promo.toJson());
      if (res.statusCode == 200) {
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error creating promotion: $e');
      }
      return false;
    }
  }

  Future<bool> updatePromotion(PromotionModel promo) async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.put(
          '/api/promotions/${promo.promotionId}',
          data: promo.toJson());
      if (res.statusCode == 200) {
        await refresh();
        // sync หน้า POS ให้รับรู้ทันที ว่าโปรโมชั่นนี้เปลี่ยนสถานะแล้ว
        ref.invalidate(activePromotionsProvider);
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error updating promotion: $e');
      }
      return false;
    }
  }

  /// Returns structured result:
  /// - {success: true, coupons_cancelled: N}  → deleted
  /// - {success: false, code: 'HAS_ORDERS', order_count: N, used_coupon_count: M} → blocked
  /// - {success: false, code: 'HAS_UNUSED_COUPONS', coupon_count: N} → needs confirmation
  Future<Map<String, dynamic>> deletePromotion(
    String promotionId, {
    bool forceDeleteCoupons = false,
  }) async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.delete(
        '/api/promotions/$promotionId',
        queryParameters: forceDeleteCoupons
            ? {'force_delete_coupons': 'true'}
            : null,
      );
      if (res.statusCode == 200) {
        final data = Map<String, dynamic>.from(res.data as Map);
        if (data['success'] == true) await refresh();
        return data;
      }
      return {'success': false, 'code': 'UNKNOWN'};
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error deleting promotion: $e');
      }
      return {'success': false, 'code': 'ERROR', 'message': '$e'};
    }
  }
}

// ─── Active Promotions Provider (ใช้ใน POS) ──────────────────────────────────
final activePromotionsProvider =
    FutureProvider<List<PromotionModel>>((ref) async {
  try {
    final api = ref.read(apiClientProvider);
    final res = await api.get('/api/promotions/active');
    if (res.statusCode == 200 && res.data != null) {
      final list = res.data['data'] as List;
      return list
          .map((j) => PromotionModel.fromJson(j as Map<String, dynamic>))
          .toList();
    }
    return [];
  } catch (e) {
    if (kDebugMode) {
      debugPrint('❌ Error loading active promotions: $e');
    }
    return [];
  }
});

// ─── Coupon Page State ────────────────────────────────────────────────────────
class CouponPageState {
  final List<CouponModel> items;
  final int page;
  final int limit;
  final int total;
  final int totalPages;
  final Map<String, int> summary; // {total, valid, used, expired}

  const CouponPageState({
    required this.items,
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
    required this.summary,
  });

  static CouponPageState empty() => const CouponPageState(
        items: [],
        page: 1,
        limit: 50,
        total: 0,
        totalPages: 1,
        summary: {'total': 0, 'valid': 0, 'used': 0, 'expired': 0},
      );

  int get startItem => total == 0 ? 0 : (page - 1) * limit + 1;
  int get endItem   => ((page - 1) * limit + items.length).clamp(0, total);
}

// ─── Coupon Provider ──────────────────────────────────────────────────────────
final couponListProvider =
    AsyncNotifierProvider<CouponNotifier, CouponPageState>(
  CouponNotifier.new,
);

class CouponNotifier extends AsyncNotifier<CouponPageState> {
  int    _page         = 1;
  int    _limit        = 50;   // อัปเดตจาก settingsProvider ใน build()
  String _status       = 'ALL';
  String _search       = '';
  String _expiresFrom  = '';
  String _expiresTo    = '';
  bool   _groupMode    = false;   // โหมดจัดกลุ่ม — โหลดทั้งหมด ไม่ paginate

  bool get isGroupMode => _groupMode;

  @override
  Future<CouponPageState> build() async {
    // ✅ รอ token ก่อน — ป้องกัน 401
    final authState = ref.watch(authProvider);
    if (authState.isRestoring || !authState.isAuthenticated) {
      return CouponPageState.empty();
    }
    // โหลดค่า listPageSize จาก Settings (reactive — rebuild เมื่อ settings เปลี่ยน)
    _limit = ref.watch(settingsProvider).listPageSize;
    return _load();
  }

  Future<CouponPageState> _load() async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get('/api/promotions/coupons', queryParameters: {
        'page':   _groupMode ? '1' : '$_page',
        'limit':  _groupMode ? '9999' : '$_limit',
        'status': _status,
        'search': _search,
        if (_expiresFrom.isNotEmpty) 'expires_from': _expiresFrom,
        if (_expiresTo.isNotEmpty)   'expires_to':   _expiresTo,
      });
      if (res.statusCode == 200 && res.data != null) {
        final d = res.data as Map<String, dynamic>;
        final items = (d['data'] as List)
            .map((j) => CouponModel.fromJson(j as Map<String, dynamic>))
            .toList();
        final rawSummary = d['summary'] as Map<String, dynamic>;
        final summary = rawSummary
            .map((k, v) => MapEntry(k, (v as num).toInt()));
        return CouponPageState(
          items:       items,
          page:        (d['page']        as num).toInt(),
          limit:       (d['limit']       as num).toInt(),
          total:       (d['total']       as num).toInt(),
          totalPages:  (d['total_pages'] as num).toInt(),
          summary:     summary,
        );
      }
      return CouponPageState.empty();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error loading coupons: $e');
      }
      rethrow;
    }
  }

  Future<void> refresh() async {
    _page = 1;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_load);
  }

  Future<void> goToPage(int page) async {
    _page = page;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_load);
  }

  Future<void> applyFilter({
    required String status,
    required String search,
    String expiresFrom = '',
    String expiresTo   = '',
  }) async {
    _page         = 1;
    _status       = status;
    _search       = search;
    _expiresFrom  = expiresFrom;
    _expiresTo    = expiresTo;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_load);
  }

  Future<void> enableGroupMode() async {
    _groupMode = true;
    _page      = 1;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_load);
  }

  Future<void> disableGroupMode() async {
    _groupMode = false;
    _page      = 1;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_load);
  }

  Future<bool> createCoupons({
    required String promotionId,
    int count = 1,
    DateTime? expiresAt,
    String? customCode,
  }) async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.post('/api/promotions/coupons', data: {
        'promotion_id': promotionId,
        'count': count,
        if (expiresAt != null) 'expires_at': expiresAt.toIso8601String(),
        // ignore: use_null_aware_elements
        if (customCode != null) 'coupon_code': customCode,
      });
      if (res.statusCode == 200) {
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error creating coupons: $e');
      }
      return false;
    }
  }

  /// ตรวจสอบ Coupon Code — คืน CouponModel ถ้า valid, null ถ้าไม่ valid
  Future<Map<String, dynamic>?> validateCoupon(String code) async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.post('/api/promotions/coupons/validate',
          data: {'coupon_code': code.toUpperCase()});
      if (res.statusCode == 200 && res.data['success'] == true) {
        return res.data['data'] as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error validating coupon: $e');
      }
      return null;
    }
  }
}

// ─── Apply Promotion Provider (คำนวณส่วนลดใน POS) ────────────────────────────
final applyPromotionProvider = FutureProvider.family<
    Map<String, dynamic>,
    Map<String, dynamic>>((ref, params) async {
  try {
    final api = ref.read(apiClientProvider);
    final res =
        await api.post('/api/promotions/apply', data: params);
    if (res.statusCode == 200 && res.data != null) {
      return res.data['data'] as Map<String, dynamic>;
    }
    return {'total_discount': 0.0, 'applied_promotions': []};
  } catch (e) {
    if (kDebugMode) {
      debugPrint('❌ Error applying promotions: $e');
    }
    return {'total_discount': 0.0, 'applied_promotions': []};
  }
});