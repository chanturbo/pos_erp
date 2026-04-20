// ignore_for_file: avoid_print

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../../core/client/api_client.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/bill_model.dart';

// ── ตัวกรอง tableId ──────────────────────────────────────────────────────────
final billingTableIdProvider = StateProvider<String?>((ref) => null);

// ── Bill provider ─────────────────────────────────────────────────────────────

final billProvider =
    AsyncNotifierProvider<BillNotifier, BillModel?>(BillNotifier.new);

class BillNotifier extends AsyncNotifier<BillModel?> {
  @override
  Future<BillModel?> build() async {
    final auth = ref.watch(authProvider);
    if (auth.isRestoring || !auth.isAuthenticated) return null;

    final tableId = ref.watch(billingTableIdProvider);
    if (tableId == null) return null;

    return _load(tableId);
  }

  Future<BillModel?> _load(String tableId) async {
    final api = ref.read(apiClientProvider);
    final res = await api.get('/api/tables/$tableId/bill');
    if (res.statusCode == 200) {
      return BillModel.fromJson(res.data['data'] as Map<String, dynamic>);
    }
    return null;
  }

  Future<void> refresh() async {
    final tableId = ref.read(billingTableIdProvider);
    if (tableId == null) return;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _load(tableId));
  }

  /// ตั้ง service charge rate (%)
  Future<bool> setServiceCharge(String tableId, double rate) async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.post(
        '/api/tables/$tableId/bill/service-charge',
        data: {'rate': rate},
      );
      if (res.statusCode == 200) {
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      print('❌ setServiceCharge error: $e');
      return false;
    }
  }

  /// Split bill เท่ากัน N คน
  Future<SplitResult?> splitEqual(String tableId, int count) async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.post(
        '/api/tables/$tableId/bill/split',
        data: {'count': count},
      );
      if (res.statusCode == 200) {
        return SplitResult.fromJson(
            res.data['data'] as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print('❌ splitEqual error: $e');
      return null;
    }
  }

  /// Split bill แบบกำหนด items ต่อคน
  Future<SplitResult?> splitByItems(
      String tableId, List<Map<String, dynamic>> splits) async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.post(
        '/api/tables/$tableId/bill/split',
        data: {'splits': splits},
      );
      if (res.statusCode == 200) {
        return SplitResult.fromJson(
            res.data['data'] as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print('❌ splitByItems error: $e');
      return null;
    }
  }

  /// Fire a held course — HELD → PENDING for all items with courseNo
  Future<bool> fireCourse(String tableId, int courseNo) async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.post(
        '/api/tables/$tableId/fire-course',
        data: {'course_no': courseNo},
      );
      if (res.statusCode == 200) {
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      print('❌ fireCourse error: $e');
      return false;
    }
  }

  /// Void a single item with a reason
  Future<bool> voidItem(String itemId) async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.put(
        '/api/kitchen/items/$itemId/status',
        data: {'status': 'CANCELLED'},
      );
      if (res.statusCode == 200) {
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      print('❌ voidItem error: $e');
      return false;
    }
  }

  Future<SplitResult?> applySplit(
      String tableId, List<Map<String, dynamic>> splits) async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.post(
        '/api/tables/$tableId/bill/split/apply',
        data: {'splits': splits},
      );
      if (res.statusCode == 200) {
        await refresh();
        return SplitResult.fromJson(
            res.data['data'] as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print('❌ applySplit error: $e');
      return null;
    }
  }
}

// ── Merge provider ────────────────────────────────────────────────────────────

final mergeTablesProvider =
    AsyncNotifierProvider<MergeTablesNotifier, void>(MergeTablesNotifier.new);

class MergeTablesNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> merge(
      {required String sourceTableId,
      required String targetTableId}) async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.post(
        '/api/tables/merge',
        data: {
          'source_table_id': sourceTableId,
          'target_table_id': targetTableId,
        },
      );
      return res.statusCode == 200;
    } catch (e) {
      print('❌ merge error: $e');
      return false;
    }
  }
}
