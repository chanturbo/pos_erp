// ignore_for_file: avoid_print

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

// ✅ Product List Provider - ใช้ AsyncNotifierProvider แทน
final productListProvider = AsyncNotifierProvider<ProductListNotifier, List<ProductModel>>(() {
  return ProductListNotifier();
});

class ProductListNotifier extends AsyncNotifier<List<ProductModel>> {
  @override
  Future<List<ProductModel>> build() async {
    // ✅ โหลดข้อมูลทันทีเมื่อ build
    return await loadProducts();
  }
  
  /// โหลดรายการสินค้า
  Future<List<ProductModel>> loadProducts() async {
    try {
      print('📡 Loading products...');
      
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get('/api/products');
      
      if (response.statusCode == 200) {
        final data = response.data['data'] as List;
        final products = data.map((json) => ProductModel.fromJson(json)).toList();
        
        print('✅ Loaded ${products.length} products');
        
        return products;
      } else {
        throw Exception('Failed to load products: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error loading products: $e');
      throw Exception('เกิดข้อผิดพลาด: $e');
    }
  }
  
  /// Refresh - เรียกใช้เมื่อต้องการ reload
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => loadProducts());
  }
  
  /// เพิ่มสินค้า
  Future<bool> addProduct(Map<String, dynamic> productData) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.post('/api/products', data: productData);
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        await refresh(); // Reload
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error adding product: $e');
      return false;
    }
  }
  
  /// แก้ไขสินค้า
  Future<bool> updateProduct(String productId, Map<String, dynamic> productData) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.put('/api/products/$productId', data: productData);
      
      if (response.statusCode == 200) {
        await refresh(); // Reload
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error updating product: $e');
      return false;
    }
  }
  
  /// ลบสินค้า
  Future<bool> deleteProduct(String productId) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.delete('/api/products/$productId');
      
      if (response.statusCode == 200) {
        await refresh(); // Reload
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error deleting product: $e');
      return false;
    }
  }
}