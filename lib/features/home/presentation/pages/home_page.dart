import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../ap/presentation/pages/ap_payment_list_page.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../products/presentation/pages/product_list_page.dart';
import '../../../customers/presentation/pages/customer_list_page.dart';
import '../../../suppliers/presentation/pages/supplier_list_page.dart';
import '../../../purchases/presentation/pages/purchase_order_list_page.dart';
import '../../../purchases/presentation/pages/goods_receipt_list_page.dart';
import '../../../ap/presentation/pages/ap_invoice_list_page.dart';
import '../../../testing/test_page.dart';
import '../../../sales/presentation/pages/pos_page.dart';
import '../../../sales/presentation/pages/sales_history_page.dart';
import '../../../dashboard/presentation/pages/dashboard_page.dart';
import '../../../inventory/presentation/pages/stock_balance_page.dart';
import '../../../reports/presentation/pages/reports_page.dart';
import '../../../../core/shortcuts/keyboard_shortcuts.dart';
import '../../../settings/presentation/pages/settings_page.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

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
                      // Row 1
                      _buildMenuCard(
                        context,
                        icon: Icons.dashboard,
                        title: 'Dashboard',
                        color: Colors.indigo,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const DashboardPage(),
                            ),
                          );
                        },
                      ),
                      _buildMenuCard(
                        context,
                        icon: Icons.shopping_cart,
                        title: 'การขาย',
                        color: Colors.blue,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const PosPage(),
                            ),
                          );
                        },
                      ),
                      _buildMenuCard(
                        context,
                        icon: Icons.inventory,
                        title: 'สินค้า',
                        color: Colors.orange,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ProductListPage(),
                            ),
                          );
                        },
                      ),
                      _buildMenuCard(
                        context,
                        icon: Icons.receipt_long,
                        title: 'รายการขาย',
                        color: Colors.indigo,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SalesHistoryPage(),
                            ),
                          );
                        },
                      ),

                      // Row 2
                      _buildMenuCard(
                        context,
                        icon: Icons.warehouse,
                        title: 'คลังสินค้า',
                        color: Colors.green,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const StockBalancePage(),
                            ),
                          );
                        },
                      ),
                      _buildMenuCard(
                        context,
                        icon: Icons.people,
                        title: 'ลูกค้า',
                        color: Colors.purple,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const CustomerListPage(),
                            ),
                          );
                        },
                      ),
                      _buildMenuCard(
                        context,
                        icon: Icons.business,
                        title: 'ซัพพลายเออร์',
                        color: Colors.cyan,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SupplierListPage(),
                            ),
                          );
                        },
                      ),
                      _buildMenuCard(
                        context,
                        icon: Icons.shopping_bag,
                        title: 'ซื้อสินค้า',
                        color: Colors.red,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const PurchaseOrderListPage(),
                            ),
                          );
                        },
                      ),

                      // Row 3
                      _buildMenuCard(
                        context,
                        icon: Icons.inventory_2,
                        title: 'รับสินค้า',
                        color: Colors.deepOrange,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const GoodsReceiptListPage(),
                            ),
                          );
                        },
                      ),
                      _buildMenuCard(
                        context,
                        icon: Icons.receipt,
                        title: 'ใบแจ้งหนี้ AP',
                        color: Colors.brown,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ApInvoiceListPage(),
                            ),
                          );
                        },
                      ),
                      _buildMenuCard(
                        context,
                        icon: Icons.payments,
                        title: 'จ่ายเงิน AP',
                        color: Colors.teal,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ApPaymentListPage(),
                            ),
                          );
                        },
                      ),
                      _buildMenuCard(
                        context,
                        icon: Icons.assessment,
                        title: 'รายงาน',
                        color: Colors.pink,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ReportsPage(),
                            ),
                          );
                        },
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
