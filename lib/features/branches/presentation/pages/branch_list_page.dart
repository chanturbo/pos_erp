// branch_list_page.dart — Branch Management

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/utils/responsive_utils.dart';
import '../../data/models/branch_model.dart';
import '../providers/branch_provider.dart';
import 'branch_form_page.dart';
import 'sync_status_page.dart';

class BranchListPage extends ConsumerStatefulWidget {
  const BranchListPage({super.key});

  @override
  ConsumerState<BranchListPage> createState() => _BranchListPageState();
}

class _BranchListPageState extends ConsumerState<BranchListPage> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  bool _isCardView = true;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      final nextValue = _searchCtrl.text.trim();
      if (nextValue != _searchQuery) {
        setState(() => _searchQuery = nextValue);
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _refreshAll() {
    ref.read(branchListProvider.notifier).refresh();
    ref.invalidate(syncStatusProvider);
  }

  @override
  Widget build(BuildContext context) {
    final branchesAsync = ref.watch(branchListProvider);
    final syncAsync = ref.watch(syncStatusProvider);

    return Scaffold(
      backgroundColor: AppTheme.surfaceColorOf(context),
      appBar: AppBar(
        automaticallyImplyLeading: !context.hasPermanentSidebar,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('จัดการสาขา'),
            Text(
              'ดูแลข้อมูลสาขา คลังสินค้า และสถานะการเชื่อมต่อ',
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.65),
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          syncAsync.when(
            data: (sync) => IconButton(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    sync.isOnline ? Icons.sync_rounded : Icons.sync_disabled,
                    color: sync.isOnline ? Colors.white : Colors.red.shade200,
                  ),
                  if (sync.hasPending)
                    Positioned(
                      right: -1,
                      top: -1,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Colors.orange,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              tooltip: sync.pendingCount > 0
                  ? 'รอ Sync ${sync.pendingCount} รายการ'
                  : 'สถานะการ Sync',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SyncStatusPage()),
              ),
            ),
            loading: () => const SizedBox(
              width: 48,
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              ),
            ),
            error: (_, _) => IconButton(
              icon: const Icon(Icons.sync_problem),
              tooltip: 'สถานะการ Sync',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SyncStatusPage()),
              ),
            ),
          ),
          IconButton(
            icon: Icon(_isCardView ? Icons.view_list_rounded : Icons.grid_view),
            tooltip: _isCardView
                ? 'เปลี่ยนเป็น ListView'
                : 'เปลี่ยนเป็น CardView',
            onPressed: () => setState(() => _isCardView = !_isCardView),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'รีเฟรชข้อมูล',
            onPressed: _refreshAll,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, null),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_business_outlined),
        label: const Text('เพิ่มสาขา'),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: context.contentMaxWidth),
          child: branchesAsync.when(
            loading: () => _buildLoadingState(context),
            error: (e, _) => _buildErrorState(context, '$e'),
            data: (branches) => _buildContent(context, branches, syncAsync),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<BranchModel> branches,
    AsyncValue<SyncStatusModel> syncAsync,
  ) {
    final filtered = branches.where(_matchesSearch).toList();
    final activeCount = branches.where((b) => b.isActive).length;
    final inactiveCount = branches.length - activeCount;
    final totalWarehouses = branches.fold<int>(
      0,
      (sum, branch) => sum + (branch.warehouseCount ?? 0),
    );

    return RefreshIndicator(
      onRefresh: () async => _refreshAll(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: context.pagePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildToolbar(context, filtered.length, branches.length),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _summaryCard(
                  context,
                  title: 'จำนวนสาขา',
                  value: '${branches.length}',
                  icon: Icons.storefront_outlined,
                  color: AppTheme.primary,
                ),
                _summaryCard(
                  context,
                  title: 'เปิดใช้งาน',
                  value: '$activeCount',
                  icon: Icons.check_circle_outline,
                  color: AppTheme.successColor,
                ),
                _summaryCard(
                  context,
                  title: 'ปิดใช้งาน',
                  value: '$inactiveCount',
                  icon: Icons.pause_circle_outline,
                  color: Colors.grey.shade700,
                ),
                _summaryCard(
                  context,
                  title: 'คลังสินค้ารวม',
                  value: '$totalWarehouses',
                  icon: Icons.warehouse_outlined,
                  color: AppTheme.infoColor,
                ),
              ],
            ),
            const SizedBox(height: 16),
            syncAsync.when(
              data: (sync) => _buildSyncPanel(context, sync),
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
            if (syncAsync.hasValue) const SizedBox(height: 16),
            _sectionTitle(
              context,
              'รายการสาขา',
              Icons.account_tree_outlined,
              AppTheme.primary,
              trailing: Text(
                'แสดง ${filtered.length} จาก ${branches.length} รายการ',
                style: _cardSubtitleStyle(context),
              ),
            ),
            const SizedBox(height: 8),
            if (branches.isEmpty)
              _buildEmptyState(context, isFiltered: false)
            else if (filtered.isEmpty)
              _buildEmptyState(context, isFiltered: true)
            else
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _isCardView
                    ? _buildCardView(context, filtered)
                    : _buildListView(context, filtered),
              ),
            SizedBox(height: context.isMobile ? 88 : 96),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar(BuildContext context, int filtered, int total) {
    return _panelCard(
      context,
      child: Padding(
        padding: context.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ค้นหาและมุมมอง',
              style: _cardTitleStyle(context, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              'ค้นหาตามชื่อสาขา รหัสสาขา เบอร์โทร หรือที่อยู่',
              style: _cardSubtitleStyle(context),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'ค้นหาสาขา...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchQuery.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'ล้างคำค้นหา',
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () => _searchCtrl.clear(),
                            ),
                    ),
                  ),
                ),
                if (!context.isMobile) ...[
                  const SizedBox(width: 12),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment<bool>(
                        value: false,
                        icon: Icon(Icons.view_list_rounded),
                        label: Text('ListView'),
                      ),
                      ButtonSegment<bool>(
                        value: true,
                        icon: Icon(Icons.grid_view_rounded),
                        label: Text('CardView'),
                      ),
                    ],
                    selected: {_isCardView},
                    onSelectionChanged: (selection) {
                      setState(() => _isCardView = selection.first);
                    },
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _metricBadge(
                  context,
                  label: 'ทั้งหมด $total',
                  color: AppTheme.primary,
                ),
                _metricBadge(
                  context,
                  label: 'แสดงผล $filtered',
                  color: AppTheme.infoColor,
                ),
                _metricBadge(
                  context,
                  label: _isCardView ? 'CardView' : 'ListView',
                  color: Colors.deepPurple,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardView(BuildContext context, List<BranchModel> branches) {
    return Column(
      key: const ValueKey('card_view'),
      children: branches
          .map(
            (branch) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _branchCard(context, branch, compact: false),
            ),
          )
          .toList(),
    );
  }

  Widget _buildListView(BuildContext context, List<BranchModel> branches) {
    return _panelCard(
      context,
      key: const ValueKey('list_view'),
      child: Column(
        children: [
          for (var i = 0; i < branches.length; i++) ...[
            _branchRow(context, branches[i]),
            if (i != branches.length - 1)
              Divider(height: 1, color: AppTheme.borderColorOf(context)),
          ],
        ],
      ),
    );
  }

  Widget _branchCard(
    BuildContext context,
    BranchModel branch, {
    required bool compact,
  }) {
    final address = branch.address?.trim();
    final phone = branch.phone?.trim();

    return _panelCard(
      context,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openForm(context, branch),
        child: Padding(
          padding: context.cardPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: compact ? 40 : 44,
                    height: compact ? 40 : 44,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.storefront_outlined,
                      color: AppTheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          branch.branchName,
                          style: _cardTitleStyle(context),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          branch.branchCode,
                          style: _cardSubtitleStyle(context),
                        ),
                      ],
                    ),
                  ),
                  _statusChip(context, branch.isActive),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _metricBadge(
                    context,
                    label: '${branch.warehouseCount ?? 0} คลัง',
                    color: AppTheme.infoColor,
                  ),
                  if ((branch.userCount ?? 0) > 0)
                    _metricBadge(
                      context,
                      label: '${branch.userCount ?? 0} ผู้ใช้',
                      color: Colors.teal,
                    ),
                ],
              ),
              if ((address != null && address.isNotEmpty) ||
                  (phone != null && phone.isNotEmpty)) ...[
                const SizedBox(height: 12),
                if (address != null && address.isNotEmpty)
                  _infoRow(context, Icons.location_on_outlined, address),
                if (phone != null && phone.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: address != null ? 6 : 0),
                    child: _infoRow(context, Icons.phone_outlined, phone),
                  ),
              ],
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _openForm(context, branch),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('แก้ไข'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _confirmDelete(context, branch),
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      size: 16,
                      color: AppTheme.errorColor,
                    ),
                    label: const Text(
                      'ลบ',
                      style: TextStyle(color: AppTheme.errorColor),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: AppTheme.errorColor.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _branchRow(BuildContext context, BranchModel branch) {
    return ListTile(
      dense: context.isMobile,
      contentPadding: EdgeInsets.symmetric(
        horizontal: context.isMobile ? 12 : 16,
        vertical: context.isMobile ? 4 : 6,
      ),
      onTap: () => _openForm(context, branch),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          Icons.storefront_outlined,
          color: AppTheme.primary,
          size: 18,
        ),
      ),
      title: Text(branch.branchName, style: _cardTitleStyle(context)),
      subtitle: Text(
        '${branch.branchCode} • ${branch.warehouseCount ?? 0} คลังสินค้า',
        style: _cardSubtitleStyle(context),
      ),
      trailing: SizedBox(
        width: context.isMobile ? 132 : 220,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: _statusChip(context, branch.isActive)),
            IconButton(
              tooltip: 'แก้ไขสาขา',
              icon: const Icon(Icons.edit_outlined, size: 18),
              onPressed: () => _openForm(context, branch),
            ),
            IconButton(
              tooltip: 'ลบสาขา',
              icon: const Icon(
                Icons.delete_outline_rounded,
                size: 18,
                color: AppTheme.errorColor,
              ),
              onPressed: () => _confirmDelete(context, branch),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncPanel(BuildContext context, SyncStatusModel sync) {
    final syncColor = sync.isOnline
        ? AppTheme.successColor
        : AppTheme.errorColor;

    return _panelCard(
      context,
      child: Padding(
        padding: context.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(
              context,
              'สถานะการเชื่อมต่อ',
              sync.isOnline
                  ? Icons.cloud_done_outlined
                  : Icons.cloud_off_outlined,
              syncColor,
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _metricBadge(
                  context,
                  label: sync.isOnline ? 'Online' : 'Offline',
                  color: syncColor,
                ),
                _metricBadge(
                  context,
                  label: 'Pending ${sync.pendingCount}',
                  color: Colors.orange,
                ),
                if (sync.failedCount > 0)
                  _metricBadge(
                    context,
                    label: 'Failed ${sync.failedCount}',
                    color: AppTheme.errorColor,
                  ),
                _metricBadge(
                  context,
                  label: 'โหมด ${sync.appMode}',
                  color: AppTheme.infoColor,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: SizedBox(
        width: context.isMobile ? 24 : 28,
        height: context.isMobile ? 24 : 28,
        child: const CircularProgressIndicator(strokeWidth: 2.5),
      ),
    ),
  );

  Widget _buildErrorState(BuildContext context, String message) => Center(
    child: Padding(
      padding: context.pagePadding,
      child: _panelCard(
        context,
        child: Padding(
          padding: context.cardPadding,
          child: Row(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: AppTheme.errorColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'เกิดข้อผิดพลาด: $message',
                  style: const TextStyle(color: AppTheme.errorColor),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _buildEmptyState(BuildContext context, {required bool isFiltered}) {
    final title = isFiltered ? 'ไม่พบสาขาที่ค้นหา' : 'ยังไม่มีสาขา';
    final subtitle = isFiltered
        ? 'ลองเปลี่ยนคำค้นหา หรือกดล้างตัวกรองเพื่อดูทั้งหมด'
        : 'สร้างสาขาแรกเพื่อเริ่มใช้งานระบบหลายสาขา';

    return _panelCard(
      context,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
        child: Center(
          child: Column(
            children: [
              Icon(
                isFiltered ? Icons.search_off_rounded : Icons.store_outlined,
                size: context.isMobile ? 58 : 68,
                color: AppTheme.subtextColorOf(context).withValues(alpha: 0.45),
              ),
              const SizedBox(height: 14),
              Text(title, style: _cardTitleStyle(context, fontSize: 15)),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: _cardSubtitleStyle(context),
              ),
              if (!isFiltered) ...[
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _openForm(context, null),
                  icon: const Icon(Icons.add_business_outlined),
                  label: const Text('เพิ่มสาขาแรก'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(
    BuildContext context,
    String title,
    IconData icon,
    Color color, {
    Widget? trailing,
  }) {
    final trailingWidgets = trailing == null ? const <Widget>[] : [trailing];
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
        ...trailingWidgets,
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

  Widget _metricBadge(
    BuildContext context, {
    required String label,
    required Color color,
  }) {
    return Container(
      constraints: const BoxConstraints(minWidth: 40),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _statusChip(BuildContext context, bool isActive) {
    final color = isActive ? AppTheme.successColor : Colors.grey.shade700;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isActive ? 'เปิดใช้งาน' : 'ปิดใช้งาน',
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _infoRow(BuildContext context, IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: AppTheme.subtextColorOf(context)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: _cardSubtitleStyle(context),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _panelCard(BuildContext context, {required Widget child, Key? key}) {
    return Card(
      key: key,
      elevation: 0,
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.borderColorOf(context)),
      ),
      child: child,
    );
  }

  TextStyle _cardTitleStyle(BuildContext context, {double? fontSize}) {
    return TextStyle(
      fontSize: fontSize ?? (context.isMobile ? 13 : 14),
      fontWeight: FontWeight.w700,
      color: Theme.of(context).colorScheme.onSurface,
    );
  }

  TextStyle _cardSubtitleStyle(BuildContext context) {
    return TextStyle(
      fontSize: context.isMobile ? 11 : 12,
      color: AppTheme.subtextColorOf(context),
      fontWeight: FontWeight.w500,
    );
  }

  bool _matchesSearch(BranchModel branch) {
    if (_searchQuery.isEmpty) return true;
    final query = _searchQuery.toLowerCase();
    return branch.branchName.toLowerCase().contains(query) ||
        branch.branchCode.toLowerCase().contains(query) ||
        (branch.phone ?? '').toLowerCase().contains(query) ||
        (branch.address ?? '').toLowerCase().contains(query);
  }

  Future<void> _openForm(BuildContext context, BranchModel? branch) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BranchFormPage(branch: branch)),
    );
    _refreshAll();
  }

  void _confirmDelete(BuildContext context, BranchModel branch) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: Text('ต้องการลบสาขา "${branch.branchName}" ใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(branchListProvider.notifier)
                  .deleteBranch(branch.branchId);
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('ลบสาขาแล้ว')));
              }
              _refreshAll();
            },
            child: const Text(
              'ลบ',
              style: TextStyle(color: AppTheme.errorColor),
            ),
          ),
        ],
      ),
    );
  }
}
