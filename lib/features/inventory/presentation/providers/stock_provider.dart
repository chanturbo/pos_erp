// ignore_for_file: avoid_print

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/client/api_client.dart';
import '../../data/models/stock_balance_model.dart';

// Stock Balance Provider
final stockBalanceProvider = AsyncNotifierProvider<StockBalanceNotifier, List<StockBalanceModel>>(() {
  return StockBalanceNotifier();
});

class StockBalanceNotifier extends AsyncNotifier<List<StockBalanceModel>> {
  @override
  Future<List<StockBalanceModel>> build() async {
    return await loadStockBalance();
  }
  
  /// โหลดสต๊อกคงเหลือ
  Future<List<StockBalanceModel>> loadStockBalance() async {
    try {
      print('📡 Loading stock balance...');
      
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get('/api/stock/balance');
      
      if (response.statusCode == 200) {
        final data = response.data['data'] as List;
        final stocks = data.map((json) => StockBalanceModel.fromJson(json)).toList();
        
        print('✅ Loaded ${stocks.length} stock items');
        
        return stocks;
      } else {
        throw Exception('Failed to load stock balance: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error loading stock balance: $e');
      throw Exception('เกิดข้อผิดพลาด: $e');
    }
  }
  
  /// Refresh
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => loadStockBalance());
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
      print('📦 Stock in: $quantity');
      
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.post('/api/stock/in', data: {
        'product_id': productId,
        'warehouse_id': warehouseId,
        'quantity': quantity,
        'reference_no': referenceNo,
        'remark': remark,
      });
      
      if (response.statusCode == 200) {
        print('✅ Stock in success');
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error stock in: $e');
      return false;
    }
  }
  
  /// เบิกสินค้าออก
  Future<bool> stockOut({
    required String productId,
    required String warehouseId,
    required double quantity,
    String? referenceNo,
    String? remark,
  }) async {
    try {
      print('📤 Stock out: $quantity');
      
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.post('/api/stock/out', data: {
        'product_id': productId,
        'warehouse_id': warehouseId,
        'quantity': quantity,
        'reference_no': referenceNo,
        'remark': remark,
      });
      
      if (response.statusCode == 200) {
        print('✅ Stock out success');
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error stock out: $e');
      return false;
    }
  }
  
  /// ปรับสต๊อก
  Future<bool> adjustStock({
    required String productId,
    required String warehouseId,
    required double newBalance,
    String? referenceNo,
    required String remark,
  }) async {
    try {
      print('📝 Adjust stock to: $newBalance');
      
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.post('/api/stock/adjust', data: {
        'product_id': productId,
        'warehouse_id': warehouseId,
        'new_quantity': newBalance,
        'reference_no': referenceNo,
        'remark': remark,
      });
      
      if (response.statusCode == 200) {
        print('✅ Adjust stock success');
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error adjust stock: $e');
      return false;
    }
  }
  
  /// โอนย้ายสินค้า
  Future<bool> transferStock({
    required String productId,
    required String fromWarehouseId,
    required String toWarehouseId,
    required double quantity,
    String? remark,
  }) async {
    try {
      print('🔄 Transfer stock: $quantity');
      
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.post('/api/stock/transfer', data: {
        'product_id': productId,
        'from_warehouse_id': fromWarehouseId,
        'to_warehouse_id': toWarehouseId,
        'quantity': quantity,
        'remark': remark,
      });
      
      if (response.statusCode == 200) {
        print('✅ Transfer stock success');
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error transfer stock: $e');
      return false;
    }
  }
}