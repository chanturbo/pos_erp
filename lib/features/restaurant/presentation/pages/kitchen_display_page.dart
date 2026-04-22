// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../data/models/kitchen_queue_model.dart';
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

  static const _stations = [
    _StationTab(key: null, label: 'ทั้งหมด', icon: Icons.grid_view),
    _StationTab(key: 'kitchen', label: 'ครัว', icon: Icons.restaurant),
    _StationTab(key: 'bar', label: 'บาร์', icon: Icons.local_bar),
    _StationTab(key: 'dessert', label: 'ของหวาน', icon: Icons.cake),
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
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        foregroundColor: Colors.white,
        title: const Text(
          'Kitchen Display',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          _RefreshButton(
            onTap: () {
              ref.read(kitchenQueueProvider.notifier).refresh();
              ref.read(kitchenSummaryProvider.notifier).refresh();
            },
          ),
          IconButton(
            icon: Icon(
              _isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
            ),
            tooltip: _isFullScreen ? 'ออกจาก Full Screen' : 'Full Screen',
            onPressed: _toggleFullScreen,
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryColor,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          isScrollable: false,
          tabs: _stations.map((s) {
            final sm = s.key != null ? summaryMap[s.key] : null;
            final active = sm?.totalActive;
            return Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(s.icon, size: 16),
                  const SizedBox(width: 6),
                  Text(s.label),
                  if (active != null && active > 0) ...[
                    const SizedBox(width: 6),
                    _Badge(count: active),
                  ],
                ],
              ),
            );
          }).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _stations
            .map((s) => _StationView(stationKey: s.key))
            .toList(),
      ),
    );
  }
}

// ── Station View ──────────────────────────────────────────────────────────────

class _StationView extends ConsumerWidget {
  final String? stationKey;
  const _StationView({required this.stationKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueAsync = ref.watch(kitchenQueueProvider);

    return queueAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: Colors.white)),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text('$e', style: const TextStyle(color: Colors.white70)),
          ],
        ),
      ),
      data: (items) {
        // filter by station
        final filtered = stationKey == null
            ? items
            : items
                  .where((i) => i.prepStation?.toLowerCase() == stationKey)
                  .toList();

        if (filtered.isEmpty) {
          return const _EmptyKitchen();
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

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (held.isNotEmpty)
              _Column(
                title: 'รอ Fire',
                count: held.length,
                color: Colors.blueGrey.shade700,
                items: held,
                overdueCount: held
                    .where(
                      (i) =>
                          DateTime.now().difference(i.createdAt).inMinutes >=
                          kHeldOverdueMinutes,
                    )
                    .length,
                onStatusChange: (id, s) => _updateStatus(context, ref, id, s),
                onFireCourse: (tableId, courseNo) =>
                    _fireCourse(context, ref, tableId, courseNo),
              ),
            _Column(
              title: 'รอทำ',
              count: pending.length,
              color: const Color(0xFF616161),
              items: pending,
              onStatusChange: (id, s) => _updateStatus(context, ref, id, s),
              onFireCourse: (tableId, courseNo) =>
                  _fireCourse(context, ref, tableId, courseNo),
            ),
            _Column(
              title: 'กำลังทำ',
              count: preparing.length,
              color: const Color(0xFF1565C0),
              items: preparing,
              onStatusChange: (id, s) => _updateStatus(context, ref, id, s),
              onFireCourse: (tableId, courseNo) =>
                  _fireCourse(context, ref, tableId, courseNo),
            ),
            _Column(
              title: 'พร้อมเสิร์ฟ',
              count: ready.length,
              color: AppTheme.successColor,
              items: ready,
              onStatusChange: (id, s) => _updateStatus(context, ref, id, s),
              onFireCourse: (tableId, courseNo) =>
                  _fireCourse(context, ref, tableId, courseNo),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateStatus(
    BuildContext context,
    WidgetRef ref,
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
    WidgetRef ref,
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

// ── Column ────────────────────────────────────────────────────────────────────

class _Column extends StatelessWidget {
  final String title;
  final int count;
  final Color color;
  final List<KitchenQueueItemModel> items;
  final int overdueCount;
  final void Function(String itemId, String newStatus) onStatusChange;
  final void Function(String tableId, int courseNo) onFireCourse;

  const _Column({
    required this.title,
    required this.count,
    required this.color,
    required this.items,
    this.overdueCount = 0,
    required this.onStatusChange,
    required this.onFireCourse,
  });

  @override
  Widget build(BuildContext context) {
    final groups = KitchenOrderGroup.groupItems(items);

    return Expanded(
      child: Column(
        children: [
          // Column header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            color: color.withValues(alpha: 0.85),
            child: Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      if (overdueCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.warningColor.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                size: 11,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '$overdueCount ค้าง',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Order groups
          Expanded(
            child: groups.isEmpty
                ? const Center(
                    child: Text(
                      '—',
                      style: TextStyle(color: Colors.white30, fontSize: 24),
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

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyKitchen extends StatelessWidget {
  const _EmptyKitchen();

  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.check_circle_outline, color: Colors.white24, size: 64),
        SizedBox(height: 16),
        Text(
          'ไม่มีรายการที่รอดำเนินการ',
          style: TextStyle(color: Colors.white38, fontSize: 16),
        ),
      ],
    ),
  );
}

// ── Refresh button ────────────────────────────────────────────────────────────

class _RefreshButton extends StatefulWidget {
  final VoidCallback onTap;
  const _RefreshButton({required this.onTap});

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

// ── Badge ─────────────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final int count;
  const _Badge({required this.count});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(
      color: AppTheme.errorColor,
      borderRadius: BorderRadius.circular(10),
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

// ── Data ──────────────────────────────────────────────────────────────────────

class _StationTab {
  final String? key;
  final String label;
  final IconData icon;
  const _StationTab({
    required this.key,
    required this.label,
    required this.icon,
  });
}
