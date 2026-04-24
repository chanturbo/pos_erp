import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/client/api_client.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../data/models/user_management_model.dart';

// ─────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────
final userListProvider =
    AsyncNotifierProvider<UserListNotifier, List<UserManagementModel>>(
  UserListNotifier.new,
);

class UserListNotifier extends AsyncNotifier<List<UserManagementModel>> {
  @override
  Future<List<UserManagementModel>> build() async {
    final auth = ref.watch(authProvider);
    if (auth.isRestoring || !auth.isAuthenticated) return [];
    return _fetchAll();
  }

  Future<List<UserManagementModel>> _fetchAll() async {
    final api = ref.read(apiClientProvider);
    final res = await api.get('/api/users');
    if (res.statusCode == 200) {
      final list = (res.data['data'] as List?) ?? [];
      return list
          .map((j) => UserManagementModel.fromJson(j as Map<String, dynamic>))
          .toList();
    }
    throw Exception(res.data['message'] ?? 'โหลดรายการผู้ใช้ไม่สำเร็จ');
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetchAll);
  }

  // ── Create ────────────────────────────────────────────────────
  Future<void> createUser({
    required String username,
    required String password,
    required String fullName,
    String? email,
    String? phone,
    String? roleId,
    String? branchId,
  }) async {
    final api = ref.read(apiClientProvider);
    final res = await api.post('/api/users', data: {
      'username':  username,
      'password':  password,
      'full_name': fullName,
      'email':     email,
      'phone':     phone,
      'role_id':   roleId,
      'branch_id': branchId,
    });

    if (res.statusCode != 200) {
      throw Exception(res.data['message'] ?? 'สร้างผู้ใช้ไม่สำเร็จ');
    }
    await refresh();
  }

  // ── Update ────────────────────────────────────────────────────
  Future<void> updateUser({
    required String userId,
    required String fullName,
    String? email,
    String? phone,
    String? roleId,
    String? branchId,
  }) async {
    final api = ref.read(apiClientProvider);
    final res = await api.put('/api/users/$userId', data: {
      'full_name':  fullName,
      'email':      email,
      'phone':      phone,
      'role_id':    roleId,
      'branch_id':  branchId,
    });

    if (res.statusCode != 200) {
      throw Exception(res.data['message'] ?? 'บันทึกข้อมูลไม่สำเร็จ');
    }
    await refresh();
  }

  // ── Change Password ───────────────────────────────────────────
  Future<void> changePassword({
    required String userId,
    required String newPassword,
    String? oldPassword,
  }) async {
    final api = ref.read(apiClientProvider);
    final res = await api.put('/api/users/$userId/password', data: {
      'new_password': newPassword,
      ...?( oldPassword != null ? {'old_password': oldPassword} : null ),
    });

    if (res.statusCode != 200) {
      throw Exception(res.data['message'] ?? 'เปลี่ยนรหัสผ่านไม่สำเร็จ');
    }
  }

  // ── Toggle Active ─────────────────────────────────────────────
  Future<void> toggleActive(String userId) async {
    final api = ref.read(apiClientProvider);
    final res = await api.put('/api/users/$userId/toggle', data: {});

    if (res.statusCode != 200) {
      throw Exception(res.data['message'] ?? 'เปลี่ยนสถานะไม่สำเร็จ');
    }
    await refresh();
  }
}
