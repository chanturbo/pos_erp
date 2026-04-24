import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/purchase_return_model.dart';
import '../../../../core/client/api_client.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

/// Provider สำหรับจัดการ Purchase Return List
final purchaseReturnListProvider = AsyncNotifierProvider<PurchaseReturnNotifier, List<PurchaseReturnModel>>(
  PurchaseReturnNotifier.new,
);

class PurchaseReturnNotifier extends AsyncNotifier<List<PurchaseReturnModel>> {
  @override
  Future<List<PurchaseReturnModel>> build() async {
    // ✅ รอ token ก่อน — ป้องกัน 401
    final authState = ref.watch(authProvider);
    if (authState.isRestoring || !authState.isAuthenticated) return [];
    return loadReturns();
  }

  /// โหลดรายการคืนสินค้า
  Future<List<PurchaseReturnModel>> loadReturns() async {
    try {
      if (kDebugMode) {
        debugPrint('📡 Loading purchase returns...');
      }

      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get('/api/purchase-returns');

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data['data'] as List;
        final returns = data
            .map((json) => PurchaseReturnModel.fromJson(json as Map<String, dynamic>))
            .toList();

        if (kDebugMode) {
          debugPrint('✅ Loaded ${returns.length} returns');
        }
        return returns;
      }

      if (kDebugMode) {
        debugPrint('⚠️ No returns data');
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error loading returns: $e');
      }
      return [];
    }
  }

  /// Refresh
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => loadReturns());
  }

  /// สร้างใบคืนสินค้าใหม่
  Future<bool> createReturn(PurchaseReturnModel returnDoc) async {
    try {
      if (kDebugMode) {
        debugPrint('📝 Creating purchase return: ${returnDoc.returnNo}');
      }

      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.post(
        '/api/purchase-returns',
        data: returnDoc.toJson(),
      );

      if (response.statusCode == 200) {
        if (kDebugMode) {
          debugPrint('✅ Return created successfully');
        }
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error creating return: $e');
      }
      return false;
    }
  }

  /// แก้ไขใบคืนสินค้า (DRAFT เท่านั้น)
  Future<bool> updateReturn(PurchaseReturnModel returnDoc) async {
    try {
      if (kDebugMode) {
        debugPrint('📝 Updating purchase return: ${returnDoc.returnNo}');
      }

      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.put(
        '/api/purchase-returns/${returnDoc.returnId}',
        data: returnDoc.toJson(),
      );

      if (response.statusCode == 200) {
        if (kDebugMode) {
          debugPrint('✅ Return updated successfully');
        }
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error updating return: $e');
      }
      return false;
    }
  }

  /// ยืนยันใบคืนสินค้า (ลดสต๊อก)
  Future<bool> confirmReturn(String returnId) async {
    try {
      if (kDebugMode) {
        debugPrint('📝 Confirming return: $returnId');
      }

      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.put('/api/purchase-returns/$returnId/confirm');

      if (response.statusCode == 200) {
        if (kDebugMode) {
          debugPrint('✅ Return confirmed successfully');
        }
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error confirming return: $e');
      }
      return false;
    }
  }

  /// ลบใบคืนสินค้า
  Future<bool> deleteReturn(String returnId) async {
    try {
      if (kDebugMode) {
        debugPrint('🗑️ Deleting return: $returnId');
      }

      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.delete('/api/purchase-returns/$returnId');

      if (response.statusCode == 200) {
        if (kDebugMode) {
          debugPrint('✅ Return deleted successfully');
        }
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error deleting return: $e');
      }
      return false;
    }
  }

  /// ดึงรายละเอียดใบคืนสินค้าพร้อมรายการ
  Future<PurchaseReturnModel?> getReturnDetails(String returnId) async {
    try {
      if (kDebugMode) {
        debugPrint('📡 Loading return details: $returnId');
      }

      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get('/api/purchase-returns/$returnId');

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data['data'] as Map<String, dynamic>;
        return PurchaseReturnModel.fromJson(data);
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error loading return details: $e');
      }
      return null;
    }
  }
}
