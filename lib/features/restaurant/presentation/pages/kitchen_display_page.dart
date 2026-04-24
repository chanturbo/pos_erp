import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/utils/responsive_utils.dart';
import '../../data/models/kitchen_queue_model.dart';
import '../../data/models/restaurant_enums.dart';
import '../providers/kitchen_provider.dart';
import '../widgets/kitchen_order_card.dart'
    show KitchenOrderCard, kHeldOverdueMinutes;

class KitchenDisplayPage extends ConsumerStatefulWidget {
  const KitchenDisplayPage({super.key});

  @override
  ConsumerState<KitchenDisplayPage> createState() => _KitchenDisplayPageState();
}

class _KitchenDisplayPageState extends ConsumerState<KitchenDisplayPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isFullScreen = false;
  int _lastStationIndex = 0;

  static List<_StationTab> get _stations => [
    const _StationTab(key: null, label: 'ทั้งหมด', icon: Icons.grid_view),
    ...PrepStation.values
        .where((s) => s != PrepStation.cashier)
        .map((s) => _StationTab(key: s.name, label: s.label, icon: s.icon)),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _stations.length, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_tabController.index == _lastStationIndex) return;
    _lastStationIndex = _tabController.index;
    final station = _stations[_tabController.index].key;
    ref.read(selectedKitchenStationProvider.notifier).state = station;
    ref.read(kitchenQueueProvider.notifier).refresh();
    ref.read(kitchenSummaryProvider.notifier).refresh();
  }

  void _toggleFullScreen() {
    setState(() => _isFullScreen = !_isFullScreen);
    if (_isFullScreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  void _refreshAll() {
    ref.read(kitchenQueueProvider.notifier).refresh();
    ref.read(kitchenSummaryProvider.notifier).refresh();
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _tabController
      ..removeListener(_onTabChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(kitchenSummaryProvider);
    final summaryList = summaryAsync.asData?.value ?? [];
    final summaryMap = {for (final s in summaryList) s.station: s};

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        title: const Text('หน้าจอครัว (KDS)'),
        backgroundColor: AppTheme.navyColor,
        foregroundColor: Colors.white,
        actions: [
          _RefreshButton(onTap: _refreshAll),
          IconButton(
            icon: Icon(
              _isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
            ),
            tooltip: _isFullScreen ? 'ออกจาก Full Screen' : 'Full Screen',
            onPressed: _toggleFullScreen,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _KitchenSummaryPanel(
              summaryList: summaryList,
              isLoading: summaryAsync.isLoading && summaryList.isEmpty,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.cardWhite,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                dividerColor: Colors.transparent,
                indicatorPadding: const EdgeInsets.all(6),
                labelColor: AppTheme.navyColor,
                unselectedLabelColor: AppTheme.subtextColor,
                splashBorderRadius: BorderRadius.circular(10),
                tabs: _stations.map((s) {
                  final sm = s.key != null ? summaryMap[s.key] : null;
                  final active = sm?.totalActive ?? 0;
                  return Tab(
                    height: 56,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(s.icon, size: 16),
                        const SizedBox(width: 6),
                        Flexible(child: Text(s.label)),
                        if (active > 0) ...[
                          const SizedBox(width: 6),
                          _Badge(count: active),
                        ],
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TabBarView(
                controller: _tabController,
                children: _stations
                    .map((s) => _StationView(stationKey: s.key))
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KitchenSummaryPanel extends StatelessWidget {
  const _KitchenSummaryPanel({
    required this.summaryList,
    required this.isLoading,
  });

  final List<KitchenStationSummary> summaryList;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;
    final totals = summaryList.fold(
      const _SummaryTotals(),
      (prev, item) => _SummaryTotals(
        pending: prev.pending + item.pendingCount,
        preparing: prev.preparing + item.preparingCount,
        ready: prev.ready + item.readyCount,
      ),
    );

    return Container(
      padding: EdgeInsets.all(isMobile ? 10 : 12),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(isMobile ? 7 : 8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.kitchen,
                  color: AppTheme.primaryColor,
                  size: isMobile ? 16 : 18,
                ),
              ),
              SizedBox(width: isMobile ? 8 : 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ภาพรวมคิวครัว',
                      style: TextStyle(
                        fontSize: isMobile ? 14 : 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.navyColor,
                      ),
                    ),
                    if (!isMobile) ...[
                      const SizedBox(height: 2),
                      const Text(
                        'ติดตามคิวรอทำ, กำลังทำ และพร้อมเสิร์ฟในหน้าจอเดียว',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.subtextColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 8 : 10),
          if (isLoading)
            const LinearProgressIndicator(
              minHeight: 3,
              color: AppTheme.primaryColor,
              backgroundColor: AppTheme.primaryContainer,
            )
          else
            isMobile
                ? SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _SummaryCard(
                          label: 'รอทำ',
                          value: '${totals.pending}',
                          icon: Icons.hourglass_top_rounded,
                          color: AppTheme.warningColor,
                          background: AppTheme.warningContainer,
                          compact: true,
                        ),
                        const SizedBox(width: 8),
                        _SummaryCard(
                          label: 'กำลังทำ',
                          value: '${totals.preparing}',
                          icon: Icons.sync_rounded,
                          color: AppTheme.infoColor,
                          background: AppTheme.infoContainer,
                          compact: true,
                        ),
                        const SizedBox(width: 8),
                        _SummaryCard(
                          label: 'พร้อมเสิร์ฟ',
                          value: '${totals.ready}',
                          icon: Icons.done_all_rounded,
                          color: AppTheme.successColor,
                          background: AppTheme.successContainer,
                          compact: true,
                        ),
                      ],
                    ),
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _SummaryCard(
                        label: 'รอทำ',
                        value: '${totals.pending}',
                        icon: Icons.hourglass_top_rounded,
                        color: AppTheme.warningColor,
                        background: AppTheme.warningContainer,
                      ),
                      _SummaryCard(
                        label: 'กำลังทำ',
                        value: '${totals.preparing}',
                        icon: Icons.sync_rounded,
                        color: AppTheme.infoColor,
                        background: AppTheme.infoContainer,
                      ),
                      _SummaryCard(
                        label: 'พร้อมเสิร์ฟ',
                        value: '${totals.ready}',
                        icon: Icons.done_all_rounded,
                        color: AppTheme.successColor,
                        background: AppTheme.successContainer,
                      ),
                    ],
                  ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.background,
    this.compact = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color background;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: compact ? 132 : 160,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: compact ? 16 : 18),
          SizedBox(width: compact ? 6 : 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: compact ? 10 : 11,
                    color: AppTheme.subtextColor,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: compact ? 15 : 17,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StationView extends ConsumerStatefulWidget {
  const _StationView({required this.stationKey});

  final String? stationKey;

  @override
  ConsumerState<_StationView> createState() => _StationViewState();
}

class _StationViewState extends ConsumerState<_StationView> {
  int _mobileStatusIndex = 0;

  @override
  Widget build(BuildContext context) {
    final queueAsync = ref.watch(kitchenQueueProvider);
    final isMobile = context.isMobile;

    return queueAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _KdsMessageState(
        icon: Icons.error_outline,
        title: 'โหลดคิวครัวไม่สำเร็จ',
        message: '$e',
        iconColor: AppTheme.errorColor,
      ),
      data: (items) {
        final filtered = widget.stationKey == null
            ? items
            : items
                  .where(
                    (i) => i.prepStation?.toLowerCase() == widget.stationKey,
                  )
                  .toList();

        if (filtered.isEmpty) {
          return const _KdsMessageState(
            icon: Icons.check_circle_outline,
            title: 'ไม่มีรายการที่รอดำเนินการ',
            message: 'เมื่อมีออเดอร์ใหม่ รายการจะขึ้นในหน้าจอนี้อัตโนมัติ',
            iconColor: AppTheme.successColor,
          );
        }

        final held = filtered.where((i) => i.kitchenStatus == 'HELD').toList();
        final pending = filtered
            .where((i) => i.kitchenStatus == 'PENDING')
            .toList();
        final preparing = filtered
            .where((i) => i.kitchenStatus == 'PREPARING')
            .toList();
        final ready = filtered
            .where((i) => i.kitchenStatus == 'READY')
            .toList();

        final columnSpecs = <_QueueColumnSpec>[
          if (held.isNotEmpty)
            _QueueColumnSpec(
              title: 'รอ Fire',
              count: held.length,
              color: Colors.blueGrey,
              softBackground: const Color(0xFFF1F4F6),
              items: held,
              overdueCount: held
                  .where(
                    (i) =>
                        DateTime.now().difference(i.createdAt).inMinutes >=
                        kHeldOverdueMinutes,
                  )
                  .length,
            ),
          _QueueColumnSpec(
            title: 'รอทำ',
            count: pending.length,
            color: AppTheme.warningColor,
            softBackground: AppTheme.warningContainer,
            items: pending,
          ),
          _QueueColumnSpec(
            title: 'กำลังทำ',
            count: preparing.length,
            color: AppTheme.infoColor,
            softBackground: AppTheme.infoContainer,
            items: preparing,
          ),
          _QueueColumnSpec(
            title: 'พร้อมเสิร์ฟ',
            count: ready.length,
            color: AppTheme.successColor,
            softBackground: AppTheme.successContainer,
            items: ready,
          ),
        ];

        if (columnSpecs.isEmpty) {
          return const _KdsMessageState(
            icon: Icons.check_circle_outline,
            title: 'ไม่มีรายการที่รอดำเนินการ',
            message: 'เมื่อมีออเดอร์ใหม่ รายการจะขึ้นในหน้าจอนี้อัตโนมัติ',
            iconColor: AppTheme.successColor,
          );
        }

        if (_mobileStatusIndex >= columnSpecs.length) {
          _mobileStatusIndex = 0;
        }

        if (isMobile) {
          final activeSpec = columnSpecs[_mobileStatusIndex];
          return Column(
            children: [
              _MobileQueueFilterBar(
                specs: columnSpecs,
                selectedIndex: _mobileStatusIndex,
                onSelected: (index) =>
                    setState(() => _mobileStatusIndex = index),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _QueueColumn(
                  spec: activeSpec,
                  onStatusChange: (id, status) =>
                      _updateStatus(context, id, status),
                  onFireCourse: (tableId, courseNo) =>
                      _fireCourse(context, tableId, courseNo),
                ),
              ),
            ],
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            const minColumnWidth = 320.0;
            final totalWidth = columnSpecs.length * minColumnWidth;

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: totalWidth > constraints.maxWidth
                    ? totalWidth
                    : constraints.maxWidth,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: columnSpecs
                      .map(
                        (spec) => Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: _QueueColumn(
                              spec: spec,
                              onStatusChange: (id, status) =>
                                  _updateStatus(context, id, status),
                              onFireCourse: (tableId, courseNo) =>
                                  _fireCourse(context, tableId, courseNo),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _updateStatus(
    BuildContext context,
    String itemId,
    String newStatus,
  ) async {
    final ok = await ref
        .read(kitchenQueueProvider.notifier)
        .updateStatus(itemId, newStatus);
    if (!context.mounted || ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('อัปเดตสถานะรายการในครัวไม่สำเร็จ')),
    );
  }

  Future<void> _fireCourse(
    BuildContext context,
    String tableId,
    int courseNo,
  ) async {
    final ok = await ref
        .read(kitchenQueueProvider.notifier)
        .fireCourse(tableId, courseNo);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Fire course $courseNo แล้ว' : 'Fire course $courseNo ไม่สำเร็จ',
        ),
      ),
    );
  }
}

class _MobileQueueFilterBar extends StatelessWidget {
  const _MobileQueueFilterBar({
    required this.specs,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<_QueueColumnSpec> specs;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: specs.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final spec = specs[index];
          final selected = index == selectedIndex;
          return GestureDetector(
            onTap: () => onSelected(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: selected
                    ? spec.color.withValues(alpha: 0.14)
                    : AppTheme.cardWhite,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: selected ? spec.color : AppTheme.borderColor,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: spec.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    spec.title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: selected ? spec.color : AppTheme.navyColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? spec.color.withValues(alpha: 0.18)
                          : AppTheme.headerBg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${spec.count}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: selected ? spec.color : AppTheme.subtextColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _QueueColumn extends StatelessWidget {
  const _QueueColumn({
    required this.spec,
    required this.onStatusChange,
    required this.onFireCourse,
  });

  final _QueueColumnSpec spec;
  final void Function(String itemId, String newStatus) onStatusChange;
  final void Function(String tableId, int courseNo) onFireCourse;

  @override
  Widget build(BuildContext context) {
    final groups = KitchenOrderGroup.groupItems(spec.items);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: spec.softBackground,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(15),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: spec.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        spec.title,
                        style: const TextStyle(
                          color: AppTheme.navyColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      if (spec.overdueCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.warningColor.withValues(
                              alpha: 0.14,
                            ),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: AppTheme.warningColor.withValues(
                                alpha: 0.35,
                              ),
                            ),
                          ),
                          child: Text(
                            '${spec.overdueCount} ค้าง',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.warningColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: spec.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${spec.count}',
                    style: TextStyle(
                      color: spec.color,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: groups.isEmpty
                ? const Center(
                    child: Text(
                      'ยังไม่มีคิวในสถานะนี้',
                      style: TextStyle(color: AppTheme.subtextColor),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount: groups.length,
                    itemBuilder: (_, i) {
                      final group = groups[i];
                      return KitchenOrderCard(
                        key: ValueKey(group.orderId),
                        group: group,
                        onStatusChange: onStatusChange,
                        onFireCourse: onFireCourse,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _KdsMessageState extends StatelessWidget {
  const _KdsMessageState({
    required this.icon,
    required this.title,
    required this.message,
    required this.iconColor,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compactHeight = constraints.maxHeight < 160;
        final iconSize = compactHeight ? 40.0 : 56.0;
        final padding = compactHeight ? 16.0 : 24.0;
        final gapLarge = compactHeight ? 10.0 : 14.0;
        final gapSmall = compactHeight ? 6.0 : 8.0;

        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: EdgeInsets.all(padding),
                decoration: BoxDecoration(
                  color: AppTheme.cardWhite,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: iconSize, color: iconColor),
                    SizedBox(height: gapLarge),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: compactHeight ? 16 : 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.navyColor,
                      ),
                    ),
                    SizedBox(height: gapSmall),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: compactHeight ? 12 : 13,
                        color: AppTheme.subtextColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RefreshButton extends StatefulWidget {
  const _RefreshButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_RefreshButton> createState() => _RefreshButtonState();
}

class _RefreshButtonState extends State<_RefreshButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _tap() {
    _ctrl.forward(from: 0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) => RotationTransition(
    turns: _ctrl,
    child: IconButton(
      icon: const Icon(Icons.refresh),
      tooltip: 'รีเฟรช',
      onPressed: _tap,
    ),
  );
}

class _Badge extends StatelessWidget {
  const _Badge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(
      color: AppTheme.primaryColor,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      '$count',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

class _StationTab {
  const _StationTab({
    required this.key,
    required this.label,
    required this.icon,
  });

  final String? key;
  final String label;
  final IconData icon;
}

class _QueueColumnSpec {
  const _QueueColumnSpec({
    required this.title,
    required this.count,
    required this.color,
    required this.softBackground,
    required this.items,
    this.overdueCount = 0,
  });

  final String title;
  final int count;
  final Color color;
  final Color softBackground;
  final List<KitchenQueueItemModel> items;
  final int overdueCount;
}

class _SummaryTotals {
  const _SummaryTotals({this.pending = 0, this.preparing = 0, this.ready = 0});

  final int pending;
  final int preparing;
  final int ready;
}
