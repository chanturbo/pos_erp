// ignore_for_file: avoid_print
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/ap_payment_model.dart';
import '../../../../core/client/api_client.dart';

/// Provider สำหรับจัดการ AP Payment List
final apPaymentListProvider = AsyncNotifierProvider<ApPaymentNotifier, List<ApPaymentModel>>(
  ApPaymentNotifier.new,
);

class ApPaymentNotifier extends AsyncNotifier<List<ApPaymentModel>> {
  @override
  Future<List<ApPaymentModel>> build() async {
    return loadPayments();
  }

  /// โหลดรายการจ่ายเงิน
  Future<List<ApPaymentModel>> loadPayments() async {
    try {
      print('📡 Loading AP payments...');

      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get('/api/ap-payments');

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data['data'] as List;
        final payments = data
            .map((json) => ApPaymentModel.fromJson(json as Map<String, dynamic>))
            .toList();

        print('✅ Loaded ${payments.length} payments');
        return payments;
      }

      print('⚠️ No payments data');
      return [];
    } catch (e) {
      print('❌ Error loading payments: $e');
      return [];
    }
  }

  /// Refresh
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => loadPayments());
  }

  /// สร้างการจ่ายเงินใหม่
  Future<bool> createPayment(ApPaymentModel payment) async {
    try {
      print('📝 Creating AP payment: ${payment.paymentNo}');

      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.post(
        '/api/ap-payments',
        data: payment.toJson(),
      );

      if (response.statusCode == 200) {
        print('✅ Payment created successfully');
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error creating payment: $e');
      return false;
    }
  }

  /// ลบการจ่ายเงิน
  Future<bool> deletePayment(String paymentId) async {
    try {
      print('🗑️ Deleting payment: $paymentId');

      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.delete('/api/ap-payments/$paymentId');

      if (response.statusCode == 200) {
        print('✅ Payment deleted successfully');
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error deleting payment: $e');
      return false;
    }
  }

  /// ดึงรายละเอียดการจ่ายเงินพร้อม Allocations
  Future<ApPaymentModel?> getPaymentDetails(String paymentId) async {
    try {
      print('📡 Loading payment details: $paymentId');

      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get('/api/ap-payments/$paymentId');

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data['data'] as Map<String, dynamic>;
        return ApPaymentModel.fromJson(data);
      }

      return null;
    } catch (e) {
      print('❌ Error loading payment details: $e');
      return null;
    }
  }
}