import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/dashboard_provider.dart';
import '../../../sales/presentation/pages/sales_history_page.dart';
import '../../../products/presentation/pages/product_list_page.dart';
import '../../../customers/presentation/pages/customer_list_page.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/utils/responsive_utils.dart';
import '../../../../shared/widgets/escape_pop_scope.dart';

class DashboardPage extends ConsumerWidget {
  final VoidCallback? onGoToPos;
  final VoidCallback? onGoToProducts;
  final VoidCallback? onGoToCustomers;
  final VoidCallback? onGoToSalesHistory;
  final bool showBackButton;

  /// เปิดหน้ารายการขาย กรองเฉพาะวันนี้ (ใช้ตอนกด card ยอดขายวันนี้/ออเดอร์วันนี้)
  final VoidCallback? onGoToTodaySales;

  /// เปิดหน้ารายการขาย กรองเฉพาะเดือนนี้
  final VoidCallback? onGoToMonthSales;

  const DashboardPage({
    super.key,
    this.onGoToPos,
    this.onGoToProducts,
    this.onGoToCustomers,
    this.onGoToSalesHistory,
    this.onGoToTodaySales,
    this.onGoToMonthSales,
    this.showBackButton = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(dashboardProvider);

    return EscapePopScope(
      child: Scaffold(
        backgroundColor: AppTheme.surfaceColor,
        appBar: AppBar(
          automaticallyImplyLeading: showBackButton,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('แดชบอร์ด'),
              Text(
                'ภาพรวมระบบ',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.65),
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'รีเฟรช',
              onPressed: () => ref.read(dashboardProvider.notifier).refresh(),
            ),
          ],
        ),

        body: dashboardAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 72,
                  color: AppTheme.errorColor,
                ),
                const SizedBox(height: 16),
                Text('เกิดข้อผิดพลาด: $error'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () =>
                      ref.read(dashboardProvider.notifier).refresh(),
                  child: const Text('ลองใหม่'),
                ),
              ],
            ),
          ),
          data: (stats) => _DashboardBody(
            stats: stats,
            onGoToPos: onGoToPos,
            onGoToProducts: onGoToProducts,
            onGoToCustomers: onGoToCustomers,
            onGoToSalesHistory: onGoToSalesHistory,
            onGoToTodaySales: onGoToTodaySales,
            onGoToMonthSales: onGoToMonthSales,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Dashboard Body
// ─────────────────────────────────────────────────────────────────
class _DashboardBody extends StatelessWidget {
  final DashboardStats stats;
  final VoidCallback? onGoToPos;
  final VoidCallback? onGoToProducts;
  final VoidCallback? onGoToCustomers;
  final VoidCallback? onGoToSalesHistory;
  final VoidCallback? onGoToTodaySales;
  final VoidCallback? onGoToMonthSales;

  const _DashboardBody({
    required this.stats,
    this.onGoToPos,
    this.onGoToProducts,
    this.onGoToCustomers,
    this.onGoToSalesHistory,
    this.onGoToTodaySales,
    this.onGoToMonthSales,
  });

  @override
  Widget build(BuildContext context) {
    final padding = context.pagePadding;

    return SingleChildScrollView(
      padding: padding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stats cards อยู่บนสุดเสมอ
              _buildStatsGrid(context),
              SizedBox(height: context.isMobile ? 12 : 16),
              if (context.isTabletOrWider) ...[
                // Tablet + Desktop: เมนูด่วน + ภาพรวม แถวเดียวกัน (กว้างเท่ากัน)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _QuickActionsCard(
                        onGoToPos: onGoToPos,
                        onGoToProducts: onGoToProducts,
                        onGoToCustomers: onGoToCustomers,
                        onGoToSalesHistory: onGoToSalesHistory,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _TodayCard(
                        stats: stats,
                        onOpenAllSales: () => _openAllSales(context),
                        onOpenMonthSales: () => _openMonthSales(context),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                // Mobile: เมนูด่วน + ภาพรวม เรียงซ้อนกัน
                _QuickActionsCard(
                  onGoToPos: onGoToPos,
                  onGoToProducts: onGoToProducts,
                  onGoToCustomers: onGoToCustomers,
                  onGoToSalesHistory: onGoToSalesHistory,
                ),
                const SizedBox(height: 12),
                _TodayCard(
                  stats: stats,
                  onOpenAllSales: () => _openAllSales(context),
                  onOpenMonthSales: () => _openMonthSales(context),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  void _openAllSales(BuildContext context) {
    if (onGoToSalesHistory != null) {
      onGoToSalesHistory!();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SalesHistoryPage()),
    );
  }

  void _openTodaySales(BuildContext context) {
    if (onGoToTodaySales != null) {
      onGoToTodaySales!();
      return;
    }
    // fallback: push route (mobile หรือกรณีไม่มี callback)
    final today = DateTime.now();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SalesHistoryPage(
          initialDateFrom: DateTime(today.year, today.month, today.day),
          initialDateTo: DateTime(today.year, today.month, today.day),
        ),
      ),
    );
  }

  void _openSalesRange(
    BuildContext context, {
    required DateTime from,
    required DateTime to,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            SalesHistoryPage(initialDateFrom: from, initialDateTo: to),
      ),
    );
  }

  void _openMonthSales(BuildContext context) {
    if (onGoToMonthSales != null) {
      onGoToMonthSales!();
      return;
    }
    final today = DateTime.now();
    _openSalesRange(
      context,
      from: DateTime(today.year, today.month, 1),
      to: DateTime(today.year, today.month, today.day),
    );
  }

  // ── Stats Cards Grid ───────────────────────────────────────────
  Widget _buildStatsGrid(BuildContext context) {
    final cards = [
      _StatCardData(
        label: 'สินค้าทั้งหมด',
        value: NumberFormat('#,##0').format(stats.totalProducts),
        icon: Icons.inventory_2_outlined,
        iconBg: const Color(0xFFFFF3E0),
        iconColor: AppTheme.primaryColor,
        onTap:
            onGoToProducts ??
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProductListPage()),
            ),
      ),
      _StatCardData(
        label: 'ลูกค้าทั้งหมด',
        value: NumberFormat('#,##0').format(stats.totalCustomers),
        icon: Icons.people_outline,
        iconBg: const Color(0xFFE8F5E9),
        iconColor: AppTheme.successColor,
        onTap:
            onGoToCustomers ??
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CustomerListPage()),
            ),
      ),
      _StatCardData(
        label: 'ยอดขายวันนี้',
        value: '฿${NumberFormat('#,##0.00').format(stats.todaySales)}',
        icon: Icons.attach_money,
        iconBg: const Color(0xFFE3F2FD),
        iconColor: AppTheme.infoColor,
        onTap: () => _openTodaySales(context),
      ),
      _StatCardData(
        label: 'ออเดอร์วันนี้',
        value: NumberFormat('#,##0').format(stats.todayOrders),
        icon: Icons.shopping_cart_outlined,
        iconBg: const Color(0xFFFFEBEE),
        iconColor: AppTheme.errorColor,
        onTap: () => _openTodaySales(context),
      ),
    ];

    if (context.isTabletOrWider) {
      // Tablet + Desktop: 4 cards แถวเดียว กว้างเท่ากัน
      return Row(
        children: [
          for (int i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(width: 14),
            Expanded(child: _StatCard(data: cards[i], compact: true)),
          ],
        ],
      );
    }

    // Mobile: 2×2 grid
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _StatCard(data: cards[0])),
            const SizedBox(width: 10),
            Expanded(child: _StatCard(data: cards[1])),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _StatCard(data: cards[2])),
            const SizedBox(width: 10),
            Expanded(child: _StatCard(data: cards[3])),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Stat Card
