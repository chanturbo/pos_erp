// ignore_for_file: avoid_print

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../../core/client/api_client.dart';
import '../../../../shared/pdf/pdf_report_button.dart';
import '../../data/models/sales_summary_model.dart';
import 'reports_pdf_report.dart';

class SalesChartDateFilter {
  final String preset;
  final DateTime? dateFrom;
  final DateTime? dateTo;

  const SalesChartDateFilter({
    required this.preset,
    this.dateFrom,
    this.dateTo,
  });

  String _formatDate(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  Map<String, dynamic> toQuery() {
    final query = <String, dynamic>{};
    if (dateFrom != null) query['start_date'] = _formatDate(dateFrom!);
    if (dateTo != null) query['end_date'] = _formatDate(dateTo!);
    return query;
  }

  @override
  bool operator ==(Object other) {
    return other is SalesChartDateFilter &&
        other.preset == preset &&
        other.dateFrom == dateFrom &&
        other.dateTo == dateTo;
  }

  @override
  int get hashCode => Object.hash(preset, dateFrom, dateTo);
}

final dailySalesProvider =
    FutureProvider.family<List<DailySalesModel>, SalesChartDateFilter>((
      ref,
      filter,
    ) async {
      final apiClient = ref.read(apiClientProvider);

      try {
        final response = await apiClient.get(
          '/api/reports/sales-daily',
          queryParameters: filter.toQuery(),
        );

        if (response.statusCode == 200) {
          final data = response.data['data'] as List;
          return data.map((json) => DailySalesModel.fromJson(json)).toList();
        }
        return [];
      } catch (e) {
        return [];
      }
    });

class SalesChartPage extends ConsumerStatefulWidget {
  const SalesChartPage({super.key});

  @override
  ConsumerState<SalesChartPage> createState() => _SalesChartPageState();
}

class _SalesChartPageState extends ConsumerState<SalesChartPage> {
  final _money = NumberFormat('#,##0.00', 'th_TH');
  String _datePreset = 'THIS_YEAR';
  DateTime? _dateFrom;
  DateTime? _dateTo;

  SalesChartDateFilter get _filter {
    final now = DateTime.now();
    switch (_datePreset) {
      case 'TODAY':
        final today = DateTime(now.year, now.month, now.day);
        return SalesChartDateFilter(
          preset: _datePreset,
          dateFrom: today,
          dateTo: today,
        );
      case 'LAST_7_DAYS':
        return SalesChartDateFilter(
          preset: _datePreset,
          dateFrom: DateTime(
            now.year,
            now.month,
            now.day,
          ).subtract(const Duration(days: 6)),
          dateTo: DateTime(now.year, now.month, now.day),
        );
      case 'LAST_30_DAYS':
        return SalesChartDateFilter(
          preset: _datePreset,
          dateFrom: DateTime(
            now.year,
            now.month,
            now.day,
          ).subtract(const Duration(days: 29)),
          dateTo: DateTime(now.year, now.month, now.day),
        );
      case 'THIS_MONTH':
        return SalesChartDateFilter(
          preset: _datePreset,
          dateFrom: DateTime(now.year, now.month, 1),
          dateTo: DateTime(now.year, now.month, now.day),
        );
      case 'THIS_YEAR':
        return SalesChartDateFilter(
          preset: _datePreset,
          dateFrom: DateTime(now.year, 1, 1),
          dateTo: DateTime(now.year, now.month, now.day),
        );
      case 'CUSTOM':
        return SalesChartDateFilter(
          preset: _datePreset,
          dateFrom: _dateFrom,
          dateTo: _dateTo,
        );
      default:
        return const SalesChartDateFilter(preset: 'ALL');
    }
  }

