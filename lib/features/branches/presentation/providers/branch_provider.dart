// ignore_for_file: avoid_print
// branch_provider.dart — Week 7

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/services/pending_sales_queue_service.dart';
import '../../../../core/services/offline_sync_service.dart';
import '../../data/models/branch_model.dart';
import '../../../../core/client/api_client.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/config/app_mode.dart';

const _selectedBranchKey = 'selected_pos_branch_id';
const _selectedWarehouseKey = 'selected_pos_warehouse_id';

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

// ── POS Context bootstrap & persisted selection ───────────────────────────────
final posContextBootstrapProvider = FutureProvider<void>((ref) async {
  final authState = ref.watch(authProvider);
  if (authState.isRestoring || !authState.isAuthenticated) return;

  final prefs = await SharedPreferences.getInstance();
  final branchId = prefs.getString(_selectedBranchKey);
  final warehouseId = prefs.getString(_selectedWarehouseKey);
  final branches = await ref.watch(branchListProvider.future);
  final warehouses = await ref.watch(warehouseListProvider.future);

  final branchNotifier = ref.read(selectedBranchProvider.notifier);
  final warehouseNotifier = ref.read(selectedWarehouseProvider.notifier);

  if (branchId != null) {
    final selected = branches.where((branch) => branch.branchId == branchId);
    if (selected.isNotEmpty) {
      await branchNotifier.setBranch(selected.first, persist: false);
    }
  }

  if (warehouseId != null) {
    final selected = warehouses
        .where((warehouse) => warehouse.warehouseId == warehouseId);
    if (selected.isNotEmpty) {
      await warehouseNotifier.setWarehouse(selected.first, persist: false);
    }
  }
});

class SelectedBranchNotifier extends Notifier<BranchModel?> {
  @override
  BranchModel? build() => null;

  Future<void> setBranch(BranchModel? branch, {bool persist = true}) async {
    state = branch;
    if (!persist) return;

    final prefs = await SharedPreferences.getInstance();
    if (branch == null) {
      await prefs.remove(_selectedBranchKey);
    } else {
      await prefs.setString(_selectedBranchKey, branch.branchId);
    }
  }
}

class SelectedWarehouseNotifier extends Notifier<WarehouseModel?> {
  @override
  WarehouseModel? build() => null;

  Future<void> setWarehouse(
    WarehouseModel? warehouse, {
    bool persist = true,
  }) async {
    state = warehouse;
    if (!persist) return;

    final prefs = await SharedPreferences.getInstance();
    if (warehouse == null) {
      await prefs.remove(_selectedWarehouseKey);
    } else {
      await prefs.setString(_selectedWarehouseKey, warehouse.warehouseId);
    }
  }
}

final selectedBranchProvider =
    NotifierProvider<SelectedBranchNotifier, BranchModel?>(
  SelectedBranchNotifier.new,
);

final selectedWarehouseProvider =
    NotifierProvider<SelectedWarehouseNotifier, WarehouseModel?>(
  SelectedWarehouseNotifier.new,
);

// ── Sync Status Provider ──────────────────────────────────────────────────────
final syncStatusProvider = StreamProvider<SyncStatusModel>((ref) async* {
  final authState = ref.watch(authProvider);
  if (authState.isRestoring || !authState.isAuthenticated) {
    yield SyncStatusModel(
      isOnline: false,
      appMode: AppModeConfig.isStandalone
          ? 'standalone'
          : (AppModeConfig.isMaster ? 'master' : 'client'),
      serverBaseUrl: AppConfig.resolveApiBaseUrl(),
      masterName: AppModeConfig.masterName,
      deviceName: AppModeConfig.deviceName,
    );
    return;
  }

  while (true) {
    yield await _loadSyncStatus(ref);
    await Future.delayed(const Duration(seconds: 3));
  }
});

final syncBatchHistoryProvider =
    StreamProvider<List<SyncBatchHistoryModel>>((ref) async* {
  final authState = ref.watch(authProvider);
  if (authState.isRestoring || !authState.isAuthenticated) {
    yield const [];
    return;
  }

  while (true) {
    yield await _loadSyncBatchHistory(ref);
    await Future.delayed(const Duration(seconds: 3));
  }
});

final syncBatchTimeRangeProvider =
    StateProvider<SyncBatchTimeRange>((ref) => SyncBatchTimeRange.last24Hours);

final syncBatchSearchProvider = StateProvider<String>((ref) => '');

final syncBatchIssuesOnlyProvider = StateProvider<bool>((ref) => false);

