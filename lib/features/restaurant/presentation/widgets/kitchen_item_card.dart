import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/models/kitchen_queue_model.dart';
import '../../../../shared/theme/app_theme.dart';

class KitchenItemCard extends StatelessWidget {
  final KitchenQueueItemModel item;
  final void Function(String newStatus) onStatusChange;

  const KitchenItemCard({
    super.key,
    required this.item,
    required this.onStatusChange,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _statusTheme(item.kitchenStatus);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.border, width: 1.5),
      ),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: colors.headerBg,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(
              children: [
                // Table name / Order no
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        item.tableId != null
                            ? Icons.table_restaurant
                            : Icons.receipt_long,
                        size: 15,
                        color: colors.headerText,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        item.tableName ?? item.orderNo,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: colors.headerText,
                        ),
                      ),
                      if (item.tableName != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          '#${item.orderNo}',
                          style: TextStyle(
                              fontSize: 11,
                              color: colors.headerText
                                  .withValues(alpha: 0.7)),
                        ),
                      ],
                    ],
                  ),
                ),
                // Wait time
                _WaitTimeBadge(createdAt: item.createdAt),
              ],
            ),
          ),

          // ── Body ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product name + qty
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item.productName,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: colors.border.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'x${_formatQty(item.quantity)} ${item.unit}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: colors.border,
                        ),
                      ),
                    ),
                  ],
                ),

                // Special instructions
                if (item.specialInstructions != null &&
                    item.specialInstructions!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.warningColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: AppTheme.warningColor.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 13, color: AppTheme.warningColor),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            item.specialInstructions!,
                            style: TextStyle(
                                fontSize: 12, color: AppTheme.warningColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Action buttons ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: _ActionRow(
                status: item.kitchenStatus, onStatusChange: onStatusChange),
          ),
        ],
      ),
    );
  }

  String _formatQty(double q) =>
      q == q.truncateToDouble() ? q.toInt().toString() : q.toString();

  _KdsTheme _statusTheme(String status) {
    switch (status) {
      case 'PREPARING':
        return _KdsTheme(
          headerBg: const Color(0xFF1565C0),
          headerText: Colors.white,
          border: const Color(0xFF1565C0),
        );
      case 'READY':
        return _KdsTheme(
          headerBg: AppTheme.successColor,
          headerText: Colors.white,
          border: AppTheme.successColor,
        );
      default: // PENDING
        return _KdsTheme(
          headerBg: const Color(0xFF424242),
          headerText: Colors.white,
          border: const Color(0xFF616161),
        );
    }
  }
}

class _KdsTheme {
  final Color headerBg;
  final Color headerText;
  final Color border;
  const _KdsTheme(
      {required this.headerBg,
      required this.headerText,
      required this.border});
}

class _WaitTimeBadge extends StatefulWidget {
  final DateTime createdAt;
  const _WaitTimeBadge({required this.createdAt});

  @override
  State<_WaitTimeBadge> createState() => _WaitTimeBadgeState();
}

class _WaitTimeBadgeState extends State<_WaitTimeBadge> {
  late Timer _timer;
  late Duration _wait;

  @override
  void initState() {
    super.initState();
    _wait = DateTime.now().difference(widget.createdAt);
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        setState(() {
          _wait = DateTime.now().difference(widget.createdAt);
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minutes = _wait.inMinutes;
    final color = minutes >= 15
        ? AppTheme.errorColor
        : minutes >= 8
            ? AppTheme.warningColor
            : Colors.white.withValues(alpha: 0.8);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.timer_outlined, size: 12, color: color),
          const SizedBox(width: 3),
          Text(
            _format(_wait),
            style: TextStyle(
                fontSize: 11, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  String _format(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    if (m == 0) return '${s}s';
    return '${m}m';
  }
}

class _ActionRow extends StatelessWidget {
  final String status;
  final void Function(String) onStatusChange;
  const _ActionRow({required this.status, required this.onStatusChange});

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      'PENDING' => Row(
          children: [
            Expanded(
              child: _ActionBtn(
                label: 'เริ่มทำ',
                icon: Icons.play_arrow,
                color: const Color(0xFF1565C0),
                onTap: () => onStatusChange('PREPARING'),
              ),
            ),
          ],
        ),
      'PREPARING' => Row(
          children: [
            Expanded(
              child: _ActionBtn(
                label: 'ย้อนกลับ',
                icon: Icons.undo,
                color: Colors.grey.shade600,
                onTap: () => onStatusChange('PENDING'),
                outlined: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: _ActionBtn(
                label: 'พร้อมเสิร์ฟ',
                icon: Icons.check,
                color: AppTheme.successColor,
                onTap: () => onStatusChange('READY'),
              ),
            ),
          ],
        ),
      'READY' => Row(
          children: [
            Expanded(
              child: _ActionBtn(
                label: 'เสิร์ฟแล้ว',
                icon: Icons.done_all,
                color: AppTheme.primaryColor,
                onTap: () => onStatusChange('SERVED'),
              ),
            ),
          ],
        ),
      _ => const SizedBox.shrink(),
    };
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool outlined;

  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) => outlined
      ? OutlinedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 16),
          label: Text(label),
          style: OutlinedButton.styleFrom(
            foregroundColor: color,
            side: BorderSide(color: color),
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          ),
        )
      : FilledButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 16),
          label: Text(label),
          style: FilledButton.styleFrom(
            backgroundColor: color,
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          ),
        );
}
