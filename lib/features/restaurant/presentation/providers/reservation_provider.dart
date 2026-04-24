
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../../core/client/api_client.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../branches/presentation/providers/branch_provider.dart';
import '../../data/models/reservation_model.dart';
import 'table_provider.dart';

final reservationDateProvider = StateProvider<DateTime>(
  (ref) => DateTime.now(),
);
final reservationStatusFilterProvider = StateProvider<String?>((ref) => null);
final reservationSearchQueryProvider = StateProvider<String>((ref) => '');

final reservationsProvider =
    AsyncNotifierProvider<ReservationsNotifier, List<ReservationModel>>(
      ReservationsNotifier.new,
    );

class ReservationsNotifier extends AsyncNotifier<List<ReservationModel>> {
  @override
  Future<List<ReservationModel>> build() async {
    final auth = ref.watch(authProvider);
    if (auth.isRestoring || !auth.isAuthenticated) return [];
    final date = ref.watch(reservationDateProvider);
    final status = ref.watch(reservationStatusFilterProvider);
    final searchQuery = ref.watch(reservationSearchQueryProvider);
    final branch = ref.watch(selectedBranchProvider);
    return _load(
      date: date,
      status: status,
      searchQuery: searchQuery,
      branchId: branch?.branchId,
    );
  }

  Future<List<ReservationModel>> _load({
    required DateTime date,
    String? status,
    String? searchQuery,
    String? branchId,
  }) async {
    final api = ref.read(apiClientProvider);
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    var url = '/api/tables/reservations?date=$y-$m-$d';
    if (branchId != null) url += '&branch_id=$branchId';
    if (status != null) url += '&status=$status';
    final trimmedQuery = (searchQuery ?? '').trim();
    if (trimmedQuery.isNotEmpty) {
      url += '&query=${Uri.encodeQueryComponent(trimmedQuery)}';
    }

    final res = await api.get(url);
    if (res.statusCode != 200) return [];
    final list = res.data['data'] as List;
    return list
        .map((j) => ReservationModel.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<void> refresh() async {
    final date = ref.read(reservationDateProvider);
    final status = ref.read(reservationStatusFilterProvider);
    final searchQuery = ref.read(reservationSearchQueryProvider);
    final branch = ref.read(selectedBranchProvider);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _load(
        date: date,
        status: status,
        searchQuery: searchQuery,
        branchId: branch?.branchId,
      ),
    );
  }

  Future<ReservationModel?> create(Map<String, dynamic> body) async {
    try {
      final api = ref.read(apiClientProvider);
      final branch = ref.read(selectedBranchProvider);
      body['branch_id'] ??= branch?.branchId ?? '';
      final res = await api.post('/api/tables/reservations', data: body);
      if (res.statusCode == 200 || res.statusCode == 201) {
        await refresh();
        return ReservationModel.fromJson(
          res.data['data'] as Map<String, dynamic>,
        );
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ createReservation error: $e');
      }
      return null;
    }
  }

  Future<void> edit(String id, Map<String, dynamic> body) async {
    try {
      final api = ref.read(apiClientProvider);
      await api.put('/api/tables/reservations/$id', data: body);
      await refresh();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ editReservation error: $e');
      }
    }
  }

  Future<bool> confirm(String id) async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.post(
        '/api/tables/reservations/$id/confirm',
        data: {},
      );
      if (res.statusCode != 200) return false;
      await refresh();
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ confirmReservation error: $e');
      }
      return false;
    }
  }

  Future<bool> cancel(String id) async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.post(
        '/api/tables/reservations/$id/cancel',
        data: {},
      );
      if (res.statusCode != 200) return false;
      await refresh();
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ cancelReservation error: $e');
      }
      return false;
    }
  }

  Future<bool> noShow(String id) async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.post(
        '/api/tables/reservations/$id/no-show',
        data: {},
      );
      if (res.statusCode != 200) return false;
      await refresh();
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ noShowReservation error: $e');
      }
      return false;
    }
  }

  Future<Map<String, dynamic>?> seat(
    String id,
    String tableId,
    String branchId,
  ) async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.post(
        '/api/tables/reservations/$id/seat',
        data: {'table_id': tableId, 'branch_id': branchId},
      );
      if (res.statusCode == 200) {
        await refresh();
        await ref.read(tableListProvider.notifier).refresh(branchId: branchId);
        return res.data['data'] as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ seatReservation error: $e');
      }
      return null;
    }
  }
}

// ── Kitchen Analytics ─────────────────────────────────────────────────────────

final kitchenAnalyticsDateProvider = StateProvider<DateTime>(
  (ref) => DateTime.now(),
);

final kitchenAnalyticsProvider =
    AsyncNotifierProvider<KitchenAnalyticsNotifier, Map<String, dynamic>?>(
      KitchenAnalyticsNotifier.new,
    );

class KitchenAnalyticsNotifier extends AsyncNotifier<Map<String, dynamic>?> {
  @override
  Future<Map<String, dynamic>?> build() async {
    final auth = ref.watch(authProvider);
    if (auth.isRestoring || !auth.isAuthenticated) return null;
    final date = ref.watch(kitchenAnalyticsDateProvider);
    final branch = ref.watch(selectedBranchProvider);
    return _load(date, branch?.branchId);
  }

  Future<Map<String, dynamic>?> _load(DateTime date, String? branchId) async {
    final api = ref.read(apiClientProvider);
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    var url = '/api/kitchen/analytics?date=$y-$m-$d';
    if (branchId != null) url += '&branch_id=$branchId';
    final res = await api.get(url);
    if (res.statusCode != 200) return null;
    return res.data['data'] as Map<String, dynamic>?;
  }

  Future<void> refresh() async {
    final date = ref.read(kitchenAnalyticsDateProvider);
    final branch = ref.read(selectedBranchProvider);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _load(date, branch?.branchId));
  }
}

// ── Table Timeline ────────────────────────────────────────────────────────────

final tableTimelineProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, tableId) async {
      final auth = ref.watch(authProvider);
      if (auth.isRestoring || !auth.isAuthenticated) return null;
      final api = ref.read(apiClientProvider);
      final res = await api.get('/api/tables/$tableId/timeline');
      if (res.statusCode != 200) return null;
      return res.data['data'] as Map<String, dynamic>?;
    });