  Future<void> _pickDate(bool isFrom) async {
    final now = DateTime.now();
    final initial = isFrom ? (_dateFrom ?? now) : (_dateTo ?? _dateFrom ?? now);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;
    setState(() {
      _datePreset = 'CUSTOM';
      if (isFrom) {
        _dateFrom = picked;
      } else {
        _dateTo = picked;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final filter = _filter;
    final dailySalesAsync = ref.watch(dailySalesProvider(filter));

    return Scaffold(
      appBar: AppBar(
        title: const Text('กราฟยอดขาย'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: PdfReportButton(
              emptyMessage: 'ไม่มีข้อมูลกราฟยอดขาย',
              title: 'รายงานกราฟยอดขาย',
              filename: () => PdfFilename.generate('sales_chart_report'),
              buildPdf: () => _buildChartPdf(filter),
              hasData: true,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(dailySalesProvider(filter)),
          ),
        ],
      ),
      body: dailySalesAsync.when(
        data: (sales) => _buildBody(sales, filter),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Future<pw.Document> _buildChartPdf(SalesChartDateFilter filter) async {
    final sales = await ref.read(dailySalesProvider(filter).future);
    return ReportsPdfBuilder.buildSalesChart(
      dailySales: sales,
      dateFrom: filter.dateFrom,
      dateTo: filter.dateTo,
    );
  }

  Widget _buildBody(List<DailySalesModel> sales, SalesChartDateFilter filter) {
    final sortedSales = [...sales]..sort((a, b) => a.date.compareTo(b.date));
    final totalSales = sortedSales.fold<double>(
      0,
      (sum, item) => sum + item.sales,
    );
    final totalOrders = sortedSales.fold<int>(
      0,
      (sum, item) => sum + item.orders,
    );
    final avgSales = sortedSales.isEmpty
        ? 0.0
        : totalSales / sortedSales.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _filterBar(),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _summaryCard('จำนวนวัน', '${sortedSales.length}', Colors.blue),
              _summaryCard(
                'ยอดขายรวม',
                '฿${_money.format(totalSales)}',
                Colors.green,
              ),
              _summaryCard('ออเดอร์รวม', '$totalOrders', Colors.orange),
              _summaryCard(
                'เฉลี่ยต่อวัน',
                '฿${_money.format(avgSales)}',
                Colors.purple,
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (sortedSales.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Column(
                  children: [
                    Icon(Icons.bar_chart, size: 72, color: Colors.grey),
                    SizedBox(height: 12),
                    Text('ยังไม่มีข้อมูลในช่วงวันที่ที่เลือก'),
                  ],
                ),
              ),
            )
          else ...[
            Text(
              _periodLabel(filter),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
                child: SizedBox(height: 320, child: _buildChart(sortedSales)),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'ตารางข้อมูล',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            ...sortedSales.reversed.map((sale) {
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
                    '฿${_money.format(sale.sales)}',
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
        ],
      ),
    );
  }

  Widget _buildChart(List<DailySalesModel> sales) {
    return LineChart(
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
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      DateFormat('dd/MM').format(date),
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                }
                return const SizedBox.shrink();
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
              return FlSpot(entry.key.toDouble(), entry.value.sales);
            }).toList(),
            isCurved: true,
            color: Colors.blue,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.blue.withValues(alpha: 0.18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterBar() {
    const options = [
      ('ALL', 'ทั้งหมด'),
      ('TODAY', 'วันนี้'),
      ('LAST_7_DAYS', '7 วัน'),
      ('LAST_30_DAYS', '30 วัน'),
      ('THIS_MONTH', 'เดือนนี้'),
      ('THIS_YEAR', 'ปีนี้'),
      ('CUSTOM', 'กำหนดเอง'),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ประเภทวันที่',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'ใช้กับกราฟยอดขายและรายงาน PDF ของหน้านี้',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: options
                  .map(
                    (option) => ChoiceChip(
                      label: Text(option.$2),
                      selected: _datePreset == option.$1,
                      onSelected: (_) {
                        setState(() {
                          _datePreset = option.$1;
                          if (option.$1 != 'CUSTOM') {
                            _dateFrom = null;
                            _dateTo = null;
                          }
                        });
                      },
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _dateChip(
                  label: _dateFrom != null
                      ? 'ตั้งแต่: ${DateFormat('dd/MM/yyyy').format(_dateFrom!)}'
                      : 'ตั้งแต่วันที่',
                  active: _dateFrom != null,
                  onTap: () => _pickDate(true),
                  onClear: _dateFrom == null
                      ? null
                      : () {
                          setState(() {
                            _datePreset = 'CUSTOM';
                            _dateFrom = null;
                          });
                        },
                ),
                _dateChip(
                  label: _dateTo != null
                      ? 'ถึง: ${DateFormat('dd/MM/yyyy').format(_dateTo!)}'
                      : 'ถึงวันที่',
                  active: _dateTo != null,
                  onTap: () => _pickDate(false),
                  onClear: _dateTo == null
                      ? null
                      : () {
                          setState(() {
                            _datePreset = 'CUSTOM';
                            _dateTo = null;
                          });
                        },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateChip({
    required String label,
    required bool active,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: active ? Colors.orange.withValues(alpha: 0.10) : null,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: active ? Colors.orange.shade300 : Colors.grey.shade400,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 16,
              color: active ? Colors.orange.shade700 : Colors.grey.shade700,
            ),
            const SizedBox(width: 8),
            Text(label),
            if (onClear != null) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.close, size: 16),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _summaryCard(String label, String value, Color color) {
    return SizedBox(
      width: 220,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _periodLabel(SalesChartDateFilter filter) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    if (filter.dateFrom != null && filter.dateTo != null) {
      return 'ช่วงเวลา: ${dateFormat.format(filter.dateFrom!)} - ${dateFormat.format(filter.dateTo!)}';
    }
    if (filter.dateFrom != null) {
      return 'ช่วงเวลา: ตั้งแต่ ${dateFormat.format(filter.dateFrom!)}';
    }
    if (filter.dateTo != null) {
      return 'ช่วงเวลา: ถึง ${dateFormat.format(filter.dateTo!)}';
    }
    return 'ช่วงเวลา: ทั้งหมด';
  }
}
