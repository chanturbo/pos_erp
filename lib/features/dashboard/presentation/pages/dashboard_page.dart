import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/dashboard_provider.dart';
import '../../../sales/presentation/pages/sales_history_page.dart';
import '../../../products/presentation/pages/product_list_page.dart';
import '../../../customers/presentation/pages/customer_list_page.dart';
import '../../../inventory/presentation/pages/stock_balance_page.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/utils/responsive_utils.dart';
import '../../../../shared/widgets/escape_pop_scope.dart';

class DashboardPage extends ConsumerWidget {
  final VoidCallback? onGoToPos;
  final VoidCallback? onGoToProducts;
  final VoidCallback? onGoToCustomers;
  final VoidCallback? onGoToSalesHistory;
  final VoidCallback? onGoToStock;
  final VoidCallback? onGoToSettings;
  final bool showBackButton;
  final bool isRestaurantMode;
  final VoidCallback? onGoToTakeaway;
  final VoidCallback? onGoToTakeawayKitchen;
  final VoidCallback? onGoToTableOverview;
  final bool showAppBar;

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
    this.onGoToStock,
    this.onGoToSettings,
    this.onGoToTodaySales,
    this.onGoToMonthSales,
    this.showBackButton = true,
    this.isRestaurantMode = false,
    this.onGoToTakeaway,
    this.onGoToTakeawayKitchen,
    this.onGoToTableOverview,
    this.showAppBar = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(dashboardProvider);

    return EscapePopScope(
      child: Scaffold(
        backgroundColor: AppTheme.surfaceColor,
        appBar: showAppBar
            ? AppBar(
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
                    onPressed: () =>
                        ref.read(dashboardProvider.notifier).refresh(),
                  ),
                ],
              )
            : null,

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
            onGoToStock: onGoToStock,
            onGoToSettings: onGoToSettings,
            onGoToTodaySales: onGoToTodaySales,
            onGoToMonthSales: onGoToMonthSales,
            isRestaurantMode: isRestaurantMode,
            onGoToTakeaway: onGoToTakeaway,
            onGoToTakeawayKitchen: onGoToTakeawayKitchen,
            onGoToTableOverview: onGoToTableOverview,
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
  final VoidCallback? onGoToStock;
  final VoidCallback? onGoToSettings;
  final VoidCallback? onGoToTodaySales;
  final VoidCallback? onGoToMonthSales;
  final bool isRestaurantMode;
  final VoidCallback? onGoToTakeaway;
  final VoidCallback? onGoToTakeawayKitchen;
  final VoidCallback? onGoToTableOverview;