// ─────────────────────────────────────────────────────────────────
class _StatCardData {
  final String label;
  final String value;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final VoidCallback? onTap;

  const _StatCardData({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    this.onTap,
  });
}

class _StatCard extends StatelessWidget {
  final _StatCardData data;
  final bool compact;
  const _StatCard({required this.data, this.compact = false});

  @override
  Widget build(BuildContext context) {
    // Icon size ตามหน้าจอ (compact = tablet/desktop แถวเดียว 4 cards)
    final iconBoxSize = (context.isMobile || compact) ? 38.0 : 46.0;
    final iconSize = (context.isMobile || compact) ? 18.0 : 22.0;
    final valueFontSize = (context.isMobile || compact) ? 18.0 : 24.0;
    final labelFontSize = (context.isMobile || compact) ? 11.0 : 12.0;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.borderColor),
      ),
      color: Colors.white,
      child: InkWell(
        onTap: data.onTap,
        borderRadius: BorderRadius.circular(12),
        hoverColor: data.iconColor.withValues(alpha: 0.04),
        child: Padding(
          padding: context.cardPadding,
          child: Row(
            children: [
              Container(
                width: iconBoxSize,
                height: iconBoxSize,
                decoration: BoxDecoration(
                  color: data.iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(data.icon, color: data.iconColor, size: iconSize),
              ),
              SizedBox(width: context.isMobile ? 10 : 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.value,
                      style: TextStyle(
                        fontSize: valueFontSize,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A1A1A),
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data.label,
                      style: TextStyle(
                        fontSize: labelFontSize,
                        color: AppTheme.subtextColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Today / Overview Card
// ─────────────────────────────────────────────────────────────────
class _TodayCard extends StatelessWidget {
  final DashboardStats stats;
  final VoidCallback onOpenAllSales;
  final VoidCallback onOpenMonthSales;

  const _TodayCard({
    required this.stats,
    required this.onOpenAllSales,
    required this.onOpenMonthSales,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.borderColor),
      ),
      color: Colors.white,
      child: Padding(
        padding: context.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardHeader(title: 'ภาพรวมทั้งหมด'),
            const SizedBox(height: 16),
            _OverviewRow(
              label: 'ยอดขายทั้งหมด',
              value: '฿${NumberFormat('#,##0.00').format(stats.totalSales)}',
              color: AppTheme.successColor,
              onTap: onOpenAllSales,
            ),
            const Divider(height: 18, color: AppTheme.borderColor),
            _OverviewRow(
              label: 'ออเดอร์ทั้งหมด',
              value: '${NumberFormat('#,##0').format(stats.totalOrders)} ออเดอร์',
              color: AppTheme.infoColor,
              onTap: onOpenAllSales,
            ),
            const Divider(height: 18, color: AppTheme.borderColor),
            _OverviewRow(
              label: 'ยอดขายเดือนนี้',
              value: '฿${NumberFormat('#,##0.00').format(stats.monthSales)}',
              color: AppTheme.primaryColor,
              onTap: onOpenMonthSales,
            ),
            const Divider(height: 18, color: AppTheme.borderColor),
            _OverviewRow(
              label: 'ออเดอร์เดือนนี้',
              value: '${NumberFormat('#,##0').format(stats.monthOrders)} ออเดอร์',
              color: AppTheme.warningColor,
              onTap: onOpenMonthSales,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Quick Actions Card
// ─────────────────────────────────────────────────────────────────
class _QuickActionsCard extends StatelessWidget {
  final VoidCallback? onGoToPos;
  final VoidCallback? onGoToProducts;
  final VoidCallback? onGoToCustomers;
  final VoidCallback? onGoToSalesHistory;

  const _QuickActionsCard({
    this.onGoToPos,
    this.onGoToProducts,
    this.onGoToCustomers,
    this.onGoToSalesHistory,
  });

  @override
  Widget build(BuildContext context) {
    final actions = [
      _QuickAction(
        icon: Icons.add_shopping_cart,
        label: 'เปิดจุดขาย',
        color: AppTheme.primaryColor,
        onTap: onGoToPos ?? () => Navigator.pushNamed(context, '/pos'),
      ),
      _QuickAction(
        icon: Icons.add_box_outlined,
        label: 'เพิ่มสินค้า',
        color: AppTheme.infoColor,
        onTap:
            onGoToProducts ??
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProductListPage()),
            ),
      ),
      _QuickAction(
        icon: Icons.person_add_outlined,
        label: 'เพิ่มลูกค้า',
        color: AppTheme.successColor,
        onTap:
            onGoToCustomers ??
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CustomerListPage()),
            ),
      ),
      _QuickAction(
        icon: Icons.receipt_long_outlined,
        label: 'รายการขาย',
        color: const Color(0xFFAD1457),
        onTap:
            onGoToSalesHistory ??
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SalesHistoryPage()),
            ),
      ),
    ];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.borderColor),
      ),
      color: Colors.white,
      child: Padding(
        padding: context.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardHeader(title: 'เมนูด่วน'),
            const SizedBox(height: 14),
            Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _QuickItemCard(action: actions[0])),
                    const SizedBox(width: 10),
                    Expanded(child: _QuickItemCard(action: actions[1])),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _QuickItemCard(action: actions[2])),
                    const SizedBox(width: 10),
                    Expanded(child: _QuickItemCard(action: actions[3])),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Shared sub-widgets
// ─────────────────────────────────────────────────────────────────
class _CardHeader extends StatelessWidget {
  final String title;
  const _CardHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: context.isMobile ? 13 : 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1A1A1A),
          ),
        ),
      ],
    );
  }
}

