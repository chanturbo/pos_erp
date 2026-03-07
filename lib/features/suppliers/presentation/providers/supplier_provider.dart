// ignore_for_file: avoid_print

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/supplier_model.dart';
import '../../../../core/client/api_client.dart';

/// Provider สำหรับจัดการ Supplier List
final supplierListProvider = AsyncNotifierProvider<SupplierNotifier, List<SupplierModel>>(
  SupplierNotifier.new,
);

class SupplierNotifier extends AsyncNotifier<List<SupplierModel>> {
  @override
  Future<List<SupplierModel>> build() async {
    return loadSuppliers();
  }

  /// โหลดรายการ Suppliers
  Future<List<SupplierModel>> loadSuppliers() async {
    try {
      print('📡 Loading suppliers...');

      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get('/api/suppliers');

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data['data'] as List;
        final suppliers = data
            .map((json) => SupplierModel.fromJson(json as Map<String, dynamic>))
            .toList();

        print('✅ Loaded ${suppliers.length} suppliers');
        return suppliers;
      }

      print('⚠️ No suppliers data');
      return [];
    } catch (e) {
      print('❌ Error loading suppliers: $e');
      return [];
    }
  }

  /// Refresh
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => loadSuppliers());
  }

  /// สร้างซัพพลายเออร์ใหม่
  Future<bool> createSupplier(SupplierModel supplier) async {
    try {
      print('📝 Creating supplier: ${supplier.supplierName}');

      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.post(
        '/api/suppliers',
        data: supplier.toJson(),
      );

      if (response.statusCode == 200) {
        print('✅ Supplier created successfully');
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error creating supplier: $e');
      return false;
    }
  }

  /// แก้ไขซัพพลายเออร์
  Future<bool> updateSupplier(SupplierModel supplier) async {
    try {
      print('📝 Updating supplier: ${supplier.supplierName}');

      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.put(
        '/api/suppliers/${supplier.supplierId}',
        data: supplier.toJson(),
      );

      if (response.statusCode == 200) {
        print('✅ Supplier updated successfully');
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error updating supplier: $e');
      return false;
    }
  }

  /// ลบซัพพลายเออร์
  Future<bool> deleteSupplier(String supplierId) async {
    try {
      print('🗑️ Deleting supplier: $supplierId');

      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.delete('/api/suppliers/$supplierId');

      if (response.statusCode == 200) {
        print('✅ Supplier deleted successfully');
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