// ignore_for_file: avoid_print
// ar_invoice_provider.dart
// Day 36-38: AR Invoice Provider

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
      print('📡 Loading AR invoices...');

      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get('/api/ar-invoices');

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data['data'] as List;
        final invoices = data
            .map((json) =>
                ArInvoiceModel.fromJson(json as Map<String, dynamic>))
            .toList();

        print('✅ Loaded ${invoices.length} AR invoices');
        return invoices;
      }

      print('⚠️ No AR invoices data');
      return [];
    } catch (e) {
      print('❌ Error loading AR invoices: $e');
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
      print('📝 Creating AR invoice: ${invoice.invoiceNo}');

      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.post(
        '/api/ar-invoices',
        data: invoice.toJson(),
      );

      if (response.statusCode == 200) {
        print('✅ AR Invoice created');
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error creating AR invoice: $e');
      return false;
    }
  }

  /// แก้ไขใบแจ้งหนี้
  Future<bool> updateInvoice(ArInvoiceModel invoice) async {
    try {
      print('📝 Updating AR invoice: ${invoice.invoiceNo}');

      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.put(
        '/api/ar-invoices/${invoice.invoiceId}',
        data: invoice.toJson(),
      );

      if (response.statusCode == 200) {
        print('✅ AR Invoice updated');
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error updating AR invoice: $e');
      return false;
    }
  }

  /// ลบใบแจ้งหนี้
  Future<bool> deleteInvoice(String invoiceId) async {
    try {
      print('🗑 Deleting AR invoice: $invoiceId');

      final apiClient = ref.read(apiClientProvider);
      final response =
          await apiClient.delete('/api/ar-invoices/$invoiceId');

      if (response.statusCode == 200 &&
          response.data['success'] == true) {
        print('✅ AR Invoice deleted');
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error deleting AR invoice: $e');
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
    print('❌ Error loading AR invoices for customer $customerId: $e');
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
    print('❌ Error loading AR invoice $invoiceId: $e');
    return null;
  }
});