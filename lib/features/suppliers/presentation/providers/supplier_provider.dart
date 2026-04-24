
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/supplier_model.dart';
import '../../../../core/client/api_client.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

/// Provider สำหรับจัดการ Supplier List
final supplierListProvider = AsyncNotifierProvider<SupplierNotifier, List<SupplierModel>>(
  SupplierNotifier.new,
);

class SupplierNotifier extends AsyncNotifier<List<SupplierModel>> {
  @override
  Future<List<SupplierModel>> build() async {
    // ✅ รอ token ก่อน — ป้องกัน 401
    final authState = ref.watch(authProvider);
    if (authState.isRestoring || !authState.isAuthenticated) return [];
    return loadSuppliers();
  }

  /// โหลดรายการ Suppliers
  Future<List<SupplierModel>> loadSuppliers() async {
    try {
      if (kDebugMode) {
        debugPrint('📡 Loading suppliers...');
      }

      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get('/api/suppliers');

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data['data'] as List;
        final suppliers = data
            .map((json) => SupplierModel.fromJson(json as Map<String, dynamic>))
            .toList();

        if (kDebugMode) {
          debugPrint('✅ Loaded ${suppliers.length} suppliers');
        }
        return suppliers;
      }

      if (kDebugMode) {
        debugPrint('⚠️ No suppliers data');
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error loading suppliers: $e');
      }
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
      if (kDebugMode) {
        debugPrint('📝 Creating supplier: ${supplier.supplierName}');
      }

      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.post(
        '/api/suppliers',
        data: supplier.toJson(),
      );

      if (response.statusCode == 200) {
        if (kDebugMode) {
          debugPrint('✅ Supplier created successfully');
        }
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error creating supplier: $e');
      }
      return false;
    }
  }

  /// แก้ไขซัพพลายเออร์
  Future<bool> updateSupplier(SupplierModel supplier) async {
    try {
      if (kDebugMode) {
        debugPrint('📝 Updating supplier: ${supplier.supplierName}');
      }

      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.put(
        '/api/suppliers/${supplier.supplierId}',
        data: supplier.toJson(),
      );

      if (response.statusCode == 200) {
        if (kDebugMode) {
          debugPrint('✅ Supplier updated successfully');
        }
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error updating supplier: $e');
      }
      return false;
    }
  }

  /// ตรวจก่อนลบ — คืน {has_history, order_count}
  Future<Map<String, dynamic>> checkDeleteSupplier(String supplierId) async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get('/api/suppliers/$supplierId/check-delete');
      if (res.statusCode == 200) {
        return Map<String, dynamic>.from(res.data as Map);
      }
      return {'success': false};
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error checking supplier delete: $e');
      }
      return {'success': false, 'message': '$e'};
    }
  }

  /// ลบซัพพลายเออร์ — server จัดการ soft-delete ถ้ามีประวัติ
  Future<String?> deleteSupplier(String supplierId) async {
    try {
      if (kDebugMode) {
        debugPrint('🗑️ Deleting supplier: $supplierId');
      }

      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.delete('/api/suppliers/$supplierId');

      if (response.statusCode == 200) {
        if (kDebugMode) {
          debugPrint('✅ Supplier deleted successfully');
        }
        await refresh();
        final msg = response.data?['message'];
        return (msg is String && msg.isNotEmpty) ? msg : 'ดำเนินการสำเร็จ';
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error deleting supplier: $e');
      }
      return null;
    }
  }
}