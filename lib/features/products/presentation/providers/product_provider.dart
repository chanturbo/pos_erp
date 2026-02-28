import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/product_model.dart';

// Product List State
class ProductListState {
  final List<ProductModel> products;
  final bool isLoading;
  final String? error;
  
  ProductListState({
    required this.products,
    required this.isLoading,
    this.error,
  });
  
  ProductListState copyWith({
    List<ProductModel>? products,
    bool? isLoading,
    String? error,
  }) {
    return ProductListState(
      products: products ?? this.products,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

// Product List Provider
final productListProvider = NotifierProvider<ProductListNotifier, ProductListState>(() {
  return ProductListNotifier();
});

class ProductListNotifier extends Notifier<ProductListState> {
  @override
  ProductListState build() {
    // โหลดข้อมูลเมื่อสร้าง
    loadProducts();
    return ProductListState(
      products: [],
      isLoading: true,
    );
  }
  
  /// โหลดรายการสินค้า
  Future<void> loadProducts() async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get('/api/products');
      
      if (response.statusCode == 200) {
        final data = response.data['data'] as List;
        final products = data.map((json) => ProductModel.fromJson(json)).toList();
        state = state.copyWith(products: products, isLoading: false);
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
  
  /// สร้างสินค้าใหม่
  Future<bool> createProduct(Map<String, dynamic> data) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.post('/api/products', data: data);
      
      if (response.statusCode == 200) {
        await loadProducts(); // Reload
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
  
  /// แก้ไขสินค้า
  Future<bool> updateProduct(String productId, Map<String, dynamic> data) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.put('/api/products/$productId', data: data);
      
      if (response.statusCode == 200) {
        await loadProducts(); // Reload
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
  
  /// ลบสินค้า
  Future<bool> deleteProduct(String productId) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.delete('/api/products/$productId');
      
      if (response.statusCode == 200) {
        await loadProducts(); // Reload
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}