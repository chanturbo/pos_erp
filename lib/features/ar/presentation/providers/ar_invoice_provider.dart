// ar_invoice_provider.dart
// Day 36-38: AR Invoice Provider

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/ar_invoice_model.dart';
import '../../../../core/client/api_client.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

/// Provider สำหรับจัดการ AR Invoice List
final arInvoiceListProvider =
    AsyncNotifierProvider<ArInvoiceNotifier, List<ArInvoiceModel>>(
  ArInvoiceNotifier.new,
);

class ArInvoiceNotifier extends AsyncNotifier<List<ArInvoiceModel>> {
  @override
  Future<List<ArInvoiceModel>> build() async {
    // ✅ รอ token ก่อน — ป้องกัน 401
    final authState = ref.watch(authProvider);
    if (authState.isRestoring || !authState.isAuthenticated) return [];
    return loadInvoices();
  }

  Future<List<ArInvoiceModel>> loadInvoices() async {
    try {
      if (kDebugMode) {
        debugPrint('📡 Loading AR invoices...');
      }

      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get('/api/ar-invoices');

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data['data'] as List;
        final invoices = data
            .map((json) =>
                ArInvoiceModel.fromJson(json as Map<String, dynamic>))
            .toList();

        if (kDebugMode) {
          debugPrint('✅ Loaded ${invoices.length} AR invoices');
        }
        return invoices;
      }

      if (kDebugMode) {
        debugPrint('⚠️ No AR invoices data');
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error loading AR invoices: $e');
      }
      return [];
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => loadInvoices());
  }

  /// สร้างใบแจ้งหนี้ใหม่
  Future<bool> createInvoice(ArInvoiceModel invoice) async {
    try {
      if (kDebugMode) {
        debugPrint('📝 Creating AR invoice: ${invoice.invoiceNo}');
      }

      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.post(
        '/api/ar-invoices',
        data: invoice.toJson(),
      );

      if (response.statusCode == 200) {
        if (kDebugMode) {
          debugPrint('✅ AR Invoice created');
        }
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error creating AR invoice: $e');
      }
      return false;
    }
  }

  /// แก้ไขใบแจ้งหนี้
  Future<bool> updateInvoice(ArInvoiceModel invoice) async {
    try {
      if (kDebugMode) {
        debugPrint('📝 Updating AR invoice: ${invoice.invoiceNo}');
      }

      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.put(
        '/api/ar-invoices/${invoice.invoiceId}',
        data: invoice.toJson(),
      );

      if (response.statusCode == 200) {
        if (kDebugMode) {
          debugPrint('✅ AR Invoice updated');
        }
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error updating AR invoice: $e');
      }
      return false;
    }
  }

  /// ลบใบแจ้งหนี้
  Future<bool> deleteInvoice(String invoiceId) async {
    try {
      if (kDebugMode) {
        debugPrint('🗑 Deleting AR invoice: $invoiceId');
      }

      final apiClient = ref.read(apiClientProvider);
      final response =
          await apiClient.delete('/api/ar-invoices/$invoiceId');

      if (response.statusCode == 200 &&
          response.data['success'] == true) {
        if (kDebugMode) {
          debugPrint('✅ AR Invoice deleted');
        }
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error deleting AR invoice: $e');
      }
      return false;
    }
  }
}

/// Provider สำหรับ AR Invoice ของลูกค้าคนเดียว
final arInvoicesByCustomerProvider = FutureProvider.family<
    List<ArInvoiceModel>, String>((ref, customerId) async {
  try {
    final apiClient = ref.read(apiClientProvider);
    final response =
        await apiClient.get('/api/ar-invoices/customer/$customerId');

    if (response.statusCode == 200 && response.data != null) {
      final data = response.data['data'] as List;
      return data
          .map((json) =>
              ArInvoiceModel.fromJson(json as Map<String, dynamic>))
          .toList();
    }
    return [];
  } catch (e) {
    if (kDebugMode) {
      debugPrint('❌ Error loading AR invoices for customer $customerId: $e');
    }
    return [];
  }
});

/// Provider สำหรับ AR Invoice เดี่ยว (พร้อม items)
final arInvoiceDetailProvider =
    FutureProvider.family<ArInvoiceModel?, String>((ref, invoiceId) async {
  try {
    final apiClient = ref.read(apiClientProvider);
    final response = await apiClient.get('/api/ar-invoices/$invoiceId');

    if (response.statusCode == 200 && response.data != null) {
      return ArInvoiceModel.fromJson(
          response.data['data'] as Map<String, dynamic>);
    }
    return null;
  } catch (e) {
    if (kDebugMode) {
      debugPrint('❌ Error loading AR invoice $invoiceId: $e');
    }
    return null;
  }
});