class _OverviewRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;

  const _OverviewRow({
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 340;

        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: stacked
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: context.isMobile ? 12 : 13,
                          color: AppTheme.subtextColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              value,
                              style: TextStyle(
                                fontSize: context.isMobile ? 12 : 14,
                                fontWeight: FontWeight.w600,
                                color: color,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.open_in_new_rounded,
                            size: context.isMobile ? 14 : 15,
                            color: AppTheme.subtextColor,
                          ),
                        ],
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: context.isMobile ? 12 : 13,
                            color: AppTheme.subtextColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: context.isMobile ? 12 : 14,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.open_in_new_rounded,
                        size: context.isMobile ? 14 : 15,
                        color: AppTheme.subtextColor,
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _QuickAction {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}

class _QuickItemCard extends StatelessWidget {
  final _QuickAction action;
  const _QuickItemCard({required this.action});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: context.isMobile ? 12 : 14,
            vertical: context.isMobile ? 10 : 12,
          ),
          decoration: BoxDecoration(
            color: action.color.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: action.color.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: action.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  action.icon,
                  size: context.isMobile ? 18 : 20,
                  color: action.color,
                ),
              ),
              SizedBox(width: context.isMobile ? 10 : 12),
              Expanded(
                child: Text(
                  action.label,
                  style: TextStyle(
                    fontSize: context.isMobile ? 12 : 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1A1A1A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 16,
                color: action.color.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