  const _DashboardBody({
    required this.stats,
    this.onGoToPos,
    this.onGoToProducts,
    this.onGoToCustomers,
    this.onGoToSalesHistory,
    this.onGoToStock,
    this.onGoToSettings,
    this.onGoToTodaySales,
    this.onGoToMonthSales,
    this.isRestaurantMode = false,
    this.onGoToTakeaway,
    this.onGoToTakeawayKitchen,
    this.onGoToTableOverview,
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
                        onGoToStock: onGoToStock,
                        onGoToSettings: onGoToSettings,
                        onGoToTodaySales: onGoToTodaySales,
                        isRestaurantMode: isRestaurantMode,
                        onGoToTakeaway: onGoToTakeaway,
                        onGoToTakeawayKitchen: onGoToTakeawayKitchen,
                        onGoToTableOverview: onGoToTableOverview,
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
                  onGoToStock: onGoToStock,
                  onGoToSettings: onGoToSettings,
                  onGoToTodaySales: onGoToTodaySales,
                  isRestaurantMode: isRestaurantMode,
                  onGoToTakeaway: onGoToTakeaway,
                  onGoToTakeawayKitchen: onGoToTakeawayKitchen,
                  onGoToTableOverview: onGoToTableOverview,
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
            const SizedBox(height: 12),
            _OverviewRow(
              label: 'ยอดขายทั้งหมด',
              value: '฿${NumberFormat('#,##0.00').format(stats.totalSales)}',
              color: AppTheme.successColor,
              icon: Icons.monetization_on_outlined,
              onTap: onOpenAllSales,
            ),
            const SizedBox(height: 8),
            _OverviewRow(
              label: 'ออเดอร์ทั้งหมด',
              value:
                  '${NumberFormat('#,##0').format(stats.totalOrders)} ออเดอร์',
              color: AppTheme.infoColor,
              icon: Icons.receipt_long_outlined,
              onTap: onOpenAllSales,
            ),
            const SizedBox(height: 8),
            _OverviewRow(
              label: 'ยอดขายเดือนนี้',
              value: '฿${NumberFormat('#,##0.00').format(stats.monthSales)}',
              color: AppTheme.primaryColor,
              icon: Icons.calendar_month_outlined,
              onTap: onOpenMonthSales,
            ),
            const SizedBox(height: 8),
            _OverviewRow(
              label: 'ออเดอร์เดือนนี้',
              value:
                  '${NumberFormat('#,##0').format(stats.monthOrders)} ออเดอร์',
              color: AppTheme.warningColor,
              icon: Icons.shopping_bag_outlined,
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
  final VoidCallback? onGoToStock;
  final VoidCallback? onGoToSettings;
  final VoidCallback? onGoToTodaySales;
  final bool isRestaurantMode;
  final VoidCallback? onGoToTakeaway;
  final VoidCallback? onGoToTakeawayKitchen;
  final VoidCallback? onGoToTableOverview;

  const _QuickActionsCard({
    this.onGoToPos,
    this.onGoToProducts,
    this.onGoToCustomers,
    this.onGoToSalesHistory,
    this.onGoToStock,
    this.onGoToSettings,
    this.onGoToTodaySales,
    this.isRestaurantMode = false,
    this.onGoToTakeaway,
    this.onGoToTakeawayKitchen,
    this.onGoToTableOverview,
  });

  @override
  Widget build(BuildContext context) {
    final posAction = _QuickAction(
      icon: Icons.qr_code_scanner_rounded,
      label: 'เปิดจุดขาย',
      color: const Color(0xFF35A8E0),
      onTap: onGoToPos ?? () => Navigator.pushNamed(context, '/pos'),
    );
    final tableAction = _QuickAction(
      icon: Icons.table_restaurant,
      label: 'เปิดโต๊ะอาหาร',
      color: const Color(0xFF63B946),
      onTap:
          onGoToTableOverview ??
          onGoToPos ??
          () => Navigator.pushNamed(context, '/pos'),
    );
    final takeawayAction = _QuickAction(
      icon: Icons.qr_code_scanner_rounded,
      label: 'ขายหน้าร้าน',
      color: const Color(0xFF39A9E8),
      onTap: onGoToTakeaway ?? () {},
    );
    final kitchenTakeawayAction = _QuickAction(
      icon: Icons.kitchen_outlined,
      label: 'ขายหน้าร้าน (ส่งเข้าครัว)',
      color: const Color(0xFF6B4122),
      onTap: onGoToTakeawayKitchen ?? onGoToTakeaway ?? () {},
    );
    final productsAction = _QuickAction(
      icon: Icons.add_box_outlined,
      label: 'เพิ่มสินค้า',
      color: const Color(0xFFFF9224),
      onTap:
          onGoToProducts ??
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProductListPage()),
          ),
    );
    final customersAction = _QuickAction(
      icon: Icons.person_add_outlined,
      label: 'เพิ่มลูกค้า',
      color: const Color(0xFF159AA4),
      onTap:
          onGoToCustomers ??
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CustomerListPage()),
          ),
    );
    final salesAction = _QuickAction(
      icon: Icons.receipt_long_outlined,
      label: 'รายการขาย',
      color: const Color(0xFF2C82C9),
      onTap:
          onGoToSalesHistory ??
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SalesHistoryPage()),
          ),
    );

    final quickActions = isRestaurantMode
        ? [
            takeawayAction,
            kitchenTakeawayAction,
            tableAction,
            productsAction,
            customersAction,
            salesAction,
          ]
        : [
            posAction,
            productsAction,
            customersAction,
            salesAction,
            _QuickAction(
              icon: Icons.inventory_2_rounded,
              label: 'จัดการสต็อก',
              color: const Color(0xFFE48928),
              onTap:
                  onGoToStock ??
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const StockBalancePage()),
                  ),
            ),
            _QuickAction(
              icon: Icons.settings_rounded,
              label: 'ตั้งค่า',
              color: const Color(0xFF6F7B86),
              onTap:
                  onGoToSettings ??
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsPage()),
                  ),
            ),
          ];

    final mainActions = [
      _MainFunctionAction(
        icon: Icons.assessment_rounded,
        label: 'รายงานวันนี้',
        color: const Color(0xFF2C82C9),
        onTap: onGoToTodaySales ?? salesAction.onTap,
      ),
      _MainFunctionAction(
        icon: Icons.description_rounded,
        label: 'ประวัติขาย',
        color: const Color(0xFF30A15B),
        onTap: salesAction.onTap,
      ),
      _MainFunctionAction(
        icon: Icons.inventory_2_rounded,
        label: 'จัดการสต็อก',
        color: const Color(0xFFE48928),
        onTap:
            onGoToStock ??
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const StockBalancePage()),
            ),
      ),
      _MainFunctionAction(
        icon: Icons.settings_rounded,
        label: 'ตั้งค่า',
        color: const Color(0xFF6F7B86),
        onTap:
            onGoToSettings ??
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
      ),
    ];

    return Column(
      children: [
        _DashboardPanel(
          title: 'เมนูด่วน',
          child: _QuickMenuGrid(actions: quickActions),
        ),
        const SizedBox(height: 8),
        _DashboardPanel(
          title: 'ฟังก์ชันหลัก',
          child: _MainFunctionGrid(actions: mainActions),
        ),
      ],
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
  final IconData icon;
  final VoidCallback onTap;

  const _OverviewRow({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconBoxSize = context.isMobile ? 38.0 : 42.0;
    final iconSize = context.isMobile ? 19.0 : 21.0;
    final valueFontSize = context.isMobile ? 15.0 : 17.0;
    final labelFontSize = context.isMobile ? 11.0 : 12.0;

    final darkTop = Color.lerp(color, Colors.black, 0.15)!;
    final lightBottom = Color.lerp(color, Colors.white, 0.1)!;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.18)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [lightBottom, darkTop],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.25),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: SizedBox(
                    width: iconBoxSize,
                    height: iconBoxSize,
                    child: Icon(icon, color: Colors.white, size: iconSize),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: labelFontSize,
                          color: AppTheme.subtextColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: valueFontSize,
                          fontWeight: FontWeight.w700,
                          color: color,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: context.isMobile ? 18 : 20,
                  color: color.withValues(alpha: 0.55),
                ),
              ],
            ),
          ),
        ),
      ),
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

