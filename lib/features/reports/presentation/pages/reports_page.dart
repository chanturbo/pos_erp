// ignore_for_file: avoid_print
// reports_page.dart — Week 6: Full Reports Hub

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/client/api_client.dart';
import '../../data/models/sales_summary_model.dart';
import 'sales_chart_page.dart';
import '../../../../core/utils/csv_export.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final salesSummaryProvider =
    FutureProvider<SalesSummaryModel>((ref) async {
  final api = ref.read(apiClientProvider);
  final res = await api.get('/api/reports/sales-summary');
  if (res.statusCode == 200) {
    return SalesSummaryModel.fromJson(res.data['data']);
  }
  throw Exception('Failed to load summary');
});

final topProductsProvider =
    FutureProvider<List<TopProductModel>>((ref) async {
  final api = ref.read(apiClientProvider);
  final res = await api.get('/api/reports/top-products?limit=5');
  if (res.statusCode == 200) {
    return (res.data['data'] as List)
        .map((j) => TopProductModel.fromJson(j))
        .toList();
  }
  return [];
});

final topCustomersProvider =
    FutureProvider<List<TopCustomerModel>>((ref) async {
  final api = ref.read(apiClientProvider);
  final res = await api.get('/api/reports/top-customers?limit=5');
  if (res.statusCode == 200) {
    return (res.data['data'] as List)
        .map((j) => TopCustomerModel.fromJson(j))
        .toList();
  }
  return [];
});

final purchaseSummaryProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final api = ref.read(apiClientProvider);
  final res = await api.get('/api/reports/purchase-summary');
  if (res.statusCode == 200) return res.data['data'] as Map<String, dynamic>;
  return {};
});

final topSuppliersProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiClientProvider);
  final res =
      await api.get('/api/reports/purchase-by-supplier?limit=5');
  if (res.statusCode == 200) {
    return (res.data['data'] as List).cast<Map<String, dynamic>>();
  }
  return [];
});

final lowStockProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiClientProvider);
  final res = await api.get('/api/reports/low-stock?threshold=10');
  if (res.statusCode == 200) {
    return (res.data['data'] as List).cast<Map<String, dynamic>>();
  }
  return [];
});

final stockAgingProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiClientProvider);
  final res = await api.get('/api/reports/stock-aging?days=90');
  if (res.statusCode == 200) {
    return (res.data['data'] as List).cast<Map<String, dynamic>>();
  }
  return [];
});

final profitLossProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final api = ref.read(apiClientProvider);
  final res = await api.get('/api/reports/profit-loss');
  if (res.statusCode == 200) return res.data['data'] as Map<String, dynamic>;
  return {};
});

final arAgingProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiClientProvider);
  final res = await api.get('/api/reports/ar-aging');
  if (res.statusCode == 200) {
    return (res.data['data'] as List).cast<Map<String, dynamic>>();
  }
  return [];
});

final apAgingProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiClientProvider);
  final res = await api.get('/api/reports/ap-aging');
  if (res.statusCode == 200) {
    return (res.data['data'] as List).cast<Map<String, dynamic>>();
  }
  return [];
});

final cashFlowProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final api = ref.read(apiClientProvider);
  final res = await api.get('/api/reports/cash-flow');
  if (res.statusCode == 200) return res.data['data'] as Map<String, dynamic>;
  return {};
});

