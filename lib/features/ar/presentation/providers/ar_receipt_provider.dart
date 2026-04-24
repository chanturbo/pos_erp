// ar_receipt_provider.dart
// Day 39-40: AR Receipt Provider

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/ar_receipt_model.dart';
import '../../../../core/client/api_client.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

/// Provider สำหรับจัดการ AR Receipt List
final arReceiptListProvider =
    AsyncNotifierProvider<ArReceiptNotifier, List<ArReceiptModel>>(
  ArReceiptNotifier.new,
);

class ArReceiptNotifier extends AsyncNotifier<List<ArReceiptModel>> {
  @override
  Future<List<ArReceiptModel>> build() async {
    // ✅ รอ token ก่อน — ป้องกัน 401
    final authState = ref.watch(authProvider);
    if (authState.isRestoring || !authState.isAuthenticated) return [];
    return loadReceipts();
  }

  Future<List<ArReceiptModel>> loadReceipts() async {
    try {
      if (kDebugMode) {
        debugPrint('📡 Loading AR receipts...');
      }

      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get('/api/ar-receipts');

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data['data'] as List;
        final receipts = data
            .map((json) =>
                ArReceiptModel.fromJson(json as Map<String, dynamic>))
            .toList();

        if (kDebugMode) {
          debugPrint('✅ Loaded ${receipts.length} AR receipts');
        }
        return receipts;
      }

      if (kDebugMode) {
        debugPrint('⚠️ No AR receipts data');
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error loading AR receipts: $e');
      }
      return [];
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => loadReceipts());
  }

  /// สร้างใบเสร็จรับเงินใหม่
  Future<bool> createReceipt(ArReceiptModel receipt) async {
    try {
      if (kDebugMode) {
        debugPrint('📝 Creating AR receipt: ${receipt.receiptNo}');
      }

      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.post(
        '/api/ar-receipts',
        data: receipt.toJson(),
      );

      if (response.statusCode == 200) {
        if (kDebugMode) {
          debugPrint('✅ AR Receipt created');
        }
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error creating AR receipt: $e');
      }
      return false;
    }
  }

  /// ลบใบเสร็จ
  Future<bool> deleteReceipt(String receiptId) async {
    try {
      if (kDebugMode) {
        debugPrint('🗑 Deleting AR receipt: $receiptId');
      }

      final apiClient = ref.read(apiClientProvider);
      final response =
          await apiClient.delete('/api/ar-receipts/$receiptId');

      if (response.statusCode == 200 &&
          response.data['success'] == true) {
        if (kDebugMode) {
          debugPrint('✅ AR Receipt deleted');
        }
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error deleting AR receipt: $e');
      }
      return false;
    }
  }
}

/// Provider สำหรับ AR Receipt ของลูกค้าคนเดียว
final arReceiptsByCustomerProvider =
    FutureProvider.family<List<ArReceiptModel>, String>(
        (ref, customerId) async {
  try {
    final apiClient = ref.read(apiClientProvider);
    final response =
        await apiClient.get('/api/ar-receipts/customer/$customerId');

    if (response.statusCode == 200 && response.data != null) {
      final data = response.data['data'] as List;
      return data
          .map((json) =>
              ArReceiptModel.fromJson(json as Map<String, dynamic>))
          .toList();
    }
    return [];
  } catch (e) {
    if (kDebugMode) {
      debugPrint('❌ Error loading AR receipts for customer $customerId: $e');
    }
    return [];
  }
});

/// Provider สำหรับ AR Receipt เดี่ยว (พร้อม allocations)
final arReceiptDetailProvider =
    FutureProvider.family<ArReceiptModel?, String>((ref, receiptId) async {
  try {
    final apiClient = ref.read(apiClientProvider);
    final response = await apiClient.get('/api/ar-receipts/$receiptId');

    if (response.statusCode == 200 && response.data != null) {
      return ArReceiptModel.fromJson(
          response.data['data'] as Map<String, dynamic>);
    }
    return null;
  } catch (e) {
    if (kDebugMode) {
      debugPrint('❌ Error loading AR receipt $receiptId: $e');
    }
    return null;
  }
});