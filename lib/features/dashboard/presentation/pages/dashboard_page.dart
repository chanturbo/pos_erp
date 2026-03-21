import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/dashboard_provider.dart';
import '../../../sales/presentation/pages/sales_history_page.dart';
import '../../../products/presentation/pages/product_list_page.dart';
import '../../../customers/presentation/pages/customer_list_page.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/utils/responsive_utils.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(dashboardProvider);

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        // ซ่อน leading เมื่อ sidebar permanent (desktop) — มี sidebar แล้ว
        automaticallyImplyLeading: !context.hasPermanentSidebar,
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
              const Icon(Icons.error_outline,
                  size: 72, color: AppTheme.errorColor),
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
        data: (stats) => _DashboardBody(stats: stats),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Dashboard Body
// ─────────────────────────────────────────────────────────────────
class _DashboardBody extends StatelessWidget {
  final DashboardStats stats;
  const _DashboardBody({required this.stats});

  @override
  Widget build(BuildContext context) {
    final padding = context.pagePadding;

    return SingleChildScrollView(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (context.isDesktopOrWider) ...[
            // ── Desktop: Stats ก่อน แล้ว Quick + Overview คู่กัน ──────
            _buildStatsGrid(context),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _QuickActionsCard()),
                const SizedBox(width: 16),
                Expanded(child: _TodayCard(stats: stats)),
              ],
            ),
          ] else ...[
            // ── Mobile/Tablet: เมนูด่วนก่อน → Stats → Overview ─────────
            _QuickActionsCard(),
            SizedBox(height: context.isMobile ? 12 : 16),
            _buildStatsGrid(context),
            SizedBox(height: context.isMobile ? 12 : 16),
            _TodayCard(stats: stats),
          ],
        ],
      ),
    );
  }

  // ── Stats Cards Grid ───────────────────────────────────────────
  Widget _buildStatsGrid(BuildContext context) {
    final cards = [
      _StatCardData(
        label: 'สินค้าทั้งหมด',
        value: '${stats.totalProducts}',
        icon: Icons.inventory_2_outlined,
        iconBg: const Color(0xFFFFF3E0),
        iconColor: AppTheme.primaryColor,
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const ProductListPage())),
      ),
      _StatCardData(
        label: 'ลูกค้าทั้งหมด',
        value: '${stats.totalCustomers}',
        icon: Icons.people_outline,
        iconBg: const Color(0xFFE8F5E9),
        iconColor: AppTheme.successColor,
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const CustomerListPage())),
      ),
      _StatCardData(
        label: 'ยอดขายวันนี้',
        value: '฿${stats.todaySales.toStringAsFixed(0)}',
        icon: Icons.attach_money,
        iconBg: const Color(0xFFE3F2FD),
        iconColor: AppTheme.infoColor,
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const SalesHistoryPage())),
      ),
      _StatCardData(
        label: 'ออเดอร์วันนี้',
        value: '${stats.todayOrders}',
        icon: Icons.shopping_cart_outlined,
        iconBg: const Color(0xFFFFEBEE),
        iconColor: AppTheme.errorColor,
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const SalesHistoryPage())),
      ),
    ];

    // Responsive columns: mobile=2, tablet=2, desktop+=4
    final cols = context.statsGridColumns;
    // Aspect ratio ปรับตามขนาด
    final aspectRatio = context.isMobile ? 1.6 : (context.isTablet ? 1.8 : 2.0);

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: cols,
      childAspectRatio: aspectRatio,
      crossAxisSpacing: context.isMobile ? 10 : 14,
      mainAxisSpacing: context.isMobile ? 10 : 14,
      children: cards.map((c) => _StatCard(data: c)).toList(),
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
  const _StatCard({required this.data});

  @override
  Widget build(BuildContext context) {
    // Icon size ตามหน้าจอ
    final iconBoxSize  = context.isMobile ? 40.0 : 46.0;
    final iconSize     = context.isMobile ? 20.0 : 22.0;
    final valueFontSize = context.isMobile ? 20.0 : 24.0;
    final labelFontSize = context.isMobile ? 11.0 : 12.0;

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
                child: Icon(data.icon,
                    color: data.iconColor, size: iconSize),
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
  const _TodayCard({required this.stats});

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
            _OverviewRow('ยอดขายทั้งหมด',
                '฿${stats.totalSales.toStringAsFixed(2)}',
                AppTheme.successColor),
            const Divider(height: 18, color: AppTheme.borderColor),
            _OverviewRow('ออเดอร์ทั้งหมด',
                '${stats.totalOrders} ออเดอร์',
                AppTheme.infoColor),
            const Divider(height: 18, color: AppTheme.borderColor),
            _OverviewRow('ยอดขายวันนี้',
                '฿${stats.todaySales.toStringAsFixed(2)}',
                AppTheme.primaryColor),
            const Divider(height: 18, color: AppTheme.borderColor),
            _OverviewRow('ออเดอร์วันนี้',
                '${stats.todayOrders} ออเดอร์',
                AppTheme.warningColor),
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
  const _QuickActionsCard();

  @override
  Widget build(BuildContext context) {
    final actions = [
      _QuickAction(
        icon: Icons.add_shopping_cart,
        label: 'เปิดจุดขาย',
        color: AppTheme.primaryColor,
        onTap: () => Navigator.pushNamed(context, '/pos'),
      ),
      _QuickAction(
        icon: Icons.add_box_outlined,
        label: 'เพิ่มสินค้า',
        color: AppTheme.infoColor,
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const ProductListPage())),
      ),
      _QuickAction(
        icon: Icons.person_add_outlined,
        label: 'เพิ่มลูกค้า',
        color: AppTheme.successColor,
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const CustomerListPage())),
      ),
      _QuickAction(
        icon: Icons.receipt_long_outlined,
        label: 'รายงานการขาย',
        color: const Color(0xFFAD1457),
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const SalesHistoryPage())),
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
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: context.isMobile ? 2.4 : 2.8,
              children: actions
                  .map((a) => _QuickItemCard(action: a))
                  .toList(),
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

  const _OverviewRow(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: context.isMobile ? 12 : 13,
                color: AppTheme.subtextColor)),
        Text(value,
            style: TextStyle(
                fontSize: context.isMobile ? 12 : 14,
                fontWeight: FontWeight.w600,
                color: color)),
      ],
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
            border: Border.all(
                color: action.color.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: action.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(action.icon,
                    size: context.isMobile ? 18 : 20,
                    color: action.color),
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
              Icon(Icons.chevron_right,
                  size: 16,
                  color: action.color.withValues(alpha: 0.5)),
            ],
          ),
        ),
      ),
    );
  }
}