class _DashboardPanel extends StatelessWidget {
  final String title;
  final Widget child;
  const _DashboardPanel({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.10),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFD8DEE6)),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: context.isMobile ? 16 : 17,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF151515),
                height: 1.1,
              ),
            ),
            const SizedBox(height: 7),
            child,
          ],
        ),
      ),
    );
  }
}

class _QuickMenuGrid extends StatelessWidget {
  final List<_QuickAction> actions;
  const _QuickMenuGrid({required this.actions});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = constraints.maxWidth < 360 ? 6.0 : 8.0;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: actions.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
            childAspectRatio: 1.34,
          ),
          itemBuilder: (context, index) =>
              _QuickItemCard(action: actions[index]),
        );
      },
    );
  }
}

class _QuickItemCard extends StatelessWidget {
  final _QuickAction action;
  const _QuickItemCard({required this.action});

  @override
  Widget build(BuildContext context) {
    final darkTop = Color.lerp(action.color, Colors.black, 0.12)!;
    final lightBottom = Color.lerp(action.color, Colors.white, 0.08)!;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: action.color.withValues(alpha: 0.22),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [lightBottom, darkTop],
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: InkWell(
            onTap: action.onTap,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 7),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    action.icon,
                    color: Colors.white,
                    size: context.isMobile ? 29 : 34,
                    shadows: const [
                      Shadow(
                        color: Color(0x66000000),
                        blurRadius: 3,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        action.label,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: context.isMobile ? 14 : 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.05,
                          shadows: const [
                            Shadow(
                              color: Color(0x66000000),
                              blurRadius: 2,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MainFunctionAction {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _MainFunctionAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}

class _MainFunctionGrid extends StatelessWidget {
  final List<_MainFunctionAction> actions;
  const _MainFunctionGrid({required this.actions});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = constraints.maxWidth < 360 ? 6.0 : 8.0;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: actions.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
            childAspectRatio: 0.96,
          ),
          itemBuilder: (context, index) =>
              _MainFunctionButton(action: actions[index]),
        );
      },
    );
  }
}

class _MainFunctionButton extends StatelessWidget {
  final _MainFunctionAction action;
  const _MainFunctionButton({required this.action});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFD5DAE1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(action.icon, color: action.color, size: 25),
              const SizedBox(height: 11),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    action.label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: context.isMobile ? 12 : 13,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF111111),
                      height: 1.05,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
