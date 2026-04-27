
import 'package:flutter/foundation.dart';
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../../core/client/api_client.dart';
import '../../../../shared/services/app_alert_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../branches/presentation/providers/branch_provider.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import '../../data/models/kitchen_queue_model.dart';

// ── Station filter ────────────────────────────────────────────────────────────
// null = ทุก station, 'kitchen' | 'bar' | 'dessert'
final selectedKitchenStationProvider = StateProvider<String?>((ref) => null);

// ── KDS pending badge count (PENDING + PREPARING) ────────────────────────────
final kdsPendingCountProvider = Provider<int>((ref) {
  return ref.watch(kitchenQueueProvider).maybeWhen(
    data: (items) => items
        .where((i) =>
            i.kitchenStatus == 'PENDING' || i.kitchenStatus == 'PREPARING')
        .length,
    orElse: () => 0,
  );
});

// ── Kitchen Queue ─────────────────────────────────────────────────────────────

final kitchenQueueProvider =
    AsyncNotifierProvider<KitchenQueueNotifier, List<KitchenQueueItemModel>>(
      KitchenQueueNotifier.new,
    );

class KitchenQueueNotifier extends AsyncNotifier<List<KitchenQueueItemModel>> {
  @override
  Future<List<KitchenQueueItemModel>> build() async {
    final auth = ref.watch(authProvider);
    if (auth.isRestoring || !auth.isAuthenticated) return [];
    return _load();
  }

  Future<List<KitchenQueueItemModel>> _load() async {
    final api = ref.read(apiClientProvider);
    final branchId = ref.read(selectedBranchProvider)?.branchId;
    final station = ref.read(selectedKitchenStationProvider);

    final buf = StringBuffer(
      '/api/kitchen/queue?status=PENDING,PREPARING,READY,HELD',
    );
    if (branchId != null) buf.write('&branch_id=$branchId');
    if (station != null) buf.write('&station=$station');

    final res = await api.get(buf.toString());
    if (res.statusCode == 200) {
      return (res.data['data'] as List)
          .map((j) => KitchenQueueItemModel.fromJson(j as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_load);
  }

  Future<void> silentRefresh() async {
    try {
      final prev = state.asData?.value ?? [];
      final prevIds = prev.map((i) => i.itemId).toSet();

      final items = await _load();
      state = AsyncValue.data(items);
      ref.invalidate(kitchenSummaryProvider);

      // เสียงแจ้งเตือนเมื่อมี PENDING item ใหม่เข้ามา
      final hasNewPending = items.any(
        (i) => i.kitchenStatus == 'PENDING' && !prevIds.contains(i.itemId),
      );
      if (hasNewPending) {
        final settings = ref.read(settingsProvider);
        if (settings.restaurantAlertSoundEnabled) {
          unawaited(ref.read(appAlertServiceProvider).playKitchenAlert());
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ kitchen silent refresh error: $e');
      }
    }
  }

  Future<bool> updateStatus(String itemId, String newStatus) async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.put(
        '/api/kitchen/items/$itemId/status',
        data: {'status': newStatus},
      );
      if (res.statusCode == 200) {
        // optimistic update
        state = state.whenData(
          (items) => items
              .map(
                (i) => i.itemId == itemId
                    ? i.copyWith(
                        kitchenStatus: newStatus,
                        preparedAt:
                            (newStatus == 'READY' || newStatus == 'SERVED')
                            ? DateTime.now()
                            : i.preparedAt,
                      )
                    : i,
              )
              .toList(),
        );
        ref.invalidate(kitchenSummaryProvider);
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ updateStatus error: $e');
      }
      return false;
    }
  }

  Future<bool> serveItem(String itemId) => updateStatus(itemId, 'SERVED');

  Future<bool> fireCourse(String tableId, int courseNo) async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.post(
        '/api/tables/$tableId/fire-course',
        data: {'course_no': courseNo},
      );
      if (res.statusCode == 200) {
        await refresh();
        ref.invalidate(kitchenSummaryProvider);
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ fireCourse error: $e');
      }
      return false;
    }
  }
}

// ── Station Summary ───────────────────────────────────────────────────────────

final kitchenSummaryProvider =
    AsyncNotifierProvider<KitchenSummaryNotifier, List<KitchenStationSummary>>(
      KitchenSummaryNotifier.new,
    );

class KitchenSummaryNotifier
    extends AsyncNotifier<List<KitchenStationSummary>> {
  @override
  Future<List<KitchenStationSummary>> build() async {
    final auth = ref.watch(authProvider);
    if (auth.isRestoring || !auth.isAuthenticated) return [];
    return _load();
  }

  Future<List<KitchenStationSummary>> _load() async {
    final api = ref.read(apiClientProvider);
    final branchId = ref.read(selectedBranchProvider)?.branchId;
    final path = branchId != null
        ? '/api/kitchen/summary?branch_id=$branchId'
        : '/api/kitchen/summary';
    final res = await api.get(path);
    if (res.statusCode == 200) {
      return (res.data['data'] as List)
          .map((j) => KitchenStationSummary.fromJson(j as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_load);
  }
}
