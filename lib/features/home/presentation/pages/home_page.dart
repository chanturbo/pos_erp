import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final syncAsync = ref.watch(syncStatusProvider); // ✅ Week 7

    return KeyboardShortcuts(
      onPosShortcut: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const PosPage()),
        );
      },
      onProductShortcut: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ProductListPage()),
        );
      },
      onCustomerShortcut: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CustomerListPage()),
        );
      },
      onSalesHistoryShortcut: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SalesHistoryPage()),
        );
      },
      onDashboardShortcut: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const DashboardPage()),
        );
      },
      onInventoryShortcut: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const StockBalancePage()),
        );
      },
      onReportsShortcut: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ReportsPage()),
        );
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('หน้าหลัก'),
          automaticallyImplyLeading: false,
          actions: [
            // ✅ Week 7 — Sync status badge
            syncAsync.when(
              data: (sync) => IconButton(
                icon: Stack(
                  children: [
                    Icon(
                      sync.isOnline ? Icons.sync : Icons.sync_disabled,
                      color: sync.isOnline ? null : Colors.red,
                    ),
                    if (sync.hasPending)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 9,
                          height: 9,
                          decoration: const BoxDecoration(
                            color: Colors.orange,
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
              error: (_, __) => const SizedBox(width: 48),
            ),
            // Settings button
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: 'ตั้งค่า',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsPage()),
                );
              },
            ),
            // Test button
            IconButton(
              icon: const Icon(Icons.science),
              tooltip: 'ทดสอบระบบ',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TestPage()),
                );
              },
            ),

            // User info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Text(
                  user?.fullName ?? '',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),

            // Logout button
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
                    Navigator.of(
                      context,
                    ).pushNamedAndRemoveUntil('/login', (route) => false);
                  }
                }
              },
            ),
          ],
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle, size: 100, color: Colors.green),
                const SizedBox(height: 24),
                Text(
                  'เข้าสู่ระบบสำเร็จ!',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                Text(
                  'ยินดีต้อนรับ ${user?.fullName ?? ''}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Username: ${user?.username ?? ''}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: Colors.grey),
                ),
                const SizedBox(height: 32),

                // Grid Menu
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 4,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    children: [
                      // Row 1: ขาย
                      _buildMenuCard(
                        context,
                        icon: Icons.dashboard,
                        title: 'Dashboard',
                        color: Colors.indigo,
                        onTap: () => _push(context, const DashboardPage()),
                      ),
                      _buildMenuCard(
                        context,
                        icon: Icons.shopping_cart,
                        title: 'การขาย',
                        color: Colors.blue,
                        onTap: () => _push(context, const PosPage()),
                      ),
                      _buildMenuCard(
                        context,
                        icon: Icons.inventory,
                        title: 'สินค้า',
                        color: Colors.orange,
                        onTap: () => _push(context, const ProductListPage()),
                      ),
                      _buildMenuCard(
                        context,
                        icon: Icons.receipt_long,
                        title: 'รายการขาย',
                        color: Colors.indigo,
                        onTap: () => _push(context, const SalesHistoryPage()),
                      ),

                      // Row 2: คลัง
                      _buildMenuCard(
                        context,
                        icon: Icons.warehouse,
                        title: 'คลังสินค้า',
                        color: Colors.green,
                        onTap: () => _push(context, const StockBalancePage()),
                      ),
                      _buildMenuCard(
                        context,
                        icon: Icons.tune,
                        title: 'ปรับสต๊อก',
                        color: Colors.deepPurple,
                        onTap: () =>
                            _push(context, const StockAdjustmentPage()),
                      ),
                      _buildMenuCard(
                        context,
                        icon: Icons.people,
                        title: 'ลูกค้า',
                        color: Colors.purple,
                        onTap: () => _push(context, const CustomerListPage()),
                      ),
                      _buildMenuCard(
                        context,
                        icon: Icons.business,
                        title: 'ซัพพลายเออร์',
                        color: Colors.cyan,
                        onTap: () => _push(context, const SupplierListPage()),
                      ),

                      // Row 3: จัดซื้อ
                      _buildMenuCard(
                        context,
                        icon: Icons.shopping_bag,
                        title: 'ซื้อสินค้า',
                        color: Colors.red,
                        onTap: () =>
                            _push(context, const PurchaseOrderListPage()),
                      ),
                      _buildMenuCard(
                        context,
                        icon: Icons.inventory_2,
                        title: 'รับสินค้า',
                        color: Colors.deepOrange,
                        onTap: () =>
                            _push(context, const GoodsReceiptListPage()),
                      ),
                      _buildMenuCard(
                        context,
                        icon: Icons.assignment_return,
                        title: 'คืนสินค้า',
                        color: Colors.amber,
                        onTap: () =>
                            _push(context, const PurchaseReturnListPage()),
                      ),
                      _buildMenuCard(
                        context,
                        icon: Icons.receipt,
                        title: 'ใบแจ้งหนี้ AP',
                        color: Colors.brown,
                        onTap: () => _push(context, const ApInvoiceListPage()),
                      ),

                      // Row 4: บัญชี
                      _buildMenuCard(
                        context,
                        icon: Icons.payments,
                        title: 'จ่ายเงิน AP',
                        color: Colors.teal,
                        onTap: () => _push(context, const ApPaymentListPage()),
                      ),
                      // ✅ Day 36-38
                      _buildMenuCard(
                        context,
                        icon: Icons.request_page,
                        title: 'ใบแจ้งหนี้ AR',
                        color: Colors.teal.shade700,
                        onTap: () => _push(context, const ArInvoiceListPage()),
                      ),
                      // ✅ Day 39-40
                      _buildMenuCard(
                        context,
                        icon: Icons.price_check,
                        title: 'รับเงิน AR',
                        color: Colors.green.shade700,
                        onTap: () => _push(context, const ArReceiptListPage()),
                      ),
                      _buildMenuCard(
                        context,
                        icon: Icons.assessment,
                        title: 'รายงาน',
                        color: Colors.pink,
                        onTap: () => _push(context, const ReportsPage()),
                      ),

                      // Row 5: โปรโมชั่น + สาขา
                      // ✅ Day 41-45
                      _buildMenuCard(
                        context,
                        icon: Icons.local_offer,
                        title: 'โปรโมชั่น',
                        color: Colors.orange.shade700,
                        onTap: () => _push(context, const PromotionListPage()),
                      ),
                      // ✅ Week 7
                      _buildMenuCard(
                        context,
                        icon: Icons.store,
                        title: 'จัดการสาขา',
                        color: Colors.indigo.shade600,
                        onTap: () => _push(context, const BranchListPage()),
                      ),
                      // ✅ Week 7
                      _buildMenuCard(
                        context,
                        icon: Icons.sync_alt,
                        title: 'Sync สถานะ',
                        color: Colors.blueGrey,
                        onTap: () => _push(context, const SyncStatusPage()),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _push(BuildContext context, Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => page),
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}