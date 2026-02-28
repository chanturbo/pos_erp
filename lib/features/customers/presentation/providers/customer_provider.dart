import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/customer_model.dart';

// Customer List State
class CustomerListState {
  final List<CustomerModel> customers;
  final bool isLoading;
  final String? error;
  
  CustomerListState({
    required this.customers,
    required this.isLoading,
    this.error,
  });
  
  CustomerListState copyWith({
    List<CustomerModel>? customers,
    bool? isLoading,
    String? error,
  }) {
    return CustomerListState(
      customers: customers ?? this.customers,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

// Customer List Provider
final customerListProvider = NotifierProvider<CustomerListNotifier, CustomerListState>(() {
  return CustomerListNotifier();
});

class CustomerListNotifier extends Notifier<CustomerListState> {
  @override
  CustomerListState build() {
    // โหลดข้อมูลเมื่อสร้าง
    loadCustomers();
    return CustomerListState(
      customers: [],
      isLoading: true,
    );
  }
  
  /// โหลดรายการลูกค้า
  Future<void> loadCustomers() async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get('/api/customers');
      
      if (response.statusCode == 200) {
        final data = response.data['data'] as List;
        final customers = data.map((json) => CustomerModel.fromJson(json)).toList();
        state = state.copyWith(customers: customers, isLoading: false);
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'โหลดข้อมูลไม่สำเร็จ',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'เกิดข้อผิดพลาด: $e',
      );
    }
  }
  
  /// สร้างลูกค้าใหม่
  Future<bool> createCustomer(Map<String, dynamic> data) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.post('/api/customers', data: data);
      
      if (response.statusCode == 200) {
        await loadCustomers(); // Reload
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
  
  /// แก้ไขลูกค้า
  Future<bool> updateCustomer(String customerId, Map<String, dynamic> data) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.put('/api/customers/$customerId', data: data);
      
      if (response.statusCode == 200) {
        await loadCustomers(); // Reload
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
  
  /// ลบลูกค้า
  Future<bool> deleteCustomer(String customerId) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.delete('/api/customers/$customerId');
      
      if (response.statusCode == 200) {
        await loadCustomers(); // Reload
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}