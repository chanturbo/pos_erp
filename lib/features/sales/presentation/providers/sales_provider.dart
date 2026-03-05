import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/client/api_client.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/sales_order_model.dart';

// ✅ Sales History Provider - ใช้ AsyncNotifierProvider
final salesHistoryProvider = AsyncNotifierProvider<SalesHistoryNotifier, List<SalesOrderModel>>(() {
  return SalesHistoryNotifier();
});

class SalesHistoryNotifier extends AsyncNotifier<List<SalesOrderModel>> {
  @override
  Future<List<SalesOrderModel>> build() async {
    // ✅ โหลดข้อมูลทันทีเมื่อ build
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
        final orders = data.map((json) => SalesOrderModel.fromJson(json)).toList();
        
        // เรียงตามวันที่ล่าสุด
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
}