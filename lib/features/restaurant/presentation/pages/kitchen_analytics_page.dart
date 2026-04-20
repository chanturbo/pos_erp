import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../shared/theme/app_theme.dart';
import '../providers/reservation_provider.dart';

class KitchenAnalyticsPage extends ConsumerWidget {
  const KitchenAnalyticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsAsync = ref.watch(kitchenAnalyticsProvider);
    final date = ref.watch(kitchenAnalyticsDateProvider);
    final fmt = DateFormat('d MMM yyyy', 'th');

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        title: const Text('Kitchen Analytics'),
        backgroundColor: AppTheme.navyColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(kitchenAnalyticsProvider.notifier).refresh(),
          ),
        ],
      ),
      body: Column(
        children: [
          _DateBar(date: date, fmt: fmt),
          Expanded(
            child: analyticsAsync.when(
              data: (data) => data == null
                  ? const Center(child: Text('ไม่มีข้อมูล'))
                  : _AnalyticsBody(data: data),
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Text('เกิดข้อผิดพลาด: $e')),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Date Picker Bar ───────────────────────────────────────────────────────────

class _DateBar extends ConsumerWidget {
  final DateTime date;
  final DateFormat fmt;
  const _DateBar({required this.date, required this.fmt});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
        color: Colors.white,
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => ref
                .read(kitchenAnalyticsDateProvider.notifier)
                .state = date.subtract(const Duration(days: 1)),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: date,
                  firstDate: DateTime.now()
                      .subtract(const Duration(days: 90)),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  ref
                      .read(kitchenAnalyticsDateProvider.notifier)
                      .state = picked;
                }
              },
              child: Text(
                fmt.format(date),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: date.day == DateTime.now().day &&
                    date.month == DateTime.now().month
                ? null
                : () => ref
                    .read(kitchenAnalyticsDateProvider.notifier)
                    .state = date.add(const Duration(days: 1)),
          ),
        ]),
      );
}

// ── Analytics Body ────────────────────────────────────────────────────────────

class _AnalyticsBody extends StatelessWidget {
  final Map<String, dynamic> data;
  const _AnalyticsBody({required this.data});

  @override
  Widget build(BuildContext context) {
    final totalOrders = data['total_orders'] as int? ?? 0;
    final totalItems = data['total_items'] as int? ?? 0;
    final avgPrepMins =
        (data['avg_prep_time_minutes'] as num?)?.toDouble() ?? 0;
    final avgOrderMins =
        (data['avg_order_time_minutes'] as num?)?.toDouble() ?? 0;
    final itemsByStation =
        (data['items_by_station'] as Map<String, dynamic>?) ?? {};
    final avgPrepByStation =
        (data['avg_prep_by_station'] as Map<String, dynamic>?) ?? {};
    final topItems =
        (data['top_items'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Summary cards ──
        Row(children: [
          Expanded(
              child: _StatCard(
                  label: 'ออเดอร์ทั้งหมด',
                  value: '$totalOrders',
                  icon: Icons.receipt_long,
                  color: AppTheme.primaryColor)),
          const SizedBox(width: 12),
          Expanded(
              child: _StatCard(
                  label: 'รายการอาหาร',
                  value: '$totalItems',
                  icon: Icons.restaurant_menu,
                  color: Colors.teal)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
              child: _StatCard(
                  label: 'เวลาเตรียมเฉลี่ย',
                  value: avgPrepMins > 0
                      ? '${avgPrepMins.toStringAsFixed(1)} น.'
                      : '-',
                  icon: Icons.timer,
                  color: Colors.orange)),
          const SizedBox(width: 12),
          Expanded(
              child: _StatCard(
                  label: 'เวลาต่อออเดอร์เฉลี่ย',
                  value: avgOrderMins > 0
                      ? '${avgOrderMins.toStringAsFixed(1)} น.'
                      : '-',
                  icon: Icons.hourglass_bottom,
                  color: Colors.purple)),
        ]),

        if (itemsByStation.isNotEmpty) ...[
          const SizedBox(height: 20),
          _SectionTitle(title: 'รายการตามสถานี'),
          const SizedBox(height: 8),
          ...itemsByStation.entries.map((e) {
            final station = e.key;
            final count = e.value as int;
            final avgPrep = (avgPrepByStation[station] as num?)
                    ?.toDouble() ??
                0;
            return _StationRow(
              station: station,
              count: count,
              avgPrep: avgPrep,
              maxCount:
                  itemsByStation.values.cast<int>().reduce((a, b) =>
                      a > b ? a : b),
            );
          }),
        ],

        if (topItems.isNotEmpty) ...[
          const SizedBox(height: 20),
          _SectionTitle(title: 'เมนูยอดนิยม'),
          const SizedBox(height: 8),
          ...topItems.asMap().entries.map((entry) {
            final i = entry.key;
            final item = entry.value;
            final name = item['product_name'] as String? ?? '';
            final count = item['count'] as int? ?? 0;
            final max = (topItems.first['count'] as int? ?? 1);
            return _TopItemRow(
                rank: i + 1, name: name, count: count, maxCount: max);
          }),
        ],

        const SizedBox(height: 24),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) => Card(
        elevation: 1,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(value,
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: color)),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade600)),
            ],
          ),
        ),
      );
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) => Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      );
}

class _StationRow extends StatelessWidget {
  final String station;
  final int count;
  final double avgPrep;
  final int maxCount;
  const _StationRow(
      {required this.station,
      required this.count,
      required this.avgPrep,
      required this.maxCount});

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 8),
        color: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: Colors.grey.shade200)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color:
                        AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _stationLabel(station),
                    style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 13),
                  ),
                ),
                const Spacer(),
                Text('$count รายการ',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                if (avgPrep > 0)
                  Text(
                    '  •  เฉลี่ย ${avgPrep.toStringAsFixed(1)}น.',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600),
                  ),
              ]),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: maxCount > 0 ? count / maxCount : 0,
                  backgroundColor: Colors.grey.shade100,
                  valueColor: AlwaysStoppedAnimation(
                      AppTheme.primaryColor.withValues(alpha: 0.7)),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
      );

  String _stationLabel(String s) => switch (s) {
        'kitchen' => 'ครัว',
        'bar' => 'บาร์',
        'dessert' => 'ของหวาน',
        'grill' => 'ย่าง',
        _ => s,
      };
}

class _TopItemRow extends StatelessWidget {
  final int rank;
  final String name;
  final int count;
  final int maxCount;
  const _TopItemRow(
      {required this.rank,
      required this.name,
      required this.count,
      required this.maxCount});

  @override
  Widget build(BuildContext context) {
    final rankColors = [
      Colors.amber.shade600,
      Colors.grey.shade500,
      Colors.brown.shade400,
    ];
    final rankColor =
        rank <= 3 ? rankColors[rank - 1] : Colors.grey.shade400;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        SizedBox(
          width: 28,
          child: Text(
            '$rank',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: rankColor,
                fontSize: 15),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: const TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: maxCount > 0 ? count / maxCount : 0,
                  backgroundColor: Colors.grey.shade100,
                  valueColor:
                      AlwaysStoppedAnimation(rankColor.withValues(alpha: 0.7)),
                  minHeight: 5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text('$count',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700)),
      ]),
    );
  }
}
