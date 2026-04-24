import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/ap_payment_model.dart';
import '../../../../core/client/api_client.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

/// Provider สำหรับจัดการ AP Payment List
final apPaymentListProvider = AsyncNotifierProvider<ApPaymentNotifier, List<ApPaymentModel>>(
  ApPaymentNotifier.new,
);

class ApPaymentNotifier extends AsyncNotifier<List<ApPaymentModel>> {
  @override
  Future<List<ApPaymentModel>> build() async {
    // ✅ รอ token ก่อน — ป้องกัน 401
    final authState = ref.watch(authProvider);
    if (authState.isRestoring || !authState.isAuthenticated) return [];
    return loadPayments();
  }

  /// โหลดรายการจ่ายเงิน
  Future<List<ApPaymentModel>> loadPayments() async {
    try {
      if (kDebugMode) {
        debugPrint('📡 Loading AP payments...');
      }

      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get('/api/ap-payments');

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data['data'] as List;
        final payments = data
            .map((json) => ApPaymentModel.fromJson(json as Map<String, dynamic>))
            .toList();

        if (kDebugMode) {
          debugPrint('✅ Loaded ${payments.length} payments');
        }
        return payments;
      }

      if (kDebugMode) {
        debugPrint('⚠️ No payments data');
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error loading payments: $e');
      }
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
      if (kDebugMode) {
        debugPrint('📝 Creating AP payment: ${payment.paymentNo}');
      }

      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.post(
        '/api/ap-payments',
        data: payment.toJson(),
      );

      if (response.statusCode == 200) {
        if (kDebugMode) {
          debugPrint('✅ Payment created successfully');
        }
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error creating payment: $e');
      }
      return false;
    }
  }

  /// ลบการจ่ายเงิน
  Future<bool> deletePayment(String paymentId) async {
    try {
      if (kDebugMode) {
        debugPrint('🗑️ Deleting payment: $paymentId');
      }

      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.delete('/api/ap-payments/$paymentId');

      if (response.statusCode == 200) {
        if (kDebugMode) {
          debugPrint('✅ Payment deleted successfully');
        }
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error deleting payment: $e');
      }
      return false;
    }
  }

  /// ดึงรายละเอียดการจ่ายเงินพร้อม Allocations
  Future<ApPaymentModel?> getPaymentDetails(String paymentId) async {
    try {
      if (kDebugMode) {
        debugPrint('📡 Loading payment details: $paymentId');
      }

      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get('/api/ap-payments/$paymentId');

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data['data'] as Map<String, dynamic>;
        return ApPaymentModel.fromJson(data);
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error loading payment details: $e');
      }
      return null;
    }
  }
}