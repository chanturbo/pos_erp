// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/offline_sync_service.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/utils/responsive_utils.dart';
import '../../data/models/branch_model.dart';
import '../providers/branch_provider.dart';

class SyncStatusPage extends ConsumerWidget {
  const SyncStatusPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncAsync = ref.watch(syncStatusProvider);

    return Scaffold(
      backgroundColor: AppTheme.surfaceColorOf(context),
      appBar: AppBar(
        automaticallyImplyLeading: Navigator.of(context).canPop(),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('สถานะการ Sync'),
            Text(
              'ติดตามคิวการซิงก์ สาขาที่ใช้งาน และสั่ง Sync ด้วยตนเอง',
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.65),
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'รีเฟรชข้อมูล',
            onPressed: () => ref.invalidate(syncStatusProvider),
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: context.contentMaxWidth),
          child: syncAsync.when(
            loading: () => _loadingWidget(context),
            error: (e, _) => _errorWidget(context, '$e'),
            data: (sync) => _buildContent(context, ref, sync),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    SyncStatusModel sync,
  ) {
    final fmt = DateFormat('dd/MM/yyyy HH:mm:ss');

    return SingleChildScrollView(
      padding: context.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _summaryCard(
                context,
                title: 'สถานะ',
                value: sync.isOnline ? 'Online' : 'Offline',
                icon: sync.isOnline
                    ? Icons.cloud_done_outlined
                    : Icons.cloud_off_outlined,
                color: sync.isOnline
                    ? AppTheme.successColor
                    : AppTheme.errorColor,
              ),
              _summaryCard(
                context,
                title: 'รอ Sync',
                value: '${sync.pendingCount}',
                icon: Icons.schedule_outlined,
                color: sync.pendingCount > 0
                    ? Colors.orange
                    : AppTheme.successColor,
              ),
              _summaryCard(
                context,
                title: 'ผิดพลาด',
                value: '${sync.failedCount}',
                icon: Icons.error_outline_rounded,
                color: sync.failedCount > 0
                    ? AppTheme.errorColor
                    : AppTheme.successColor,
              ),
              _summaryCard(
                context,
                title: 'โหมด',
                value: sync.appMode,
                icon: Icons.settings_suggest_outlined,
                color: AppTheme.infoColor,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _sectionTitle(
            context,
            'สถานะปัจจุบัน',
            sync.isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
            sync.isOnline ? AppTheme.successColor : AppTheme.errorColor,
          ),
          const SizedBox(height: 8),
          _panelCard(
            context,
            child: Padding(
              padding: context.cardPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: context.isMobile ? 48 : 56,
                        height: context.isMobile ? 48 : 56,
                        decoration: BoxDecoration(
                          color:
                              (sync.isOnline
                                      ? AppTheme.successColor
                                      : AppTheme.errorColor)
                                  .withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          sync.isOnline ? Icons.wifi : Icons.wifi_off,
                          size: context.isMobile ? 24 : 28,
                          color: sync.isOnline
                              ? AppTheme.successColor
                              : AppTheme.errorColor,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sync.isOnline ? 'เชื่อมต่ออยู่' : 'ออฟไลน์',
                              style: _cardTitleStyle(
                                context,
                                fontSize: context.isMobile ? 14 : 16,
                                color: sync.isOnline
                                    ? AppTheme.successColor
                                    : AppTheme.errorColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              sync.lastSyncAt != null
                                  ? 'Sync ล่าสุด: ${fmt.format(sync.lastSyncAt!)}'
                                  : 'ยังไม่เคย Sync',
                              style: _cardSubtitleStyle(context),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (!sync.isOnline) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            size: 18,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'อยู่ในโหมดออฟไลน์ ข้อมูลจะถูก Sync อัตโนมัติเมื่อกลับมาออนไลน์',
                              style: TextStyle(
                                fontSize: context.isMobile ? 11 : 12,
                                color: Colors.orange.shade900,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _sectionTitle(
            context,
            'การตั้งค่าสาขา',
            Icons.account_tree_outlined,
            AppTheme.primary,
          ),
          const SizedBox(height: 8),
          _buildBranchConfigPanel(context, ref),
          const SizedBox(height: 16),
          _sectionTitle(
            context,
            'จัดการ Sync',
            Icons.sync_alt_rounded,
            AppTheme.infoColor,
          ),
          const SizedBox(height: 8),
          _buildActionPanel(context, ref, sync),
          if (sync.hasPending || sync.hasFailed) ...[
            const SizedBox(height: 16),
            _sectionTitle(
              context,
              'คิวการซิงก์',
              Icons.inventory_2_outlined,
              Colors.orange,
            ),
            const SizedBox(height: 8),
            _buildQueuePanel(context, sync),
          ],
          SizedBox(height: context.isMobile ? 24 : 32),
        ],
      ),
    );
  }

  Widget _buildBranchConfigPanel(BuildContext context, WidgetRef ref) {
    final selectedBranch = ref.watch(selectedBranchProvider);
    final selectedWarehouse = ref.watch(selectedWarehouseProvider);

    return _panelCard(
      context,
      child: Padding(
        padding: context.cardPadding,
        child: Column(
          children: [
            _configRow(
              context,
              icon: Icons.storefront_outlined,
              title: selectedBranch?.branchName ?? 'ยังไม่ได้เลือกสาขา',
              subtitle: selectedBranch?.branchCode ?? 'สาขาที่ใช้งาน',
              color: AppTheme.primary,
              buttonLabel: 'เปลี่ยนสาขา',
              onTap: () => _showBranchPicker(context, ref),
            ),
            Divider(color: AppTheme.borderColorOf(context), height: 20),
            _configRow(
              context,
              icon: Icons.warehouse_outlined,
              title: selectedWarehouse?.warehouseName ?? 'ยังไม่ได้เลือกคลัง',
              subtitle: selectedWarehouse?.warehouseCode ?? 'คลังที่ใช้งาน',
              color: AppTheme.infoColor,
              buttonLabel: 'เปลี่ยนคลัง',
              onTap: () => _showWarehousePicker(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionPanel(
    BuildContext context,
    WidgetRef ref,
    SyncStatusModel sync,
  ) {
    return _panelCard(
      context,
      child: Padding(
        padding: context.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'สั่งงานการซิงก์ด้วยตนเอง',
              style: _cardTitleStyle(context, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              'เหมาะสำหรับกรณีต้องการอัปเดตข้อมูลทันทีหรือทดสอบการเชื่อมต่อ',
              style: _cardSubtitleStyle(context),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ElevatedButton.icon(
                  onPressed: sync.isOnline
                      ? () => _triggerSync(context, ref)
                      : null,
                  icon: const Icon(Icons.cloud_upload_outlined),
                  label: const Text('Sync ตอนนี้'),
                ),
                OutlinedButton.icon(
                  onPressed: sync.failedCount > 0
                      ? () => _retryFailed(context, ref)
                      : null,
                  icon: const Icon(Icons.replay_rounded),
                  label: const Text('ลองใหม่'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQueuePanel(BuildContext context, SyncStatusModel sync) {
    final rows = <Widget>[
      _queueRow(
        context,
        icon: Icons.schedule_rounded,
        color: Colors.orange,
        label: 'รอดำเนินการ',
        value: '${sync.pendingCount} รายการ',
      ),
      if (sync.hasFailed)
        _queueRow(
          context,
          icon: Icons.error_outline_rounded,
          color: AppTheme.errorColor,
          label: 'ผิดพลาด',
          value: '${sync.failedCount} รายการ',
        ),
    ];

    return _panelCard(
      context,
      child: Padding(
        padding: context.cardPadding,
        child: Column(
          children: [
            ...rows,
            Divider(color: AppTheme.borderColorOf(context), height: 20),
            Text(
              'ข้อมูลจะถูก Sync อัตโนมัติทุก 30 วินาทีเมื่อออนไลน์',
              textAlign: TextAlign.center,
              style: _cardSubtitleStyle(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _configRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required String buttonLabel,
    required VoidCallback onTap,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 19),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: _cardTitleStyle(context)),
              const SizedBox(height: 2),
              Text(subtitle, style: _cardSubtitleStyle(context)),
            ],
          ),
        ),
        TextButton(onPressed: onTap, child: Text(buttonLabel)),
      ],
    );
  }

  Widget _queueRow(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(label, style: _cardTitleStyle(context, fontSize: 12)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: context.isMobile ? 12 : 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  Widget _summaryCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final width = context.isMobile ? (context.screenWidth - 36) / 2 : 220.0;
    return SizedBox(
      width: width,
      child: _panelCard(
        context,
        child: Padding(
          padding: context.cardPadding,
          child: Row(
            children: [
              Container(
                width: context.isMobile ? 38 : 42,
                height: context.isMobile ? 38 : 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              SizedBox(width: context.isMobile ? 10 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: context.isMobile ? 14 : 18,
                        fontWeight: FontWeight.w700,
                        color: color,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(title, style: _cardSubtitleStyle(context)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _panelCard(BuildContext context, {required Widget child}) {
    return Card(
      elevation: 0,
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.borderColorOf(context)),
      ),
      child: child,
    );
  }

  Widget _loadingWidget(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: SizedBox(
        width: context.isMobile ? 24 : 28,
        height: context.isMobile ? 24 : 28,
        child: const CircularProgressIndicator(strokeWidth: 2.5),
      ),
    ),
  );

  Widget _errorWidget(BuildContext context, String msg) => Center(
    child: Padding(
      padding: context.pagePadding,
      child: _panelCard(
        context,
        child: Padding(
          padding: context.cardPadding,
          child: Row(
            children: [
              const Icon(Icons.error_outline, color: AppTheme.errorColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'เกิดข้อผิดพลาด: $msg',
                  style: const TextStyle(color: AppTheme.errorColor),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  TextStyle _cardTitleStyle(
    BuildContext context, {
    double? fontSize,
    Color? color,
  }) {
    return TextStyle(
      fontSize: fontSize ?? (context.isMobile ? 13 : 14),
      fontWeight: FontWeight.w700,
      color: color ?? Theme.of(context).colorScheme.onSurface,
    );
  }

  TextStyle _cardSubtitleStyle(BuildContext context) {
    return TextStyle(
      fontSize: context.isMobile ? 11 : 12,
      color: AppTheme.subtextColorOf(context),
      fontWeight: FontWeight.w500,
    );
  }

  void _showBranchPicker(BuildContext context, WidgetRef ref) {
    final branchesAsync = ref.read(branchListProvider);
    branchesAsync.whenData((branches) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Theme.of(context).cardColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (_) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'เลือกสาขา',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              ...branches.map(
                (b) => ListTile(
                  leading: const Icon(Icons.storefront_outlined),
                  title: Text(b.branchName),
                  subtitle: Text(b.branchCode),
                  onTap: () {
                    ref.read(selectedBranchProvider.notifier).state = b;
                    Navigator.pop(context);
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    });
  }

  void _showWarehousePicker(BuildContext context, WidgetRef ref) {
    final selectedBranch = ref.read(selectedBranchProvider);
    if (selectedBranch == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กรุณาเลือกสาขาก่อน')));
      return;
    }

    final warehousesAsync = ref.read(warehouseListProvider);
    warehousesAsync.whenData((warehouses) {
      final myWh = warehouses
          .where((w) => w.branchId == selectedBranch.branchId)
          .toList();

      showModalBottomSheet(
        context: context,
        backgroundColor: Theme.of(context).cardColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (_) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'เลือกคลังสินค้า',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              ...myWh.map(
                (w) => ListTile(
                  leading: const Icon(Icons.warehouse_outlined),
                  title: Text(w.warehouseName),
                  subtitle: Text(w.warehouseCode),
                  onTap: () {
                    ref.read(selectedWarehouseProvider.notifier).state = w;
                    Navigator.pop(context);
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    });
  }

  Future<void> _triggerSync(BuildContext context, WidgetRef ref) async {
    final svc = ref.read(offlineSyncServiceProvider);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('กำลัง Sync...')));
    final result = await svc.syncNow();
    if (context.mounted) {
      ref.invalidate(syncStatusProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result ? 'Sync สำเร็จ ✅' : 'Sync ไม่สำเร็จ ❌'),
          backgroundColor: result ? null : Colors.red,
        ),
      );
    }
  }

  Future<void> _retryFailed(BuildContext context, WidgetRef ref) async {
    final svc = ref.read(offlineSyncServiceProvider);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('กำลังลองใหม่...')));
    await svc.retryFailed();
    if (context.mounted) {
      ref.invalidate(syncStatusProvider);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ลองใหม่แล้ว')));
    }
  }
}
