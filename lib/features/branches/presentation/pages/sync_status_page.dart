// ignore_for_file: avoid_print
// sync_status_page.dart — Week 7: Sync Status & Manual Sync

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/branch_provider.dart';
import '../../data/models/branch_model.dart';
import '../../../../core/services/offline_sync_service.dart';

class SyncStatusPage extends ConsumerWidget {
  const SyncStatusPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncAsync = ref.watch(syncStatusProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('สถานะการ Sync'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(syncStatusProvider),
          ),
        ],
      ),
      body: syncAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('เกิดข้อผิดพลาด: $e')),
        data: (sync) => _buildContent(context, ref, sync),
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, WidgetRef ref, SyncStatusModel sync) {
    final fmt = DateFormat('dd/MM/yyyy HH:mm:ss');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Status Card ────────────────────────────────────────────────
          _buildStatusCard(sync, fmt),
          const SizedBox(height: 16),

          // ── Mode Card ──────────────────────────────────────────────────
          _buildModeCard(context),
          const SizedBox(height: 16),

          // ── Action Buttons ─────────────────────────────────────────────
          _buildActionButtons(context, ref, sync),
          const SizedBox(height: 16),

          // ── Pending Items (detail) ─────────────────────────────────────
          if (sync.hasPending) ...[
            const Text('รายการรอ Sync',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            _buildSyncQueueDetails(context, ref),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusCard(SyncStatusModel sync, DateFormat fmt) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: sync.isOnline
                        ? Colors.green.withValues(alpha:0.1)
                        : Colors.red.withValues(alpha:0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    sync.isOnline ? Icons.wifi : Icons.wifi_off,
                    color: sync.isOnline ? Colors.green : Colors.red,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sync.isOnline ? 'เชื่อมต่ออยู่' : 'ออฟไลน์',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: sync.isOnline
                              ? Colors.green
                              : Colors.red,
                        ),
                      ),
                      if (sync.lastSyncAt != null)
                        Text(
                          'Sync ล่าสุด: ${fmt.format(sync.lastSyncAt!)}',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[600]),
                        )
                      else
                        Text('ยังไม่เคย Sync',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[500])),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                    child: _statBox(
                  '${sync.pendingCount}',
                  'รอ Sync',
                  sync.pendingCount > 0 ? Colors.orange : Colors.green,
                  Icons.schedule,
                )),
                const SizedBox(width: 12),
                Expanded(
                    child: _statBox(
                  '${sync.failedCount}',
                  'ผิดพลาด',
                  sync.failedCount > 0 ? Colors.red : Colors.green,
                  Icons.error_outline,
                )),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statBox(
      String value, String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: color)),
              Text(label,
                  style:
                      TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeCard(BuildContext context) {
    return Consumer(builder: (_, ref, _) {
      final selectedBranch = ref.watch(selectedBranchProvider);
      final selectedWarehouse = ref.watch(selectedWarehouseProvider);

      return Card(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.settings, size: 18, color: Colors.indigo),
                  SizedBox(width: 8),
                  Text('การตั้งค่าสาขา',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                ],
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading:
                    const Icon(Icons.store, color: Colors.indigo),
                title: Text(selectedBranch?.branchName ??
                    'ยังไม่ได้เลือกสาขา'),
                subtitle: const Text('สาขาที่ใช้งาน'),
                trailing: TextButton(
                  onPressed: () =>
                      _showBranchPicker(context, ref),
                  child: const Text('เปลี่ยน'),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading:
                    const Icon(Icons.warehouse, color: Colors.indigo),
                title: Text(selectedWarehouse?.warehouseName ??
                    'ยังไม่ได้เลือกคลัง'),
                subtitle: const Text('คลังสินค้าที่ใช้งาน'),
                trailing: TextButton(
                  onPressed: () =>
                      _showWarehousePicker(context, ref),
                  child: const Text('เปลี่ยน'),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildActionButtons(
      BuildContext context, WidgetRef ref, SyncStatusModel sync) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.sync_alt, size: 18, color: Colors.indigo),
                SizedBox(width: 8),
                Text('จัดการ Sync',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: sync.isOnline
                        ? () => _triggerSync(context, ref)
                        : null,
                    icon: const Icon(Icons.cloud_upload),
                    label: const Text('Sync ตอนนี้'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: sync.failedCount > 0
                        ? () => _retryFailed(context, ref)
                        : null,
                    icon: const Icon(Icons.replay),
                    label: const Text('ลองใหม่'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            if (!sync.isOnline) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha:0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 16, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'อยู่ในโหมดออฟไลน์ ข้อมูลจะถูก Sync เมื่อเชื่อมต่อใหม่',
                        style: TextStyle(
                            fontSize: 12, color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSyncQueueDetails(BuildContext context, WidgetRef ref) {
    final syncAsync = ref.watch(syncStatusProvider);
    return syncAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (sync) {
        // pendingItems injected from API (see SyncStatusModel / branch_routes)
        // If not available, show a simple count card
        return Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                _syncQueueRow(Icons.schedule, Colors.orange,
                    'รอดำเนินการ', '${sync.pendingCount} รายการ'),
                if (sync.hasFailed)
                  _syncQueueRow(Icons.error_outline, Colors.red,
                      'ผิดพลาด', '${sync.failedCount} รายการ'),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'ข้อมูลจะถูก Sync อัตโนมัติทุก 30 วินาทีเมื่อออนไลน์',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey[500]),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _syncQueueRow(
      IconData icon, Color color, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(fontSize: 13)),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  void _showBranchPicker(BuildContext context, WidgetRef ref) {
    final branchesAsync = ref.read(branchListProvider);
    branchesAsync.whenData((branches) {
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(16))),
        builder: (_) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('เลือกสาขา',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            ...branches.map((b) => ListTile(
                  leading: const Icon(Icons.store),
                  title: Text(b.branchName),
                  subtitle: Text(b.branchCode),
                  onTap: () {
                    ref.read(selectedBranchProvider.notifier).state = b;
                    Navigator.pop(context);
                  },
                )),
            const SizedBox(height: 8),
          ],
        ),
      );
    });
  }

  void _showWarehousePicker(BuildContext context, WidgetRef ref) {
    final selectedBranch = ref.read(selectedBranchProvider);
    if (selectedBranch == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('กรุณาเลือกสาขาก่อน')));
      return;
    }

    final warehousesAsync = ref.read(warehouseListProvider);
    warehousesAsync.whenData((warehouses) {
      final myWh = warehouses
          .where((w) => w.branchId == selectedBranch.branchId)
          .toList();

      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(16))),
        builder: (_) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('เลือกคลังสินค้า',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            ...myWh.map((w) => ListTile(
                  leading: const Icon(Icons.warehouse),
                  title: Text(w.warehouseName),
                  subtitle: Text(w.warehouseCode),
                  onTap: () {
                    ref
                        .read(selectedWarehouseProvider.notifier)
                        .state = w;
                    Navigator.pop(context);
                  },
                )),
            const SizedBox(height: 8),
          ],
        ),
      );
    });
  }

  Future<void> _triggerSync(BuildContext context, WidgetRef ref) async {
    final svc = ref.read(offlineSyncServiceProvider);

    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กำลัง Sync...')));
    final result = await svc.syncNow();
    if (context.mounted) {
      ref.invalidate(syncStatusProvider);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result ? 'Sync สำเร็จ ✅' : 'Sync ไม่สำเร็จ ❌'),
        backgroundColor: result ? null : Colors.red,
      ));
    }
  }

  Future<void> _retryFailed(BuildContext context, WidgetRef ref) async {
    final svc = ref.read(offlineSyncServiceProvider);

    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กำลังลองใหม่...')));
    await svc.retryFailed();
    if (context.mounted) {
      ref.invalidate(syncStatusProvider);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('ลองใหม่แล้ว')));
    }
  }
}