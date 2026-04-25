import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/utils/responsive_utils.dart';
import '../providers/reservation_provider.dart';

const _kAnalyticsRefreshSeconds = 30;

// ─── Page ─────────────────────────────────────────────────────────────────────

class KitchenAnalyticsPage extends ConsumerStatefulWidget {
  const KitchenAnalyticsPage({super.key});

  @override
  ConsumerState<KitchenAnalyticsPage> createState() =>
      _KitchenAnalyticsPageState();
}

class _KitchenAnalyticsPageState extends ConsumerState<KitchenAnalyticsPage> {
  Timer? _countdownTimer;
  int _countdown = _kAnalyticsRefreshSeconds;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdown = _kAnalyticsRefreshSeconds;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _countdown--;
        if (_countdown <= 0) {
          _countdown = _kAnalyticsRefreshSeconds;
          unawaited(ref.read(kitchenAnalyticsProvider.notifier).refresh());
        }
      });
    });
  }

  void _refreshAll() {
    _startCountdown();
    unawaited(ref.read(kitchenAnalyticsProvider.notifier).refresh());
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final analyticsAsync = ref.watch(kitchenAnalyticsProvider);
    final analytics = analyticsAsync.asData?.value;
    final date = ref.watch(kitchenAnalyticsDateProvider);
    final fmt = DateFormat('d MMM yyyy', 'th');

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        title: const Text('Kitchen Analytics'),
        backgroundColor: AppTheme.navyColor,
        foregroundColor: Colors.white,
        actions: [
          _CountdownRefreshButton(
            countdown: _countdown,
            total: _kAnalyticsRefreshSeconds,
            onTap: _refreshAll,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _AnalyticsSummaryPanel(
              date: date,
              fmt: fmt,
              data: analytics,
              isLoading: analyticsAsync.isLoading && analytics == null,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: analyticsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => _AnalyticsMessageState(
                  icon: Icons.analytics_outlined,
                  title: 'โหลดข้อมูลไม่สำเร็จ',
                  message: '$e',
                  iconColor: AppTheme.errorColor,
                ),
                data: (data) => data == null
                    ? const _AnalyticsMessageState(
                        icon: Icons.bar_chart_outlined,
                        title: 'ไม่มีข้อมูลสำหรับวันนี้',
                        message: 'ยังไม่มีการบันทึกข้อมูลครัวสำหรับวันที่เลือก',
                        iconColor: AppTheme.subtextColor,
                      )
                    : _AnalyticsContent(data: data),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Summary Panel ───────────────────────────────────────────────────────────

class _AnalyticsSummaryPanel extends StatelessWidget {
  const _AnalyticsSummaryPanel({
    required this.date,
    required this.fmt,
    required this.data,
    required this.isLoading,
  });

  final DateTime date;
  final DateFormat fmt;
  final Map<String, dynamic>? data;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;
    final totalOrders = data?['total_orders'] as int? ?? 0;
    final totalItems = data?['total_items'] as int? ?? 0;
    final avgPrepMins =
        (data?['avg_prep_time_minutes'] as num?)?.toDouble() ?? 0;
    final avgOrderMins =
        (data?['avg_order_time_minutes'] as num?)?.toDouble() ?? 0;

    return Container(
      padding: EdgeInsets.all(isMobile ? 10 : 12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppTheme.borderColorOf(context)),
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
                  borderRadius: AppRadius.md,
                ),
                child: Icon(
                  Icons.insights_rounded,
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
                      'ภาพรวมครัว',
                      style: TextStyle(
                        fontSize: isMobile ? 14 : 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.navyColor,
                      ),
                    ),
                    if (!isMobile) ...[
                      const SizedBox(height: 2),
                      const Text(
                        'ติดตามปริมาณออเดอร์ เวลาเตรียม และเมนูที่ถูกสั่งบ่อย',
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
          _AnalyticsDatePanel(date: date, fmt: fmt),
          SizedBox(height: isMobile ? 8 : 10),
          if (isLoading)
            const LinearProgressIndicator(
              minHeight: 3,
              color: AppTheme.primaryColor,
              backgroundColor: AppTheme.primaryContainer,
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _StatCard(
                    label: 'ออเดอร์ทั้งหมด',
                    value: '$totalOrders',
                    icon: Icons.receipt_long,
                    color: AppTheme.primaryColor,
                    background: AppTheme.primaryContainer,
                    compact: true,
                  ),
                  const SizedBox(width: 8),
                  _StatCard(
                    label: 'รายการอาหาร',
                    value: '$totalItems',
                    icon: Icons.restaurant_menu,
                    color: AppTheme.infoColor,
                    background: AppTheme.infoContainer,
                    compact: true,
                  ),
                  const SizedBox(width: 8),
                  _StatCard(
                    label: 'เตรียมเฉลี่ย',
                    value: avgPrepMins > 0
                        ? '${avgPrepMins.toStringAsFixed(1)} น.'
                        : '-',
                    icon: Icons.timer_outlined,
                    color: AppTheme.warningColor,
                    background: AppTheme.warningContainer,
                    compact: true,
                  ),
                  const SizedBox(width: 8),
                  _StatCard(
                    label: 'ต่อออเดอร์',
                    value: avgOrderMins > 0
                        ? '${avgOrderMins.toStringAsFixed(1)} น.'
                        : '-',
                    icon: Icons.hourglass_bottom_outlined,
                    color: AppTheme.successColor,
                    background: AppTheme.successContainer,
                    compact: true,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Date Panel ───────────────────────────────────────────────────────────────

class _AnalyticsDatePanel extends ConsumerWidget {
  const _AnalyticsDatePanel({required this.date, required this.fmt});

  final DateTime date;
  final DateFormat fmt;

  bool get _isToday {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () =>
              ref.read(kitchenAnalyticsDateProvider.notifier).state = date
                  .subtract(const Duration(days: 1)),
          visualDensity: VisualDensity.compact,
        ),
        Expanded(
          child: InkWell(
            borderRadius: AppRadius.md,
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: date,
                firstDate: DateTime.now().subtract(const Duration(days: 90)),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                ref.read(kitchenAnalyticsDateProvider.notifier).state = picked;
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.surface3Of(context),
                borderRadius: AppRadius.md,
                border: Border.all(color: AppTheme.borderColorOf(context)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 16,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      fmt.format(date),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textColorOf(context),
                      ),
                    ),
                  ),
                  if (_isToday) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.12),
                        borderRadius: AppRadius.pill,
                      ),
                      child: const Text(
                        'วันนี้',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: _isToday
              ? null
              : () => ref.read(kitchenAnalyticsDateProvider.notifier).state =
                    date.add(const Duration(days: 1)),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}

// ─── Analytics Content ────────────────────────────────────────────────────────

class _AnalyticsContent extends StatelessWidget {
  const _AnalyticsContent({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final itemsByStation =
        (data['items_by_station'] as Map<String, dynamic>?) ?? {};
    final avgPrepByStation =
        (data['avg_prep_by_station'] as Map<String, dynamic>?) ?? {};
    final topItems =
        (data['top_items'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    if (itemsByStation.isEmpty && topItems.isEmpty) {
      return const _AnalyticsMessageState(
        icon: Icons.bar_chart_outlined,
        title: 'ยังไม่มีรายละเอียดครัว',
        message: 'เมื่อมีออเดอร์และรายการครัว ระบบจะแสดงสถิติตามสถานีและเมนู',
        iconColor: AppTheme.subtextColor,
      );
    }

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        if (itemsByStation.isNotEmpty) ...[
          _AnalyticsSectionPanel(
            title: 'ประสิทธิภาพตามสถานี',
            icon: Icons.kitchen_outlined,
            color: AppTheme.infoColor,
            background: AppTheme.infoContainer,
            trailing: '${itemsByStation.length} สถานี',
            child: Column(
              children: itemsByStation.entries.map((e) {
                final station = e.key;
                final count = (e.value as num?)?.toInt() ?? 0;
                final avgPrep =
                    (avgPrepByStation[station] as num?)?.toDouble() ?? 0;
                final maxCount = itemsByStation.values
                    .map((value) => (value as num?)?.toInt() ?? 0)
                    .reduce((a, b) => a > b ? a : b);
                return _StationRow(
                  station: station,
                  count: count,
                  avgPrep: avgPrep,
                  maxCount: maxCount,
                );
              }).toList(),
            ),
          ),
        ],

        if (topItems.isNotEmpty) ...[
          const SizedBox(height: 16),
          _AnalyticsSectionPanel(
            title: 'เมนูยอดนิยม',
            icon: Icons.star_outline_rounded,
            color: AppTheme.warningColor,
            background: AppTheme.warningContainer,
            trailing: '${topItems.length} เมนู',
            child: Column(
              children: topItems.asMap().entries.map((entry) {
                final i = entry.key;
                final item = entry.value;
                final name = item['product_name'] as String? ?? '';
                final count = (item['count'] as num?)?.toInt() ?? 0;
                final max = (topItems.first['count'] as num?)?.toInt() ?? 1;
                return _TopItemRow(
                  rank: i + 1,
                  name: name,
                  count: count,
                  maxCount: max,
                );
              }).toList(),
            ),
          ),
        ],

        const SizedBox(height: 24),
      ],
    );
  }
}

// ─── Section Panel (mirrors _QueueColumn header style) ────────────────────────

class _AnalyticsSectionPanel extends StatelessWidget {
  const _AnalyticsSectionPanel({
    required this.title,
    required this.icon,
    required this.color,
    required this.background,
    required this.child,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final Color color;
  final Color background;
  final Widget child;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppTheme.borderColorOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: background,
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
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: AppTheme.navyColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (trailing != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: AppRadius.pill,
                    ),
                    child: Text(
                      trailing!,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(12), child: child),
        ],
      ),
    );
  }
}

// ─── Stat Card ────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({
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
      width: compact ? 132 : null,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 14,
        vertical: compact ? 8 : 14,
      ),
      decoration: BoxDecoration(color: background, borderRadius: AppRadius.md),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 10 : 11,
                    color: AppTheme.subtextColor,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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

// ─── Station Row ──────────────────────────────────────────────────────────────

class _StationRow extends StatelessWidget {
  const _StationRow({
    required this.station,
    required this.count,
    required this.avgPrep,
    required this.maxCount,
  });

  final String station;
  final int count;
  final double avgPrep;
  final int maxCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.10),
                  borderRadius: AppRadius.sm,
                ),
                child: Text(
                  _stationLabel(station),
                  style: const TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '$count รายการ',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textColorOf(context),
                ),
              ),
              if (avgPrep > 0) ...[
                const SizedBox(width: 6),
                Text(
                  '• เฉลี่ย ${avgPrep.toStringAsFixed(1)}น.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.mutedTextOf(context),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: AppRadius.xs,
            child: LinearProgressIndicator(
              value: maxCount > 0 ? count / maxCount : 0,
              backgroundColor: AppTheme.surface3Of(context),
              valueColor: AlwaysStoppedAnimation(
                AppTheme.primaryColor.withValues(alpha: 0.7),
              ),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  String _stationLabel(String s) => switch (s) {
    'kitchen' => 'ครัว',
    'bar' => 'บาร์',
    'dessert' => 'ของหวาน',
    'grill' => 'ย่าง',
    _ => s,
  };
}

// ─── Top Item Row ─────────────────────────────────────────────────────────────

class _TopItemRow extends StatelessWidget {
  const _TopItemRow({
    required this.rank,
    required this.name,
    required this.count,
    required this.maxCount,
  });

  final int rank;
  final String name;
  final int count;
  final int maxCount;

  @override
  Widget build(BuildContext context) {
    final rankColors = [
      Colors.amber.shade600,
      Colors.grey.shade500,
      Colors.brown.shade400,
    ];
    final rankColor = rank <= 3
        ? rankColors[rank - 1]
        : AppTheme.mutedTextOf(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$rank',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: rankColor,
                fontSize: 15,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textColorOf(context),
                  ),
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: AppRadius.xs,
                  child: LinearProgressIndicator(
                    value: maxCount > 0 ? count / maxCount : 0,
                    backgroundColor: AppTheme.surface3Of(context),
                    valueColor: AlwaysStoppedAnimation(
                      rankColor.withValues(alpha: 0.65),
                    ),
                    minHeight: 5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$count',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppTheme.textColorOf(context),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Message State (mirrors _KdsMessageState) ─────────────────────────────────

class _AnalyticsMessageState extends StatelessWidget {
  const _AnalyticsMessageState({
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
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.cardColor(context),
              borderRadius: AppRadius.lg,
              border: Border.all(color: AppTheme.borderColorOf(context)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 56, color: iconColor),
                const SizedBox(height: 14),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textColorOf(context),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.mutedTextOf(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Countdown Refresh Button (mirrors KDS) ───────────────────────────────────

class _CountdownRefreshButton extends StatefulWidget {
  const _CountdownRefreshButton({
    required this.countdown,
    required this.total,
    required this.onTap,
  });

  final int countdown;
  final int total;
  final VoidCallback onTap;

  @override
  State<_CountdownRefreshButton> createState() =>
      _CountdownRefreshButtonState();
}

class _CountdownRefreshButtonState extends State<_CountdownRefreshButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _spinCtrl;

  @override
  void initState() {
    super.initState();
    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _spinCtrl.dispose();
    super.dispose();
  }

  void _tap() {
    _spinCtrl.forward(from: 0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.countdown / widget.total;
    final isUrgent = widget.countdown <= 5;

    return Tooltip(
      message: 'อัพเดทใน ${widget.countdown} วิ  (กดเพื่อรีเฟรชทันที)',
      child: InkWell(
        onTap: _tap,
        borderRadius: AppRadius.sm,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: RotationTransition(
                  turns: _spinCtrl,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 2.5,
                        backgroundColor: Colors.white24,
                        color: isUrgent ? Colors.orangeAccent : Colors.white,
                      ),
                      const Icon(Icons.refresh, size: 12, color: Colors.white),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${widget.countdown}s',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isUrgent ? Colors.orangeAccent : Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