Future<SyncStatusModel> _loadSyncStatus(Ref ref) async {
  final localQueued =
      await ref.read(pendingSalesQueueServiceProvider).pendingCount();
  final batchMetrics = ref.read(offlineSyncServiceProvider).lastBatchMetrics;

  if (AppModeConfig.isStandalone) {
    return SyncStatusModel(
      isOnline: true,
      pendingCount: 0,
      failedCount: 0,
      appMode: 'standalone',
      serverBaseUrl: AppConfig.resolveApiBaseUrl(),
      deviceName: AppModeConfig.deviceName,
      lastBatchTotalItems: batchMetrics?.totalItems ?? 0,
      lastBatchAppliedItems: batchMetrics?.appliedItems ?? 0,
      lastBatchReplayedItems: batchMetrics?.replayedItems ?? 0,
      lastBatchPassesUsed: batchMetrics?.passesUsed ?? 0,
      lastBatchPendingItems: batchMetrics?.pendingItems ?? 0,
    );
  }

  try {
    final api = ref.read(apiClientProvider);
    final res = await api.get('/api/branches/sync/status');
    if (res.statusCode == 200) {
      final d = res.data['data'] as Map<String, dynamic>;
      return SyncStatusModel(
        pendingCount: (d['pending_count'] as int? ?? 0) + localQueued,
        failedCount: d['failed_count'] as int? ?? 0,
        lastSyncAt: d['last_sync_at'] != null
            ? DateTime.parse(d['last_sync_at'] as String)
            : null,
        isOnline: true,
        appMode: AppModeConfig.isMaster ? 'master' : 'client',
        serverBaseUrl: AppConfig.resolveApiBaseUrl(),
        masterName: AppModeConfig.masterName,
        deviceName: AppModeConfig.deviceName,
        lastBatchTotalItems: batchMetrics?.totalItems ?? 0,
        lastBatchAppliedItems: batchMetrics?.appliedItems ?? 0,
        lastBatchReplayedItems: batchMetrics?.replayedItems ?? 0,
        lastBatchPassesUsed: batchMetrics?.passesUsed ?? 0,
        lastBatchPendingItems: batchMetrics?.pendingItems ?? 0,
      );
    }
  } catch (_) {}

  return SyncStatusModel(
    isOnline: false,
    pendingCount: localQueued,
    serverBaseUrl: AppConfig.resolveApiBaseUrl(),
    masterName: AppModeConfig.masterName,
    deviceName: AppModeConfig.deviceName,
    lastBatchTotalItems: batchMetrics?.totalItems ?? 0,
    lastBatchAppliedItems: batchMetrics?.appliedItems ?? 0,
    lastBatchReplayedItems: batchMetrics?.replayedItems ?? 0,
    lastBatchPassesUsed: batchMetrics?.passesUsed ?? 0,
    lastBatchPendingItems: batchMetrics?.pendingItems ?? 0,
  );
}

Future<List<SyncBatchHistoryModel>> _loadSyncBatchHistory(Ref ref) async {
  try {
    final rows = await ref
        .read(offlineSyncServiceProvider)
        .loadRecentBatchMetrics(limit: 20);
    return rows.map(SyncBatchHistoryModel.fromMap).toList();
  } catch (e) {
    print('❌ Error loading sync batch history: $e');
    return const [];
  }
}

class ConnectionStatusModel {
  final bool isConnected;
  final String title;
  final String detail;

  const ConnectionStatusModel({
    required this.isConnected,
    required this.title,
    required this.detail,
  });
}

final connectionStatusProvider = StreamProvider<ConnectionStatusModel>((ref) async* {
  final authState = ref.watch(authProvider);
  if (authState.isRestoring || !authState.isAuthenticated) {
    yield const ConnectionStatusModel(
      isConnected: false,
      title: 'กำลังตรวจสอบ',
      detail: 'รอการเข้าสู่ระบบ',
    );
    return;
  }

  while (true) {
    if (AppModeConfig.isStandalone) {
      yield ConnectionStatusModel(
        isConnected: true,
        title: 'Standalone',
        detail: 'ใช้งานเครื่องเดียว ไม่ใช้ระบบ sync',
      );
    } else if (AppModeConfig.isMaster) {
      yield ConnectionStatusModel(
        isConnected: true,
        title: 'Master พร้อมใช้งาน',
        detail: AppModeConfig.deviceName,
      );
    } else if (AppModeConfig.masterIp == null) {
      yield const ConnectionStatusModel(
        isConnected: false,
        title: 'ยังไม่ได้เชื่อมต่อ',
        detail: 'เลือก Master ก่อนเริ่มขาย',
      );
    } else {
      final api = ref.read(apiClientProvider);
      try {
        final res = await api.get('/api/health').timeout(
              const Duration(seconds: 2),
            );
        final connected = res.statusCode == 200;
        if (connected) {
          await ref
              .read(pendingSalesQueueServiceProvider)
              .replayPendingOrders(api);
        }
        yield ConnectionStatusModel(
          isConnected: connected,
          title: connected ? 'Connected' : 'Disconnected',
          detail: connected
              ? '${AppModeConfig.masterName ?? 'Master'} พร้อมใช้งาน'
              : 'ติดต่อ ${AppModeConfig.masterName ?? 'Master'} ไม่ได้',
        );
      } on DioException {
        yield ConnectionStatusModel(
          isConnected: false,
          title: 'Disconnected',
          detail: 'ติดต่อ ${AppModeConfig.masterName ?? 'Master'} ไม่ได้',
        );
      } catch (_) {
        yield ConnectionStatusModel(
          isConnected: false,
          title: 'Disconnected',
          detail: 'ติดต่อ ${AppModeConfig.masterName ?? 'Master'} ไม่ได้',
        );
      }
    }

    await Future.delayed(const Duration(seconds: 3));
  }
});
