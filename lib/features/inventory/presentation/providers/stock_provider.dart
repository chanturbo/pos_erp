import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/client/api_client.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/stock_balance_model.dart';
import '../../data/models/stock_movement_model.dart';

// Stock Balance State
class StockBalanceState {
  final List<StockBalanceModel> stocks;
  final bool isLoading;
  final String? error;
  
  StockBalanceState({
    required this.stocks,
    required this.isLoading,
    this.error,
  });
  
  StockBalanceState copyWith({
    List<StockBalanceModel>? stocks,
    bool? isLoading,
    String? error,
  }) {
    return StockBalanceState(
      stocks: stocks ?? this.stocks,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

// Stock Balance Provider
final stockBalanceProvider = NotifierProvider<StockBalanceNotifier, StockBalanceState>(() {
  return StockBalanceNotifier();
});

class StockBalanceNotifier extends Notifier<StockBalanceState> {
  @override
  StockBalanceState build() {
    loadStockBalance();
    return StockBalanceState(
      stocks: [],
      isLoading: true,
    );
  }
  
  /// โหลดสต๊อกคงเหลือ
  Future<void> loadStockBalance() async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get('/api/stock/balance');
      
      if (response.statusCode == 200) {
        final data = response.data['data'] as List;
        final stocks = data.map((json) => StockBalanceModel.fromJson(json)).toList();
        state = state.copyWith(stocks: stocks, isLoading: false);
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
  
  /// รับสินค้าเข้า
  Future<bool> stockIn({
    required String productId,
    required String warehouseId,
    required double quantity,
    String? referenceNo,
    String? remark,
  }) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.post('/api/stock/in', data: {
        'product_id': productId,
        'warehouse_id': warehouseId,
        'quantity': quantity,
        'reference_no': referenceNo,
        'remark': remark,
      });
      
      if (response.statusCode == 200) {
        await loadStockBalance(); // Reload
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
  
  /// เบิกสินค้าออก
  Future<Map<String, dynamic>> stockOut({
    required String productId,
    required String warehouseId,
    required double quantity,
    String? referenceNo,
    String? remark,
  }) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.post('/api/stock/out', data: {
        'product_id': productId,
        'warehouse_id': warehouseId,
        'quantity': quantity,
        'reference_no': referenceNo,
        'remark': remark,
      });
      
      if (response.statusCode == 200) {
        await loadStockBalance(); // Reload
        return {'success': true, 'message': response.data['message']};
      } else {
        return {'success': false, 'message': response.data['message'] ?? 'เบิกสินค้าไม่สำเร็จ'};
      }
    } catch (e) {
      return {'success': false, 'message': 'เกิดข้อผิดพลาด: $e'};
    }
  }
  
  /// ปรับสต๊อก
  Future<bool> adjustStock({
    required String productId,
    required String warehouseId,
    required double newBalance,
    String? referenceNo,
    String? remark,
  }) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.post('/api/stock/adjust', data: {
        'product_id': productId,
        'warehouse_id': warehouseId,
        'new_balance': newBalance,
        'reference_no': referenceNo,
        'remark': remark,
      });
      
      if (response.statusCode == 200) {
        await loadStockBalance(); // Reload
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}