// ── Main Page ─────────────────────────────────────────────────────────────────

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _fmt = NumberFormat('#,##0.00', 'th_TH');
  final _fmtInt = NumberFormat('#,##0', 'th_TH');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refreshAll() {
    ref.invalidate(salesSummaryProvider);
    ref.invalidate(topProductsProvider);
    ref.invalidate(topCustomersProvider);
    ref.invalidate(purchaseSummaryProvider);
    ref.invalidate(topSuppliersProvider);
    ref.invalidate(lowStockProvider);
    ref.invalidate(stockAgingProvider);
    ref.invalidate(profitLossProvider);
    ref.invalidate(arAgingProvider);
    ref.invalidate(apAgingProvider);
    ref.invalidate(cashFlowProvider);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('รายงาน'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'กราฟยอดขาย',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SalesChartPage())),
          ),
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'Export CSV',
            onPressed: () => _exportReport(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshAll,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.shopping_cart), text: 'การขาย'),
            Tab(icon: Icon(Icons.shopping_bag), text: 'การซื้อ'),
            Tab(icon: Icon(Icons.warehouse), text: 'สต๊อก'),
            Tab(icon: Icon(Icons.account_balance), text: 'การเงิน'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSalesTab(),
          _buildPurchaseTab(),
          _buildInventoryTab(),
          _buildFinancialTab(),
        ],
      ),
    );
  }

  // ── Tab 1: Sales ───────────────────────────────────────────────────────────
  Widget _buildSalesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('สรุปยอดขาย', Icons.attach_money, Colors.green),
          ref.watch(salesSummaryProvider).when(
                data: _buildSalesSummaryCards,
                loading: _loadingWidget,
                error: (e, _) => _errorWidget('$e'),
              ),
          const SizedBox(height: 24),
          _sectionTitle('สินค้าขายดี Top 5', Icons.star, Colors.amber),
          ref.watch(topProductsProvider).when(
                data: _buildTopProducts,
                loading: _loadingWidget,
                error: (e, _) => _errorWidget('$e'),
              ),
          const SizedBox(height: 24),
          _sectionTitle('ลูกค้าซื้อบ่อย Top 5', Icons.people, Colors.purple),
          ref.watch(topCustomersProvider).when(
                data: _buildTopCustomers,
                loading: _loadingWidget,
                error: (e, _) => _errorWidget('$e'),
              ),
        ],
      ),
    );
  }

  Widget _buildSalesSummaryCards(SalesSummaryModel s) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 2.0,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: [
        _summaryCard('ยอดขายรวม', '฿${_fmt.format(s.totalSales)}',
            Icons.attach_money, Colors.green),
        _summaryCard('จำนวนออเดอร์', _fmtInt.format(s.totalOrders),
            Icons.shopping_cart, Colors.blue),
        _summaryCard('เฉลี่ย/ออเดอร์', '฿${_fmt.format(s.avgOrderValue)}',
            Icons.analytics, Colors.orange),
        _summaryCard('ส่วนลดรวม', '฿${_fmt.format(s.totalDiscount)}',
            Icons.discount, Colors.red),
      ],
    );
  }

  Widget _buildTopProducts(List<TopProductModel> products) {
    if (products.isEmpty) return _emptyWidget('ยังไม่มีข้อมูลการขาย');
    return Column(
      children: products.asMap().entries.map((e) {
        final p = e.value;
        return _rankCard(
          rank: e.key + 1,
          title: p.productName,
          subtitle:
              'ขาย ${_fmtInt.format(p.totalQuantity)} ชิ้น | ${p.orderCount} ออเดอร์',
          trailing: '฿${_fmt.format(p.totalSales)}',
          trailingColor: Colors.green,
        );
      }).toList(),
    );
  }

  Widget _buildTopCustomers(List<TopCustomerModel> customers) {
    if (customers.isEmpty) return _emptyWidget('ยังไม่มีข้อมูลลูกค้า');
    return Column(
      children: customers.asMap().entries.map((e) {
        final c = e.value;
        return _rankCard(
          rank: e.key + 1,
          title: c.customerName,
          subtitle: '${c.orderCount} ออเดอร์',
          trailing: '฿${_fmt.format(c.totalSales)}',
          trailingColor: Colors.blue,
        );
      }).toList(),
    );
  }

  // ── Tab 2: Purchase ────────────────────────────────────────────────────────
  Widget _buildPurchaseTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('สรุปการจัดซื้อ', Icons.shopping_bag, Colors.red),
          ref.watch(purchaseSummaryProvider).when(
                data: _buildPurchaseSummaryCards,
                loading: _loadingWidget,
                error: (e, _) => _errorWidget('$e'),
              ),
          const SizedBox(height: 24),
          _sectionTitle(
              'ซัพพลายเออร์สูงสุด Top 5', Icons.business, Colors.cyan),
          ref.watch(topSuppliersProvider).when(
                data: _buildTopSuppliers,
                loading: _loadingWidget,
                error: (e, _) => _errorWidget('$e'),
              ),
        ],
      ),
    );
  }

  Widget _buildPurchaseSummaryCards(Map<String, dynamic> data) {
    if (data.isEmpty) return _emptyWidget('ยังไม่มีข้อมูล');
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 2.0,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: [
        _summaryCard(
            'ใบสั่งซื้อทั้งหมด',
            _fmtInt.format(data['total_po'] ?? 0),
            Icons.receipt,
            Colors.red),
        _summaryCard(
            'มูลค่าสั่งซื้อรวม',
            '฿${_fmt.format((data['total_po_amount'] ?? 0.0) as num)}',
            Icons.payments,
            Colors.orange),
        _summaryCard(
            'ใบรับสินค้า',
            _fmtInt.format(data['total_gr'] ?? 0),
            Icons.inventory_2,
            Colors.blue),
      ],
    );
  }

  Widget _buildTopSuppliers(List<Map<String, dynamic>> list) {
    if (list.isEmpty) return _emptyWidget('ยังไม่มีข้อมูล');
    return Column(
      children: list.asMap().entries.map((e) {
        final s = e.value;
        return _rankCard(
          rank: e.key + 1,
          title: s['supplier_name'] as String? ?? '',
          subtitle: '${s['po_count']} PO',
          trailing: '฿${_fmt.format((s['total_amount'] as num?) ?? 0)}',
          trailingColor: Colors.red,
        );
      }).toList(),
    );
  }

  // ── Tab 3: Inventory ───────────────────────────────────────────────────────
  Widget _buildInventoryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
              'สินค้าใกล้หมด (≤10 ชิ้น)', Icons.warning, Colors.orange),
          ref.watch(lowStockProvider).when(
                data: _buildLowStock,
                loading: _loadingWidget,
                error: (e, _) => _errorWidget('$e'),
              ),
          const SizedBox(height: 24),
          _sectionTitle(
              'สินค้าค้างสต๊อก (≥90 วัน)', Icons.hourglass_empty, Colors.brown),
          ref.watch(stockAgingProvider).when(
                data: _buildStockAging,
                loading: _loadingWidget,
                error: (e, _) => _errorWidget('$e'),
              ),
        ],
      ),
    );
  }

  Widget _buildLowStock(List<Map<String, dynamic>> list) {
    if (list.isEmpty) {
      return _emptyWidget('สินค้าทุกรายการมีปริมาณเพียงพอ ✅');
    }
    return Column(
      children: list.map((item) {
        final qty = (item['current_stock'] as num).toDouble();
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          color: qty <= 0 ? Colors.red[50] : Colors.orange[50],
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: qty <= 0 ? Colors.red : Colors.orange,
              child: Text(
                qty <= 0 ? '0' : _fmtInt.format(qty),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(item['product_name'] as String? ?? ''),
            subtitle: Text(item['product_code'] as String? ?? ''),
            trailing: Text(
              item['base_unit'] as String? ?? '',
              style: TextStyle(
                  color: qty <= 0 ? Colors.red : Colors.orange,
                  fontWeight: FontWeight.bold),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStockAging(List<Map<String, dynamic>> list) {
    if (list.isEmpty) return _emptyWidget('ไม่มีสินค้าค้างสต๊อก ✅');
    return Column(
      children: list.map((item) {
        final days = item['days_no_movement'] as int? ?? 0;
        Color badgeColor;
        if (days > 180) {
          badgeColor = Colors.red;
        } else if (days > 90) {
          badgeColor = Colors.orange;
        } else {
          badgeColor = Colors.brown;
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha:0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${days}d',
                style: TextStyle(
                    color: badgeColor, fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(item['product_name'] as String? ?? ''),
            subtitle: Text(
                'คงเหลือ: ${_fmtInt.format((item['quantity'] as num?) ?? 0)} ${item['base_unit'] ?? ''}'),
            trailing: item['last_movement'] != null
                ? Text(
                    DateFormat('dd/MM/yy').format(
                        DateTime.parse(item['last_movement'] as String)),
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey[600]),
                  )
                : const Text('ไม่มีข้อมูล',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
          ),
        );
      }).toList(),
    );
  }

  // ── Tab 4: Financial ───────────────────────────────────────────────────────
  Widget _buildFinancialTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('กำไร-ขาดทุน (ปีนี้)', Icons.trending_up, Colors.green),
          ref.watch(profitLossProvider).when(
                data: _buildProfitLoss,
                loading: _loadingWidget,
                error: (e, _) => _errorWidget('$e'),
              ),
          const SizedBox(height: 24),
          _sectionTitle('กระแสเงินสด (ปีนี้)', Icons.water_drop, Colors.blue),
          ref.watch(cashFlowProvider).when(
                data: _buildCashFlow,
                loading: _loadingWidget,
                error: (e, _) => _errorWidget('$e'),
              ),
          const SizedBox(height: 24),
          _sectionTitle('ลูกหนี้คงค้าง (AR Aging)', Icons.person_outline,
              Colors.teal),
          ref.watch(arAgingProvider).when(
                data: (list) => _buildAgingTable(list, isAR: true),
                loading: _loadingWidget,
                error: (e, _) => _errorWidget('$e'),
              ),
          const SizedBox(height: 24),
          _sectionTitle(
              'เจ้าหนี้คงค้าง (AP Aging)', Icons.business, Colors.brown),
          ref.watch(apAgingProvider).when(
                data: (list) => _buildAgingTable(list, isAR: false),
                loading: _loadingWidget,
                error: (e, _) => _errorWidget('$e'),
              ),
        ],
      ),
    );
  }

  Widget _buildProfitLoss(Map<String, dynamic> data) {
    if (data.isEmpty) return _emptyWidget('ยังไม่มีข้อมูล');

    final revenue = (data['revenue'] as num?)?.toDouble() ?? 0;
    final netRevenue = (data['net_revenue'] as num?)?.toDouble() ?? 0;
    final cogs = (data['cogs'] as num?)?.toDouble() ?? 0;
    final grossProfit = (data['gross_profit'] as num?)?.toDouble() ?? 0;
    final grossMargin =
        (data['gross_margin_pct'] as num?)?.toDouble() ?? 0;
    final netProfit = (data['net_profit'] as num?)?.toDouble() ?? 0;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _plRow('รายได้รวม', revenue, Colors.green, bold: false),
            _plRow('(-) ส่วนลด', data['discount'] as num? ?? 0,
                Colors.red,
                isNegative: true),
            _plRow('รายได้สุทธิ', netRevenue, Colors.green, bold: true),
            const Divider(),
            _plRow('(-) ต้นทุนสินค้า (COGS)', cogs, Colors.red,
                isNegative: true),
            _plRow('กำไรขั้นต้น', grossProfit,
                grossProfit >= 0 ? Colors.green : Colors.red,
                bold: true),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('อัตรากำไรขั้นต้น',
                      style: TextStyle(color: Colors.grey[600])),
                  Text('${grossMargin.toStringAsFixed(1)}%',
                      style: TextStyle(
                          color: grossMargin >= 0 ? Colors.green : Colors.red,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            const Divider(),
            _plRow('กำไรสุทธิ', netProfit,
                netProfit >= 0 ? Colors.green : Colors.red,
                bold: true),
          ],
        ),
      ),
    );
  }

  Widget _plRow(String label, num value, Color color,
      {bool bold = false, bool isNegative = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontWeight:
                      bold ? FontWeight.bold : FontWeight.normal)),
          Text(
            '${isNegative ? '-' : ''}฿${_fmt.format(value.abs())}',
            style: TextStyle(
                color: color,
                fontWeight:
                    bold ? FontWeight.bold : FontWeight.normal,
                fontSize: bold ? 16 : 14),
          ),
        ],
      ),
    );
  }

  Widget _buildCashFlow(Map<String, dynamic> data) {
    if (data.isEmpty) return _emptyWidget('ยังไม่มีข้อมูล');

    final inflow = data['inflow'] as Map<String, dynamic>? ?? {};
    final outflow = data['outflow'] as Map<String, dynamic>? ?? {};
    final netCash = (data['net_cash_flow'] as num?)?.toDouble() ?? 0;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('รายรับ (Inflow)',
                style: TextStyle(
                    color: Colors.green[700],
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            _plRow('  ยอดขาย POS',
                (inflow['pos_sales'] as num?) ?? 0, Colors.green),
            _plRow('  รับชำระ AR',
                (inflow['ar_receipts'] as num?) ?? 0, Colors.green),
            _plRow('รวมรายรับ', (inflow['total'] as num?) ?? 0,
                Colors.green,
                bold: true),
            const Divider(),
            Text('รายจ่าย (Outflow)',
                style: TextStyle(
                    color: Colors.red[700],
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            _plRow('  จ่ายชำระ AP',
                (outflow['ap_payments'] as num?) ?? 0, Colors.red,
                isNegative: true),
            _plRow('รวมรายจ่าย', (outflow['total'] as num?) ?? 0,
                Colors.red,
                bold: true, isNegative: true),
            const Divider(),
            _plRow('กระแสเงินสดสุทธิ', netCash,
                netCash >= 0 ? Colors.green : Colors.red,
                bold: true),
          ],
        ),
      ),
    );
  }

  Widget _buildAgingTable(List<Map<String, dynamic>> list,
      {required bool isAR}) {
    if (list.isEmpty) {
      return _emptyWidget(isAR ? 'ไม่มีลูกหนี้คงค้าง ✅' : 'ไม่มีเจ้าหนี้คงค้าง ✅');
    }

    // สรุปตาม bucket
    final buckets = <String, double>{};
    for (final item in list) {
      final bucket = item['aging_bucket'] as String? ?? 'อื่นๆ';
      final outstanding = (item['outstanding'] as num?)?.toDouble() ?? 0;
      buckets[bucket] = (buckets[bucket] ?? 0) + outstanding;
    }

    final bucketOrder = [
      'ยังไม่ถึงกำหนด',
      '1-30 วัน',
      '31-60 วัน',
      '61-90 วัน',
      'เกิน 90 วัน',
    ];

    final totalOutstanding =
        list.fold<double>(0, (s, i) => s + ((i['outstanding'] as num?)?.toDouble() ?? 0));

    return Column(
      children: [
        // Summary by bucket
        Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                ...bucketOrder
                    .where((b) => buckets.containsKey(b))
                    .map((b) {
                  final color = _agingBucketColor(b);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Text(b),
                          ],
                        ),
                        Text('฿${_fmt.format(buckets[b]!)}',
                            style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  );
                }),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('รวมค้างชำระ',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('฿${_fmt.format(totalOutstanding)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.red)),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Detail list
        ...list.take(10).map((item) {
          final overdue = item['overdue_days'] as int? ?? 0;
          final outstanding =
              (item['outstanding'] as num?)?.toDouble() ?? 0;
          final name = isAR
              ? item['customer_name'] as String? ?? ''
              : item['supplier_name'] as String? ?? '';

          return Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              dense: true,
              title: Text(name),
              subtitle: Text(
                  '${item[isAR ? 'invoice_no' : 'invoice_no'] ?? ''} | ${item['aging_bucket']}'),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('฿${_fmt.format(outstanding)}',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _agingBucketColor(
                              item['aging_bucket'] as String? ?? ''))),
                  if (overdue > 0)
                    Text('เกิน $overdue วัน',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.red)),
                ],
              ),
            ),
          );
        }),
        if (list.length > 10)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '... และอีก ${list.length - 10} รายการ',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ),
      ],
    );
  }

  Color _agingBucketColor(String bucket) {
    switch (bucket) {
      case 'ยังไม่ถึงกำหนด':
        return Colors.green;
      case '1-30 วัน':
        return Colors.orange;
      case '31-60 วัน':
        return Colors.deepOrange;
      case '61-90 วัน':
        return Colors.red;
      case 'เกิน 90 วัน':
        return Colors.red[900]!;
      default:
        return Colors.grey;
    }
  }

  // ── Shared Widgets ─────────────────────────────────────────────────────────
  Widget _sectionTitle(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(title,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _summaryCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 3,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 6),
            Text(title,
                style:
                    const TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _rankCard({
    required int rank,
    required String title,
    required String subtitle,
    required String trailing,
    required Color trailingColor,
  }) {
    final rankColors = [
      Colors.amber,
      Colors.grey[400]!,
      Colors.brown[400]!,
      Colors.blue,
      Colors.blue,
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: rankColors[(rank - 1).clamp(0, 4)],
          child: Text('$rank',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        title: Text(title),
        subtitle: Text(subtitle,
            style: const TextStyle(fontSize: 12)),
        trailing: Text(trailing,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: trailingColor)),
      ),
    );
  }

  Widget _loadingWidget() =>
      const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );

  Widget _errorWidget(String msg) => Padding(
        padding: const EdgeInsets.all(12),
        child: Text('เกิดข้อผิดพลาด: $msg',
            style: const TextStyle(color: Colors.red)),
      );

  Widget _emptyWidget(String msg) => Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Text(msg,
              style: TextStyle(color: Colors.grey[500])),
        ),
      );

  // ── Export ─────────────────────────────────────────────────────────────────
  Future<void> _exportReport(BuildContext context) async {
    final summaryAsync = ref.read(salesSummaryProvider);
    final topAsync = ref.read(topProductsProvider);

    summaryAsync.whenData((s) async {
      topAsync.whenData((products) async {
        final headers = ['รายการ', 'ค่า'];
        final rows = [
          ['ยอดขายรวม', '฿${_fmt.format(s.totalSales)}'],
          ['จำนวนออเดอร์', '${s.totalOrders}'],
          ['ยอดเฉลี่ย/ออเดอร์', '฿${_fmt.format(s.avgOrderValue)}'],
          ['ส่วนลดรวม', '฿${_fmt.format(s.totalDiscount)}'],
          [''],
          ['สินค้าขายดี Top 5', ''],
          ...products.map((p) => [
                p.productName,
                '฿${_fmt.format(p.totalSales)} (${_fmtInt.format(p.totalQuantity)} ชิ้น)',
              ]),
        ];

        final path = await CsvExport.exportToCsv(
          filename: 'sales_report',
          headers: headers,
          rows: rows,
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                path != null ? 'Export สำเร็จ: $path' : 'Export ไม่สำเร็จ'),
            backgroundColor: path != null ? null : Colors.red,
          ));
        }
      });
    });
  }
}