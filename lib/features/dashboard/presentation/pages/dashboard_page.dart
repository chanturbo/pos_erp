import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/dashboard_card.dart';
import '../../../sales/presentation/pages/sales_history_page.dart';
import '../../../products/presentation/pages/product_list_page.dart';
import '../../../customers/presentation/pages/customer_list_page.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(dashboardProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(dashboardProvider);
            },
          ),
        ],
      ),
      body: dashboardAsync.when(
        data: (stats) => _buildDashboard(context, stats),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 80, color: Colors.red),
              const SizedBox(height: 16),
              Text('เกิดข้อผิดพลาด: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(dashboardProvider),
                child: const Text('ลองใหม่'),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildDashboard(BuildContext context, DashboardStats stats) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome
          Text(
            'ภาพรวมระบบ',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // Today Stats
          const Text(
            'วันนี้',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 1.8,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              DashboardCard(
                title: 'ยอดขายวันนี้',
                value: '฿${stats.todaySales.toStringAsFixed(2)}',
                icon: Icons.attach_money,
                color: Colors.green,
              ),
              DashboardCard(
                title: 'ออเดอร์วันนี้',
                value: '${stats.todayOrders}',
                icon: Icons.shopping_cart,
                color: Colors.blue,
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Overall Stats
          const Text(
            'ภาพรวมทั้งหมด',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 1.8,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              DashboardCard(
                title: 'ยอดขายทั้งหมด',
                value: '฿${stats.totalSales.toStringAsFixed(2)}',
                icon: Icons.money,
                color: Colors.orange,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SalesHistoryPage()),
                  );
                },
              ),
              DashboardCard(
                title: 'ออเดอร์ทั้งหมด',
                value: '${stats.totalOrders}',
                icon: Icons.receipt_long,
                color: Colors.blue,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SalesHistoryPage()),
                  );
                },
              ),
              DashboardCard(
                title: 'สินค้าทั้งหมด',
                value: '${stats.totalProducts}',
                icon: Icons.inventory,
                color: Colors.purple,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProductListPage()),
                  );
                },
              ),
              DashboardCard(
                title: 'ลูกค้าทั้งหมด',
                value: '${stats.totalCustomers}',
                icon: Icons.people,
                color: Colors.teal,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CustomerListPage()),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Quick Actions
          const Text(
            'เมนูด่วน',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                avatar: const Icon(Icons.add_shopping_cart, size: 18),
                label: const Text('เปิดจุดขาย'),
                onPressed: () {
                  Navigator.pushNamed(context, '/pos');
                },
              ),
              ActionChip(
                avatar: const Icon(Icons.add_box, size: 18),
                label: const Text('เพิ่มสินค้า'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProductListPage()),
                  );
                },
              ),
              ActionChip(
                avatar: const Icon(Icons.person_add, size: 18),
                label: const Text('เพิ่มลูกค้า'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CustomerListPage()),
                  );
                },
              ),
              ActionChip(
                avatar: const Icon(Icons.receipt, size: 18),
                label: const Text('รายงานการขาย'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SalesHistoryPage()),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}