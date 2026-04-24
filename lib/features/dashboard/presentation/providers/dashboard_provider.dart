
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/client/api_client.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

// Dashboard Stats Model
class DashboardStats {
  final int totalOrders;
  final double totalSales;
  final int totalProducts;
  final int totalCustomers;
  final double todaySales;
  final int todayOrders;
  final double last7DaysSales;
  final int last7DaysOrders;
  final double last30DaysSales;
  final int last30DaysOrders;
  final double monthSales;
  final int monthOrders;

  DashboardStats({
    required this.totalOrders,
    required this.totalSales,
    required this.totalProducts,
    required this.totalCustomers,
    required this.todaySales,
    required this.todayOrders,
    required this.last7DaysSales,
    required this.last7DaysOrders,
    required this.last30DaysSales,
    required this.last30DaysOrders,
    required this.monthSales,
    required this.monthOrders,
  });
}

// ✅ Dashboard Provider - ใช้ AsyncNotifierProvider
final dashboardProvider =
    AsyncNotifierProvider<DashboardNotifier, DashboardStats>(() {
      return DashboardNotifier();
    });

class DashboardNotifier extends AsyncNotifier<DashboardStats> {
  @override
  Future<DashboardStats> build() async {
    // ✅ รอ token ก่อน — ป้องกัน 401
    final authState = ref.watch(authProvider);
    if (authState.isRestoring || !authState.isAuthenticated) {
      return DashboardStats(
        totalOrders: 0,
        totalSales: 0,
        totalProducts: 0,
        totalCustomers: 0,
        todaySales: 0,
        todayOrders: 0,
        last7DaysSales: 0,
        last7DaysOrders: 0,
        last30DaysSales: 0,
        last30DaysOrders: 0,
        monthSales: 0,
        monthOrders: 0,
      );
    }
    return await loadStats();
  }

  /// โหลดสถิติ Dashboard
  Future<DashboardStats> loadStats() async {
    try {
      if (kDebugMode) {
        debugPrint('📡 Loading dashboard stats...');
      }

      final apiClient = ref.read(apiClientProvider);

      // ดึงข้อมูลจาก API
      final salesResponse = await apiClient.get('/api/sales');
      final productsResponse = await apiClient.get('/api/products');
      final customersResponse = await apiClient.get('/api/customers');

      final orders = (salesResponse.data['data'] as List?) ?? [];
      final products = (productsResponse.data['data'] as List?) ?? [];
      final customers = (customersResponse.data['data'] as List?) ?? [];

      // คำนวณยอดขาย
      double totalSales = 0;
      double todaySales = 0;
      int todayOrders = 0;
      double last7DaysSales = 0;
      int last7DaysOrders = 0;
      double last30DaysSales = 0;
      int last30DaysOrders = 0;
      double monthSales = 0;
      int monthOrders = 0;

      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      final last7DaysStart = todayStart.subtract(const Duration(days: 6));
      final last30DaysStart = todayStart.subtract(const Duration(days: 29));
      final monthStart = DateTime(today.year, today.month, 1);

      for (var order in orders) {
        final amount = (order['total_amount'] as num).toDouble();
        totalSales += amount;

        final orderDate = DateTime.parse(order['order_date']);
        final orderDay = DateTime(
          orderDate.year,
          orderDate.month,
          orderDate.day,
        );
        if (orderDate.year == today.year &&
            orderDate.month == today.month &&
            orderDate.day == today.day) {
          todaySales += amount;
          todayOrders++;
        }
        if (!orderDay.isBefore(last7DaysStart) &&
            !orderDay.isAfter(todayStart)) {
          last7DaysSales += amount;
          last7DaysOrders++;
        }
        if (!orderDay.isBefore(last30DaysStart) &&
            !orderDay.isAfter(todayStart)) {
          last30DaysSales += amount;
          last30DaysOrders++;
        }
        if (!orderDay.isBefore(monthStart) && !orderDay.isAfter(todayStart)) {
          monthSales += amount;
          monthOrders++;
        }
      }

      final stats = DashboardStats(
        totalOrders: orders.length,
        totalSales: totalSales,
        totalProducts: products.length,
        totalCustomers: customers.length,
        todaySales: todaySales,
        todayOrders: todayOrders,
        last7DaysSales: last7DaysSales,
        last7DaysOrders: last7DaysOrders,
        last30DaysSales: last30DaysSales,
        last30DaysOrders: last30DaysOrders,
        monthSales: monthSales,
        monthOrders: monthOrders,
      );

      if (kDebugMode) {
        debugPrint('✅ Dashboard stats loaded');
      }

      return stats;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error loading dashboard stats: $e');
      }

      // Return default stats if error
      return DashboardStats(
        totalOrders: 0,
        totalSales: 0,
        totalProducts: 0,
        totalCustomers: 0,
        todaySales: 0,
        todayOrders: 0,
        last7DaysSales: 0,
        last7DaysOrders: 0,
        last30DaysSales: 0,
        last30DaysOrders: 0,
        monthSales: 0,
        monthOrders: 0,
      );
    }
  }

  /// Refresh
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => loadStats());
  }
}
