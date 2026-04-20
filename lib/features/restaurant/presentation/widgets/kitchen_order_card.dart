import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/models/kitchen_queue_model.dart';
import '../../../../shared/theme/app_theme.dart';

class KitchenOrderCard extends StatelessWidget {
  final KitchenOrderGroup group;
  final void Function(String itemId, String newStatus) onStatusChange;
  final void Function(String tableId, int courseNo) onFireCourse;

  const KitchenOrderCard({
    super.key,
    required this.group,
    required this.onStatusChange,
    required this.onFireCourse,
  });

  @override
  Widget build(BuildContext context) {
    // สีหัว card ตาม status ที่ urgent ที่สุด
    final headerTheme = _groupTheme(group.items);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: headerTheme.border, width: 1.5),
      ),
      elevation: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: headerTheme.headerBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(
              children: [
                Icon(
                  group.tableId != null
                      ? Icons.table_restaurant
                      : Icons.receipt_long,
                  size: 15,
                  color: Colors.white,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    group.tableName ?? group.orderNo,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (group.tableName != null)
                  Text(
                    '#${group.orderNo}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                const SizedBox(width: 8),
                _OrderWaitBadge(createdAt: group.createdAt),
              ],
            ),
          ),

          // ── Items ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: group.items
                  .map((item) => _ItemRow(
                        item: item,
                        onStatusChange: (s) =>
                            onStatusChange(item.itemId, s),
                        onFireCourse: () {
                          final tableId = item.tableId;
                          if (tableId == null || tableId.isEmpty) return;
                          onFireCourse(tableId, item.courseNo);
                        },
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  _KdsTheme _groupTheme(List<KitchenQueueItemModel> items) {
    // ลำดับความสำคัญ: PENDING > PREPARING > READY > HELD
    if (items.any((i) => i.kitchenStatus == 'PENDING')) {
      return _KdsTheme(
        headerBg: const Color(0xFF424242),
        border: const Color(0xFF616161),
      );
    }
    if (items.any((i) => i.kitchenStatus == 'PREPARING')) {
      return _KdsTheme(
        headerBg: const Color(0xFF1565C0),
        border: const Color(0xFF1565C0),
      );
    }
    if (items.any((i) => i.kitchenStatus == 'HELD')) {
      return _KdsTheme(
        headerBg: Colors.blueGrey.shade600,
        border: Colors.blueGrey.shade400,
      );
    }
    return _KdsTheme(
      headerBg: AppTheme.successColor,
      border: AppTheme.successColor,
    );
  }
}

// ── Single item row inside the order card ────────────────────────────────────

class _ItemRow extends StatelessWidget {
  final KitchenQueueItemModel item;
  final void Function(String newStatus) onStatusChange;
  final VoidCallback onFireCourse;

  const _ItemRow({
    required this.item,
    required this.onStatusChange,
    required this.onFireCourse,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(item.kitchenStatus);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status dot
              Padding(
                padding: const EdgeInsets.only(top: 3, right: 8),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              // Product name
              Expanded(
                child: Text(
                  item.productName,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              // Course badge (only if course > 1 or HELD)
              if (item.courseNo > 1 || item.isHeld) ...[
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade300),
                  ),
                  child: Text(
                    item.isHeld ? 'C${item.courseNo} HOLD' : 'C${item.courseNo}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
              ],
              // Qty badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'x${_fmtQty(item.quantity)} ${item.unit}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          // Special instructions
          if (item.specialInstructions != null &&
              item.specialInstructions!.isNotEmpty) ...[
            const SizedBox(height: 3),
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 12, color: AppTheme.warningColor),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      item.specialInstructions!,
                      style: TextStyle(
                          fontSize: 11, color: AppTheme.warningColor),
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Action buttons
          _ActionButtons(
            status: item.kitchenStatus,
            onStatusChange: onStatusChange,
            onFireCourse: onFireCourse,
          ),
          const Divider(height: 12, thickness: 0.5),
        ],
      ),
    );
  }

  Color _statusColor(String status) => switch (status) {
        'PREPARING' => const Color(0xFF1565C0),
        'READY' => AppTheme.successColor,
        'HELD' => Colors.blueGrey,
        'CANCELLED' => AppTheme.errorColor,
        _ => const Color(0xFF757575),
      };

  String _fmtQty(double q) =>
      q == q.truncateToDouble() ? q.toInt().toString() : q.toString();
}

// ── Compact action buttons ────────────────────────────────────────────────────

class _ActionButtons extends StatelessWidget {
  final String status;
  final void Function(String) onStatusChange;
  final VoidCallback onFireCourse;
  const _ActionButtons({
    required this.status,
    required this.onStatusChange,
    required this.onFireCourse,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 14),
      child: switch (status) {
        'HELD' => _outlineBtn('รอ fire', Icons.pause_circle_outline,
            Colors.blueGrey, onFireCourse),
        'PENDING' => _btn('เริ่มทำ', Icons.play_arrow,
            const Color(0xFF1565C0), () => onStatusChange('PREPARING')),
        'PREPARING' => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _outlineBtn('ย้อนกลับ', Icons.undo, Colors.grey.shade600,
                  () => onStatusChange('PENDING')),
              const SizedBox(width: 8),
              _btn('พร้อมเสิร์ฟ', Icons.check, AppTheme.successColor,
                  () => onStatusChange('READY')),
            ],
          ),
        'READY' => _btn('เสิร์ฟแล้ว', Icons.done_all, AppTheme.primaryColor,
            () => onStatusChange('SERVED')),
        _ => const SizedBox.shrink(),
      },
    );
  }

  Widget _btn(String label, IconData icon, Color color, VoidCallback onTap) =>
      FilledButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 14),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        style: FilledButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      );

  Widget _outlineBtn(
          String label, IconData icon, Color color, VoidCallback onTap) =>
      OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 14),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      );
}

// ── Wait badge สำหรับ order ──────────────────────────────────────────────────

class _OrderWaitBadge extends StatefulWidget {
  final DateTime createdAt;
  const _OrderWaitBadge({required this.createdAt});

  @override
  State<_OrderWaitBadge> createState() => _OrderWaitBadgeState();
}

class _OrderWaitBadgeState extends State<_OrderWaitBadge> {
  late Timer _timer;
  late Duration _wait;

  @override
  void initState() {
    super.initState();
    _wait = DateTime.now().difference(widget.createdAt);
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _wait = DateTime.now().difference(widget.createdAt));
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = _wait.inMinutes;
    final color = m >= 15
        ? AppTheme.errorColor
        : m >= 8
            ? AppTheme.warningColor
            : Colors.white.withValues(alpha: 0.8);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.timer_outlined, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            m == 0 ? '${_wait.inSeconds}s' : '${m}m',
            style: TextStyle(
                fontSize: 11, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _KdsTheme {
  final Color headerBg;
  final Color border;
  const _KdsTheme({required this.headerBg, required this.border});
}
