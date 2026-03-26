// ignore_for_file: avoid_print

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/client/api_client.dart';
import '../../data/models/purchase_order_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

// ✅ Provider
final purchaseListProvider = AsyncNotifierProvider<PurchaseListNotifier, List<PurchaseOrderModel>>(() {
  return PurchaseListNotifier();
});

class PurchaseListNotifier extends AsyncNotifier<List<PurchaseOrderModel>> {
  @override
  Future<List<PurchaseOrderModel>> build() async {
    // ✅ รอ token ก่อน — ป้องกัน 401
    final authState = ref.watch(authProvider);
    if (authState.isRestoring || !authState.isAuthenticated) return [];
    return await loadPurchaseOrders();
  }

  /// โหลดรายการใบสั่งซื้อ
  Future<List<PurchaseOrderModel>> loadPurchaseOrders() async {
    try {
      print('📡 Loading purchase orders...');

      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get('/api/purchases');

      if (response.statusCode == 200) {
        final data = response.data['data'] as List;
        final orders = data.map((json) => PurchaseOrderModel.fromJson(json)).toList();

        print('✅ Loaded ${orders.length} purchase orders');

        return orders;
      } else {
        throw Exception('Failed to load purchase orders: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error loading purchase orders: $e');
      throw Exception('เกิดข้อผิดพลาด: $e');
    }
  }

  /// Refresh
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => loadPurchaseOrders());
  }

  /// สร้างใบสั่งซื้อใหม่
  Future<bool> createPurchaseOrder(PurchaseOrderModel order) async {
    try {
      print('📝 Creating purchase order...');

      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.post(
        '/api/purchases',
        data: order.toJson(),
      );

      if (response.statusCode == 200) {
        print('✅ Purchase order created');
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error creating purchase order: $e');
      return false;
    }
  }

  /// แก้ไขใบสั่งซื้อ
  Future<bool> updatePurchaseOrder(PurchaseOrderModel order) async {
    try {
      print('📝 Updating purchase order: ${order.poNo}');

      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.put(
        '/api/purchases/${order.poId}',
        data: order.toJson(),
      );

      if (response.statusCode == 200) {
        print('✅ Purchase order updated');
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error updating purchase order: $e');
      return false;
    }
  }

  /// ลบใบสั่งซื้อ
  Future<bool> deletePurchaseOrder(String poId) async {
    try {
      print('🗑️ Deleting purchase order: $poId');

      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.delete('/api/purchases/$poId');

      if (response.statusCode == 200) {
        print('✅ Purchase order deleted');
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error deleting purchase order: $e');
      return false;
    }
  }

  /// อนุมัติใบสั่งซื้อ
  Future<bool> approvePurchaseOrder(String poId) async {
    try {
      print('✅ Approving purchase order: $poId');

      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.post('/api/purchases/$poId/approve');

      if (response.statusCode == 200) {
        print('✅ Purchase order approved');
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error approving purchase order: $e');
      return false;
    }
  }

  /// รับสินค้า
  Future<bool> receivePurchaseOrder(String poId, List<Map<String, dynamic>> items) async {
    try {
      print('📦 Receiving items for PO: $poId');

      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.post(
        '/api/purchases/$poId/receive',
        data: {'items': items},
      );

      if (response.statusCode == 200) {
        print('✅ Items received');
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error receiving items: $e');
      return false;
    }
  }

  /// ดึงรายละเอียดใบสั่งซื้อ
  Future<PurchaseOrderModel?> getPurchaseOrderDetails(String poId) async {
    try {
      print('📡 Loading purchase order details: $poId');

      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get('/api/purchases/$poId');

      if (response.statusCode == 200) {
        final data = response.data['data'];
        final order = PurchaseOrderModel.fromJson(data);

        print('✅ Loaded purchase order details');

        return order;
      }
      return null;
    } catch (e) {
      print('❌ Error loading purchase order details: $e');
      return null;
    }
  }
}