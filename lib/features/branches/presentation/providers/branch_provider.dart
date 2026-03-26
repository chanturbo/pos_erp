// ignore_for_file: avoid_print
// branch_provider.dart — Week 7

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../data/models/branch_model.dart';
import '../../../../core/client/api_client.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/config/app_mode.dart';

// ── Branch Provider ───────────────────────────────────────────────────────────
final branchListProvider =
    AsyncNotifierProvider<BranchNotifier, List<BranchModel>>(
  BranchNotifier.new,
);

class BranchNotifier extends AsyncNotifier<List<BranchModel>> {
  @override
  Future<List<BranchModel>> build() async {
    // ✅ รอ token ก่อน — ป้องกัน 401
    final authState = ref.watch(authProvider);
    if (authState.isRestoring || !authState.isAuthenticated) return [];
    return _load();
  }

  Future<List<BranchModel>> _load() async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get('/api/branches');
      if (res.statusCode == 200) {
        return (res.data['data'] as List)
            .map((j) => BranchModel.fromJson(j as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      print('❌ Error loading branches: $e');
      return [];
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_load);
  }

  Future<bool> createBranch(BranchModel branch) async {
    try {
      final api = ref.read(apiClientProvider);
      final res =
          await api.post('/api/branches', data: branch.toJson());
      if (res.statusCode == 200) {
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error creating branch: $e');
      return false;
    }
  }

  Future<bool> updateBranch(BranchModel branch) async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.put(
          '/api/branches/${branch.branchId}',
          data: branch.toJson());
      if (res.statusCode == 200) {
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error updating branch: $e');
      return false;
    }
  }

  Future<bool> deleteBranch(String branchId) async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.delete('/api/branches/$branchId');
      if (res.statusCode == 200) {
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error deleting branch: $e');
      return false;
    }
  }
}

// ── Warehouse Provider ────────────────────────────────────────────────────────
final warehouseListProvider =
    AsyncNotifierProvider<WarehouseNotifier, List<WarehouseModel>>(
  WarehouseNotifier.new,
);

class WarehouseNotifier extends AsyncNotifier<List<WarehouseModel>> {
  @override
  Future<List<WarehouseModel>> build() async {
    // ✅ รอ token ก่อน — ป้องกัน 401
    final authState = ref.watch(authProvider);
    if (authState.isRestoring || !authState.isAuthenticated) return [];
    return _load();
  }

  Future<List<WarehouseModel>> _load() async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get('/api/branches/warehouses');
      if (res.statusCode == 200) {
        return (res.data['data'] as List)
            .map((j) =>
                WarehouseModel.fromJson(j as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      print('❌ Error loading warehouses: $e');
      return [];
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_load);
  }

  Future<bool> createWarehouse(WarehouseModel wh) async {
    try {
      final api = ref.read(apiClientProvider);
      final res =
          await api.post('/api/branches/warehouses', data: wh.toJson());
      if (res.statusCode == 200) {
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error creating warehouse: $e');
      return false;
    }
  }

  Future<bool> updateWarehouse(WarehouseModel wh) async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.put(
          '/api/branches/warehouses/${wh.warehouseId}',
          data: wh.toJson());
      if (res.statusCode == 200) {
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error updating warehouse: $e');
      return false;
    }
  }
}

// ── Sync Status Provider ──────────────────────────────────────────────────────
final syncStatusProvider =
    FutureProvider<SyncStatusModel>((ref) async {
  try {
    final api = ref.read(apiClientProvider);
    final res = await api.get('/api/branches/sync/status');
    if (res.statusCode == 200) {
      final d = res.data['data'] as Map<String, dynamic>;
      return SyncStatusModel(
        pendingCount: d['pending_count'] as int? ?? 0,
        failedCount: d['failed_count'] as int? ?? 0,
        lastSyncAt: d['last_sync_at'] != null
            ? DateTime.parse(d['last_sync_at'] as String)
            : null,
        isOnline: true,
        appMode: AppModeConfig.isMaster ? 'master' : 'client',
      );
    }
    return SyncStatusModel(isOnline: false);
  } catch (e) {
    return SyncStatusModel(isOnline: false);
  }
});

// ── Currently selected branch (for POS context) ───────────────────────────────
final selectedBranchProvider =
    StateProvider<BranchModel?>((ref) => null);

final selectedWarehouseProvider =
    StateProvider<WarehouseModel?>((ref) => null);