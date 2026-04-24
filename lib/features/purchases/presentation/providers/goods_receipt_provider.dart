
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/client/api_client.dart';
import '../../data/models/goods_receipt_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

// ✅ Provider
final goodsReceiptListProvider =
    AsyncNotifierProvider<GoodsReceiptListNotifier, List<GoodsReceiptModel>>(
      () {
        return GoodsReceiptListNotifier();
      },
    );

class GoodsReceiptListNotifier extends AsyncNotifier<List<GoodsReceiptModel>> {
  @override
  Future<List<GoodsReceiptModel>> build() async {
    // ✅ รอ token ก่อน — ป้องกัน 401
    final authState = ref.watch(authProvider);
    if (authState.isRestoring || !authState.isAuthenticated) return [];
    return await loadGoodsReceipts();
  }

  /// โหลดรายการใบรับสินค้า
  Future<List<GoodsReceiptModel>> loadGoodsReceipts() async {
    try {
      if (kDebugMode) {
        debugPrint('📡 Loading goods receipts...');
      }

      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get('/api/goods-receipts');

      if (response.statusCode == 200) {
        final data = response.data['data'] as List;
        final receipts = data
            .map((json) => GoodsReceiptModel.fromJson(json))
            .toList();

        if (kDebugMode) {
          debugPrint('✅ Loaded ${receipts.length} goods receipts');
        }

        return receipts;
      } else {
        throw Exception(
          'Failed to load goods receipts: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error loading goods receipts: $e');
      }
      throw Exception('เกิดข้อผิดพลาด: $e');
    }
  }

  /// Refresh
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => loadGoodsReceipts());
  }

  /// สร้างใบรับสินค้าใหม่
  Future<bool> createGoodsReceipt(GoodsReceiptModel receipt) async {
    try {
      if (kDebugMode) {
        debugPrint('📝 Creating goods receipt...');
      }

      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.post(
        '/api/goods-receipts',
        data: receipt.toJson(),
      );

      if (response.statusCode == 200) {
        if (kDebugMode) {
          debugPrint('✅ Goods receipt created');
        }
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error creating goods receipt: $e');
      }
      return false;
    }
  }

  /// แก้ไขใบรับสินค้า
  Future<bool> updateGoodsReceipt(GoodsReceiptModel receipt) async {
    try {
      if (kDebugMode) {
        debugPrint('📝 Updating goods receipt: ${receipt.grNo}');
      }

      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.put(
        '/api/goods-receipts/${receipt.grId}',
        data: receipt.toJson(),
      );

      if (response.statusCode == 200) {
        if (kDebugMode) {
          debugPrint('✅ Goods receipt updated');
        }
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error updating goods receipt: $e');
      }
      return false;
    }
  }

  /// ลบใบรับสินค้า
  Future<bool> deleteGoodsReceipt(String grId) async {
    try {
      if (kDebugMode) {
        debugPrint('🗑️ Deleting goods receipt: $grId');
      }

      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.delete('/api/goods-receipts/$grId');

      if (response.statusCode == 200) {
        if (kDebugMode) {
          debugPrint('✅ Goods receipt deleted');
        }
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error deleting goods receipt: $e');
      }
      return false;
    }
  }

  /// ยืนยันใบรับสินค้า (บันทึกเข้าสต๊อก)
  Future<bool> confirmGoodsReceipt(String grId) async {
    try {
      if (kDebugMode) {
        debugPrint('✅ Confirming goods receipt: $grId');
      }

      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.post(
        '/api/goods-receipts/$grId/confirm',
      );

      if (response.statusCode == 200) {
        if (kDebugMode) {
          debugPrint('✅ Goods receipt confirmed and stock updated');
        }
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error confirming goods receipt: $e');
      }
      return false;
    }
  }

  /// ดึงรายละเอียดใบรับสินค้า
  Future<GoodsReceiptModel?> getGoodsReceiptDetails(String grId) async {
    try {
      if (kDebugMode) {
        debugPrint('📡 Loading goods receipt details: $grId');
      }

      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get('/api/goods-receipts/$grId');

      if (response.statusCode == 200) {
        final data = response.data['data'];
        final receipt = GoodsReceiptModel.fromJson(data);

        if (kDebugMode) {
          debugPrint('✅ Loaded goods receipt details');
        }

        return receipt;
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error loading goods receipt details: $e');
      }
      return null;
    }
  }

  /// ดึงรายการ PO ที่รอรับสินค้า
  Future<List<Map<String, dynamic>>> getPendingPurchaseOrders() async {
    try {
      if (kDebugMode) {
        debugPrint('📡 Loading pending purchase orders...');
      }

      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get('/api/purchases');

      if (response.statusCode == 200) {
        final data = response.data['data'] as List;

        // Filter เฉพาะ PO ที่อนุมัติแล้ว และยังรับไม่ครบ
        final pendingPOs = data
            .where((po) {
              final status = po['status'] as String;
              return status == 'APPROVED' || status == 'PARTIAL';
            })
            .map((e) => e as Map<String, dynamic>)
            .toList(); // ✅ แก้ไข

        if (kDebugMode) {
          debugPrint('✅ Found ${pendingPOs.length} pending purchase orders');
        }

        return pendingPOs;
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error loading pending purchase orders: $e');
      }
      return [];
    }
  }
}