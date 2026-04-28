import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:pos_erp/main.dart'
    show getMasterBackgroundHostRunning, refreshRuntimeForAppModeChange;
import '../../../../core/client/api_client.dart';
import '../../../../core/config/app_mode.dart';
import '../../../../core/services/master_discovery_service.dart';
import '../../../../core/services/offline_sync_service.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/utils/responsive_utils.dart';
import '../../../../shared/widgets/app_dialogs.dart';
import '../../../../shared/widgets/mobile_home_button.dart';
import '../../data/models/branch_model.dart';
import '../providers/branch_provider.dart';

final masterBackgroundHostStatusProvider = FutureProvider<bool?>((ref) async {
  return getMasterBackgroundHostRunning();
});

class SyncStatusPage extends ConsumerWidget {
  final bool preferBackButton;

  const SyncStatusPage({super.key, this.preferBackButton = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(posContextBootstrapProvider);
    final syncAsync = ref.watch(syncStatusProvider);
    final historyAsync = ref.watch(syncBatchHistoryProvider);

    return Scaffold(
      backgroundColor: AppTheme.surfaceColorOf(context),
      appBar: AppBar(
        leading: preferBackButton && Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: 'ย้อนกลับ',
                onPressed: () => Navigator.of(context).maybePop(),
              )
            : buildMobileHomeLeading(context),
        automaticallyImplyLeading: Navigator.of(context).canPop(),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('การเชื่อมต่อ/ซิงก์'),
            Text(
              'ตั้งค่าโหมดเครื่อง ตรวจสอบการเชื่อมต่อ และติดตามคิวการส่งข้อมูล',
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
            data: (sync) => _buildContent(context, ref, sync, historyAsync),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    SyncStatusModel sync,
    AsyncValue<List<SyncBatchHistoryModel>> historyAsync,
  ) {
    final fmt = DateFormat('dd/MM/yyyy HH:mm:ss');
    final timeRange = ref.watch(syncBatchTimeRangeProvider);
    final searchQuery = ref.watch(syncBatchSearchProvider);
    final issuesOnly = ref.watch(syncBatchIssuesOnlyProvider);
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
            AppModeConfig.isStandalone ? 'โหมดการใช้งาน' : 'โหมดการเชื่อมต่อ',
            AppModeConfig.isStandalone
                ? Icons.computer_rounded
                : Icons.router_outlined,
            AppTheme.primary,
          ),
          const SizedBox(height: 8),
          _buildConnectionPanel(context, ref, sync),
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
          if (sync.hasBatchMetrics) ...[
            const SizedBox(height: 16),
            _sectionTitle(
              context,
              'ผล Sync ล่าสุด',
              Icons.analytics_outlined,
              AppTheme.infoColor,
            ),
            const SizedBox(height: 8),
            _buildBatchMetricsPanel(context, sync),
          ],
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
          const SizedBox(height: 16),
          _sectionTitle(
            context,
            'แนวโน้มย้อนหลัง',
            Icons.timeline_rounded,
            AppTheme.primary,
          ),
          const SizedBox(height: 8),
          _buildHistoryPanel(
            context,
            ref,
            historyAsync,
            timeRange,
            searchQuery,
            issuesOnly,
          ),
          const SizedBox(height: 16),
          _sectionTitle(
            context,
            'Debug / Export',
            Icons.bug_report_outlined,
            Colors.deepOrange,
          ),
          const SizedBox(height: 8),
          _buildDebugPanel(
            context,
            ref,
            historyAsync,
            timeRange,
            searchQuery,
            issuesOnly,
          ),
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

  Widget _buildConnectionPanel(
    BuildContext context,
    WidgetRef ref,
    SyncStatusModel sync,
  ) {
    final discovery = MasterDiscoveryService.instance;
    final hostStatusAsync = ref.watch(masterBackgroundHostStatusProvider);

    return _panelCard(
      context,
      child: Padding(
        padding: context.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppModeConfig.isStandalone
                  ? 'เครื่องนี้กำลังทำงานแบบเครื่องเดียว ไม่ใช้การเชื่อมต่อระหว่างเครื่อง'
                  : 'ให้เครื่องหลักเป็น Master และเครื่องขายอื่นเชื่อมเข้ามาเป็น Slave',
              style: _cardTitleStyle(context, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              AppModeConfig.isStandalone
                  ? 'เหมาะสำหรับร้านที่มีเครื่องเดียว ทุกข้อมูลจะบันทึกในฐานข้อมูลของเครื่องนี้โดยตรง'
                  : 'เมื่อ Slave เชื่อมต่อแล้ว การขายและการบันทึกข้อมูลจะยิง API ไปที่ Master เพื่อเก็บลงฐานข้อมูลเครื่องหลักโดยตรง',
              style: _cardSubtitleStyle(context),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ChoiceChip(
                  label: const Text('Standalone'),
                  selected: AppModeConfig.mode == AppMode.standalone,
                  onSelected: (_) =>
                      _switchMode(context, ref, AppMode.standalone),
                ),
                ChoiceChip(
                  label: const Text('Master'),
                  selected: AppModeConfig.mode == AppMode.master,
                  onSelected: (_) => _switchMode(context, ref, AppMode.master),
                ),
                ChoiceChip(
                  label: const Text('Slave POS'),
                  selected: AppModeConfig.mode == AppMode.clientPOS,
                  onSelected: (_) =>
                      _switchMode(context, ref, AppMode.clientPOS),
                ),
                ChoiceChip(
                  label: const Text('Slave Mobile'),
                  selected: AppModeConfig.mode == AppMode.clientMobile,
                  onSelected: (_) =>
                      _switchMode(context, ref, AppMode.clientMobile),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _configRow(
              context,
              icon: Icons.badge_outlined,
              title: sync.deviceName ?? AppModeConfig.deviceName,
              subtitle: AppModeConfig.isStandalone
                  ? 'ชื่ออุปกรณ์สำหรับใช้งานเครื่องเดียว'
                  : AppModeConfig.isMaster
                  ? 'ชื่อ Master ที่เครื่องอื่นจะมองเห็น'
                  : 'ชื่ออุปกรณ์เครื่องนี้',
              color: AppTheme.primary,
              buttonLabel: 'แก้ชื่อ',
              onTap: () => _editDeviceName(context, ref),
            ),
            const SizedBox(height: 10),
            _configRow(
              context,
              icon: AppModeConfig.isStandalone
                  ? Icons.computer_rounded
                  : AppModeConfig.isMaster
                  ? Icons.wifi_tethering_rounded
                  : Icons.link_rounded,
              title: AppModeConfig.isStandalone
                  ? 'โหมดเครื่องเดียว'
                  : AppModeConfig.isMaster
                  ? 'Master พร้อมให้เชื่อมต่อ'
                  : (sync.masterName ?? 'ยังไม่ได้เชื่อมต่อ Master'),
              subtitle: AppModeConfig.isStandalone
                  ? 'ปิดระบบ sync และใช้งานฐานข้อมูลในเครื่องนี้เท่านั้น'
                  : AppModeConfig.isMaster
                  ? (sync.serverBaseUrl ?? 'กำลังระบุ IP')
                  : (AppModeConfig.masterIp != null
                        ? '${AppModeConfig.masterIp}:${AppModeConfig.masterPort}'
                        : 'เลือก Master ในรายการด้านล่าง'),
              color: AppModeConfig.isStandalone
                  ? AppTheme.infoColor
                  : AppModeConfig.isMaster
                  ? AppTheme.successColor
                  : AppTheme.infoColor,
              buttonLabel: AppModeConfig.isStandalone
                  ? 'ใช้งานอยู่'
                  : AppModeConfig.isMaster
                  ? 'ประกาศอยู่'
                  : (AppModeConfig.masterIp != null ? 'ยกเลิก' : 'รอเชื่อมต่อ'),
              onTap: AppModeConfig.isStandalone || AppModeConfig.isMaster
                  ? () {}
                  : () => _disconnectMaster(context, ref),
            ),
            const SizedBox(height: 10),
            _buildMasterHostIndicator(context, hostStatusAsync),
            if (AppModeConfig.isStandalone) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.infoColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'ไม่ต้องตั้งค่า Master, Slave หรือเชื่อมต่อ Wi‑Fi เพิ่ม สามารถขายและบันทึกข้อมูลในเครื่องนี้ได้ทันที',
                  style: _cardSubtitleStyle(context),
                ),
              ),
            ],
            if (!AppModeConfig.isStandalone && !AppModeConfig.isMaster) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Text(
                    'Master ที่พบใน Wi-Fi',
                    style: _cardTitleStyle(context, fontSize: 13),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _refreshDiscovery(context, ref),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('ค้นหาใหม่'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              StreamBuilder<List<DiscoveredMaster>>(
                stream: discovery.stream,
                initialData: discovery.masters,
                builder: (context, snapshot) {
                  final masters = snapshot.data ?? const <DiscoveredMaster>[];
                  if (masters.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.infoColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'ยังไม่พบ Master ในเครือข่ายเดียวกัน ลองให้เครื่องหลักเปิดโหมด Master และอยู่ใน Wi-Fi เดียวกัน',
                        style: _cardSubtitleStyle(context),
                      ),
                    );
                  }

                  return Column(
                    children: masters
                        .map(
                          (master) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppTheme.borderColorOf(context),
                                ),
                              ),
                              child: ListTile(
                                leading: const Icon(Icons.dns_outlined),
                                title: Text(master.name),
                                subtitle: Text('${master.host}:${master.port}'),
                                trailing: FilledButton(
                                  onPressed: () =>
                                      _connectToMaster(context, ref, master),
                                  child: const Text('เชื่อมต่อ'),
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMasterHostIndicator(
    BuildContext context,
    AsyncValue<bool?> hostStatusAsync,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = AppTheme.borderColorOf(context);
    final bgColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF8FAFC);

    final (icon, color, title, subtitle) = hostStatusAsync.when(
      loading: () => (
        Icons.hourglass_top_rounded,
        AppTheme.infoColor,
        'กำลังตรวจสอบ Master background host',
        'รอสถานะจากระบบปฏิบัติการ',
      ),
      error: (_, _) => (
        Icons.error_outline_rounded,
        AppTheme.errorColor,
        'ตรวจสอบสถานะ background host ไม่สำเร็จ',
        'ระบบยังทำงานต่อได้ แต่ไม่สามารถอ่านสถานะจาก native ได้ตอนนี้',
      ),
      data: (running) {
        if (running == null) {
          return (
            Icons.info_outline_rounded,
            AppTheme.infoColor,
            'Background host ไม่รองรับบนแพลตฟอร์มนี้',
            'บน iOS ระบบอาจพักแอปเมื่อออกจาก foreground แม้อยู่ในโหมด Master',
          );
        }
        if (running) {
          return (
            Icons.verified_rounded,
            AppTheme.successColor,
            'Master background host กำลังทำงาน',
            'Android foreground service ถูกเปิดไว้เพื่อช่วยคงการทำงานของโหมด Master',
          );
        }
        return (
          AppModeConfig.isMaster
              ? Icons.warning_amber_rounded
              : Icons.pause_circle_outline_rounded,
          AppModeConfig.isMaster ? Colors.orange : AppTheme.infoColor,
          AppModeConfig.isMaster
              ? 'Master background host ยังไม่ทำงาน'
              : 'Master background host ปิดอยู่',
          AppModeConfig.isMaster
              ? 'หากเพิ่งสลับโหมด ลองรอสักครู่หรือเปิดหน้านี้ใหม่'
              : 'สถานะนี้เป็นปกติเมื่อไม่ได้ใช้โหมด Master',
        );
      },
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _cardTitleStyle(context, fontSize: 13)),
                const SizedBox(height: 2),
                Text(subtitle, style: _cardSubtitleStyle(context)),
              ],
            ),
          ),
        ],
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
              AppModeConfig.isStandalone
                  ? 'การซิงก์ถูกปิดในโหมดนี้'
                  : 'สั่งงานการซิงก์ด้วยตนเอง',
              style: _cardTitleStyle(context, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              AppModeConfig.isStandalone
                  ? 'โหมด Standalone ไม่ต้องเชื่อมต่อเครื่องอื่น และไม่ต้องส่งข้อมูลข้ามเครื่อง'
                  : 'เหมาะสำหรับกรณีต้องการอัปเดตข้อมูลทันทีหรือทดสอบการเชื่อมต่อ',
              style: _cardSubtitleStyle(context),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ElevatedButton.icon(
                  onPressed: !AppModeConfig.isStandalone && sync.isOnline
                      ? () => _triggerSync(context, ref)
                      : null,
                  icon: const Icon(Icons.cloud_upload_outlined),
                  label: const Text('Sync ตอนนี้'),
                ),
                OutlinedButton.icon(
                  onPressed: !AppModeConfig.isStandalone && sync.failedCount > 0
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

  Widget _buildBatchMetricsPanel(BuildContext context, SyncStatusModel sync) {
    return _panelCard(
      context,
      child: Padding(
        padding: context.cardPadding,
        child: Column(
          children: [
            _queueRow(
              context,
              icon: Icons.list_alt_rounded,
              color: AppTheme.infoColor,
              label: 'Batch ล่าสุด',
              value:
                  '${sync.lastBatchAppliedItems}/${sync.lastBatchTotalItems} รายการ',
            ),
            _queueRow(
              context,
              icon: Icons.repeat_rounded,
              color: sync.lastBatchReplayedItems > 0
                  ? Colors.orange
                  : AppTheme.successColor,
              label: 'Replay ใน batch',
              value:
                  '${sync.lastBatchReplayedItems} รายการ / ${sync.lastBatchPassesUsed} รอบ',
            ),
            _queueRow(
              context,
              icon: sync.lastBatchPendingItems > 0
                  ? Icons.warning_amber_rounded
                  : Icons.check_circle_outline_rounded,
              color: sync.lastBatchPendingItems > 0
                  ? AppTheme.errorColor
                  : AppTheme.successColor,
              label: 'ค้างหลังจบ batch',
              value: '${sync.lastBatchPendingItems} รายการ',
            ),
            Divider(color: AppTheme.borderColorOf(context), height: 20),
            Text(
              sync.lastBatchReplayedItems > 0
                  ? 'มีการ replay ภายใน batch ล่าสุดเพื่อแก้ dependency order อัตโนมัติ'
                  : 'batch ล่าสุด apply ได้ตามลำดับตั้งแต่รอบแรก',
              textAlign: TextAlign.center,
              style: _cardSubtitleStyle(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryPanel(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<SyncBatchHistoryModel>> historyAsync,
    SyncBatchTimeRange timeRange,
    String searchQuery,
    bool issuesOnly,
  ) {
    final fmt = DateFormat('dd/MM HH:mm');

    return _panelCard(
      context,
      child: Padding(
        padding: context.cardPadding,
        child: historyAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text(
            'โหลดประวัติ batch ไม่สำเร็จ: $e',
            style: _cardSubtitleStyle(context),
          ),
          data: (history) {
            final filtered = _filterHistory(
              history,
              timeRange: timeRange,
              searchQuery: searchQuery,
              issuesOnly: issuesOnly,
            );
            if (filtered.isEmpty) {
              return Text(
                'ไม่พบประวัติ SYNC_BATCH ในช่วงเวลาที่เลือก',
                style: _cardSubtitleStyle(context),
              );
            }

            final recent = filtered.take(10).toList();
            final children = <Widget>[
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: SyncBatchTimeRange.values
                      .map(
                        (range) => ChoiceChip(
                          label: Text(_timeRangeLabel(range)),
                          selected: timeRange == range,
                          onSelected: (_) =>
                              ref
                                      .read(syncBatchTimeRangeProvider.notifier)
                                      .state =
                                  range,
                        ),
                      )
                      .toList(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  children: [
                    TextFormField(
                      initialValue: searchQuery,
                      decoration: const InputDecoration(
                        hintText: 'ค้นหา batchId หรือ deviceName',
                        prefixIcon: Icon(Icons.search_rounded),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (value) =>
                          ref.read(syncBatchSearchProvider.notifier).state =
                              value,
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: issuesOnly,
                      onChanged: (value) =>
                          ref.read(syncBatchIssuesOnlyProvider.notifier).state =
                              value,
                      title: const Text('แสดงเฉพาะ batch ที่มีปัญหา'),
                      subtitle: const Text(
                        'โฟกัสเฉพาะ replay > 0 หรือ pending > 0',
                      ),
                    ),
                  ],
                ),
              ),
              ...recent.map<Widget>((entry) {
                final color = entry.hasPending
                    ? AppTheme.errorColor
                    : (entry.hasReplay ? Colors.orange : AppTheme.successColor);
                return InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _showBatchDetails(context, entry),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Icon(Icons.fiber_manual_record, size: 10, color: color),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${fmt.format(entry.createdAt)}  ${entry.appliedItems}/${entry.totalItems} รายการ',
                            style: _cardTitleStyle(context, fontSize: 12),
                          ),
                        ),
                        Text(
                          'Replay ${entry.replayedItems} | ค้าง ${entry.pendingItems}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.open_in_new_rounded,
                          size: 16,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            );
          },
        ),
      ),
    );
  }

  Widget _buildDebugPanel(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<SyncBatchHistoryModel>> historyAsync,
    SyncBatchTimeRange timeRange,
    String searchQuery,
    bool issuesOnly,
  ) {
    return _panelCard(
      context,
      child: Padding(
        padding: context.cardPadding,
        child: historyAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text(
            'โหลดข้อมูล debug ไม่สำเร็จ: $e',
            style: _cardSubtitleStyle(context),
          ),
          data: (history) {
            final filtered = _filterHistory(
              history,
              timeRange: timeRange,
              searchQuery: searchQuery,
              issuesOnly: issuesOnly,
            );
            if (filtered.isEmpty) {
              return Text(
                'ยังไม่มีข้อมูลสำหรับวิเคราะห์ในช่วงเวลานี้',
                style: _cardSubtitleStyle(context),
              );
            }

            final replayHeavy = [...filtered]
              ..sort((a, b) => b.replayedItems.compareTo(a.replayedItems));
            final pendingHeavy = [...filtered]
              ..sort((a, b) => b.pendingItems.compareTo(a.pendingItems));

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _queueRow(
                  context,
                  icon: Icons.repeat_rounded,
                  color: Colors.orange,
                  label: 'Replay สูงสุด',
                  value:
                      '${replayHeavy.first.replayedItems} รายการ (${replayHeavy.first.batchId})',
                ),
                _queueRow(
                  context,
                  icon: Icons.warning_amber_rounded,
                  color: AppTheme.errorColor,
                  label: 'Pending สูงสุด',
                  value:
                      '${pendingHeavy.first.pendingItems} รายการ (${pendingHeavy.first.batchId})',
                ),
                Divider(color: AppTheme.borderColorOf(context), height: 20),
                Text(
                  'Batch ที่ควรดูเพิ่ม',
                  style: _cardTitleStyle(context, fontSize: 12),
                ),
                const SizedBox(height: 8),
                ...filtered
                    .where((e) => e.hasReplay || e.hasPending)
                    .take(5)
                    .map(
                      (entry) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(
                          entry.batchId,
                          style: _cardTitleStyle(context, fontSize: 12),
                        ),
                        subtitle: Text(
                          'Replay ${entry.replayedItems} | Pending ${entry.pendingItems} | Passes ${entry.passesUsed}',
                          style: _cardSubtitleStyle(context),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _showBatchDetails(context, entry),
                      ),
                    ),
                Divider(color: AppTheme.borderColorOf(context), height: 20),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () => _exportDebugReport(context, filtered),
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('คัดลอก Debug Report'),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'ใช้รายงานนี้เพื่อตรวจ batch ที่ replay/pending สูงผิดปกติ และชี้เป้าปัญหา dependency ของ schema',
                  style: _cardSubtitleStyle(context),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _exportDebugReport(
    BuildContext context,
    List<SyncBatchHistoryModel> history,
  ) async {
    final buffer = StringBuffer()
      ..writeln('SYNC_BATCH DEBUG REPORT')
      ..writeln('Generated: ${DateTime.now().toIso8601String()}')
      ..writeln('');

    for (final entry in history.take(20)) {
      buffer.writeln(
        '${entry.createdAt.toIso8601String()} | '
        'batch=${entry.batchId} | '
        'applied=${entry.appliedItems}/${entry.totalItems} | '
        'replayed=${entry.replayedItems} | '
        'passes=${entry.passesUsed} | '
        'pending=${entry.pendingItems} | '
        'mode=${entry.appMode ?? '-'} | '
        'device=${entry.deviceName ?? '-'}',
      );
    }

    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('คัดลอก Debug Report แล้ว')));
    }
  }

  List<SyncBatchHistoryModel> _filterHistory(
    List<SyncBatchHistoryModel> history, {
    required SyncBatchTimeRange timeRange,
    required String searchQuery,
    required bool issuesOnly,
  }) {
    var filtered = history;

    filtered = _filterHistoryByRange(filtered, timeRange);

    final normalizedQuery = searchQuery.trim().toLowerCase();
    if (normalizedQuery.isNotEmpty) {
      filtered = filtered.where((entry) {
        final batchId = entry.batchId.toLowerCase();
        final deviceName = (entry.deviceName ?? '').toLowerCase();
        return batchId.contains(normalizedQuery) ||
            deviceName.contains(normalizedQuery);
      }).toList();
    }

    if (issuesOnly) {
      filtered = filtered
          .where((entry) => entry.hasReplay || entry.hasPending)
          .toList();
    }

    return filtered;
  }

  List<SyncBatchHistoryModel> _filterHistoryByRange(
    List<SyncBatchHistoryModel> history,
    SyncBatchTimeRange range,
  ) {
    if (range == SyncBatchTimeRange.all) return history;

    final now = DateTime.now();
    final threshold = switch (range) {
      SyncBatchTimeRange.lastHour => now.subtract(const Duration(hours: 1)),
      SyncBatchTimeRange.last24Hours => now.subtract(const Duration(hours: 24)),
      SyncBatchTimeRange.last7Days => now.subtract(const Duration(days: 7)),
      SyncBatchTimeRange.all => DateTime.fromMillisecondsSinceEpoch(0),
    };

    return history
        .where((entry) => entry.createdAt.isAfter(threshold))
        .toList();
  }

  String _timeRangeLabel(SyncBatchTimeRange range) {
    return switch (range) {
      SyncBatchTimeRange.lastHour => '1 ชม.',
      SyncBatchTimeRange.last24Hours => '24 ชม.',
      SyncBatchTimeRange.last7Days => '7 วัน',
      SyncBatchTimeRange.all => 'ทั้งหมด',
    };
  }

  Future<void> _showBatchDetails(
    BuildContext context,
    SyncBatchHistoryModel entry,
  ) async {
    final payloadLines = entry.payload.entries
        .map((e) => '${e.key}: ${e.value}')
        .join('\n');

    await showDialog<void>(
      context: context,
      builder: (_) => AppDialog(
        title: buildAppDialogTitle(
          context,
          title: 'Batch ${entry.batchId}',
          icon: Icons.receipt_long_outlined,
          iconColor: AppTheme.infoColor,
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: SelectableText(
              'created_at: ${entry.createdAt.toIso8601String()}\n'
              'applied: ${entry.appliedItems}/${entry.totalItems}\n'
              'replayed: ${entry.replayedItems}\n'
              'passes: ${entry.passesUsed}\n'
              'pending: ${entry.pendingItems}\n'
              'mode: ${entry.appMode ?? '-'}\n'
              'device: ${entry.deviceName ?? '-'}\n\n'
              'payload\n'
              '$payloadLines',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(
                  text:
                      'batch=${entry.batchId}\ncreated_at=${entry.createdAt.toIso8601String()}\n$payloadLines',
                ),
              );
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('คัดลอก'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('ปิด'),
          ),
        ],
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
                    ref.read(selectedBranchProvider.notifier).setBranch(b);
                    ref
                        .read(selectedWarehouseProvider.notifier)
                        .setWarehouse(null);
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
                    ref
                        .read(selectedWarehouseProvider.notifier)
                        .setWarehouse(w);
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

  Future<void> _switchMode(
    BuildContext context,
    WidgetRef ref,
    AppMode mode,
  ) async {
    if (AppModeConfig.mode == mode) return;

    if (mode == AppMode.standalone) {
      await AppModeConfig.setMode(
        AppMode.standalone,
        deviceName: AppModeConfig.deviceName,
      );
      await AppModeConfig.clearMasterConnection();
    } else if (mode == AppMode.master) {
      await AppModeConfig.setMode(
        AppMode.master,
        deviceName: AppModeConfig.deviceName,
      );
    } else {
      await AppModeConfig.setMode(
        mode,
        masterIp: AppModeConfig.masterIp,
        masterName: AppModeConfig.masterName,
        masterPort: AppModeConfig.masterPort,
        deviceName: AppModeConfig.deviceName,
      );
    }

    await MasterDiscoveryService.instance.refresh();
    await refreshRuntimeForAppModeChange();
    ref.invalidate(masterBackgroundHostStatusProvider);
    ref.invalidate(syncStatusProvider);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            mode == AppMode.standalone
                ? 'เครื่องนี้ถูกตั้งเป็น Standalone แล้ว'
                : mode == AppMode.master
                ? 'เครื่องนี้ถูกตั้งเป็น Master แล้ว'
                : 'สลับเป็นโหมด Slave แล้ว',
          ),
        ),
      );
    }
  }

  Future<void> _editDeviceName(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController(text: AppModeConfig.deviceName);

    final nextName = await showDialog<String>(
      context: context,
      builder: (_) => AppDialog(
        title: buildAppDialogTitle(
          context,
          title: AppModeConfig.isMaster ? 'ตั้งชื่อ Master' : 'ตั้งชื่ออุปกรณ์',
          icon: Icons.edit_outlined,
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'ชื่อที่จะแสดง',
            hintText: 'เช่น POS-Main-Store',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );

    if (nextName == null || nextName.isEmpty) return;

    await AppModeConfig.setDeviceName(nextName);
    await MasterDiscoveryService.instance.refresh();
    ref.invalidate(syncStatusProvider);

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('บันทึกชื่ออุปกรณ์แล้ว')));
    }
  }

  Future<void> _refreshDiscovery(BuildContext context, WidgetRef ref) async {
    await MasterDiscoveryService.instance.refresh();
    ref.invalidate(syncStatusProvider);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กำลังค้นหา Master ในเครือข่าย')),
      );
    }
  }

  Future<void> _connectToMaster(
    BuildContext context,
    WidgetRef ref,
    DiscoveredMaster master,
  ) async {
    final tempClient = ApiClient(
      baseUrl: 'http://${master.host}:${master.port}',
    );

    try {
      final health = await tempClient.get('/api/health');
      if (health.statusCode != 200) {
        throw Exception('Master ไม่ตอบสนอง');
      }

      await AppModeConfig.setMode(
        AppMode.clientPOS,
        masterIp: master.host,
        masterName: master.name,
        masterPort: master.port,
        deviceName: AppModeConfig.deviceName,
      );
      await MasterDiscoveryService.instance.refresh();
      ref.invalidate(syncStatusProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'เชื่อมต่อกับ ${master.name} แล้ว การขายครั้งถัดไปจะบันทึกที่ฐานข้อมูลฝั่ง Master',
            ),
          ),
        );
      }
    } on DioException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เชื่อมต่อไม่สำเร็จ: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เชื่อมต่อไม่สำเร็จ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _disconnectMaster(BuildContext context, WidgetRef ref) async {
    await AppModeConfig.clearMasterConnection();
    await MasterDiscoveryService.instance.refresh();
    ref.invalidate(syncStatusProvider);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ตัดการเชื่อมต่อ Master แล้ว')),
      );
    }
  }
}
