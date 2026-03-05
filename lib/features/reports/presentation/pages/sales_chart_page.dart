// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/sales_summary_model.dart';

// Daily Sales Provider
final dailySalesProvider = FutureProvider<List<DailySalesModel>>((ref) async {
  final apiClient = ref.read(apiClientProvider);
  
  try {
    final response = await apiClient.get('/api/reports/sales-daily?days=7');
    
    if (response.statusCode == 200) {
      final data = response.data['data'] as List;
      return data.map((json) => DailySalesModel.fromJson(json)).toList();
    }
    return [];
  } catch (e) {
    return [];
  }
});

class SalesChartPage extends ConsumerWidget {
  const SalesChartPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dailySalesAsync = ref.watch(dailySalesProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('กราฟยอดขาย'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(dailySalesProvider);
            },
          ),
        ],
      ),
      body: dailySalesAsync.when(
        data: (sales) => _buildChart(sales),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }
  
  Widget _buildChart(List<DailySalesModel> sales) {
    if (sales.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text('ยังไม่มีข้อมูล'),
          ],
        ),
      );
    }
    
    // เรียงข้อมูลตามวันที่
    sales.sort((a, b) => a.date.compareTo(b.date));
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ยอดขาย 7 วันล่าสุด',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          
          // Line Chart
          SizedBox(
            height: 300,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: true),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 60,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '฿${(value / 1000).toStringAsFixed(0)}k',
                          style: const TextStyle(fontSize: 10),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= 0 && value.toInt() < sales.length) {
                          final date = DateTime.parse(sales[value.toInt()].date);
                          return Text(
                            DateFormat('dd/MM').format(date),
                            style: const TextStyle(fontSize: 10),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: true),
                lineBarsData: [
                  LineChartBarData(
                    spots: sales.asMap().entries.map((entry) {
                      return FlSpot(
                        entry.key.toDouble(),
                        entry.value.sales,
                      );
                    }).toList(),
                    isCurved: true,
                    color: Colors.blue,
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.blue.withOpacity(0.3),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          
          // Data Table
          const Text(
            'ตารางข้อมูล',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          ...sales.reversed.map((sale) {
            final date = DateTime.parse(sale.date);
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  child: Text(DateFormat('dd').format(date)),
                ),
                title: Text(DateFormat('dd MMMM yyyy', 'th').format(date)),
                subtitle: Text('${sale.orders} ออเดอร์'),
                trailing: Text(
                  '฿${sale.sales.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}