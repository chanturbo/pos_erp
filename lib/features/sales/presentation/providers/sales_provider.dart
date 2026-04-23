// ignore_for_file: avoid_print

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/client/api_client.dart';
import '../../data/models/sales_order_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../settings/presentation/pages/settings_page.dart';

// ── Points Config ────────────────────────────────────────────────
// ✅ Week 5: ทุก 100 บาท ได้ 1 คะแนน (ปรับได้)
const int kPointsPerBaht = 100; // ใช้ 100 บาท/1 point

/// คำนวณ points ที่จะได้รับจากยอดซื้อ
int calculateEarnedPoints(double totalAmount) {
  return (totalAmount / kPointsPerBaht).floor();
}

// ─────────────────────────────────────────────────────────────────
// Sales History Provider
// ─────────────────────────────────────────────────────────────────
final salesHistoryProvider =
    AsyncNotifierProvider<SalesHistoryNotifier, List<SalesOrderModel>>(() {
      return SalesHistoryNotifier();
    });

final takeawayOrdersProvider = Provider<List<SalesOrderModel>>((ref) {
  final orders = ref
      .watch(salesHistoryProvider)
      .maybeWhen(
        data: (value) => value,
        orElse: () => const <SalesOrderModel>[],
      );
  final takeawayOrders =
      orders
          .where((order) => order.serviceType?.toUpperCase() == 'TAKEAWAY')
          .toList()
        ..sort((a, b) => b.orderDate.compareTo(a.orderDate));
  return takeawayOrders;
});

final takeawayOpenOrdersProvider = Provider<List<SalesOrderModel>>((ref) {
  return ref
      .watch(takeawayOrdersProvider)
      .where((order) => order.status.toUpperCase() == 'OPEN')
      .toList();
});

final takeawayOpenOrdersCountProvider = Provider<int>((ref) {
  return ref.watch(takeawayOpenOrdersProvider).length;
});

final takeawayPollingProvider = Provider.autoDispose.family<void, Duration?>((
  ref,
  pollingIntervalOverride,
) {
  final authState = ref.watch(authProvider);
  if (authState.isRestoring || !authState.isAuthenticated) return;

  final settings = ref.watch(settingsProvider);
  if (!settings.takeawayAutoRefreshEnabled) return;

  final interval =
      pollingIntervalOverride ??
      Duration(seconds: settings.takeawayPollingIntervalSeconds);

  if (interval <= Duration.zero) return;

  final timer = Timer.periodic(interval, (_) {
    ref.read(salesHistoryProvider.notifier).refreshSilently();
  });
  ref.onDispose(timer.cancel);
});

class SalesHistoryNotifier extends AsyncNotifier<List<SalesOrderModel>> {
  @override
  Future<List<SalesOrderModel>> build() async {
    // ✅ รอ token ก่อน — ป้องกัน 401
    final authState = ref.watch(authProvider);
    if (authState.isRestoring || !authState.isAuthenticated) return [];
    return await loadOrders();
  }

  /// โหลดรายการขาย
  Future<List<SalesOrderModel>> loadOrders() async {
    try {
      print('📡 Loading sales orders...');
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get('/api/sales');

      if (response.statusCode == 200) {
        final data = response.data['data'] as List;
        final orders = data
            .map((json) => SalesOrderModel.fromJson(json))
            .toList();
        orders.sort((a, b) => b.orderDate.compareTo(a.orderDate));
        print('✅ Loaded ${orders.length} orders');
        return orders;
      } else {
        throw Exception('Failed to load orders: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error loading orders: $e');
      throw Exception('เกิดข้อผิดพลาด: $e');
    }
  }

  /// Refresh
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => loadOrders());
  }

  Future<void> refreshSilently() async {
    try {
      final orders = await loadOrders();
      state = AsyncValue.data(orders);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// ดึงรายละเอียดใบขาย
  Future<SalesOrderModel?> getOrderDetails(String orderId) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get('/api/sales/$orderId');
      if (response.statusCode == 200) {
        return SalesOrderModel.fromJson(response.data['data']);
      }
      return null;
    } catch (e) {
      print('❌ Error getting order details: $e');
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // ✅ Week 5: Member Points
  // ─────────────────────────────────────────────────────────────

  /// บวก Points ให้ลูกค้าหลังขายสำเร็จ
  /// เรียกจาก payment_page.dart หลัง POST /api/sales สำเร็จ
  Future<bool> addPointsToCustomer({
    required String customerId,
    required double totalAmount,
  }) async {
    if (customerId == 'WALK_IN') return false; // ลูกค้าทั่วไปไม่สะสมแต้ม

    final points = calculateEarnedPoints(totalAmount);
    if (points <= 0) return false;

    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.put(
        '/api/customers/$customerId/points',
        data: {
          'action': 'add',
          'points': points,
          'remark':
              'สะสมแต้มจากการซื้อสินค้า ฿${totalAmount.toStringAsFixed(2)}',
        },
      );
      if (response.statusCode == 200) {
        print('✅ Added $points points to customer $customerId');
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error adding points: $e');
      return false;
    }
  }

  /// ดึง points ปัจจุบันของลูกค้า
  Future<int> getCustomerPoints(String customerId) async {
    if (customerId == 'WALK_IN') return 0;
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get('/api/customers/$customerId');
      if (response.statusCode == 200) {
        return (response.data['data']['points'] as int?) ?? 0;
      }
      return 0;
    } catch (e) {
      print('❌ Error getting points: $e');
      return 0;
    }
  }

  /// หัก Points (redeem) — สำหรับอนาคต
  Future<bool> redeemPoints({
    required String customerId,
    required int points,
    required String remark,
  }) async {
    if (customerId == 'WALK_IN') return false;
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.put(
        '/api/customers/$customerId/points',
        data: {'action': 'deduct', 'points': points, 'remark': remark},
      );
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Error redeeming points: $e');
      return false;
    }
  }
}
