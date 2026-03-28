import 'package:flutter/material.dart';
import 'package:pos_erp/shared/theme/app_theme.dart';

/// Reusable page-number pagination bar.
///
/// Usage:
/// ```dart
/// PaginationBar(
///   currentPage: _currentPage,
///   totalItems: filtered.length,
///   pageSize: _pageSize,
///   onPageChanged: (p) => setState(() => _currentPage = p),
/// )
/// ```
class PaginationBar extends StatelessWidget {
  final int currentPage;   // 1-based
  final int totalItems;
  final int pageSize;
  final ValueChanged<int> onPageChanged;

  const PaginationBar({
    super.key,
    required this.currentPage,
    required this.totalItems,
    required this.pageSize,
    required this.onPageChanged,
  });

  int get _totalPages => totalItems == 0 ? 1 : (totalItems / pageSize).ceil();

  /// Returns the list of "slots" to display:
  /// an int = page number, -1 = ellipsis
  List<int> _buildSlots() {
    final total = _totalPages;
    if (total <= 7) return List.generate(total, (i) => i + 1);

    final slots = <int>[];
    // Always show first
    slots.add(1);

    if (currentPage > 3) slots.add(-1); // left ellipsis

    final start = (currentPage - 1).clamp(2, total - 1);
    final end   = (currentPage + 1).clamp(2, total - 1);
    for (int p = start; p <= end; p++) {
      slots.add(p);
    }

    if (currentPage < total - 2) slots.add(-1); // right ellipsis

    // Always show last
    slots.add(total);
    return slots;
  }

  @override
  Widget build(BuildContext context) {
    final total = _totalPages;
    final slots = _buildSlots();

    final startItem = totalItems == 0 ? 0 : (currentPage - 1) * pageSize + 1;
    final endItem   = (currentPage * pageSize).clamp(0, totalItems);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: AppTheme.headerBg,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          // Item count text
          Text(
            totalItems == 0
                ? 'ไม่มีรายการ'
                : 'แสดง $startItem–$endItem จาก $totalItems รายการ',
            style: const TextStyle(fontSize: 12, color: AppTheme.textSub),
          ),
          const Spacer(),
          // Prev button
          _NavButton(
            icon: Icons.chevron_left,
            enabled: currentPage > 1,
            onTap: () => onPageChanged(currentPage - 1),
          ),
          const SizedBox(width: 4),
          // Page buttons
          ...slots.map((slot) {
            if (slot == -1) {
              return const Padding(
                padding: EdgeInsets.symmetric(horizontal: 2),
                child: Text('...', style: TextStyle(color: AppTheme.textSub)),
              );
            }
            final isActive = slot == currentPage;
            return _PageButton(
              page: slot,
              isActive: isActive,
              onTap: () => onPageChanged(slot),
            );
          }),
          const SizedBox(width: 4),
          // Next button
          _NavButton(
            icon: Icons.chevron_right,
            enabled: currentPage < total,
            onTap: () => onPageChanged(currentPage + 1),
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _NavButton({required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: enabled ? AppTheme.border : Colors.transparent,
          ),
        ),
        child: Icon(
          icon,
          size: 16,
          color: enabled ? Colors.black87 : AppTheme.textSub,
        ),
      ),
    );
  }
}

class _PageButton extends StatelessWidget {
  final int page;
  final bool isActive;
  final VoidCallback onTap;

  const _PageButton({required this.page, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          constraints: const BoxConstraints(minWidth: 28),
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive ? AppTheme.primary : Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isActive ? AppTheme.primary : AppTheme.border,
            ),
          ),
          child: Text(
            '$page',
            style: TextStyle(
              fontSize: 12,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              color: isActive ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }
}
