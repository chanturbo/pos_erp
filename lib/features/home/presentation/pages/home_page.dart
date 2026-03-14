import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/theme/app_theme.dart';           // OAG Identity
import '../../../ap/presentation/pages/ap_payment_list_page.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../products/presentation/pages/product_list_page.dart';
import '../../../customers/presentation/pages/customer_list_page.dart';
import '../../../purchases/presentation/pages/purchase_return_list_page.dart';
import '../../../suppliers/presentation/pages/supplier_list_page.dart';
import '../../../purchases/presentation/pages/purchase_order_list_page.dart';
import '../../../purchases/presentation/pages/goods_receipt_list_page.dart';
import '../../../ap/presentation/pages/ap_invoice_list_page.dart';
import '../../../ar/presentation/pages/ar_invoice_list_page.dart';        // ✅ Day 36-38
import '../../../ar/presentation/pages/ar_receipt_list_page.dart';        // ✅ Day 39-40
import '../../../promotions/presentation/pages/promotion_list_page.dart'; // ✅ Day 41-45
import '../../../branches/presentation/pages/branch_list_page.dart';      // ✅ Week 7
import '../../../branches/presentation/pages/sync_status_page.dart';      // ✅ Week 7
import '../../../branches/presentation/providers/branch_provider.dart';   // ✅ Week 7
import '../../../testing/test_page.dart';
import '../../../sales/presentation/pages/pos_page.dart';
import '../../../sales/presentation/pages/sales_history_page.dart';
import '../../../dashboard/presentation/pages/dashboard_page.dart';
import '../../../inventory/presentation/pages/stock_balance_page.dart';
import '../../../inventory/presentation/pages/stock_adjustment_page.dart';
import '../../../reports/presentation/pages/reports_page.dart';
import '../../../../core/shortcuts/keyboard_shortcuts.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import '../../../../shared/utils/responsive_utils.dart'; // ✅ Phase 4

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user      = authState.user;
    final syncAsync = ref.watch(syncStatusProvider); // ✅ Week 7

    return KeyboardShortcuts(
      onPosShortcut:          () => _push(context, const PosPage()),
      onProductShortcut:      () => _push(context, const ProductListPage()),
      onCustomerShortcut:     () => _push(context, const CustomerListPage()),
      onSalesHistoryShortcut: () => _push(context, const SalesHistoryPage()),
      onDashboardShortcut:    () => _push(context, const DashboardPage()),
      onInventoryShortcut:    () => _push(context, const StockBalancePage()),
      onReportsShortcut:      () => _push(context, const ReportsPage()),
      child: Scaffold(
        // AppBar สีจาก theme (navyColor) — กำหนดใน AppTheme.lightTheme
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // OAG Orange brand dot
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 8),
                decoration: const BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                ),
              ),
              const Text('หน้าหลัก'),
            ],
          ),
          automaticallyImplyLeading: false,
          actions: [
            // ✅ Week 7 — Sync status badge
            syncAsync.when(
              data: (sync) => IconButton(
                icon: Stack(
                  children: [
                    Icon(
                      sync.isOnline ? Icons.sync : Icons.sync_disabled,
                      color: sync.isOnline ? Colors.white70 : AppTheme.errorLight,
                    ),
                    if (sync.hasPending)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 9,
                          height: 9,
                          decoration: const BoxDecoration(
                            color: AppTheme.primaryColor, // Orange badge
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
                tooltip: sync.pendingCount > 0
                    ? 'รอ Sync ${sync.pendingCount} รายการ'
                    : 'Sync สถานะ',
                onPressed: () => _push(context, const SyncStatusPage()),
              ),
              loading: () => const SizedBox(width: 48),
              error: (_, _) => const SizedBox(width: 48),
            ),

            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: 'ตั้งค่า',
              onPressed: () => _push(context, const SettingsPage()),
            ),
            IconButton(
              icon: const Icon(Icons.science),
              tooltip: 'ทดสอบระบบ',
              onPressed: () => _push(context, const TestPage()),
            ),

            // ✅ ซ่อนชื่อบน mobile เล็ก
            if (!context.isMobile)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: Text(
                    user?.fullName ?? '',
                    style: const TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                ),
              ),

            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'ออกจากระบบ',
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('ออกจากระบบ'),
                    content: const Text('คุณต้องการออกจากระบบใช่หรือไม่?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('ยกเลิก'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('ออกจากระบบ'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await ref.read(authProvider.notifier).logout();
                  if (context.mounted) {
                    Navigator.of(context)
                        .pushNamedAndRemoveUntil('/login', (route) => false);
                  }
                }
              },
            ),
          ],
        ),

        body: Center(
          child: SingleChildScrollView(
            padding: context.pagePadding,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: context.contentMaxWidth),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ── Welcome Banner (Navy card) ─────────────────
                  Container(
                    padding: EdgeInsets.all(context.isMobile ? 16 : 20),
                    margin: EdgeInsets.only(bottom: context.isMobile ? 20 : 28),
                    decoration: BoxDecoration(
                      color: AppTheme.navyColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppTheme.primaryColor.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Icon(
                            Icons.check_circle_rounded,
                            size: context.isMobile ? 26 : 32,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ยินดีต้อนรับ ${user?.fullName ?? ''}',
                                style: TextStyle(
                                  fontSize: context.isMobile ? 15 : 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                user?.username ?? '',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF8A9BC0),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Responsive Grid Menu ───────────────────────
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: context.menuGridColumns, // ✅ 2/3/4/5
                    mainAxisSpacing: context.isMobile ? 10 : 16,
                    crossAxisSpacing: context.isMobile ? 10 : 16,
                    childAspectRatio: context.isMobile ? 1.1 : 1.0,
                    children: [
                      // Row 1: ขาย
                      _buildMenuCard(context,
                          icon: Icons.dashboard,
                          title: 'Dashboard',
                          color: AppTheme.navyLight,
                          onTap: () => _push(context, const DashboardPage())),
                      _buildMenuCard(context,
                          icon: Icons.shopping_cart,
                          title: 'การขาย',
                          color: AppTheme.infoColor,
                          onTap: () => _push(context, const PosPage())),
                      _buildMenuCard(context,
                          icon: Icons.inventory,
                          title: 'สินค้า',
                          color: AppTheme.primaryColor,
                          onTap: () => _push(context, const ProductListPage())),
                      _buildMenuCard(context,
                          icon: Icons.receipt_long,
                          title: 'รายการขาย',
                          color: AppTheme.navyColor,
                          onTap: () => _push(context, const SalesHistoryPage())),

                      // Row 2: คลัง
                      _buildMenuCard(context,
                          icon: Icons.warehouse,
                          title: 'คลังสินค้า',
                          color: AppTheme.successColor,
                          onTap: () => _push(context, const StockBalancePage())),
                      _buildMenuCard(context,
                          icon: Icons.tune,
                          title: 'ปรับสต๊อก',
                          color: AppTheme.purpleColor,
                          onTap: () => _push(context, const StockAdjustmentPage())),
                      _buildMenuCard(context,
                          icon: Icons.people,
                          title: 'ลูกค้า',
                          color: const Color(0xFF7B1FA2),
                          onTap: () => _push(context, const CustomerListPage())),
                      _buildMenuCard(context,
                          icon: Icons.business,
                          title: 'ซัพพลายเออร์',
                          color: AppTheme.infoLight,
                          onTap: () => _push(context, const SupplierListPage())),

                      // Row 3: จัดซื้อ
                      _buildMenuCard(context,
                          icon: Icons.shopping_bag,
                          title: 'ซื้อสินค้า',
                          color: AppTheme.errorColor,
                          onTap: () => _push(context, const PurchaseOrderListPage())),
                      _buildMenuCard(context,
                          icon: Icons.inventory_2,
                          title: 'รับสินค้า',
                          color: AppTheme.primaryDark,
                          onTap: () => _push(context, const GoodsReceiptListPage())),
                      _buildMenuCard(context,
                          icon: Icons.assignment_return,
                          title: 'คืนสินค้า',
                          color: AppTheme.warningColor,
                          onTap: () => _push(context, const PurchaseReturnListPage())),
                      _buildMenuCard(context,
                          icon: Icons.receipt,
                          title: 'ใบแจ้งหนี้ AP',
                          color: AppTheme.brownColor,
                          onTap: () => _push(context, const ApInvoiceListPage())),

                      // Row 4: บัญชี
                      _buildMenuCard(context,
                          icon: Icons.payments,
                          title: 'จ่ายเงิน AP',
                          color: AppTheme.tealColor,
                          onTap: () => _push(context, const ApPaymentListPage())),
                      // ✅ Day 36-38
                      _buildMenuCard(context,
                          icon: Icons.request_page,
                          title: 'ใบแจ้งหนี้ AR',
                          color: const Color(0xFF00695C),
                          onTap: () => _push(context, const ArInvoiceListPage())),
                      // ✅ Day 39-40
                      _buildMenuCard(context,
                          icon: Icons.price_check,
                          title: 'รับเงิน AR',
                          color: AppTheme.successColor,
                          onTap: () => _push(context, const ArReceiptListPage())),
                      _buildMenuCard(context,
                          icon: Icons.assessment,
                          title: 'รายงาน',
                          color: const Color(0xFFAD1457),
                          onTap: () => _push(context, const ReportsPage())),

                      // Row 5: โปรโมชั่น + สาขา
                      // ✅ Day 41-45
                      _buildMenuCard(context,
                          icon: Icons.local_offer,
                          title: 'โปรโมชั่น',
                          color: AppTheme.primaryColor,
                          onTap: () => _push(context, const PromotionListPage())),
                      // ✅ Week 7
                      _buildMenuCard(context,
                          icon: Icons.store,
                          title: 'จัดการสาขา',
                          color: AppTheme.navyColor,
                          onTap: () => _push(context, const BranchListPage())),
                      // ✅ Week 7
                      _buildMenuCard(context,
                          icon: Icons.sync_alt,
                          title: 'Sync สถานะ',
                          color: const Color(0xFF546E7A),
                          onTap: () => _push(context, const SyncStatusPage())),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────

  void _push(BuildContext context, Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  Widget _buildMenuCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    final iconSize = context.isMobile ? 36.0 : 48.0;
    final fontSize = context.isMobile ? 12.0 : 15.0;
    final isDark   = AppTheme.isDark(context);

    return Card(
      elevation: 0,
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        hoverColor: AppTheme.primaryColor.withValues(alpha: 0.06),
        splashColor: AppTheme.primaryColor.withValues(alpha: 0.12),
        child: Padding(
          padding: EdgeInsets.all(context.isMobile ? 8 : 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon bubble with semantic color border
              Container(
                padding: EdgeInsets.all(context.isMobile ? 10 : 14),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: color.withValues(alpha: 0.28),
                    width: 1.5,
                  ),
                ),
                child: Icon(icon, size: iconSize, color: color),
              ),
              SizedBox(height: context.isMobile ? 6 : 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? const Color(0xFFE0E0E0)
                      : const Color(0xFF1A1A1A),
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}