// ignore_for_file: avoid_print
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
      print('📡 Loading purchase returns...');

      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get('/api/purchase-returns');

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data['data'] as List;
        final returns = data
            .map((json) => PurchaseReturnModel.fromJson(json as Map<String, dynamic>))
            .toList();

        print('✅ Loaded ${returns.length} returns');
        return returns;
      }

      print('⚠️ No returns data');
      return [];
    } catch (e) {
      print('❌ Error loading returns: $e');
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
      print('📝 Creating purchase return: ${returnDoc.returnNo}');

      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.post(
        '/api/purchase-returns',
        data: returnDoc.toJson(),
      );

      if (response.statusCode == 200) {
        print('✅ Return created successfully');
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error creating return: $e');
      return false;
    }
  }

  /// ยืนยันใบคืนสินค้า (ลดสต๊อก)
  Future<bool> confirmReturn(String returnId) async {
    try {
      print('📝 Confirming return: $returnId');

      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.put('/api/purchase-returns/$returnId/confirm');

      if (response.statusCode == 200) {
        print('✅ Return confirmed successfully');
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error confirming return: $e');
      return false;
    }
  }

  /// ลบใบคืนสินค้า
  Future<bool> deleteReturn(String returnId) async {
    try {
      print('🗑️ Deleting return: $returnId');

      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.delete('/api/purchase-returns/$returnId');

      if (response.statusCode == 200) {
        print('✅ Return deleted successfully');
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error deleting return: $e');
      return false;
    }
  }

  /// ดึงรายละเอียดใบคืนสินค้าพร้อมรายการ
  Future<PurchaseReturnModel?> getReturnDetails(String returnId) async {
    try {
      print('📡 Loading return details: $returnId');

      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get('/api/purchase-returns/$returnId');

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data['data'] as Map<String, dynamic>;
        return PurchaseReturnModel.fromJson(data);
      }

      return null;
    } catch (e) {
      print('❌ Error loading return details: $e');
      return null;
    }
  }
}