import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/client/api_client.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/sales_summary_model.dart';
import 'sales_chart_page.dart'; // ✅ เพิ่ม
import '../../../../core/utils/csv_export.dart';

// Sales Summary Provider
final salesSummaryProvider = FutureProvider<SalesSummaryModel>((ref) async {
  final apiClient = ref.read(apiClientProvider);

  try {
    final response = await apiClient.get('/api/reports/sales-summary');

    if (response.statusCode == 200) {
      return SalesSummaryModel.fromJson(response.data['data']);
    }
    throw Exception('Failed to load summary');
  } catch (e) {
    throw Exception('Error: $e');
  }
});

// Top Products Provider
final topProductsProvider = FutureProvider<List<TopProductModel>>((ref) async {
  final apiClient = ref.read(apiClientProvider);

  try {
    final response = await apiClient.get('/api/reports/top-products?limit=5');

    if (response.statusCode == 200) {
      final data = response.data['data'] as List;
      return data.map((json) => TopProductModel.fromJson(json)).toList();
    }
    return [];
  } catch (e) {
    return [];
  }
});

// Top Customers Provider
final topCustomersProvider = FutureProvider<List<TopCustomerModel>>((
  ref,
) async {
  final apiClient = ref.read(apiClientProvider);

  try {
    final response = await apiClient.get('/api/reports/top-customers?limit=5');

    if (response.statusCode == 200) {
      final data = response.data['data'] as List;
      return data.map((json) => TopCustomerModel.fromJson(json)).toList();
    }
    return [];
  } catch (e) {
    return [];
  }
});

class ReportsPage extends ConsumerWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(salesSummaryProvider);
    final topProductsAsync = ref.watch(topProductsProvider);
    final topCustomersAsync = ref.watch(topCustomersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('รายงาน'),
        actions: [
          // ✅ เพิ่มปุ่ม Export
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'Export รายงาน',
            onPressed: () => _exportReport(context, ref),
          ),
          // ✅ เพิ่มปุ่มดูกราฟ
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'กราฟยอดขาย',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SalesChartPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(salesSummaryProvider);
              ref.invalidate(topProductsProvider);
              ref.invalidate(topCustomersProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(salesSummaryProvider);
          ref.invalidate(topProductsProvider);
          ref.invalidate(topCustomersProvider);
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sales Summary
              const Text(
                'สรุปยอดขาย',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              summaryAsync.when(
                data: (summary) => _buildSalesSummary(summary),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(child: Text('Error: $error')),
              ),
              const SizedBox(height: 32),

              // Top Products
              const Text(
                'สินค้าขายดี Top 5',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              topProductsAsync.when(
                data: (products) => _buildTopProducts(products),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(child: Text('Error: $error')),
              ),
              const SizedBox(height: 32),

              // Top Customers
              const Text(
                'ลูกค้าซื้อบ่อย Top 5',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              topCustomersAsync.when(
                data: (customers) => _buildTopCustomers(customers),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(child: Text('Error: $error')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSalesSummary(SalesSummaryModel summary) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.5,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        _buildSummaryCard(
          'ยอดขายรวม',
          '฿${summary.totalSales.toStringAsFixed(2)}',
          Icons.attach_money,
          Colors.green,
        ),
        _buildSummaryCard(
          'จำนวนออเดอร์',
          '${summary.totalOrders}',
          Icons.shopping_cart,
          Colors.blue,
        ),
        _buildSummaryCard(
          'ยอดเฉลี่ย/ออเดอร์',
          '฿${summary.avgOrderValue.toStringAsFixed(2)}',
          Icons.analytics,
          Colors.orange,
        ),
        _buildSummaryCard(
          'ส่วนลดรวม',
          '฿${summary.totalDiscount.toStringAsFixed(2)}',
          Icons.discount,
          Colors.red,
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopProducts(List<TopProductModel> products) {
    if (products.isEmpty) {
      return const Center(child: Text('ยังไม่มีข้อมูล'));
    }

    return Column(
      children: products.asMap().entries.map((entry) {
        final index = entry.key;
        final product = entry.value;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getRankColor(index),
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(product.productName),
            subtitle: Text(
              'ขาย: ${product.totalQuantity.toStringAsFixed(0)} ชิ้น | ${product.orderCount} ออเดอร์',
            ),
            trailing: Text(
              '฿${product.totalSales.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTopCustomers(List<TopCustomerModel> customers) {
    if (customers.isEmpty) {
      return const Center(child: Text('ยังไม่มีข้อมูล'));
    }

    return Column(
      children: customers.asMap().entries.map((entry) {
        final index = entry.key;
        final customer = entry.value;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getRankColor(index),
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(customer.customerName),
            subtitle: Text('${customer.orderCount} ออเดอร์'),
            trailing: Text(
              '฿${customer.totalSales.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Color _getRankColor(int index) {
    switch (index) {
      case 0:
        return Colors.amber;
      case 1:
        return Colors.grey[400]!;
      case 2:
        return Colors.brown[400]!;
      default:
        return Colors.blue;
    }
  }

  // ✅ เพิ่ม method
  Future<void> _exportReport(BuildContext context, WidgetRef ref) async {
    final summaryAsync = ref.read(salesSummaryProvider);
    final topProductsAsync = ref.read(topProductsProvider);

    summaryAsync.whenData((summary) async {
      topProductsAsync.whenData((products) async {
        final headers = ['รายการ', 'ค่า'];
        final rows = [
          ['ยอดขายรวม', '฿${summary.totalSales.toStringAsFixed(2)}'],
          ['จำนวนออเดอร์', '${summary.totalOrders}'],
          ['ยอดเฉลี่ย/ออเดอร์', '฿${summary.avgOrderValue.toStringAsFixed(2)}'],
          ['ส่วนลดรวม', '฿${summary.totalDiscount.toStringAsFixed(2)}'],
          [''],
          ['สินค้าขายดี Top 5', ''],
          ...products.map(
            (p) => [
              p.productName,
              '฿${p.totalSales.toStringAsFixed(2)} (${p.totalQuantity.toStringAsFixed(0)} ชิ้น)',
            ],
          ),
        ];

        final filepath = await CsvExport.exportToCsv(
          filename: 'sales_report',
          headers: headers,
          rows: rows,
        );

        if (filepath != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Export สำเร็จ: $filepath'),
              action: SnackBarAction(
                label: 'เปิด',
                onPressed: () {
                  // TODO: Open file
                },
              ),
            ),
          );
        } else if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Export ไม่สำเร็จ'),
              backgroundColor: Colors.red,
            ),
          );
        }
      });
    });
  }
}
