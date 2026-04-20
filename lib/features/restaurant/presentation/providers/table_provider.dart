// ignore_for_file: avoid_print

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../../core/client/api_client.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../branches/presentation/providers/branch_provider.dart';
import '../../data/models/dining_table_model.dart';
import '../../data/models/table_session_model.dart';

// ── Zone List ─────────────────────────────────────────────────────────────────

final zoneListProvider =
    AsyncNotifierProvider<ZoneNotifier, List<ZoneModel>>(ZoneNotifier.new);

class ZoneNotifier extends AsyncNotifier<List<ZoneModel>> {
  @override
  Future<List<ZoneModel>> build() async {
    final authState = ref.watch(authProvider);
    final selectedBranch = ref.watch(selectedBranchProvider);
    if (authState.isRestoring || !authState.isAuthenticated) return [];
    return _load(branchId: selectedBranch?.branchId);
  }

  Future<List<ZoneModel>> _load({String? branchId}) async {
    final api = ref.read(apiClientProvider);
    final path = branchId == null || branchId.isEmpty
        ? '/api/tables/zones'
        : '/api/tables/zones?branch_id=$branchId';
    final res = await api.get(path);
    if (res.statusCode == 200) {
      return (res.data['data'] as List)
          .map((j) => ZoneModel.fromJson(j as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<void> refresh() async {
    final selectedBranch = ref.read(selectedBranchProvider);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _load(branchId: selectedBranch?.branchId),
    );
  }

  Future<bool> createZone({
    required String zoneName,
    required String branchId,
    int displayOrder = 0,
  }) async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.post('/api/tables/zones', data: {
        'zone_name': zoneName,
        'branch_id': branchId,
        'display_order': displayOrder,
      });
      if (res.statusCode == 201) {
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      print('❌ createZone error: $e');
      return false;
    }
  }

  Future<bool> updateZone(String zoneId,
      {String? zoneName, int? displayOrder, bool? isActive}) async {
    try {
      final api = ref.read(apiClientProvider);
      final body = <String, dynamic>{};
      if (zoneName != null) body['zone_name'] = zoneName;
      if (displayOrder != null) body['display_order'] = displayOrder;
      if (isActive != null) body['is_active'] = isActive;
      await api.put('/api/tables/zones/$zoneId', data: body);
      await refresh();
      return true;
    } catch (e) {
      print('❌ updateZone error: $e');
      return false;
    }
  }

  Future<bool> deleteZone(String zoneId) async {
    try {
      final api = ref.read(apiClientProvider);
      await api.delete('/api/tables/zones/$zoneId');
      await refresh();
      return true;
    } catch (e) {
      print('❌ deleteZone error: $e');
      return false;
    }
  }
}

// ── Table List ────────────────────────────────────────────────────────────────

final tableListProvider =
    AsyncNotifierProvider<TableNotifier, List<DiningTableModel>>(
        TableNotifier.new);

class TableNotifier extends AsyncNotifier<List<DiningTableModel>> {
  @override
  Future<List<DiningTableModel>> build() async {
    final authState = ref.watch(authProvider);
    final selectedBranch = ref.watch(selectedBranchProvider);
    if (authState.isRestoring || !authState.isAuthenticated) return [];
    return _load(branchId: selectedBranch?.branchId);
  }

  Future<List<DiningTableModel>> _load({String? branchId}) async {
    final api = ref.read(apiClientProvider);
    final params = branchId != null ? '?branch_id=$branchId' : '';
    final res = await api.get('/api/tables/$params');
    if (res.statusCode == 200) {
      return (res.data['data'] as List)
          .map((j) => DiningTableModel.fromJson(j as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<void> refresh({String? branchId}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _load(branchId: branchId));
  }

  Future<bool> createTable({
    required String tableNo,
    required String zoneId,
    String? tableDisplayName,
    int capacity = 4,
  }) async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.post('/api/tables/', data: {
        'table_no': tableNo,
        'zone_id': zoneId,
        'table_display_name': tableDisplayName,
        'capacity': capacity,
      });
      if (res.statusCode == 201) {
        final selectedBranch = ref.read(selectedBranchProvider);
        await refresh(branchId: selectedBranch?.branchId);
        return true;
      }
      return false;
    } catch (e) {
      print('❌ createTable error: $e');
      return false;
    }
  }

  Future<bool> updateTable(
    String tableId, {
    String? tableNo,
    String? tableDisplayName,
    String? zoneId,
    int? capacity,
    String? status,
  }) async {
    try {
      final api = ref.read(apiClientProvider);
      final body = <String, dynamic>{};
      if (tableNo != null) body['table_no'] = tableNo;
      if (tableDisplayName != null) body['table_display_name'] = tableDisplayName;
      if (zoneId != null) body['zone_id'] = zoneId;
      if (capacity != null) body['capacity'] = capacity;
      if (status != null) body['status'] = status;
      await api.put('/api/tables/$tableId', data: body);
      final selectedBranch = ref.read(selectedBranchProvider);
      await refresh(branchId: selectedBranch?.branchId);
      return true;
    } catch (e) {
      print('❌ updateTable error: $e');
      return false;
    }
  }

  Future<bool> deleteTable(String tableId) async {
    try {
      final api = ref.read(apiClientProvider);
      await api.delete('/api/tables/$tableId');
      final selectedBranch = ref.read(selectedBranchProvider);
      await refresh(branchId: selectedBranch?.branchId);
      return true;
    } catch (e) {
      print('❌ deleteTable error: $e');
      return false;
    }
  }

  // ── Session actions ──────────────────────────────────────────────────────────

  Future<TableSessionModel?> openTable({
    required String tableId,
    required int guestCount,
    required String branchId,
    String? openedBy,
  }) async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.post('/api/tables/$tableId/open', data: {
        'guest_count': guestCount,
        'branch_id': branchId,
        'opened_by': openedBy,
      });
      if (res.statusCode == 201) {
        await refresh(branchId: branchId);
        return TableSessionModel.fromJson(
            res.data['data'] as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print('❌ openTable error: $e');
      return null;
    }
  }

  Future<bool> closeTable(String tableId) async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.post('/api/tables/$tableId/close', data: {});
      if (res.statusCode == 200) {
        final selectedBranch = ref.read(selectedBranchProvider);
        await refresh(branchId: selectedBranch?.branchId);
        return true;
      }
      return false;
    } catch (e) {
      print('❌ closeTable error: $e');
      return false;
    }
  }

  Future<TableSessionModel?> getActiveSession(String tableId) async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get('/api/tables/$tableId/session');
      if (res.statusCode == 200) {
        return TableSessionModel.fromJson(
            res.data['data'] as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<TableSessionModel?> transferTable({
    required String fromTableId,
    required String targetTableId,
  }) async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.post('/api/tables/$fromTableId/transfer', data: {
        'target_table_id': targetTableId,
      });
      if (res.statusCode == 200) {
        final selectedBranch = ref.read(selectedBranchProvider);
        await refresh(branchId: selectedBranch?.branchId);
        return TableSessionModel.fromJson(
          res.data['data'] as Map<String, dynamic>,
        );
      }
      return null;
    } catch (e) {
      print('❌ transferTable error: $e');
      return null;
    }
  }

  Future<void> assignWaiter(String tableId, String waiterName) async {
    try {
      final api = ref.read(apiClientProvider);
      await api.post('/api/tables/$tableId/assign-waiter', data: {
        'waiter_name': waiterName,
      });
    } catch (e) {
      print('❌ assignWaiter error: $e');
      rethrow;
    }
  }

  Future<bool> updateGuestCount(String tableId, int guestCount) async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.post('/api/tables/$tableId/update-guest-count',
          data: {'guest_count': guestCount});
      if (res.statusCode == 200) {
        await refresh(branchId: null);
        return true;
      }
      return false;
    } catch (e) {
      print('❌ updateGuestCount error: $e');
      return false;
    }
  }
}

// ── Selected zone filter ────────────────────────────────────────────────────

final selectedZoneFilterProvider = StateProvider<String?>((ref) => null);
