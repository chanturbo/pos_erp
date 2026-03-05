// ignore_for_file: avoid_print

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/customer_model.dart';

// ✅ Customer List Provider - ใช้ AsyncNotifierProvider
final customerListProvider = AsyncNotifierProvider<CustomerListNotifier, List<CustomerModel>>(() {
  return CustomerListNotifier();
});

class CustomerListNotifier extends AsyncNotifier<List<CustomerModel>> {
  @override
  Future<List<CustomerModel>> build() async {
    // ✅ โหลดข้อมูลทันทีเมื่อ build
    return await loadCustomers();
  }
  
  /// โหลดรายการลูกค้า
  Future<List<CustomerModel>> loadCustomers() async {
    try {
      print('📡 Loading customers...');
      
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get('/api/customers');
      
      if (response.statusCode == 200) {
        final data = response.data['data'] as List;
        final customers = data.map((json) => CustomerModel.fromJson(json)).toList();
        
        print('✅ Loaded ${customers.length} customers');
        
        return customers;
      } else {
        throw Exception('Failed to load customers: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error loading customers: $e');
      throw Exception('เกิดข้อผิดพลาด: $e');
    }
  }
  
  /// Refresh
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => loadCustomers());
  }
  
  /// สร้างลูกค้าใหม่
  Future<bool> createCustomer(Map<String, dynamic> data) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.post('/api/customers', data: data);
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error creating customer: $e');
      return false;
    }
  }
  
  /// แก้ไขลูกค้า
  Future<bool> updateCustomer(String customerId, Map<String, dynamic> data) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.put('/api/customers/$customerId', data: data);
      
      if (response.statusCode == 200) {
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error updating customer: $e');
      return false;
    }
  }
  
  /// ลบลูกค้า
  Future<bool> deleteCustomer(String customerId) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.delete('/api/customers/$customerId');
      
      if (response.statusCode == 200) {
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error deleting customer: $e');
      return false;
    }
  }
}