import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/client/api_client.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/sales_order_model.dart';

// Sales History State
class SalesHistoryState {
  final List<SalesOrderModel> orders;
  final bool isLoading;
  final String? error;
  
  SalesHistoryState({
    required this.orders,
    required this.isLoading,
    this.error,
  });
  
  SalesHistoryState copyWith({
    List<SalesOrderModel>? orders,
    bool? isLoading,
    String? error,
  }) {
    return SalesHistoryState(
      orders: orders ?? this.orders,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

// Sales History Provider
final salesHistoryProvider = NotifierProvider<SalesHistoryNotifier, SalesHistoryState>(() {
  return SalesHistoryNotifier();
});

class SalesHistoryNotifier extends Notifier<SalesHistoryState> {
  @override
  SalesHistoryState build() {
    loadOrders();
    return SalesHistoryState(
      orders: [],
      isLoading: true,
    );
  }
  
  /// โหลดรายการขาย
  Future<void> loadOrders() async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get('/api/sales');
      
      if (response.statusCode == 200) {
        final data = response.data['data'] as List;
        final orders = data.map((json) => SalesOrderModel.fromJson(json)).toList();
        
        // เรียงตามวันที่ล่าสุด
        orders.sort((a, b) => b.orderDate.compareTo(a.orderDate));
        
        state = state.copyWith(orders: orders, isLoading: false);
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'โหลดข้อมูลไม่สำเร็จ',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'เกิดข้อผิดพลาด: $e',
      );
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
      return null;
    }
  }
}