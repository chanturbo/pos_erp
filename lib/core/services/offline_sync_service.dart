// ignore_for_file: avoid_print
// offline_sync_service.dart — Week 7: Offline Mode & Background Sync

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../config/app_mode.dart';
import '../../../../core/client/api_client.dart';

/// OfflineSyncService
/// ─────────────────────────────────────────────────────────────
/// ทำงานเป็น background service สำหรับ sync ข้อมูลระหว่าง
/// Client POS <──► Master Server
///
/// Flow:
///   1. Client ทำรายการ → บันทึกใน local DB + เพิ่มใน sync queue
///   2. OfflineSyncService ส่งข้อมูลไป Master ทุก 30 วินาที
///   3. Master ตอบกลับ → Client mark as SYNCED
///   4. ถ้าออฟไลน์ → รอจนกว่าจะออนไลน์แล้ว retry อัตโนมัติ
/// ─────────────────────────────────────────────────────────────
class OfflineSyncService {
  final Ref _ref;
  Timer? _autoSyncTimer;
  bool _isSyncing = false;

  static const _syncIntervalSeconds = 30;

  OfflineSyncService(this._ref);

  // ── Start / Stop auto sync ─────────────────────────────────────────────────

  /// เริ่ม auto sync ทุก 30 วินาที
  void startAutoSync() {
    if (AppModeConfig.isStandalone) {
      print('ℹ️ OfflineSyncService: Standalone mode — auto sync disabled');
      return;
    }
    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer.periodic(
      const Duration(seconds: _syncIntervalSeconds),
      (_) => _autoSyncTick(),
    );
    print('🔄 OfflineSyncService: Auto sync started (every ${_syncIntervalSeconds}s)');
  }

  void stopAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;
    print('⏹ OfflineSyncService: Auto sync stopped');
  }

  void dispose() => stopAutoSync();

  // ── Manual sync ───────────────────────────────────────────────────────────

  /// เรียกใช้จาก UI "Sync ตอนนี้"
  Future<bool> syncNow() async {
    if (AppModeConfig.isStandalone) {
      print('ℹ️ Standalone mode — no sync required');
      return true;
    }
    if (_isSyncing) {
      print('⚠️ Sync already in progress, skipping');
      return false;
    }
    return _doSync();
  }

  /// Retry เฉพาะรายการที่ FAILED
  Future<void> retryFailed() async {
    if (AppModeConfig.isStandalone) return;
    final api = _ref.read(apiClientProvider);
    try {
      // Reset FAILED → PENDING
      await api.post('/api/sync/retry-failed', data: {});
      await syncNow();
    } catch (e) {
      print('❌ retryFailed error: $e');
    }
  }

  // ── Enqueue local changes ─────────────────────────────────────────────────

  /// เพิ่มรายการลง Sync Queue (เรียกหลัง save ข้อมูลที่ client)
  Future<void> enqueue({
    required String tableName,
    required String recordId,
    required String operation, // INSERT | UPDATE | DELETE
    required Map<String, dynamic> data,
    String? deviceId,
  }) async {
    if (AppModeConfig.isStandalone) return;
    final api = _ref.read(apiClientProvider);
    try {
      await api.post('/api/sync/enqueue', data: {
        'queue_id': 'Q${DateTime.now().millisecondsSinceEpoch}',
        'device_id': deviceId ?? 'local',
        'table_name': tableName,
        'record_id': recordId,
        'operation': operation,
        'data': data,
      });
      print('📝 Enqueued $operation on $tableName:$recordId');
    } catch (e) {
      print('❌ Enqueue error: $e');
    }
  }

  // ── Internal sync logic ───────────────────────────────────────────────────

  Future<void> _autoSyncTick() async {
    if (_isSyncing) return;
    final online = await _checkOnline();
    if (!online) {
      print('📴 Offline — skipping auto sync');
      return;
    }
    await _doSync();
  }

  Future<bool> _doSync() async {
    _isSyncing = true;
    print('🔄 OfflineSyncService: Starting sync...');

    try {
      final api = _ref.read(apiClientProvider);

      // Step 1: Push pending items to master
      final pushRes =
          await api.post('/api/sync/push-pending', data: {});

      if (pushRes.statusCode == 200) {
        final pushed = pushRes.data['data']?['pushed'] as int? ?? 0;
        if (pushed > 0) {
          print('✅ Pushed $pushed items to master');
        }
      }

      // Step 2: Pull new data from master
      final lastSync = await _getLastSyncTime();
      final pullRes = await api.get(
          '/api/branches/sync/pull?since=${lastSync ?? ''}');

      if (pullRes.statusCode == 200) {
        final items = pullRes.data['data']?['items'] as List? ?? [];
        if (items.isNotEmpty) {
          await _applyPulledData(items);
          print('✅ Applied ${items.length} items from master');
        }
      }

      print('✅ Sync completed successfully');
      _isSyncing = false;
      return true;
    } catch (e) {
      print('❌ Sync failed: $e');
      _isSyncing = false;
      return false;
    }
  }

  Future<void> _applyPulledData(List items) async {
    // แต่ละ item จาก Master จะถูก apply ลง local DB
    // โดยปกติจะเรียก upsert ใน Drift ตาม table_name + record_id
    for (final item in items) {
      final map = item as Map<String, dynamic>;
      print('  📥 Apply: ${map['operation']} ${map['table_name']}:${map['record_id']}');
      // TODO: dispatch to appropriate repository based on table_name
      // e.g. if (map['table_name'] == 'products') { await productRepo.upsert(map['data']); }
    }
  }

  Future<bool> _checkOnline() async {
    try {
      final api = _ref.read(apiClientProvider);
      final res = await api.get('/api/health').timeout(
          const Duration(seconds: 3));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<String?> _getLastSyncTime() async {
    try {
      final api = _ref.read(apiClientProvider);
      final res = await api.get('/api/branches/sync/status');
      if (res.statusCode == 200) {
        return res.data['data']?['last_sync_at'] as String?;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

// ── Sync Service Provider ──────────────────────────────────────────────────────
final offlineSyncServiceProvider = Provider<OfflineSyncService>((ref) {
  final svc = OfflineSyncService(ref);
  // cleanup on dispose
  ref.onDispose(() => svc.dispose());
  return svc;
});

// ── Connectivity status ────────────────────────────────────────────────────────
final isOnlineProvider = StateProvider<bool>((ref) => true);

/// เรียกใช้ใน main.dart หลัง app เริ่ม เพื่อ start auto sync
/// ```dart
/// ref.read(offlineSyncServiceProvider).startAutoSync();
/// ```
