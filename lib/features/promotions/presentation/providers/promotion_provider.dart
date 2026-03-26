// ignore_for_file: avoid_print
// promotion_provider.dart
// Day 41-45: Promotion Provider

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/promotion_model.dart';
import '../../../../core/client/api_client.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

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
      print('❌ Error loading promotions: $e');
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
      print('❌ Error creating promotion: $e');
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
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error updating promotion: $e');
      return false;
    }
  }

  Future<bool> deletePromotion(String promotionId) async {
    try {
      final api = ref.read(apiClientProvider);
      final res =
          await api.delete('/api/promotions/$promotionId');
      if (res.statusCode == 200 && res.data['success'] == true) {
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error deleting promotion: $e');
      return false;
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
    print('❌ Error loading active promotions: $e');
    return [];
  }
});

// ─── Coupon Provider ──────────────────────────────────────────────────────────
final couponListProvider =
    AsyncNotifierProvider<CouponNotifier, List<CouponModel>>(
  CouponNotifier.new,
);

class CouponNotifier extends AsyncNotifier<List<CouponModel>> {
  @override
  Future<List<CouponModel>> build() async {
    // ✅ รอ token ก่อน — ป้องกัน 401
    final authState = ref.watch(authProvider);
    if (authState.isRestoring || !authState.isAuthenticated) return [];
    return _load();
  }

  Future<List<CouponModel>> _load() async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get('/api/promotions/coupons');
      if (res.statusCode == 200 && res.data != null) {
        final list = res.data['data'] as List;
        return list
            .map((j) => CouponModel.fromJson(j as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      print('❌ Error loading coupons: $e');
      return [];
    }
  }

  Future<void> refresh() async {
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
      print('❌ Error creating coupons: $e');
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
      print('❌ Error validating coupon: $e');
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
    print('❌ Error applying promotions: $e');
    return {'total_discount': 0.0, 'applied_promotions': []};
  }
});