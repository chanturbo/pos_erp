import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../shared/theme/app_theme.dart';
import '../providers/reservation_provider.dart';

class TableTimelinePage extends ConsumerWidget {
  final String tableId;
  final String? tableName;

  const TableTimelinePage({
    super.key,
    required this.tableId,
    this.tableName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timelineAsync = ref.watch(tableTimelineProvider(tableId));

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        title: Text('Timeline — ${tableName ?? tableId}'),
        backgroundColor: AppTheme.navyColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.invalidate(tableTimelineProvider(tableId)),
          ),
        ],
      ),
      body: timelineAsync.when(
        data: (data) => data == null
            ? const Center(child: Text('ไม่พบข้อมูล session'))
            : _TimelineBody(data: data),
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline,
                  size: 48, color: AppTheme.errorColor),
              const SizedBox(height: 12),
              Text('ไม่พบ session ที่เปิดอยู่',
                  style: TextStyle(color: Colors.grey.shade600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimelineBody extends StatelessWidget {
  final Map<String, dynamic> data;
  const _TimelineBody({required this.data});

  @override
  Widget build(BuildContext context) {
    final events = (data['events'] as List?) ?? [];
    final openedAt = DateTime.tryParse(data['opened_at'] as String? ?? '');
    final duration = openedAt != null
        ? DateTime.now().difference(openedAt)
        : Duration.zero;

    return Column(
      children: [
        _SessionHeader(data: data, duration: duration),
        Expanded(
          child: events.isEmpty
              ? Center(
                  child: Text('ยังไม่มีกิจกรรม',
                      style: TextStyle(color: Colors.grey.shade500)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: events.length,
                  itemBuilder: (_, i) => _TimelineItem(
                    event: events[i] as Map<String, dynamic>,
                    isLast: i == events.length - 1,
                  ),
                ),
        ),
      ],
    );
  }
}

class _SessionHeader extends StatelessWidget {
  final Map<String, dynamic> data;
  final Duration duration;
  const _SessionHeader({required this.data, required this.duration});

  @override
  Widget build(BuildContext context) {
    final waiterName = data['waiter_name'] as String?;
    final guestCount = data['guest_count'] as int? ?? 0;
    final status = data['status'] as String? ?? '';
    final fmt = DateFormat('HH:mm');
    final openedAt =
        DateTime.tryParse(data['opened_at'] as String? ?? '');

    final mins = duration.inMinutes;
    final durationStr =
        mins >= 60 ? '${mins ~/ 60}ชม. ${mins % 60}น.' : '$mins น.';

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  _StatusDot(status: status),
                  const SizedBox(width: 8),
                  Text(
                    _statusLabel(status),
                    style: TextStyle(
                        fontSize: 12,
                        color: _statusColor(status),
                        fontWeight: FontWeight.w600),
                  ),
                ]),
                const SizedBox(height: 4),
                Text(
                  openedAt != null
                      ? 'เปิด ${fmt.format(openedAt)} ($durationStr)'
                      : '-',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
                if (waiterName != null)
                  Text('พนักงาน: $waiterName',
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey.shade600)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Icon(Icons.group, size: 16, color: Colors.grey),
              Text('$guestCount คน',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  String _statusLabel(String s) => switch (s) {
        'OPEN' => 'เปิดอยู่',
        'BILLED' => 'รอชำระเงิน',
        'CLOSED' => 'ปิดแล้ว',
        _ => s,
      };

  Color _statusColor(String s) => switch (s) {
        'OPEN' => AppTheme.successColor,
        'BILLED' => Colors.orange,
        'CLOSED' => Colors.grey,
        _ => Colors.grey,
      };
}

class _StatusDot extends StatelessWidget {
  final String status;
  const _StatusDot({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'OPEN' => AppTheme.successColor,
      'BILLED' => Colors.orange,
      _ => Colors.grey,
    };
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final Map<String, dynamic> event;
  final bool isLast;
  const _TimelineItem({required this.event, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final type = event['type'] as String? ?? '';
    final desc = event['description'] as String? ?? '';
    final ts = DateTime.tryParse(event['timestamp'] as String? ?? '');
    final timeFmt = DateFormat('HH:mm');
    final info = _typeInfo(type);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 48,
            child: Column(children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: info.$1.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(info.$2, size: 16, color: info.$1),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: Colors.grey.shade200,
                  ),
                ),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(desc,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500)),
                      ),
                      if (ts != null)
                        Text(
                          timeFmt.format(ts),
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500),
                        ),
                    ],
                  ),
                  if (type == 'order') _OrderDetail(event: event),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  (Color, IconData) _typeInfo(String type) => switch (type) {
        'opened' => (AppTheme.successColor, Icons.door_front_door),
        'order' => (AppTheme.primaryColor, Icons.receipt_long),
        'item_status' => (Colors.teal, Icons.restaurant),
        'merge_in' => (Colors.indigo, Icons.merge_type),
        'merge_out' => (Colors.deepOrange, Icons.merge_type),
        'waiter' => (Colors.purple, Icons.badge),
        'billed' => (Colors.orange, Icons.receipt),
        'closed' => (Colors.grey, Icons.door_back_door),
        _ => (Colors.grey, Icons.circle),
      };
}

class _OrderDetail extends StatelessWidget {
  final Map<String, dynamic> event;
  const _OrderDetail({required this.event});

  @override
  Widget build(BuildContext context) {
    final data = event['data'] as Map<String, dynamic>? ?? {};
    final items = (data['items'] as List?) ?? [];
    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items
            .map((item) {
              final i = item as Map<String, dynamic>;
              final name = i['name'] as String? ?? '';
              final qty = i['qty'] ?? 1;
              final course = i['course_no'] as int? ?? 1;
              final kStatus = i['kitchen_status'] as String? ?? '';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(children: [
                  Text('$qty×',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(name,
                        style: const TextStyle(fontSize: 12)),
                  ),
                  if (course > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('คอร์ส $course',
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.blue.shade700)),
                    ),
                  const SizedBox(width: 4),
                  _KitchenStatusDot(status: kStatus),
                ]),
              );
            })
            .toList(),
      ),
    );
  }
}

class _KitchenStatusDot extends StatelessWidget {
  final String status;
  const _KitchenStatusDot({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'PENDING' => Colors.orange,
      'PREPARING' => Colors.blue,
      'READY' => AppTheme.successColor,
      'SERVED' => Colors.grey,
      'CANCELLED' => AppTheme.errorColor,
      _ => Colors.grey,
    };
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
