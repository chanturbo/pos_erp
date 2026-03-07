// ignore_for_file: avoid_print

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/client/api_client.dart';
import '../../data/models/supplier_model.dart';

// Supplier Provider
final supplierListProvider = AsyncNotifierProvider<SupplierListNotifier, List<SupplierModel>>(() {
  return SupplierListNotifier();
});

class SupplierListNotifier extends AsyncNotifier<List<SupplierModel>> {
  @override
  Future<List<SupplierModel>> build() async {
    return await loadSuppliers();
  }

  /// โหลดรายการซัพพลายเออร์
  Future<List<SupplierModel>> loadSuppliers() async {
    try {
      print('📡 Loading suppliers...');

      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get('/api/suppliers');

      if (response.statusCode == 200) {
        final data = response.data['data'] as List;
        final suppliers = data.map((json) => SupplierModel.fromJson(json)).toList();

        print('✅ Loaded ${suppliers.length} suppliers');

        return suppliers;
      } else {
        throw Exception('Failed to load suppliers: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error loading suppliers: $e');
      throw Exception('เกิดข้อผิดพลาด: $e');
    }
  }

  /// Refresh
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => loadSuppliers());
  }

  /// สร้างซัพพลายเอร์ใหม่
  Future<bool> createSupplier(SupplierModel supplier) async {
    try {
      print('📝 Creating supplier: ${supplier.supplierName}');

      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.post(
        '/api/suppliers',
        data: supplier.toJson(),
      );

      if (response.statusCode == 200) {
        print('✅ Supplier created');
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error creating supplier: $e');
      return false;
    }
  }

  /// อัพเดทซัพพลายเอร์
  Future<bool> updateSupplier(SupplierModel supplier) async {
    try {
      print('📝 Updating supplier: ${supplier.supplierName}');

      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.put(
        '/api/suppliers/${supplier.supplierId}',
        data: supplier.toJson(),
      );

      if (response.statusCode == 200) {
        print('✅ Supplier updated');
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error updating supplier: $e');
      return false;
    }
  }

  /// ลบซัพพลายเอร์
  Future<bool> deleteSupplier(String supplierId) async {
    try {
      print('🗑️ Deleting supplier: $supplierId');

      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.delete('/api/suppliers/$supplierId');

      if (response.statusCode == 200) {
        print('✅ Supplier deleted');
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error deleting supplier: $e');
      return false;
    }
  }
}