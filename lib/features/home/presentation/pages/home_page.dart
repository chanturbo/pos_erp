import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../products/presentation/pages/product_list_page.dart';
import '../../../customers/presentation/pages/customer_list_page.dart'; // ✅ เพิ่ม
import '../../../testing/test_page.dart'; // ✅ เพิ่มบรรทัดนี้
import '../../../sales/presentation/pages/pos_page.dart'; // ✅ เพิ่ม
import '../../../sales/presentation/pages/sales_history_page.dart';
import '../../../dashboard/presentation/pages/dashboard_page.dart'; // ✅ เพิ่ม

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    return Scaffold(
      // ✅ เพิ่มปุ่มในหน้า Home (ในส่วน AppBar actions)
      appBar: AppBar(
        title: const Text('หน้าหลัก'),
        automaticallyImplyLeading: false,
        actions: [
          // ✅ เพิ่มปุ่มทดสอบ
          IconButton(
            icon: const Icon(Icons.science),
            tooltip: 'ทดสอบระบบ',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TestPage()),
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
                constraints: const BoxConstraints(maxWidth: 800),
                child: GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 3,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  children: [
                    _buildMenuCard(
                      context,
                      icon: Icons.dashboard,
                      title: 'Dashboard',
                      color: Colors.indigo,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const DashboardPage(),
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
                          MaterialPageRoute(builder: (_) => const PosPage()),
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
                            builder: (_) => const ProductListPage(),
                          ),
                        );
                      },
                    ),
                    // ✅ เพิ่มเมนูนี้
                    _buildMenuCard(
                      context,
                      icon: Icons.receipt_long,
                      title: 'รายการขาย',
                      color: Colors.indigo,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SalesHistoryPage(),
                          ),
                        );
                      },
                    ),
                    _buildMenuCard(
                      context,
                      icon: Icons.warehouse,
                      title: 'คลังสินค้า',
                      color: Colors.green,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('เร็วๆ นี้...')),
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
                            builder: (_) => const CustomerListPage(),
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
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('เร็วๆ นี้...')),
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
            ),
          ],
        ),
      ),
    );
  }
}
