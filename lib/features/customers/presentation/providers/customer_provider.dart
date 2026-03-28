// ignore_for_file: avoid_print

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/client/api_client.dart';
import '../../data/models/customer_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

// ─────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────
final customerListProvider =
    AsyncNotifierProvider<CustomerListNotifier, List<CustomerModel>>(
  CustomerListNotifier.new,
);

class CustomerListNotifier extends AsyncNotifier<List<CustomerModel>> {
  // Pagination state
  int _total = 0;
  int _limit = 500;
  int _offset = 0;
  bool _hasMore = false;

  int get total => _total;
  int get limit => _limit;
  bool get hasMore => _hasMore;

  @override
  Future<List<CustomerModel>> build() async {
    // ✅ รอ token ก่อน — ป้องกัน 401
    final authState = ref.watch(authProvider);
    if (authState.isRestoring || !authState.isAuthenticated) return [];
    return await loadCustomers();
  }

  /// โหลดรายการลูกค้า (รองรับ pagination + server-side search)
  Future<List<CustomerModel>> loadCustomers({
    int limit = 500,
    int offset = 0,
    String search = '',
    bool activeOnly = false,
    bool membersOnly = false,
  }) async {
    try {
      print('📡 Loading customers (limit=$limit offset=$offset search="$search")...');

      final apiClient = ref.read(apiClientProvider);

      // ✅ ส่ง params ให้ server filter — ไม่โหลดทั้งหมดมา filter ใน Dart
      final queryParams = <String, dynamic>{
        'limit': limit,
        'offset': offset,
        if (search.isNotEmpty) 'search': search,
        if (activeOnly) 'active_only': 'true',
      };

      // ✅ สร้าง URL พร้อม query string เอง เพราะ ApiClient.get() ไม่รับ queryParameters
      final queryString = queryParams.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value.toString())}')
          .join('&');
      final path =
          queryString.isEmpty ? '/api/customers' : '/api/customers?$queryString';

      final response = await apiClient.get(path);

      if (response.statusCode == 200) {
        final rawList = (response.data['data'] as List?) ?? [];
        var customers =
            rawList.map((json) => CustomerModel.fromJson(json)).toList();

        // membersOnly filter ยังทำฝั่ง client ได้เพราะเป็น boolean flag
        // ที่ไม่ต้องการ query DB เพิ่มเติม
        if (membersOnly) {
          customers = customers
              .where((c) => c.memberNo != null && c.memberNo!.isNotEmpty)
              .toList();
        }

        // บันทึก pagination info
        final pagination =
            response.data['pagination'] as Map<String, dynamic>? ?? {};
        _total = pagination['total'] as int? ?? customers.length;
        _limit = limit;
        _offset = offset;
        _hasMore = pagination['has_more'] as bool? ?? false;

        print('✅ Loaded ${customers.length} / $_total customers');
        return customers;
      } else {
        throw Exception('Failed to load customers: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error loading customers: $e');
      rethrow;
    }
  }

  /// Refresh — โหลดใหม่จากต้น
  Future<void> refresh({
    String search = '',
    bool activeOnly = false,
    bool membersOnly = false,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => loadCustomers(
        limit: _limit,
        offset: 0,
        search: search,
        activeOnly: activeOnly,
        membersOnly: membersOnly,
      ),
    );
  }

  /// โหลดหน้าถัดไป (infinite scroll)
  Future<void> loadMore({
    String search = '',
    bool activeOnly = false,
    bool membersOnly = false,
  }) async {
    if (!_hasMore) return;
    final current = state.value ?? [];
    final next = await loadCustomers(
      limit: _limit,
      offset: _offset + _limit,
      search: search,
      activeOnly: activeOnly,
      membersOnly: membersOnly,
    );
    state = AsyncValue.data([...current, ...next]);
  }

  /// สร้างลูกค้าใหม่
  Future<bool> createCustomer(Map<String, dynamic> data) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final response =
          await apiClient.post('/api/customers', data: data);

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
  Future<bool> updateCustomer(
      String customerId, Map<String, dynamic> data) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.put(
        '/api/customers/$customerId',
        data: data,
      );

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

  /// ตรวจก่อนลบ — คืน {has_history, has_orders, order_count, has_points}
  Future<Map<String, dynamic>> checkDeleteCustomer(String customerId) async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get('/api/customers/$customerId/check-delete');
      if (res.statusCode == 200) {
        return Map<String, dynamic>.from(res.data as Map);
      }
      return {'success': false};
    } catch (e) {
      print('❌ Error checking customer delete: $e');
      return {'success': false, 'message': '$e'};
    }
  }

  /// ลบลูกค้า (Soft Delete) — คืนค่า message จาก server หรือ null ถ้าเกิดข้อผิดพลาด
  Future<String?> deleteCustomer(String customerId) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.delete('/api/customers/$customerId');

      if (response.statusCode == 200) {
        await refresh();
        final data = response.data is Map ? response.data as Map : {};
        return data['message'] as String? ?? 'ดำเนินการสำเร็จ';
      }
      return null;
    } catch (e) {
      print('❌ Error deleting customer: $e');
      return null;
    }
  }
}