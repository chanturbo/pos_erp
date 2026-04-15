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

  /// Widget แสดงก่อนปุ่มเลขหน้า เช่น ปุ่ม PDF
  final Widget? trailing;

  const PaginationBar({
    super.key,
    required this.currentPage,
    required this.totalItems,
    required this.pageSize,
    required this.onPageChanged,
    this.trailing,
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

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final countText = Text(
      totalItems == 0
          ? 'ไม่มีรายการ'
          : 'แสดง $startItem–$endItem จาก $totalItems รายการ',
      style: TextStyle(
        fontSize: 12,
        color: isDark ? Colors.white60 : AppTheme.textSub,
      ),
    );

    final pageNav = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _NavButton(
          icon: Icons.chevron_left,
          enabled: currentPage > 1,
          onTap: () => onPageChanged(currentPage - 1),
        ),
        const SizedBox(width: 4),
        ...slots.map((slot) {
          if (slot == -1) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                '...',
                style: TextStyle(
                  color: isDark ? Colors.white38 : AppTheme.textSub,
                ),
              ),
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
        _NavButton(
          icon: Icons.chevron_right,
          enabled: currentPage < total,
          onTap: () => onPageChanged(currentPage + 1),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // แบ่ง 2 แถวเมื่อหน้าจอแคบและมี trailing widget
        final isNarrow = trailing != null && constraints.maxWidth < 560;

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: isNarrow ? 6 : 8,
          ),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.navyDark : AppTheme.headerBg,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(12),
              bottomRight: Radius.circular(12),
            ),
          ),
          child: isNarrow
              // ── หน้าจอแคบ: trailing บนสุด, pagination แถวล่าง ──
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [trailing!],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        countText,
                        const Spacer(),
                        pageNav,
                      ],
                    ),
                  ],
                )
              // ── หน้าจอกว้าง: แถวเดียว ──
              : Row(
                  children: [
                    Flexible(child: countText),
                    const SizedBox(width: 8),
                    const Spacer(),
                    if (trailing != null) ...[
                      trailing!,
                      const SizedBox(width: 8),
                    ],
                    pageNav,
                  ],
                ),
        );
      },
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = enabled
        ? (isDark
            ? Colors.white.withValues(alpha: 0.10)
            : Colors.white)
        : Colors.transparent;
    final borderColor = enabled
        ? (isDark
            ? Colors.white.withValues(alpha: 0.22)
            : AppTheme.border)
        : Colors.transparent;
    final iconColor = enabled
        ? (isDark ? Colors.white : Colors.black87)
        : (isDark ? Colors.white24 : AppTheme.textSub);

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: borderColor),
        ),
        child: Icon(icon, size: 16, color: iconColor),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isActive
        ? AppTheme.primary
        : (isDark ? Colors.white.withValues(alpha: 0.10) : Colors.white);
    final borderColor = isActive
        ? AppTheme.primary
        : (isDark ? Colors.white.withValues(alpha: 0.22) : AppTheme.border);
    final textColor = isActive
        ? Colors.white
        : (isDark ? Colors.white : Colors.black87);

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
            color: bgColor,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: borderColor),
          ),
          child: Text(
            '$page',
            style: TextStyle(
              fontSize: 12,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}
