import 'package:flutter/material.dart';
import '../../data/models/dining_table_model.dart';
import '../../../../shared/theme/app_theme.dart';

class TableCard extends StatelessWidget {
  final DiningTableModel table;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const TableCard({
    super.key,
    required this.table,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _statusColors(table.status);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: colors.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: colors.border.withValues(alpha:0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header: table no + status icon ──
              Row(
                children: [
                  Expanded(
                    child: Text(
                      table.displayName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: colors.text,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _StatusDot(color: colors.dot),
                ],
              ),
              const SizedBox(height: 4),

              // ── Zone name ──
              if (table.zoneName != null)
                Text(
                  table.zoneName!,
                  style: TextStyle(fontSize: 11, color: colors.text.withValues(alpha:0.6)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

              const Spacer(),

              // ── Bottom info ──
              if (table.isOccupied) ...[
                if (table.activeGuestCount != null)
                  _InfoRow(
                    icon: Icons.people_outline,
                    label: '${table.activeGuestCount} คน',
                    color: colors.text,
                  ),
                if (table.sessionOpenedAt != null)
                  _InfoRow(
                    icon: Icons.timer_outlined,
                    label: _formatDuration(
                        DateTime.now().difference(table.sessionOpenedAt!)),
                    color: colors.text,
                  ),
              ] else ...[
                _InfoRow(
                  icon: Icons.chair_outlined,
                  label: '${table.capacity} ที่นั่ง',
                  color: colors.text.withValues(alpha:0.7),
                ),
              ],

              const SizedBox(height: 6),

              // ── Status badge ──
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.badge,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _statusLabel(table.status),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: colors.badgeText,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h > 0) return '$h ชม. $m นาที';
    return '$m นาที';
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'OCCUPIED':
        return 'มีลูกค้า';
      case 'RESERVED':
        return 'จองแล้ว';
      case 'CLEANING':
        return 'กำลังเก็บ';
      case 'DISABLED':
        return 'ปิดใช้งาน';
      default:
        return 'ว่าง';
    }
  }

  _TableColors _statusColors(String status) {
    switch (status) {
      case 'OCCUPIED':
        return _TableColors(
          bg: const Color(0xFFFFF3E0),
          border: const Color(0xFFFF9800),
          dot: const Color(0xFFFF9800),
          text: const Color(0xFF5D4037),
          badge: const Color(0xFFFF9800),
          badgeText: Colors.white,
        );
      case 'RESERVED':
        return _TableColors(
          bg: const Color(0xFFE3F2FD),
          border: AppTheme.infoColor,
          dot: AppTheme.infoColor,
          text: const Color(0xFF1A237E),
          badge: AppTheme.infoColor,
          badgeText: Colors.white,
        );
      case 'CLEANING':
        return _TableColors(
          bg: const Color(0xFFFFFDE7),
          border: AppTheme.warningColor,
          dot: AppTheme.warningColor,
          text: const Color(0xFF5D4037),
          badge: AppTheme.warningColor,
          badgeText: Colors.white,
        );
      case 'DISABLED':
        return _TableColors(
          bg: const Color(0xFFF5F5F5),
          border: Colors.grey.shade400,
          dot: Colors.grey.shade400,
          text: Colors.grey.shade600,
          badge: Colors.grey.shade400,
          badgeText: Colors.white,
        );
      default: // AVAILABLE
        return _TableColors(
          bg: const Color(0xFFE8F5E9),
          border: AppTheme.successColor,
          dot: AppTheme.successColor,
          text: const Color(0xFF1B5E20),
          badge: AppTheme.successColor,
          badgeText: Colors.white,
        );
    }
  }
}

class _TableColors {
  final Color bg;
  final Color border;
  final Color dot;
  final Color text;
  final Color badge;
  final Color badgeText;
  const _TableColors({
    required this.bg,
    required this.border,
    required this.dot,
    required this.text,
    required this.badge,
    required this.badgeText,
  });
}

class _StatusDot extends StatelessWidget {
  final Color color;
  const _StatusDot({required this.color});

  @override
  Widget build(BuildContext context) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoRow({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: color)),
        ],
      );
}
