// ignore_for_file: avoid_print
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/ap_invoice_model.dart';
import '../../../../core/client/api_client.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

/// Provider สำหรับจัดการ AP Invoice List
final apInvoiceListProvider = AsyncNotifierProvider<ApInvoiceNotifier, List<ApInvoiceModel>>(
  ApInvoiceNotifier.new,
);

class ApInvoiceNotifier extends AsyncNotifier<List<ApInvoiceModel>> {
  @override
  Future<List<ApInvoiceModel>> build() async {
    // ✅ รอ token ก่อน — ป้องกัน 401
    final authState = ref.watch(authProvider);
    if (authState.isRestoring || !authState.isAuthenticated) return [];
    return loadInvoices();
  }

  /// โหลดรายการใบแจ้งหนี้
  Future<List<ApInvoiceModel>> loadInvoices() async {
    try {
      print('📡 Loading AP invoices...');

      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get('/api/ap-invoices');

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data['data'] as List;
        final invoices = data
            .map((json) => ApInvoiceModel.fromJson(json as Map<String, dynamic>))
            .toList();

        print('✅ Loaded ${invoices.length} invoices');
        return invoices;
      }

      print('⚠️ No invoices data');
      return [];
    } catch (e) {
      print('❌ Error loading invoices: $e');
      return [];
    }
  }

  /// Refresh
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => loadInvoices());
  }

  /// สร้างใบแจ้งหนี้ใหม่
  Future<bool> createInvoice(ApInvoiceModel invoice) async {
    try {
      print('📝 Creating AP invoice: ${invoice.invoiceNo}');

      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.post(
        '/api/ap-invoices',
        data: invoice.toJson(),
      );

      if (response.statusCode == 200) {
        print('✅ Invoice created successfully');
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error creating invoice: $e');
      return false;
    }
  }

  /// แก้ไขใบแจ้งหนี้
  Future<bool> updateInvoice(ApInvoiceModel invoice) async {
    try {
      print('📝 Updating AP invoice: ${invoice.invoiceNo}');

      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.put(
        '/api/ap-invoices/${invoice.invoiceId}',
        data: invoice.toJson(),
      );

      if (response.statusCode == 200) {
        print('✅ Invoice updated successfully');
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error updating invoice: $e');
      return false;
    }
  }

  /// ลบใบแจ้งหนี้
  Future<bool> deleteInvoice(String invoiceId) async {
    try {
      print('🗑️ Deleting invoice: $invoiceId');

      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.delete('/api/ap-invoices/$invoiceId');

      if (response.statusCode == 200) {
        print('✅ Invoice deleted successfully');
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error deleting invoice: $e');
      return false;
    }
  }

  /// ดึงรายละเอียดใบแจ้งหนี้พร้อมรายการสินค้า
  Future<ApInvoiceModel?> getInvoiceDetails(String invoiceId) async {
    try {
      print('📡 Loading invoice details: $invoiceId');

      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get('/api/ap-invoices/$invoiceId');

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data['data'] as Map<String, dynamic>;
        return ApInvoiceModel.fromJson(data);
      }

      return null;
    } catch (e) {
      print('❌ Error loading invoice details: $e');
      return null;
    }
  }

  /// ดึงรายการใบแจ้งหนี้ของซัพพลายเออร์
  Future<List<ApInvoiceModel>> getInvoicesBySupplier(String supplierId) async {
    try {
      print('📡 Loading invoices for supplier: $supplierId');

      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get('/api/ap-invoices/supplier/$supplierId');

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data['data'] as List;
        final invoices = data
            .map((json) => ApInvoiceModel.fromJson(json as Map<String, dynamic>))
            .toList();

        print('✅ Loaded ${invoices.length} invoices for supplier');
        return invoices;
      }

      return [];
    } catch (e) {
      print('❌ Error loading invoices by supplier: $e');
      return [];
    }
  }

  /// ดึงใบแจ้งหนี้ที่ยังไม่จ่ายเงิน (สำหรับจ่ายเงิน)
  Future<List<ApInvoiceModel>> getUnpaidInvoices(String supplierId) async {
    try {
      final invoices = await getInvoicesBySupplier(supplierId);
      return invoices.where((inv) => !inv.isFullyPaid).toList();
    } catch (e) {
      print('❌ Error loading unpaid invoices: $e');
      return [];
    }
  }
}