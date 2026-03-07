// ignore_for_file: avoid_print

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_erp/core/client/api_client.dart';


// Dashboard Stats Model
class DashboardStats {
  final int totalOrders;
  final double totalSales;
  final int totalProducts;
  final int totalCustomers;
  final double todaySales;
  final int todayOrders;
  
  DashboardStats({
    required this.totalOrders,
    required this.totalSales,
    required this.totalProducts,
    required this.totalCustomers,
    required this.todaySales,
    required this.todayOrders,
  });
}

// ✅ Dashboard Provider - ใช้ AsyncNotifierProvider
final dashboardProvider = AsyncNotifierProvider<DashboardNotifier, DashboardStats>(() {
  return DashboardNotifier();
});

class DashboardNotifier extends AsyncNotifier<DashboardStats> {
  @override
  Future<DashboardStats> build() async {
    // ✅ โหลดข้อมูลทันทีเมื่อ build
    return await loadStats();
  }
  
  /// โหลดสถิติ Dashboard
  Future<DashboardStats> loadStats() async {
    try {
      print('📡 Loading dashboard stats...');
      
      final apiClient = ref.read(apiClientProvider);
      
      // ดึงข้อมูลจาก API
      final salesResponse = await apiClient.get('/api/sales');
      final productsResponse = await apiClient.get('/api/products');
      final customersResponse = await apiClient.get('/api/customers');
      
      final orders = salesResponse.data['data'] as List;
      final products = productsResponse.data['data'] as List;
      final customers = customersResponse.data['data'] as List;
      
      // คำนวณยอดขาย
      double totalSales = 0;
      double todaySales = 0;
      int todayOrders = 0;
      
      final today = DateTime.now();
      
      for (var order in orders) {
        final amount = (order['total_amount'] as num).toDouble();
        totalSales += amount;
        
        final orderDate = DateTime.parse(order['order_date']);
        if (orderDate.year == today.year &&
            orderDate.month == today.month &&
            orderDate.day == today.day) {
          todaySales += amount;
          todayOrders++;
        }
      }
      
      final stats = DashboardStats(
        totalOrders: orders.length,
        totalSales: totalSales,
        totalProducts: products.length,
        totalCustomers: customers.length,
        todaySales: todaySales,
        todayOrders: todayOrders,
      );
      
      print('✅ Dashboard stats loaded');
      
      return stats;
    } catch (e) {
      print('❌ Error loading dashboard stats: $e');
      
      // Return default stats if error
      return DashboardStats(
        totalOrders: 0,
        totalSales: 0,
        totalProducts: 0,
        totalCustomers: 0,
        todaySales: 0,
        todayOrders: 0,
      );
    }
  }
  
  /// Refresh
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => loadStats());
  }
}