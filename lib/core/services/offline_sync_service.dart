// ignore_for_file: avoid_print
// offline_sync_service.dart — Week 7: Offline Mode & Background Sync

import 'dart:async';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../database/app_database.dart';
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
  final AppDatabase _db;
  Timer? _autoSyncTimer;
  bool _isSyncing = false;
  SyncBatchMetrics? _lastBatchMetrics;

  static const _syncIntervalSeconds = 30;
  static const _maxApplyReplayPasses = 3;
  static const Map<String, int> _tableApplyPriority = {
    'companies': 10,
    'branches': 20,
    'roles': 30,
    'users': 40,
    'product_groups': 50,
    'modifier_groups': 60,
    'products': 70,
    'modifiers': 80,
    'product_modifiers': 90,
    'warehouses': 100,
    'customer_groups': 110,
    'customers': 120,
    'suppliers': 130,
    'zones': 140,
    'dining_tables': 150,
    'sales_orders': 160,
    'sales_order_items': 170,
    'order_item_modifiers': 180,
    'purchase_orders': 190,
    'purchase_order_items': 200,
    'goods_receipts': 210,
    'goods_receipt_items': 220,
    'purchase_returns': 230,
    'purchase_return_items': 240,
    'stock_balances': 250,
    'serial_numbers': 260,
    'stock_movements': 270,
    'points_transactions': 280,
    'promotions': 290,
    'promotion_usages': 300,
    'coupons': 310,
    'ar_invoices': 320,
    'ar_invoice_items': 330,
    'ar_receipts': 340,
    'ar_receipt_allocations': 350,
    'ap_invoices': 360,
    'ap_invoice_items': 370,
    'ap_payments': 380,
    'ap_payment_allocations': 390,
    'devices': 400,
    'active_sessions': 410,
  };

  OfflineSyncService(this._ref, {AppDatabase? database})
      : _db = database ?? AppDatabase();

  SyncBatchMetrics? get lastBatchMetrics => _lastBatchMetrics;

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

  void dispose() {
    stopAutoSync();
    unawaited(_db.close());
  }

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
          final applyResult = await _applyPulledData(items);
          _lastBatchMetrics = applyResult.metrics;
          await _persistBatchMetrics(applyResult.metrics);
          final acknowledgedQueueIds = applyResult.acknowledgedQueueIds;
          if (acknowledgedQueueIds.isNotEmpty) {
            await _acknowledgePulledItems(acknowledgedQueueIds);
          }
          print(
            '📊 Sync batch: total=${applyResult.metrics.totalItems}, '
            'applied=${applyResult.metrics.appliedItems}, '
            'replayed=${applyResult.metrics.replayedItems}, '
            'passes=${applyResult.metrics.passesUsed}, '
            'pending=${applyResult.metrics.pendingItems}',
          );
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

  Future<ApplyBatchResult> _applyPulledData(List items) async {
    final acknowledgedQueueIds = <String>[];
    var pendingItems = items
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    final totalItems = pendingItems.length;
    var replayedItems = 0;
    var passesUsed = 0;

    pendingItems = _sortItemsByDependency(pendingItems);

    for (var pass = 1; pass <= _maxApplyReplayPasses && pendingItems.isNotEmpty; pass++) {
      final retryQueue = <Map<String, dynamic>>[];
      var appliedThisPass = 0;
      passesUsed = pass;

      if (pass > 1) {
        replayedItems += pendingItems.length;
        print(
          '🔁 Replay pass $pass for ${pendingItems.length} pending sync items',
        );
      }

      for (final map in pendingItems) {
        print(
          '  📥 Apply: ${map['operation']} ${map['table_name']}:${map['record_id']}',
        );
        try {
          final applied = await _dispatchPulledItem(map);
          if (applied) {
            appliedThisPass++;
            final queueId = map['queue_id'] as String?;
            if (queueId != null &&
                queueId.isNotEmpty &&
                !acknowledgedQueueIds.contains(queueId)) {
              acknowledgedQueueIds.add(queueId);
            }
          } else {
            retryQueue.add(map);
          }
        } catch (e) {
          print(
            '❌ Failed to apply ${map['table_name']}:${map['record_id']} - $e',
          );
          retryQueue.add(map);
        }
      }

      if (retryQueue.isEmpty) {
        break;
      }

      if (appliedThisPass == 0) {
        print(
          '⚠️ Replay stopped with ${retryQueue.length} unapplied sync items',
        );
        pendingItems = retryQueue;
        break;
      }

      pendingItems = _sortItemsByDependency(retryQueue);
    }

    return ApplyBatchResult(
      acknowledgedQueueIds: acknowledgedQueueIds,
      metrics: SyncBatchMetrics(
        totalItems: totalItems,
        appliedItems: acknowledgedQueueIds.length,
        replayedItems: replayedItems,
        passesUsed: passesUsed,
        pendingItems: totalItems - acknowledgedQueueIds.length,
      ),
    );
  }

  List<Map<String, dynamic>> _sortItemsByDependency(
    List<Map<String, dynamic>> items,
  ) {
    final indexed = items.indexed.toList();
    indexed.sort((a, b) {
      final aPriority = _applyPriorityForTable(a.$2['table_name'] as String?);
      final bPriority = _applyPriorityForTable(b.$2['table_name'] as String?);
      final byPriority = aPriority.compareTo(bPriority);
      if (byPriority != 0) return byPriority;
      return a.$1.compareTo(b.$1);
    });
    return indexed.map((entry) => entry.$2).toList();
  }

  int _applyPriorityForTable(String? tableName) {
    return _tableApplyPriority[tableName] ?? 1000;
  }

  Future<bool> _dispatchPulledItem(Map<String, dynamic> item) async {
    final tableName = item['table_name'] as String?;
    final operation = (item['operation'] as String? ?? 'UPDATE').toUpperCase();
    final recordId = item['record_id'] as String?;
    final data = Map<String, dynamic>.from(item['data'] as Map? ?? const {});

    if (tableName == null || recordId == null) {
      print('⚠️ Skip sync item with missing table_name/record_id: $item');
      return false;
    }

    switch (tableName) {
      case 'companies':
        await _applyCompany(operation, recordId, data);
        return true;
      case 'branches':
        await _applyBranch(operation, recordId, data);
        return true;
      case 'roles':
        await _applyRole(operation, recordId, data);
        return true;
      case 'users':
        await _applyUser(operation, recordId, data);
        return true;
      case 'product_groups':
        await _applyProductGroup(operation, recordId, data);
        return true;
      case 'modifier_groups':
        await _applyModifierGroup(operation, recordId, data);
        return true;
      case 'modifiers':
        await _applyModifier(operation, recordId, data);
        return true;
      case 'product_modifiers':
        return await _applyProductModifier(operation, recordId, data);
      case 'zones':
        await _applyZone(operation, recordId, data);
        return true;
      case 'dining_tables':
        await _applyDiningTable(operation, recordId, data);
        return true;
      case 'warehouses':
        await _applyWarehouse(operation, recordId, data);
        return true;
      case 'stock_balances':
        await _applyStockBalance(operation, recordId, data);
        return true;
      case 'serial_numbers':
        await _applySerialNumber(operation, recordId, data);
        return true;
      case 'products':
        await _applyProduct(operation, recordId, data);
        return true;
      case 'customer_groups':
        await _applyCustomerGroup(operation, recordId, data);
        return true;
      case 'customers':
        await _applyCustomer(operation, recordId, data);
        return true;
      case 'points_transactions':
        await _applyPointsTransaction(operation, recordId, data);
        return true;
      case 'suppliers':
        await _applySupplier(operation, recordId, data);
        return true;
      case 'sales_orders':
        await _applySalesOrder(operation, recordId, data);
        return true;
      case 'sales_order_items':
        await _applySalesOrderItem(operation, recordId, data);
        return true;
      case 'order_item_modifiers':
        await _applyOrderItemModifier(operation, recordId, data);
        return true;
      case 'purchase_orders':
        await _applyPurchaseOrder(operation, recordId, data);
        return true;
      case 'purchase_order_items':
        await _applyPurchaseOrderItem(operation, recordId, data);
        return true;
      case 'goods_receipts':
        await _applyGoodsReceipt(operation, recordId, data);
        return true;
      case 'goods_receipt_items':
        await _applyGoodsReceiptItem(operation, recordId, data);
        return true;
      case 'purchase_returns':
        await _applyPurchaseReturn(operation, recordId, data);
        return true;
      case 'purchase_return_items':
        await _applyPurchaseReturnItem(operation, recordId, data);
        return true;
      case 'stock_movements':
        await _applyStockMovement(operation, recordId, data);
        return true;
      case 'promotions':
        await _applyPromotion(operation, recordId, data);
        return true;
      case 'promotion_usages':
        await _applyPromotionUsage(operation, recordId, data);
        return true;
      case 'coupons':
        await _applyCoupon(operation, recordId, data);
        return true;
      case 'ar_invoices':
        await _applyArInvoice(operation, recordId, data);
        return true;
      case 'ar_invoice_items':
        await _applyArInvoiceItem(operation, recordId, data);
        return true;
      case 'ar_receipts':
        await _applyArReceipt(operation, recordId, data);
        return true;
      case 'ar_receipt_allocations':
        await _applyArReceiptAllocation(operation, recordId, data);
        return true;
      case 'ap_invoices':
        await _applyApInvoice(operation, recordId, data);
        return true;
      case 'ap_invoice_items':
        await _applyApInvoiceItem(operation, recordId, data);
        return true;
      case 'ap_payments':
        await _applyApPayment(operation, recordId, data);
        return true;
      case 'ap_payment_allocations':
        await _applyApPaymentAllocation(operation, recordId, data);
        return true;
      case 'devices':
        await _applyDevice(operation, recordId, data);
        return true;
      case 'active_sessions':
        await _applyActiveSession(operation, recordId, data);
        return true;
      default:
        print('⚠️ Unsupported sync table: $tableName');
        return false;
    }
  }

  Future<void> _acknowledgePulledItems(List<String> queueIds) async {
    final api = _ref.read(apiClientProvider);
    try {
      final response = await api.post(
        '/api/branches/sync/acknowledge',
        data: {'queue_ids': queueIds},
      );
      if (response.statusCode != 200) {
        print('⚠️ Failed to acknowledge pulled items: ${response.statusCode}');
      }
    } catch (e) {
      print('⚠️ Acknowledge error: $e');
    }
  }

  Future<void> _persistBatchMetrics(SyncBatchMetrics metrics) async {
    try {
      final now = DateTime.now();
      final batchId = 'B${now.microsecondsSinceEpoch}';
      await _db.into(_db.auditLogs).insert(
            AuditLogsCompanion(
              logId: Value('LOG$batchId'),
              tableNameValue: const Value('sync_batches'),
              recordId: Value(batchId),
              action: const Value('SYNC_BATCH'),
              newValue: Value({
                'total_items': metrics.totalItems,
                'applied_items': metrics.appliedItems,
                'replayed_items': metrics.replayedItems,
                'passes_used': metrics.passesUsed,
                'pending_items': metrics.pendingItems,
                'app_mode': AppModeConfig.isStandalone
                    ? 'standalone'
                    : (AppModeConfig.isMaster ? 'master' : 'client'),
                'device_name': AppModeConfig.deviceName,
                'created_at': now.toIso8601String(),
              }),
              createdAt: Value(now),
            ),
          );
    } catch (e) {
      print('⚠️ Failed to persist sync batch metrics: $e');
    }
  }

  Future<List<Map<String, dynamic>>> loadRecentBatchMetrics({
    int limit = 20,
  }) async {
    final rows = await (_db.select(_db.auditLogs)
          ..where((t) =>
              t.action.equals('SYNC_BATCH') &
              t.tableNameValue.equals('sync_batches'))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(limit))
        .get();

    return rows.map((row) {
      final payload = Map<String, dynamic>.from(row.newValue as Map? ?? const {});
      return {
        'batch_id': row.recordId,
        'created_at':
            payload['created_at'] ?? row.createdAt.toIso8601String(),
        'total_items': payload['total_items'] as int? ?? 0,
        'applied_items': payload['applied_items'] as int? ?? 0,
        'replayed_items': payload['replayed_items'] as int? ?? 0,
        'passes_used': payload['passes_used'] as int? ?? 0,
        'pending_items': payload['pending_items'] as int? ?? 0,
        'app_mode': payload['app_mode'] as String?,
        'device_name': payload['device_name'] as String?,
        'payload': payload,
      };
    }).toList();
  }

  Future<void> _applyCompany(
    String operation,
    String recordId,
    Map<String, dynamic> data,
  ) async {
    if (operation == 'DELETE') {
      await (_db.delete(_db.companies)
            ..where((t) => t.companyId.equals(recordId)))
          .go();
      return;
    }

    await _db.into(_db.companies).insertOnConflictUpdate(
          CompaniesCompanion(
            companyId: Value(recordId),
            companyName: Value(_stringValue(data, 'company_name') ?? '-'),
            taxId: Value(_stringValue(data, 'tax_id')),
            address: Value(_stringValue(data, 'address')),
            phone: Value(_stringValue(data, 'phone')),
            logoUrl: Value(_stringValue(data, 'logo_url')),
            createdAt: Value(_dateTimeValue(data, 'created_at') ?? DateTime.now()),
            updatedAt: Value(_dateTimeValue(data, 'updated_at') ?? DateTime.now()),
          ),
        );
  }

  Future<void> _applyBranch(
    String operation,
    String recordId,
    Map<String, dynamic> data,
  ) async {
    if (operation == 'DELETE') {
      await (_db.delete(_db.branches)
            ..where((t) => t.branchId.equals(recordId)))
          .go();
      return;
    }

    await _db.into(_db.branches).insertOnConflictUpdate(
          BranchesCompanion(
            branchId: Value(recordId),
            companyId: Value(_stringValue(data, 'company_id') ?? 'COMP001'),
            branchCode: Value(_stringValue(data, 'branch_code') ?? recordId),
            branchName: Value(_stringValue(data, 'branch_name') ?? '-'),
            address: Value(_stringValue(data, 'address')),
            phone: Value(_stringValue(data, 'phone')),
            isActive: Value(_boolValue(data, 'is_active', fallback: true)),
            createdAt: Value(_dateTimeValue(data, 'created_at') ?? DateTime.now()),
            updatedAt: Value(_dateTimeValue(data, 'updated_at') ?? DateTime.now()),
          ),
        );
  }

  Future<void> _applyRole(
    String operation,
    String recordId,
    Map<String, dynamic> data,
  ) async {
    if (operation == 'DELETE') {
      await (_db.delete(_db.roles)..where((t) => t.roleId.equals(recordId))).go();
      return;
    }

    await _db.into(_db.roles).insertOnConflictUpdate(
          RolesCompanion(
            roleId: Value(recordId),
            roleName: Value(_stringValue(data, 'role_name') ?? '-'),
            permissions: Value(data['permissions'] ?? const {}),
            createdAt: Value(_dateTimeValue(data, 'created_at') ?? DateTime.now()),
          ),
        );
  }

  Future<void> _applyUser(
    String operation,
    String recordId,
    Map<String, dynamic> data,
  ) async {
    if (operation == 'DELETE') {
      await (_db.delete(_db.users)..where((t) => t.userId.equals(recordId))).go();
      return;
    }

    await _db.into(_db.users).insertOnConflictUpdate(
          UsersCompanion(
            userId: Value(recordId),
            username: Value(_stringValue(data, 'username') ?? recordId),
            passwordHash:
                Value(_stringValue(data, 'password_hash') ?? 'SYNC_IMPORTED'),
            fullName: Value(_stringValue(data, 'full_name') ?? '-'),
            email: Value(_stringValue(data, 'email')),
            phone: Value(_stringValue(data, 'phone')),
            roleId: Value(_stringValue(data, 'role_id')),
            branchId: Value(_stringValue(data, 'branch_id')),
            isActive: Value(_boolValue(data, 'is_active', fallback: true)),
            lastLogin: Value(_dateTimeValue(data, 'last_login')),
            createdAt: Value(_dateTimeValue(data, 'created_at') ?? DateTime.now()),
            updatedAt: Value(_dateTimeValue(data, 'updated_at') ?? DateTime.now()),
          ),
        );
  }

  Future<void> _applyProductGroup(
    String operation,
    String recordId,
    Map<String, dynamic> data,
  ) async {
    if (operation == 'DELETE') {
      await (_db.delete(_db.productGroups)
            ..where((t) => t.groupId.equals(recordId)))
          .go();
      return;
    }

    await _db.into(_db.productGroups).insertOnConflictUpdate(
          ProductGroupsCompanion(
            groupId: Value(recordId),
            groupCode: Value(_stringValue(data, 'group_code') ?? recordId),
            groupName: Value(_stringValue(data, 'group_name') ?? '-'),
            parentGroupId: Value(_stringValue(data, 'parent_group_id')),
            groupType: Value(_stringValue(data, 'group_type') ?? 'GENERAL'),
            imageUrl: Value(_stringValue(data, 'image_url')),
            displayOrder: Value(_intValue(data, 'display_order')),
            createdAt: Value(_dateTimeValue(data, 'created_at') ?? DateTime.now()),
          ),
        );
  }

  Future<void> _applyModifierGroup(
    String operation,
    String recordId,
    Map<String, dynamic> data,
  ) async {
    if (operation == 'DELETE') {
      await (_db.delete(_db.modifierGroups)
            ..where((t) => t.modifierGroupId.equals(recordId)))
          .go();
      return;
    }

    await _db.into(_db.modifierGroups).insertOnConflictUpdate(
          ModifierGroupsCompanion(
            modifierGroupId: Value(recordId),
            groupName: Value(_stringValue(data, 'group_name') ?? '-'),
            selectionType: Value(
              _stringValue(data, 'selection_type') ?? 'SINGLE',
            ),
            minSelection: Value(_intValue(data, 'min_selection')),
            maxSelection: Value(_intValue(data, 'max_selection', fallback: 1)),
            isRequired: Value(_boolValue(data, 'is_required', fallback: false)),
            createdAt: Value(
              _dateTimeValue(data, 'created_at') ?? DateTime.now(),
            ),
          ),
        );
  }

  Future<void> _applyModifier(
    String operation,
    String recordId,
    Map<String, dynamic> data,
  ) async {
    if (operation == 'DELETE') {
      await (_db.delete(_db.modifiers)
            ..where((t) => t.modifierId.equals(recordId)))
          .go();
      return;
    }

    await _db.into(_db.modifiers).insertOnConflictUpdate(
          ModifiersCompanion(
            modifierId: Value(recordId),
            modifierGroupId: Value(_stringValue(data, 'modifier_group_id') ?? ''),
            modifierName: Value(_stringValue(data, 'modifier_name') ?? '-'),
            priceAdjustment: Value(_doubleValue(data, 'price_adjustment')),
            isDefault: Value(_boolValue(data, 'is_default', fallback: false)),
            displayOrder: Value(_intValue(data, 'display_order')),
            createdAt: Value(
              _dateTimeValue(data, 'created_at') ?? DateTime.now(),
            ),
          ),
        );
  }

  Future<bool> _applyProductModifier(
    String operation,
    String recordId,
    Map<String, dynamic> data,
  ) async {
    final keys = _compositeKeyParts(
      recordId,
      fallback: [
        _stringValue(data, 'product_id'),
        _stringValue(data, 'modifier_group_id'),
      ],
    );
    final productId = keys.$1;
    final modifierGroupId = keys.$2;

    if (productId == null || modifierGroupId == null) {
      print('⚠️ Skip product_modifiers with incomplete key: $recordId');
      return false;
    }

    if (operation == 'DELETE') {
      await (_db.delete(_db.productModifiers)
            ..where((t) => t.productId.equals(productId))
            ..where((t) => t.modifierGroupId.equals(modifierGroupId)))
          .go();
      return true;
    }

    await _db.into(_db.productModifiers).insertOnConflictUpdate(
          ProductModifiersCompanion(
            productId: Value(productId),
            modifierGroupId: Value(modifierGroupId),
            isRequired: Value(_boolValue(data, 'is_required', fallback: false)),
          ),
        );
    return true;
  }

  Future<void> _applyZone(
    String operation,
    String recordId,
    Map<String, dynamic> data,
  ) async {
    if (operation == 'DELETE') {
      await (_db.delete(_db.zones)..where((t) => t.zoneId.equals(recordId))).go();
      return;
    }

    await _db.into(_db.zones).insertOnConflictUpdate(
          ZonesCompanion(
            zoneId: Value(recordId),
            zoneName: Value(_stringValue(data, 'zone_name') ?? '-'),
            branchId: Value(_stringValue(data, 'branch_id') ?? ''),
            displayOrder: Value(_intValue(data, 'display_order')),
            isActive: Value(_boolValue(data, 'is_active', fallback: true)),
            createdAt: Value(
              _dateTimeValue(data, 'created_at') ?? DateTime.now(),
            ),
          ),
        );
  }

  Future<void> _applyDiningTable(
    String operation,
    String recordId,
    Map<String, dynamic> data,
  ) async {
    if (operation == 'DELETE') {
      await (_db.delete(_db.diningTables)
            ..where((t) => t.tableId.equals(recordId)))
          .go();
      return;
    }

    await _db.into(_db.diningTables).insertOnConflictUpdate(
          DiningTablesCompanion(
            tableId: Value(recordId),
            tableNo: Value(_stringValue(data, 'table_no') ?? recordId),
            tableDisplayName: Value(_stringValue(data, 'table_display_name')),
            zoneId: Value(_stringValue(data, 'zone_id') ?? ''),
            capacity: Value(_intValue(data, 'capacity', fallback: 4)),
            status: Value(_stringValue(data, 'status') ?? 'AVAILABLE'),
            currentOrderId: Value(_stringValue(data, 'current_order_id')),
            lastOccupiedAt: Value(_dateTimeValue(data, 'last_occupied_at')),
            createdAt: Value(
              _dateTimeValue(data, 'created_at') ?? DateTime.now(),
            ),
          ),
        );
  }

  Future<void> _applyWarehouse(
    String operation,
    String recordId,
    Map<String, dynamic> data,
  ) async {
    if (operation == 'DELETE') {
      await (_db.delete(_db.warehouses)
            ..where((t) => t.warehouseId.equals(recordId)))
          .go();
      return;
    }

    await _db.into(_db.warehouses).insertOnConflictUpdate(
          WarehousesCompanion(
            warehouseId: Value(recordId),
            warehouseCode:
                Value(_stringValue(data, 'warehouse_code') ?? recordId),
            warehouseName: Value(_stringValue(data, 'warehouse_name') ?? '-'),
            branchId: Value(_stringValue(data, 'branch_id') ?? ''),
            isActive: Value(_boolValue(data, 'is_active', fallback: true)),
            createdAt: Value(_dateTimeValue(data, 'created_at') ?? DateTime.now()),
          ),
        );
  }

  Future<void> _applyStockBalance(
    String operation,
    String recordId,
    Map<String, dynamic> data,
  ) async {
    if (operation == 'DELETE') {
      await (_db.delete(_db.stockBalances)
            ..where((t) => t.stockId.equals(recordId)))
          .go();
      return;
    }

    await _db.into(_db.stockBalances).insertOnConflictUpdate(
          StockBalancesCompanion(
            stockId: Value(recordId),
            productId: Value(_stringValue(data, 'product_id') ?? ''),
            warehouseId: Value(_stringValue(data, 'warehouse_id') ?? ''),
            quantity: Value(_doubleValue(data, 'quantity')),
            reservedQty: Value(_doubleValue(data, 'reserved_qty')),
            avgCost: Value(_doubleValue(data, 'avg_cost')),
            lastCost: Value(_doubleValue(data, 'last_cost')),
            updatedAt: Value(_dateTimeValue(data, 'updated_at') ?? DateTime.now()),
          ),
        );
  }

  Future<void> _applySerialNumber(
    String operation,
    String recordId,
    Map<String, dynamic> data,
  ) async {
    if (operation == 'DELETE') {
      await (_db.delete(_db.serialNumbers)
            ..where((t) => t.serialId.equals(recordId)))
          .go();
      return;
    }

    await _db.into(_db.serialNumbers).insertOnConflictUpdate(
          SerialNumbersCompanion(
            serialId: Value(recordId),
            productId: Value(_stringValue(data, 'product_id') ?? ''),
            serialNo: Value(_stringValue(data, 'serial_no') ?? ''),
            warehouseId: Value(_stringValue(data, 'warehouse_id') ?? ''),
            status: Value(_stringValue(data, 'status') ?? 'AVAILABLE'),
            createdAt: Value(_dateTimeValue(data, 'created_at') ?? DateTime.now()),
          ),
        );
  }

  Future<void> _applyProduct(
    String operation,
    String recordId,
    Map<String, dynamic> data,
  ) async {
    if (operation == 'DELETE') {
      await (_db.delete(_db.products)
            ..where((t) => t.productId.equals(recordId)))
          .go();
      return;
    }

    await _db.into(_db.products).insertOnConflictUpdate(
          ProductsCompanion(
            productId: Value(recordId),
            productCode: Value(_stringValue(data, 'product_code') ?? recordId),
            barcode: Value(_stringValue(data, 'barcode')),
            productName: Value(_stringValue(data, 'product_name') ?? '-'),
            productNameEn: Value(_stringValue(data, 'product_name_en')),
            groupId: Value(_stringValue(data, 'group_id')),
            brand: Value(_stringValue(data, 'brand')),
            model: Value(_stringValue(data, 'model')),
            color: Value(_stringValue(data, 'color')),
            baseUnit: Value(_stringValue(data, 'base_unit') ?? 'PCS'),
            unitConversion: Value(data['unit_conversion']),
            priceLevel1: Value(_doubleValue(data, 'price_level1')),
            priceLevel2: Value(_doubleValue(data, 'price_level2')),
            priceLevel3: Value(_doubleValue(data, 'price_level3')),
            priceLevel4: Value(_doubleValue(data, 'price_level4')),
            priceLevel5: Value(_doubleValue(data, 'price_level5')),
            costMethod: Value(_stringValue(data, 'cost_method') ?? 'AVG'),
            standardCost: Value(_doubleValue(data, 'standard_cost')),
            isStockControl:
                Value(_boolValue(data, 'is_stock_control', fallback: true)),
            isSerialControl:
                Value(_boolValue(data, 'is_serial_control', fallback: false)),
            allowNegativeStock:
                Value(_boolValue(data, 'allow_negative_stock', fallback: false)),
            reorderPoint: Value(_doubleValue(data, 'reorder_point')),
            vatType: Value(_stringValue(data, 'vat_type') ?? 'I'),
            vatRate: Value(_doubleValue(data, 'vat_rate', fallback: 7)),
            imageUrls: Value(data['image_urls']),
            imagePath: Value(_stringValue(data, 'image_path')),
            isActive: Value(_boolValue(data, 'is_active', fallback: true)),
            createdAt: Value(_dateTimeValue(data, 'created_at') ?? DateTime.now()),
            updatedAt: Value(_dateTimeValue(data, 'updated_at') ?? DateTime.now()),
          ),
        );
  }

  Future<void> _applyCustomerGroup(
    String operation,
    String recordId,
    Map<String, dynamic> data,
  ) async {
    if (operation == 'DELETE') {
      await (_db.delete(_db.customerGroups)
            ..where((t) => t.customerGroupId.equals(recordId)))
          .go();
      return;
    }

    await _db.into(_db.customerGroups).insertOnConflictUpdate(
          CustomerGroupsCompanion(
            customerGroupId: Value(recordId),
            groupName: Value(_stringValue(data, 'group_name') ?? '-'),
            discountRate: Value(_doubleValue(data, 'discount_rate')),
            priceLevel: Value(_intValue(data, 'price_level', fallback: 1)),
            createdAt: Value(_dateTimeValue(data, 'created_at') ?? DateTime.now()),
          ),
        );
  }

  Future<void> _applyCustomer(
    String operation,
    String recordId,
    Map<String, dynamic> data,
  ) async {
    if (operation == 'DELETE') {
      await (_db.delete(_db.customers)
            ..where((t) => t.customerId.equals(recordId)))
          .go();
      return;
    }

    await _db.into(_db.customers).insertOnConflictUpdate(
          CustomersCompanion(
            customerId: Value(recordId),
            customerCode: Value(_stringValue(data, 'customer_code') ?? recordId),
            customerName: Value(_stringValue(data, 'customer_name') ?? '-'),
            customerGroupId: Value(_stringValue(data, 'customer_group_id')),
            address: Value(_stringValue(data, 'address')),
            phone: Value(_stringValue(data, 'phone')),
            email: Value(_stringValue(data, 'email')),
            taxId: Value(_stringValue(data, 'tax_id')),
            creditLimit: Value(_doubleValue(data, 'credit_limit')),
            creditDays: Value(_intValue(data, 'credit_days')),
            currentBalance: Value(_doubleValue(data, 'current_balance')),
            memberNo: Value(_stringValue(data, 'member_no')),
            points: Value(_intValue(data, 'points')),
            isActive: Value(_boolValue(data, 'is_active', fallback: true)),
            createdAt: Value(_dateTimeValue(data, 'created_at') ?? DateTime.now()),
            updatedAt: Value(_dateTimeValue(data, 'updated_at') ?? DateTime.now()),
          ),
        );
  }

  Future<void> _applyPointsTransaction(
    String operation,
    String recordId,
    Map<String, dynamic> data,
  ) async {
    if (operation == 'DELETE') {
      await (_db.delete(_db.pointsTransactions)
            ..where((t) => t.transactionId.equals(recordId)))
          .go();
      return;
    }

    await _db.into(_db.pointsTransactions).insertOnConflictUpdate(
          PointsTransactionsCompanion(
            transactionId: Value(recordId),
            customerId: Value(_stringValue(data, 'customer_id') ?? ''),
            type: Value(_stringValue(data, 'type') ?? 'EARN'),
            points: Value(_intValue(data, 'points')),
            referenceNo: Value(_stringValue(data, 'reference_no')),
            remark: Value(_stringValue(data, 'remark')),
            createdAt: Value(_dateTimeValue(data, 'created_at') ?? DateTime.now()),
          ),
        );
  }

  Future<void> _applySupplier(
    String operation,
    String recordId,
    Map<String, dynamic> data,
  ) async {
    if (operation == 'DELETE') {
      await (_db.delete(_db.suppliers)
            ..where((t) => t.supplierId.equals(recordId)))
          .go();
      return;
    }

    await _db.into(_db.suppliers).insertOnConflictUpdate(
          SuppliersCompanion(
            supplierId: Value(recordId),
            supplierCode: Value(_stringValue(data, 'supplier_code') ?? recordId),
            supplierName: Value(_stringValue(data, 'supplier_name') ?? '-'),
            contactPerson: Value(_stringValue(data, 'contact_person')),
            phone: Value(_stringValue(data, 'phone')),
            email: Value(_stringValue(data, 'email')),
            lineId: Value(_stringValue(data, 'line_id')),
            address: Value(_stringValue(data, 'address')),
            taxId: Value(_stringValue(data, 'tax_id')),
            creditTerm: Value(_intValue(data, 'credit_term', fallback: 30)),
            creditLimit: Value(_doubleValue(data, 'credit_limit')),
            currentBalance: Value(_doubleValue(data, 'current_balance')),
            isActive: Value(_boolValue(data, 'is_active', fallback: true)),
            createdAt: Value(_dateTimeValue(data, 'created_at') ?? DateTime.now()),
            updatedAt: Value(_dateTimeValue(data, 'updated_at') ?? DateTime.now()),
          ),
        );
  }

  Future<void> _applySalesOrder(
    String operation,
    String recordId,
    Map<String, dynamic> data,
  ) async {
    if (operation == 'DELETE') {
      await (_db.delete(_db.salesOrders)
            ..where((t) => t.orderId.equals(recordId)))
          .go();
      return;
    }

    await _db.into(_db.salesOrders).insertOnConflictUpdate(
          SalesOrdersCompanion(
            orderId: Value(recordId),
            orderNo: Value(_stringValue(data, 'order_no') ?? recordId),
            orderDate: Value(_dateTimeValue(data, 'order_date') ?? DateTime.now()),
            orderType: Value(_stringValue(data, 'order_type') ?? 'SALE'),
            customerId: Value(_stringValue(data, 'customer_id')),
            customerName: Value(_stringValue(data, 'customer_name')),
            customerAddress: Value(_stringValue(data, 'customer_address')),
            customerTaxId: Value(_stringValue(data, 'customer_tax_id')),
            branchId: Value(_stringValue(data, 'branch_id') ?? ''),
            warehouseId: Value(_stringValue(data, 'warehouse_id') ?? ''),
            userId: Value(_stringValue(data, 'user_id') ?? ''),
            tableId: Value(_stringValue(data, 'table_id')),
            partySize: Value(_intValueOrNull(data, 'party_size')),
            subtotal: Value(_doubleValue(data, 'subtotal')),
            discountAmount: Value(_doubleValue(data, 'discount_amount')),
            amountBeforeVat: Value(_doubleValue(data, 'amount_before_vat')),
            vatAmount: Value(_doubleValue(data, 'vat_amount')),
            totalAmount: Value(_doubleValue(data, 'total_amount')),
            couponDiscount: Value(_doubleValue(data, 'coupon_discount')),
            couponCodes: Value(_stringValue(data, 'coupon_codes')),
            pointsUsed: Value(_intValue(data, 'points_used')),
            promotionIds: Value(_stringValue(data, 'promotion_ids')),
            paymentType: Value(_stringValue(data, 'payment_type') ?? 'CASH'),
            paidAmount: Value(_doubleValue(data, 'paid_amount')),
            changeAmount: Value(_doubleValue(data, 'change_amount')),
            status: Value(_stringValue(data, 'status') ?? 'OPEN'),
            isVatInclude: Value(_boolValue(data, 'is_vat_include', fallback: true)),
            remark: Value(_stringValue(data, 'remark')),
            createdAt: Value(_dateTimeValue(data, 'created_at') ?? DateTime.now()),
            updatedAt: Value(_dateTimeValue(data, 'updated_at') ?? DateTime.now()),
          ),
        );
  }

  Future<void> _applySalesOrderItem(
    String operation,
    String recordId,
    Map<String, dynamic> data,
  ) async {
    if (operation == 'DELETE') {
      await (_db.delete(_db.salesOrderItems)
            ..where((t) => t.itemId.equals(recordId)))
          .go();
      return;
    }

    await _db.into(_db.salesOrderItems).insertOnConflictUpdate(
          SalesOrderItemsCompanion(
            itemId: Value(recordId),
            orderId: Value(_stringValue(data, 'order_id') ?? ''),
            lineNo: Value(_intValue(data, 'line_no', fallback: 1)),
            productId: Value(_stringValue(data, 'product_id') ?? ''),
            productCode: Value(_stringValue(data, 'product_code') ?? ''),
            productName: Value(_stringValue(data, 'product_name') ?? '-'),
            unit: Value(_stringValue(data, 'unit') ?? ''),
            quantity: Value(_doubleValue(data, 'quantity')),
            unitPrice: Value(_doubleValue(data, 'unit_price')),
            discountPercent: Value(_doubleValue(data, 'discount_percent')),
            discountAmount: Value(_doubleValue(data, 'discount_amount')),
            amount: Value(_doubleValue(data, 'amount')),
            cost: Value(_doubleValue(data, 'cost')),
            warehouseId: Value(_stringValue(data, 'warehouse_id') ?? ''),
            serialNo: Value(_stringValue(data, 'serial_no')),
            kitchenStatus: Value(_stringValue(data, 'kitchen_status') ?? 'PENDING'),
            preparedAt: Value(_dateTimeValue(data, 'prepared_at')),
            specialInstructions: Value(_stringValue(data, 'special_instructions')),
            isFreeItem: Value(_boolValue(data, 'is_free_item', fallback: false)),
            promotionId: Value(_stringValue(data, 'promotion_id')),
            createdAt: Value(_dateTimeValue(data, 'created_at') ?? DateTime.now()),
          ),
        );
  }

  Future<void> _applyOrderItemModifier(
    String operation,
    String recordId,
    Map<String, dynamic> data,
  ) async {
    if (operation == 'DELETE') {
      await (_db.delete(_db.orderItemModifiers)
            ..where((t) => t.itemModifierId.equals(recordId)))
          .go();
      return;
    }

    await _db.into(_db.orderItemModifiers).insertOnConflictUpdate(
          OrderItemModifiersCompanion(
            itemModifierId: Value(recordId),
            orderItemId: Value(_stringValue(data, 'order_item_id') ?? ''),
            modifierId: Value(_stringValue(data, 'modifier_id') ?? ''),
            modifierName: Value(_stringValue(data, 'modifier_name') ?? '-'),
            priceAdjustment: Value(_doubleValue(data, 'price_adjustment')),
            createdAt: Value(_dateTimeValue(data, 'created_at') ?? DateTime.now()),
          ),
        );
  }

  Future<void> _applyPurchaseOrder(
    String operation,
    String recordId,
    Map<String, dynamic> data,
  ) async {
    if (operation == 'DELETE') {
      await (_db.delete(_db.purchaseOrders)
            ..where((t) => t.poId.equals(recordId)))
          .go();
      return;
    }

    await _db.into(_db.purchaseOrders).insertOnConflictUpdate(
          PurchaseOrdersCompanion(
            poId: Value(recordId),
            poNo: Value(_stringValue(data, 'po_no') ?? recordId),
            poDate: Value(_dateTimeValue(data, 'po_date') ?? DateTime.now()),
            supplierId: Value(_stringValue(data, 'supplier_id') ?? ''),
            supplierName: Value(_stringValue(data, 'supplier_name') ?? '-'),
            warehouseId: Value(_stringValue(data, 'warehouse_id') ?? ''),
            warehouseName: Value(_stringValue(data, 'warehouse_name') ?? '-'),
            userId: Value(_stringValue(data, 'user_id') ?? ''),
            subtotal: Value(_doubleValue(data, 'subtotal')),
            discountAmount: Value(_doubleValue(data, 'discount_amount')),
            vatAmount: Value(_doubleValue(data, 'vat_amount')),
            totalAmount: Value(_doubleValue(data, 'total_amount')),
            status: Value(_stringValue(data, 'status') ?? 'DRAFT'),
            paymentStatus: Value(_stringValue(data, 'payment_status') ?? 'UNPAID'),
            deliveryDate: Value(_dateTimeValue(data, 'delivery_date')),
            remark: Value(_stringValue(data, 'remark')),
            createdAt: Value(_dateTimeValue(data, 'created_at') ?? DateTime.now()),
            updatedAt: Value(_dateTimeValue(data, 'updated_at') ?? DateTime.now()),
          ),
        );
  }

  Future<void> _applyPurchaseOrderItem(
    String operation,
    String recordId,
    Map<String, dynamic> data,
  ) async {
    if (operation == 'DELETE') {
      await (_db.delete(_db.purchaseOrderItems)
            ..where((t) => t.itemId.equals(recordId)))
          .go();
      return;
    }

    await _db.into(_db.purchaseOrderItems).insertOnConflictUpdate(
          PurchaseOrderItemsCompanion(
            itemId: Value(recordId),
            poId: Value(_stringValue(data, 'po_id') ?? ''),
            lineNo: Value(_intValue(data, 'line_no', fallback: 1)),
            productId: Value(_stringValue(data, 'product_id') ?? ''),
            productCode: Value(_stringValue(data, 'product_code') ?? ''),
            productName: Value(_stringValue(data, 'product_name') ?? '-'),
            unit: Value(_stringValue(data, 'unit') ?? ''),
            quantity: Value(_doubleValue(data, 'quantity')),
            unitPrice: Value(_doubleValue(data, 'unit_price')),
            discountPercent: Value(_doubleValue(data, 'discount_percent')),
            discountAmount: Value(_doubleValue(data, 'discount_amount')),
            amount: Value(_doubleValue(data, 'amount')),
            receivedQuantity: Value(_doubleValue(data, 'received_quantity')),
            remainingQuantity: Value(_doubleValue(data, 'remaining_quantity')),
          ),
        );
  }

  Future<void> _applyGoodsReceipt(
    String operation,
    String recordId,
    Map<String, dynamic> data,
  ) async {
    if (operation == 'DELETE') {
      await (_db.delete(_db.goodsReceipts)
            ..where((t) => t.grId.equals(recordId)))
          .go();
      return;
    }

    await _db.into(_db.goodsReceipts).insertOnConflictUpdate(
          GoodsReceiptsCompanion(
            grId: Value(recordId),
            grNo: Value(_stringValue(data, 'gr_no') ?? recordId),
            grDate: Value(_dateTimeValue(data, 'gr_date') ?? DateTime.now()),
            poId: Value(_stringValue(data, 'po_id')),
            poNo: Value(_stringValue(data, 'po_no')),
            supplierId: Value(_stringValue(data, 'supplier_id') ?? ''),
            supplierName: Value(_stringValue(data, 'supplier_name') ?? '-'),
            warehouseId: Value(_stringValue(data, 'warehouse_id') ?? ''),
            warehouseName: Value(_stringValue(data, 'warehouse_name') ?? '-'),
            userId: Value(_stringValue(data, 'user_id') ?? ''),
            status: Value(_stringValue(data, 'status') ?? 'DRAFT'),
            remark: Value(_stringValue(data, 'remark')),
            createdAt: Value(_dateTimeValue(data, 'created_at') ?? DateTime.now()),
            updatedAt: Value(_dateTimeValue(data, 'updated_at') ?? DateTime.now()),
          ),
        );
  }

  Future<void> _applyGoodsReceiptItem(
    String operation,
    String recordId,
    Map<String, dynamic> data,
  ) async {
    if (operation == 'DELETE') {
      await (_db.delete(_db.goodsReceiptItems)
            ..where((t) => t.itemId.equals(recordId)))
          .go();
      return;
    }

    await _db.into(_db.goodsReceiptItems).insertOnConflictUpdate(
          GoodsReceiptItemsCompanion(
            itemId: Value(recordId),
            grId: Value(_stringValue(data, 'gr_id') ?? ''),
            lineNo: Value(_intValue(data, 'line_no', fallback: 1)),
            poItemId: Value(_stringValue(data, 'po_item_id')),
            productId: Value(_stringValue(data, 'product_id') ?? ''),
            productCode: Value(_stringValue(data, 'product_code') ?? ''),
            productName: Value(_stringValue(data, 'product_name') ?? '-'),
            unit: Value(_stringValue(data, 'unit') ?? ''),
            orderedQuantity: Value(_doubleValue(data, 'ordered_quantity')),
            receivedQuantity: Value(_doubleValue(data, 'received_quantity')),
            unitPrice: Value(_doubleValue(data, 'unit_price')),
            amount: Value(_doubleValue(data, 'amount')),
            lotNumber: Value(_stringValue(data, 'lot_number')),
            expiryDate: Value(_dateTimeValue(data, 'expiry_date')),
            remark: Value(_stringValue(data, 'remark')),
          ),
        );
  }

  Future<void> _applyPurchaseReturn(
    String operation,
    String recordId,
    Map<String, dynamic> data,
  ) async {
    if (operation == 'DELETE') {
      await (_db.delete(_db.purchaseReturns)
            ..where((t) => t.returnId.equals(recordId)))
          .go();
      return;
    }

    await _db.into(_db.purchaseReturns).insertOnConflictUpdate(
          PurchaseReturnsCompanion(
            returnId: Value(recordId),
            returnNo: Value(_stringValue(data, 'return_no') ?? recordId),
            returnDate: Value(_dateTimeValue(data, 'return_date') ?? DateTime.now()),
            supplierId: Value(_stringValue(data, 'supplier_id') ?? ''),
            supplierName: Value(_stringValue(data, 'supplier_name') ?? '-'),
            referenceType: Value(_stringValue(data, 'reference_type')),
            referenceId: Value(_stringValue(data, 'reference_id')),
            totalAmount: Value(_doubleValue(data, 'total_amount')),
            status: Value(_stringValue(data, 'status') ?? 'DRAFT'),
            reason: Value(_stringValue(data, 'reason')),
            remark: Value(_stringValue(data, 'remark')),
            userId: Value(_stringValue(data, 'user_id') ?? ''),
            createdAt: Value(_dateTimeValue(data, 'created_at') ?? DateTime.now()),
            updatedAt: Value(_dateTimeValue(data, 'updated_at') ?? DateTime.now()),
          ),
        );
  }

  Future<void> _applyPurchaseReturnItem(
    String operation,
    String recordId,
    Map<String, dynamic> data,
  ) async {
    if (operation == 'DELETE') {
      await (_db.delete(_db.purchaseReturnItems)
            ..where((t) => t.itemId.equals(recordId)))
          .go();
      return;
    }

    await _db.into(_db.purchaseReturnItems).insertOnConflictUpdate(
          PurchaseReturnItemsCompanion(
            itemId: Value(recordId),
            returnId: Value(_stringValue(data, 'return_id') ?? ''),
            lineNo: Value(_intValue(data, 'line_no', fallback: 1)),
            productId: Value(_stringValue(data, 'product_id') ?? ''),
            productCode: Value(_stringValue(data, 'product_code') ?? ''),
            productName: Value(_stringValue(data, 'product_name') ?? '-'),
            unit: Value(_stringValue(data, 'unit') ?? ''),
            warehouseId: Value(_stringValue(data, 'warehouse_id') ?? ''),
            warehouseName: Value(_stringValue(data, 'warehouse_name') ?? '-'),
            quantity: Value(_doubleValue(data, 'quantity')),
            unitPrice: Value(_doubleValue(data, 'unit_price')),
            amount: Value(_doubleValue(data, 'amount')),
            reason: Value(_stringValue(data, 'reason')),
            remark: Value(_stringValue(data, 'remark')),
          ),
        );
  }

  Future<void> _applyStockMovement(
    String operation,
    String recordId,
    Map<String, dynamic> data,
  ) async {
    if (operation == 'DELETE') {
      await (_db.delete(_db.stockMovements)
            ..where((t) => t.movementId.equals(recordId)))
          .go();
      return;
    }

    await _db.into(_db.stockMovements).insertOnConflictUpdate(
          StockMovementsCompanion(
            movementId: Value(recordId),
            movementNo: Value(_stringValue(data, 'movement_no') ?? recordId),
            movementDate: Value(_dateTimeValue(data, 'movement_date') ?? DateTime.now()),
            movementType: Value(_stringValue(data, 'movement_type') ?? ''),
            productId: Value(_stringValue(data, 'product_id') ?? ''),
            warehouseId: Value(_stringValue(data, 'warehouse_id') ?? ''),
            quantity: Value(_doubleValue(data, 'quantity')),
            unitCost: Value(_doubleValue(data, 'unit_cost')),
            lotNumber: Value(_stringValue(data, 'lot_number')),
            expiryDate: Value(_dateTimeValue(data, 'expiry_date')),
            referenceType: Value(_stringValue(data, 'reference_type')),
            referenceId: Value(_stringValue(data, 'reference_id')),
            referenceNo: Value(_stringValue(data, 'reference_no')),
            userId: Value(_stringValue(data, 'user_id') ?? ''),
            remark: Value(_stringValue(data, 'remark')),
            createdAt: Value(_dateTimeValue(data, 'created_at') ?? DateTime.now()),
            updatedAt: Value(_dateTimeValue(data, 'updated_at') ?? DateTime.now()),
          ),
        );
  }

  Future<void> _applyPromotion(
    String operation,
    String recordId,
    Map<String, dynamic> data,
  ) async {
    if (operation == 'DELETE') {
      await (_db.delete(_db.promotions)
            ..where((t) => t.promotionId.equals(recordId)))
          .go();
      return;
    }

    await _db.into(_db.promotions).insertOnConflictUpdate(
          PromotionsCompanion(
            promotionId: Value(recordId),
            promotionCode: Value(_stringValue(data, 'promotion_code') ?? recordId),
            promotionName: Value(_stringValue(data, 'promotion_name') ?? '-'),
            promotionType: Value(_stringValue(data, 'promotion_type') ?? ''),
            discountType: Value(_stringValue(data, 'discount_type')),
            discountValue: Value(_doubleValue(data, 'discount_value')),
            maxDiscountAmount: Value(_doubleValueOrNull(data, 'max_discount_amount')),
            buyQty: Value(_intValueOrNull(data, 'buy_qty')),
            getQty: Value(_intValueOrNull(data, 'get_qty')),
            getProductId: Value(_stringValue(data, 'get_product_id')),
            minAmount: Value(_doubleValue(data, 'min_amount')),
            minQty: Value(_doubleValue(data, 'min_qty')),
            applyTo: Value(_stringValue(data, 'apply_to') ?? ''),
            applyToIds: Value(_stringListValue(data, 'apply_to_ids')),
            startDate: Value(_dateTimeValue(data, 'start_date') ?? DateTime.now()),
            endDate: Value(_dateTimeValue(data, 'end_date') ?? DateTime.now()),
            startTime: Value(_stringValue(data, 'start_time')),
            endTime: Value(_stringValue(data, 'end_time')),
            applyDays: Value(data['apply_days']),
            maxUses: Value(_intValueOrNull(data, 'max_uses')),
            maxUsesPerCustomer:
                Value(_intValueOrNull(data, 'max_uses_per_customer')),
            currentUses: Value(_intValue(data, 'current_uses')),
            isExclusive: Value(_boolValue(data, 'is_exclusive', fallback: false)),
            isActive: Value(_boolValue(data, 'is_active', fallback: true)),
            createdBy: Value(_stringValue(data, 'created_by')),
            createdAt: Value(_dateTimeValue(data, 'created_at') ?? DateTime.now()),
            updatedAt: Value(_dateTimeValue(data, 'updated_at') ?? DateTime.now()),
          ),
        );
  }

  Future<void> _applyPromotionUsage(
    String operation,
    String recordId,
    Map<String, dynamic> data,
  ) async {
    if (operation == 'DELETE') {
      await (_db.delete(_db.promotionUsages)
            ..where((t) => t.usageId.equals(recordId)))
          .go();
      return;
    }

    await _db.into(_db.promotionUsages).insertOnConflictUpdate(
          PromotionUsagesCompanion(
            usageId: Value(recordId),
            promotionId: Value(_stringValue(data, 'promotion_id') ?? ''),
            orderId: Value(_stringValue(data, 'order_id') ?? ''),
            customerId: Value(_stringValue(data, 'customer_id')),
            discountAmount: Value(_doubleValue(data, 'discount_amount')),
            usedAt: Value(_dateTimeValue(data, 'used_at') ?? DateTime.now()),
          ),
        );
  }

  Future<void> _applyCoupon(
    String operation,
    String recordId,
    Map<String, dynamic> data,
  ) async {
    if (operation == 'DELETE') {
      await (_db.delete(_db.coupons)..where((t) => t.couponId.equals(recordId)))
          .go();
      return;
    }

    await _db.into(_db.coupons).insertOnConflictUpdate(
          CouponsCompanion(
            couponId: Value(recordId),
            couponCode: Value(_stringValue(data, 'coupon_code') ?? recordId),
            promotionId: Value(_stringValue(data, 'promotion_id') ?? ''),
            isUsed: Value(_boolValue(data, 'is_used', fallback: false)),
            usedBy: Value(_stringValue(data, 'used_by')),
            usedAt: Value(_dateTimeValue(data, 'used_at')),
            expiresAt: Value(_dateTimeValue(data, 'expires_at')),
            createdAt: Value(_dateTimeValue(data, 'created_at') ?? DateTime.now()),
          ),
        );
  }

  Future<void> _applyArInvoice(
    String operation,
    String recordId,
    Map<String, dynamic> data,
  ) async {
    if (operation == 'DELETE') {
      await (_db.delete(_db.arInvoices)
            ..where((t) => t.invoiceId.equals(recordId)))
          .go();
      return;
    }

    await _db.into(_db.arInvoices).insertOnConflictUpdate(
          ArInvoicesCompanion(
            invoiceId: Value(recordId),
            invoiceNo: Value(_stringValue(data, 'invoice_no') ?? recordId),
            invoiceDate: Value(_dateTimeValue(data, 'invoice_date') ?? DateTime.now()),
            dueDate: Value(_dateTimeValue(data, 'due_date')),
            customerId: Value(_stringValue(data, 'customer_id') ?? ''),
            customerName: Value(_stringValue(data, 'customer_name') ?? '-'),
            totalAmount: Value(_doubleValue(data, 'total_amount')),
            paidAmount: Value(_doubleValue(data, 'paid_amount')),
            referenceType: Value(_stringValue(data, 'reference_type')),
            referenceId: Value(_stringValue(data, 'reference_id')),
            status: Value(_stringValue(data, 'status') ?? 'UNPAID'),
            remark: Value(_stringValue(data, 'remark')),
            createdAt: Value(_dateTimeValue(data, 'created_at') ?? DateTime.now()),
            updatedAt: Value(_dateTimeValue(data, 'updated_at') ?? DateTime.now()),
          ),
        );
  }

  Future<void> _applyArInvoiceItem(
    String operation,
    String recordId,
    Map<String, dynamic> data,
  ) async {
    if (operation == 'DELETE') {
      await (_db.delete(_db.arInvoiceItems)
            ..where((t) => t.itemId.equals(recordId)))
          .go();
      return;
    }

    await _db.into(_db.arInvoiceItems).insertOnConflictUpdate(
          ArInvoiceItemsCompanion(
            itemId: Value(recordId),
            invoiceId: Value(_stringValue(data, 'invoice_id') ?? ''),
            lineNo: Value(_intValue(data, 'line_no', fallback: 1)),
            productId: Value(_stringValue(data, 'product_id') ?? ''),
            productCode: Value(_stringValue(data, 'product_code') ?? ''),
            productName: Value(_stringValue(data, 'product_name') ?? '-'),
            unit: Value(_stringValue(data, 'unit') ?? ''),
            quantity: Value(_doubleValue(data, 'quantity')),
            unitPrice: Value(_doubleValue(data, 'unit_price')),
            discountAmount: Value(_doubleValue(data, 'discount_amount')),
            amount: Value(_doubleValue(data, 'amount')),
            remark: Value(_stringValue(data, 'remark')),
          ),
        );
  }

  Future<void> _applyArReceipt(
    String operation,
    String recordId,
    Map<String, dynamic> data,
  ) async {
    if (operation == 'DELETE') {
      await (_db.delete(_db.arReceipts)
            ..where((t) => t.receiptId.equals(recordId)))
          .go();
      return;
    }

    await _db.into(_db.arReceipts).insertOnConflictUpdate(
          ArReceiptsCompanion(
            receiptId: Value(recordId),
            receiptNo: Value(_stringValue(data, 'receipt_no') ?? recordId),
            receiptDate: Value(_dateTimeValue(data, 'receipt_date') ?? DateTime.now()),
            customerId: Value(_stringValue(data, 'customer_id') ?? ''),
            customerName: Value(_stringValue(data, 'customer_name') ?? '-'),
            totalAmount: Value(_doubleValue(data, 'total_amount')),
            paymentMethod: Value(_stringValue(data, 'payment_method') ?? 'CASH'),
            bankName: Value(_stringValue(data, 'bank_name')),
            chequeNo: Value(_stringValue(data, 'cheque_no')),
            chequeDate: Value(_dateTimeValue(data, 'cheque_date')),
            transferRef: Value(_stringValue(data, 'transfer_ref')),
            userId: Value(_stringValue(data, 'user_id') ?? ''),
            remark: Value(_stringValue(data, 'remark')),
            createdAt: Value(_dateTimeValue(data, 'created_at') ?? DateTime.now()),
          ),
        );
  }

  Future<void> _applyArReceiptAllocation(
    String operation,
    String recordId,
    Map<String, dynamic> data,
  ) async {
    if (operation == 'DELETE') {
      await (_db.delete(_db.arReceiptAllocations)
            ..where((t) => t.allocationId.equals(recordId)))
          .go();
      return;
    }

    await _db.into(_db.arReceiptAllocations).insertOnConflictUpdate(
          ArReceiptAllocationsCompanion(
            allocationId: Value(recordId),
            receiptId: Value(_stringValue(data, 'receipt_id') ?? ''),
            invoiceId: Value(_stringValue(data, 'invoice_id') ?? ''),
            allocatedAmount: Value(_doubleValue(data, 'allocated_amount')),
            createdAt: Value(_dateTimeValue(data, 'created_at') ?? DateTime.now()),
          ),
        );
  }

  Future<void> _applyApInvoice(
    String operation,
    String recordId,
    Map<String, dynamic> data,
  ) async {
    if (operation == 'DELETE') {
      await (_db.delete(_db.apInvoices)
            ..where((t) => t.invoiceId.equals(recordId)))
          .go();
      return;
    }

    await _db.into(_db.apInvoices).insertOnConflictUpdate(
          ApInvoicesCompanion(
            invoiceId: Value(recordId),
            invoiceNo: Value(_stringValue(data, 'invoice_no') ?? recordId),
            invoiceDate: Value(_dateTimeValue(data, 'invoice_date') ?? DateTime.now()),
            dueDate: Value(_dateTimeValue(data, 'due_date')),
            supplierId: Value(_stringValue(data, 'supplier_id') ?? ''),
            supplierName: Value(_stringValue(data, 'supplier_name') ?? '-'),
            totalAmount: Value(_doubleValue(data, 'total_amount')),
            paidAmount: Value(_doubleValue(data, 'paid_amount')),
            referenceType: Value(_stringValue(data, 'reference_type')),
            referenceId: Value(_stringValue(data, 'reference_id')),
            status: Value(_stringValue(data, 'status') ?? 'UNPAID'),
            remark: Value(_stringValue(data, 'remark')),
            createdAt: Value(_dateTimeValue(data, 'created_at') ?? DateTime.now()),
            updatedAt: Value(_dateTimeValue(data, 'updated_at') ?? DateTime.now()),
          ),
        );
  }

  Future<void> _applyApInvoiceItem(
    String operation,
    String recordId,
    Map<String, dynamic> data,
  ) async {
    if (operation == 'DELETE') {
      await (_db.delete(_db.apInvoiceItems)
            ..where((t) => t.itemId.equals(recordId)))
          .go();
      return;
    }

    await _db.into(_db.apInvoiceItems).insertOnConflictUpdate(
          ApInvoiceItemsCompanion(
            itemId: Value(recordId),
            invoiceId: Value(_stringValue(data, 'invoice_id') ?? ''),
            lineNo: Value(_intValue(data, 'line_no', fallback: 1)),
            productId: Value(_stringValue(data, 'product_id') ?? ''),
            productCode: Value(_stringValue(data, 'product_code') ?? ''),
            productName: Value(_stringValue(data, 'product_name') ?? '-'),
            unit: Value(_stringValue(data, 'unit') ?? ''),
            quantity: Value(_doubleValue(data, 'quantity')),
            unitPrice: Value(_doubleValue(data, 'unit_price')),
            amount: Value(_doubleValue(data, 'amount')),
            remark: Value(_stringValue(data, 'remark')),
          ),
        );
  }

  Future<void> _applyApPayment(
    String operation,
    String recordId,
    Map<String, dynamic> data,
  ) async {
    if (operation == 'DELETE') {
      await (_db.delete(_db.apPayments)
            ..where((t) => t.paymentId.equals(recordId)))
          .go();
      return;
    }

    await _db.into(_db.apPayments).insertOnConflictUpdate(
          ApPaymentsCompanion(
            paymentId: Value(recordId),
            paymentNo: Value(_stringValue(data, 'payment_no') ?? recordId),
            paymentDate: Value(_dateTimeValue(data, 'payment_date') ?? DateTime.now()),
            supplierId: Value(_stringValue(data, 'supplier_id') ?? ''),
            supplierName: Value(_stringValue(data, 'supplier_name') ?? '-'),
            totalAmount: Value(_doubleValue(data, 'total_amount')),
            paymentMethod: Value(_stringValue(data, 'payment_method') ?? 'CASH'),
            bankName: Value(_stringValue(data, 'bank_name')),
            chequeNo: Value(_stringValue(data, 'cheque_no')),
            chequeDate: Value(_dateTimeValue(data, 'cheque_date')),
            transferRef: Value(_stringValue(data, 'transfer_ref')),
            userId: Value(_stringValue(data, 'user_id') ?? ''),
            remark: Value(_stringValue(data, 'remark')),
            createdAt: Value(_dateTimeValue(data, 'created_at') ?? DateTime.now()),
          ),
        );
  }

  Future<void> _applyApPaymentAllocation(
    String operation,
    String recordId,
    Map<String, dynamic> data,
  ) async {
    if (operation == 'DELETE') {
      await (_db.delete(_db.apPaymentAllocations)
            ..where((t) => t.allocationId.equals(recordId)))
          .go();
      return;
    }

    await _db.into(_db.apPaymentAllocations).insertOnConflictUpdate(
          ApPaymentAllocationsCompanion(
            allocationId: Value(recordId),
            paymentId: Value(_stringValue(data, 'payment_id') ?? ''),
            invoiceId: Value(_stringValue(data, 'invoice_id') ?? ''),
            allocatedAmount: Value(_doubleValue(data, 'allocated_amount')),
            createdAt: Value(_dateTimeValue(data, 'created_at') ?? DateTime.now()),
          ),
        );
  }

  Future<void> _applyDevice(
    String operation,
    String recordId,
    Map<String, dynamic> data,
  ) async {
    if (operation == 'DELETE') {
      await (_db.delete(_db.devices)
            ..where((t) => t.deviceId.equals(recordId)))
          .go();
      return;
    }

    await _db.into(_db.devices).insertOnConflictUpdate(
          DevicesCompanion(
            deviceId: Value(recordId),
            deviceName: Value(_stringValue(data, 'device_name') ?? '-'),
            deviceType: Value(_stringValue(data, 'device_type') ?? ''),
            ipAddress: Value(_stringValue(data, 'ip_address')),
            macAddress: Value(_stringValue(data, 'mac_address')),
            isOnline: Value(_boolValue(data, 'is_online', fallback: true)),
            lastSeen: Value(_dateTimeValue(data, 'last_seen')),
            createdAt: Value(_dateTimeValue(data, 'created_at') ?? DateTime.now()),
          ),
        );
  }

  Future<void> _applyActiveSession(
    String operation,
    String recordId,
    Map<String, dynamic> data,
  ) async {
    if (operation == 'DELETE') {
      await (_db.delete(_db.activeSessions)
            ..where((t) => t.sessionId.equals(recordId)))
          .go();
      return;
    }

    await _db.into(_db.activeSessions).insertOnConflictUpdate(
          ActiveSessionsCompanion(
            sessionId: Value(recordId),
            deviceId: Value(_stringValue(data, 'device_id')),
            userId: Value(_stringValue(data, 'user_id')),
            token: Value(_stringValue(data, 'token') ?? ''),
            ipAddress: Value(_stringValue(data, 'ip_address')),
            startedAt: Value(_dateTimeValue(data, 'started_at') ?? DateTime.now()),
            lastActivity:
                Value(_dateTimeValue(data, 'last_activity') ?? DateTime.now()),
          ),
        );
  }

  String? _stringValue(Map<String, dynamic> data, String key) {
    final value = data[key];
    return value?.toString();
  }

  bool _boolValue(
    Map<String, dynamic> data,
    String key, {
    required bool fallback,
  }) {
    final value = data[key];
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.toLowerCase();
      if (normalized == 'true' || normalized == '1') return true;
      if (normalized == 'false' || normalized == '0') return false;
    }
    return fallback;
  }

  double _doubleValue(
    Map<String, dynamic> data,
    String key, {
    double fallback = 0,
  }) {
    final value = data[key];
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  double? _doubleValueOrNull(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  int _intValue(
    Map<String, dynamic> data,
    String key, {
    int fallback = 0,
  }) {
    final value = data[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  int? _intValueOrNull(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  List<String>? _stringListValue(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value == null) return null;
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return null;
  }

  (String?, String?) _compositeKeyParts(
    String recordId, {
    List<String?> fallback = const [],
  }) {
    final normalized = recordId.trim();
    if (normalized.isNotEmpty) {
      for (final separator in const ['|', ':', ',', ';']) {
        if (normalized.contains(separator)) {
          final parts = normalized.split(separator).map((e) => e.trim()).toList();
          if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
            return (parts[0], parts[1]);
          }
        }
      }
    }

    if (fallback.length >= 2 &&
        (fallback[0]?.isNotEmpty ?? false) &&
        (fallback[1]?.isNotEmpty ?? false)) {
      return (fallback[0], fallback[1]);
    }

    return (null, null);
  }

  DateTime? _dateTimeValue(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
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

class ApplyBatchResult {
  final List<String> acknowledgedQueueIds;
  final SyncBatchMetrics metrics;

  const ApplyBatchResult({
    required this.acknowledgedQueueIds,
    required this.metrics,
  });
}

class SyncBatchMetrics {
  final int totalItems;
  final int appliedItems;
  final int replayedItems;
  final int passesUsed;
  final int pendingItems;

  const SyncBatchMetrics({
    required this.totalItems,
    required this.appliedItems,
    required this.replayedItems,
    required this.passesUsed,
    required this.pendingItems,
  });
}

// ── Sync Service Provider ──────────────────────────────────────────────────────
final offlineSyncServiceProvider = Provider<OfflineSyncService>((ref) {
  final db = ref.read(appDatabaseProvider);
  final svc = OfflineSyncService(ref, database: db);
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
