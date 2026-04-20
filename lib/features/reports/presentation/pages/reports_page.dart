// ignore_for_file: avoid_print
// reports_page.dart — Week 6: Full Reports Hub

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../../core/client/api_client.dart';
import '../../../../shared/pdf/pdf_report_button.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/utils/responsive_utils.dart';
import '../../../../shared/widgets/escape_pop_scope.dart';
import '../../../../shared/widgets/mobile_home_button.dart';
import '../../../../shared/permissions/app_permissions.dart';
import '../../data/models/sales_summary_model.dart';
import 'reports_pdf_report.dart';
import 'sales_chart_page.dart';
import 'customer_purchase_summary_page.dart';
import 'customer_dividend_summary_page.dart';
import 'customer_dividend_run_list_page.dart';
import '../../../../core/utils/csv_export.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/services/license/license_models.dart';
import '../../../../core/services/license/license_service.dart';
import '../../../branches/presentation/providers/branch_provider.dart';
import '../../../purchases/presentation/pages/purchase_order_list_page.dart';
import '../../../purchases/presentation/pages/goods_receipt_list_page.dart';
import '../../../inventory/presentation/pages/stock_balance_page.dart';
import '../../../inventory/presentation/pages/stock_movement_history_page.dart';
import '../../../products/presentation/pages/product_list_page.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final salesSummaryProvider = FutureProvider<SalesSummaryModel>((ref) async {
  final api = ref.read(apiClientProvider);
  final res = await api.get('/api/reports/sales-summary');
  if (res.statusCode == 200) {
    return SalesSummaryModel.fromJson(res.data['data']);
  }
  throw Exception('Failed to load summary');
});

final topProductsProvider = FutureProvider<List<TopProductModel>>((ref) async {
  final api = ref.read(apiClientProvider);
  final res = await api.get('/api/reports/top-products?limit=5');
  if (res.statusCode == 200) {
    return (res.data['data'] as List)
        .map((j) => TopProductModel.fromJson(j))
        .toList();
  }
  return [];
});

final topCustomersProvider = FutureProvider<List<TopCustomerModel>>((
  ref,
) async {
  final api = ref.read(apiClientProvider);
  final res = await api.get('/api/reports/top-customers?limit=5');
  if (res.statusCode == 200) {
    return (res.data['data'] as List)
        .map((j) => TopCustomerModel.fromJson(j))
        .toList();
  }
  return [];
});

final purchaseSummaryProvider = FutureProvider<Map<String, dynamic>>((
  ref,
) async {
  final api = ref.read(apiClientProvider);
  final res = await api.get('/api/reports/purchase-summary');
  if (res.statusCode == 200) return res.data['data'] as Map<String, dynamic>;
  return {};
});

enum _ReportsAppBarAction { salesChart, exportCsv, exportPdf }

final topSuppliersProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final api = ref.read(apiClientProvider);
  final res = await api.get('/api/reports/purchase-by-supplier?limit=5');
  if (res.statusCode == 200) {
    return (res.data['data'] as List).cast<Map<String, dynamic>>();
  }
  return [];
});

final purchaseCategoryProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final api = ref.read(apiClientProvider);
  final res = await api.get('/api/reports/purchase-by-category');
  if (res.statusCode == 200) {
    return (res.data['data'] as List).cast<Map<String, dynamic>>();
  }
  return [];
});

final lowStockProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final api = ref.read(apiClientProvider);
  final res = await api.get('/api/reports/low-stock?threshold=10');
  if (res.statusCode == 200) {
    return (res.data['data'] as List).cast<Map<String, dynamic>>();
  }
  return [];
});

final stockMovementProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final api = ref.read(apiClientProvider);
  final res = await api.get('/api/reports/stock-movement?days=30');
  if (res.statusCode == 200) {
    return (res.data['data'] as List).cast<Map<String, dynamic>>();
  }
  return [];
});

final stockAgingProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final api = ref.read(apiClientProvider);
  final res = await api.get('/api/reports/stock-aging?days=90');
  if (res.statusCode == 200) {
    return (res.data['data'] as List).cast<Map<String, dynamic>>();
  }
  return [];
});

final restaurantReportProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final api = ref.read(apiClientProvider);
  final branchId = ref.watch(selectedBranchProvider)?.branchId;
  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
  final query = branchId != null && branchId.isNotEmpty
      ? '/api/kitchen/analytics?date=$today&branch_id=$branchId'
      : '/api/kitchen/analytics?date=$today';
  final res = await api.get(query);
  if (res.statusCode == 200) return res.data['data'] as Map<String, dynamic>;
  return {};
});

class FinancialDateFilter {
  final String preset;
  final DateTime? dateFrom;
  final DateTime? dateTo;

  const FinancialDateFilter({required this.preset, this.dateFrom, this.dateTo});

  String _formatDate(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  Map<String, dynamic> toQuery() {
    final query = <String, dynamic>{};
    if (dateFrom != null) query['start_date'] = _formatDate(dateFrom!);
    if (dateTo != null) query['end_date'] = _formatDate(dateTo!);
    return query;
  }

  @override
  bool operator ==(Object other) {
    return other is FinancialDateFilter &&
        other.preset == preset &&
        other.dateFrom == dateFrom &&
        other.dateTo == dateTo;
  }

  @override
  int get hashCode => Object.hash(preset, dateFrom, dateTo);
}

final profitLossProvider =
    FutureProvider.family<Map<String, dynamic>, FinancialDateFilter>((
      ref,
      filter,
    ) async {
      final api = ref.read(apiClientProvider);
      final res = await api.get(
        '/api/reports/profit-loss',
        queryParameters: filter.toQuery(),
      );
      if (res.statusCode == 200) {
        return res.data['data'] as Map<String, dynamic>;
      }
      return {};
    });

final arAgingProvider =
    FutureProvider.family<List<Map<String, dynamic>>, FinancialDateFilter>((
      ref,
      filter,
    ) async {
      final api = ref.read(apiClientProvider);
      final res = await api.get(
        '/api/reports/ar-aging',
        queryParameters: filter.toQuery(),
      );
      if (res.statusCode == 200) {
        return (res.data['data'] as List).cast<Map<String, dynamic>>();
      }
      return [];
    });

final apAgingProvider =
    FutureProvider.family<List<Map<String, dynamic>>, FinancialDateFilter>((
      ref,
      filter,
    ) async {
      final api = ref.read(apiClientProvider);
      final res = await api.get(
        '/api/reports/ap-aging',
        queryParameters: filter.toQuery(),
      );
      if (res.statusCode == 200) {
        return (res.data['data'] as List).cast<Map<String, dynamic>>();
      }
      return [];
    });

final cashFlowProvider =
    FutureProvider.family<Map<String, dynamic>, FinancialDateFilter>((
      ref,
      filter,
    ) async {
      final api = ref.read(apiClientProvider);
      final res = await api.get(
        '/api/reports/cash-flow',
        queryParameters: filter.toQuery(),
      );
      if (res.statusCode == 200) {
        return res.data['data'] as Map<String, dynamic>;
      }
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
  int _currentTab = 0;
  final _fmt = NumberFormat('#,##0.00', 'th_TH');
  final _fmtInt = NumberFormat('#,##0', 'th_TH');
  final _fmtQty = NumberFormat('#,##0.##', 'th_TH');
  String _financialDatePreset = 'THIS_YEAR';
  DateTime? _financialDateFrom;
  DateTime? _financialDateTo;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging &&
          _currentTab != _tabController.index) {
        setState(() => _currentTab = _tabController.index);
      }
    });
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
    ref.invalidate(purchaseCategoryProvider);
    ref.invalidate(lowStockProvider);
    ref.invalidate(stockMovementProvider);
    ref.invalidate(stockAgingProvider);
    ref.invalidate(profitLossProvider(_financialFilter));
    ref.invalidate(arAgingProvider(_financialFilter));
    ref.invalidate(apAgingProvider(_financialFilter));
    ref.invalidate(cashFlowProvider(_financialFilter));
  }

  FinancialDateFilter get _financialFilter {
    final now = DateTime.now();
    switch (_financialDatePreset) {
      case 'TODAY':
        final today = DateTime(now.year, now.month, now.day);
        return FinancialDateFilter(
          preset: _financialDatePreset,
          dateFrom: today,
          dateTo: today,
        );
      case 'LAST_7_DAYS':
        return FinancialDateFilter(
          preset: _financialDatePreset,
          dateFrom: DateTime(
            now.year,
            now.month,
            now.day,
          ).subtract(const Duration(days: 6)),
          dateTo: DateTime(now.year, now.month, now.day),
        );
      case 'LAST_30_DAYS':
        return FinancialDateFilter(
          preset: _financialDatePreset,
          dateFrom: DateTime(
            now.year,
            now.month,
            now.day,
          ).subtract(const Duration(days: 29)),
          dateTo: DateTime(now.year, now.month, now.day),
        );
      case 'THIS_MONTH':
        return FinancialDateFilter(
          preset: _financialDatePreset,
          dateFrom: DateTime(now.year, now.month, 1),
          dateTo: DateTime(now.year, now.month, now.day),
        );
      case 'THIS_YEAR':
        return FinancialDateFilter(
          preset: _financialDatePreset,
          dateFrom: DateTime(now.year, 1, 1),
          dateTo: DateTime(now.year, now.month, now.day),
        );
      case 'CUSTOM':
        return FinancialDateFilter(
          preset: _financialDatePreset,
          dateFrom: _financialDateFrom,
          dateTo: _financialDateTo,
        );
      default:
        return const FinancialDateFilter(preset: 'ALL');
    }
  }

  Future<void> _pickFinancialDate(bool isFrom) async {
    final now = DateTime.now();
    final initial = isFrom
        ? (_financialDateFrom ?? now)
        : (_financialDateTo ?? _financialDateFrom ?? now);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;
    setState(() {
      _financialDatePreset = 'CUSTOM';
      if (isFrom) {
        _financialDateFrom = picked;
      } else {
        _financialDateTo = picked;
      }
    });
  }

  bool _canAccessDividend() {
    final roleId = ref.watch(authProvider).user?.roleId?.toUpperCase();
    final permData = ref.watch(rolePermissionsProvider).value;
    return roleId == 'ADMIN' ||
        ((permData?[roleId] ?? defaultRolePermissions[roleId] ?? [])
            .contains(AppPermission.customerDividend));
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompactDesktop = context.isDesktopOrWider && screenWidth < 1180;
    final isTightDesktop = context.isDesktopOrWider && screenWidth < 1080;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topBarBg = isDark ? AppTheme.navyDark : AppTheme.navy;
    final tabFontSize = (context.isMobile || isTightDesktop) ? 12.0 : 13.0;

    return EscapePopScope(
      child: Scaffold(
        backgroundColor: AppTheme.surfaceColorOf(context),
        body: Column(
          children: [
            // ── Custom TopBar (product_list style) ─────────────
            Container(
              color: topBarBg,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // Home button (mobile)
                  if (context.isMobile) ...[
                    InkWell(
                      onTap: () => navigateToMobileHome(context),
                      borderRadius: BorderRadius.circular(8),
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.home_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  // Back button (desktop, if can pop)
                  if (!context.isMobile && canPop) ...[
                    InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(8),
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.arrow_back, color: Colors.white, size: 20),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  // Page icon
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.28),
                      ),
                    ),
                    child: const Icon(
                      Icons.assessment_outlined,
                      color: AppTheme.primaryLight,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Title
                  const Text(
                    'รายงาน',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  // Action buttons
                  if (!isCompactDesktop) ...[
                    IconButton(
                      icon: const Icon(Icons.bar_chart, color: Colors.white),
                      tooltip: 'กราฟยอดขาย',
                      onPressed: () => _openSalesChart(context),
                    ),
                    IconButton(
                      icon: const Icon(Icons.file_download, color: Colors.white),
                      tooltip: 'Export CSV',
                      onPressed: () => _exportReport(context),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      tooltip: 'รีเฟรชข้อมูล',
                      onPressed: _refreshAll,
                    ),
                    _buildPdfAction(),
                  ] else ...[
                    PopupMenuButton<_ReportsAppBarAction>(
                      tooltip: 'การทำงานเพิ่มเติม',
                      iconSize: isTightDesktop ? 20 : 22,
                      icon: const Icon(Icons.more_vert, color: Colors.white),
                      onSelected: (action) =>
                          _handleAppBarAction(context, action),
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: _ReportsAppBarAction.salesChart,
                          child: ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.bar_chart),
                            title: Text('กราฟยอดขาย'),
                          ),
                        ),
                        PopupMenuItem(
                          value: _ReportsAppBarAction.exportCsv,
                          child: ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.file_download),
                            title: Text('Export CSV'),
                          ),
                        ),
                        PopupMenuItem(
                          value: _ReportsAppBarAction.exportPdf,
                          child: ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.picture_as_pdf_outlined),
                            title: Text('Export PDF'),
                          ),
                        ),
                      ],
                    ),
                  ],
                  // Badge (ท้ายสุด)
                  if (!isCompactDesktop) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AppTheme.primary.withValues(alpha: 0.5),
                        ),
                      ),
                      child: const Text(
                        'Reports',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryLight,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // ── TabBar ────────────────────────────────────────
            Container(
              color: topBarBg,
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white54,
                indicatorColor: AppTheme.primary,
                indicatorWeight: 3,
                dividerColor: Colors.transparent,
                labelStyle: TextStyle(
                  fontSize: tabFontSize,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: TextStyle(
                  fontSize: tabFontSize,
                  fontWeight: FontWeight.w500,
                ),
                tabs: const [
                  Tab(icon: Icon(Icons.shopping_cart), text: 'การขาย'),
                  Tab(icon: Icon(Icons.shopping_bag), text: 'การซื้อ'),
                  Tab(icon: Icon(Icons.warehouse), text: 'สต๊อก'),
                  Tab(icon: Icon(Icons.account_balance), text: 'การเงิน'),
                  Tab(icon: Icon(Icons.restaurant), text: 'ร้านอาหาร'),
                ],
              ),
            ),
            // ── Tab content ───────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _tabShell(context, _buildSalesTab()),
                  _tabShell(context, _buildPurchaseTab()),
                  _tabShell(context, _buildInventoryTab()),
                  _tabShell(context, _buildFinancialTab()),
                  _tabShell(context, _buildRestaurantTab()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabShell(BuildContext context, Widget child) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: context.contentMaxWidth),
        child: child,
      ),
    );
  }

  Widget _buildPdfAction() {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: PdfReportButton(
        emptyMessage: 'ไม่มีข้อมูลสำหรับสร้างรายงาน',
        title: _pdfTitle,
        filename: () => PdfFilename.generate(_pdfFilenamePrefix),
        buildPdf: _buildCurrentTabPdf,
        hasData: true,
      ),
    );
  }

  void _openSalesChart(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SalesChartPage()),
    );
  }

  void _handleAppBarAction(BuildContext context, _ReportsAppBarAction action) {
    switch (action) {
      case _ReportsAppBarAction.salesChart:
        _openSalesChart(context);
        break;
      case _ReportsAppBarAction.exportCsv:
        _exportReport(context);
        break;
      case _ReportsAppBarAction.exportPdf:
        _showPdfExportSheet(context);
        break;
    }
  }

  void _showPdfExportSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ส่งออกรายงาน',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'เลือกส่งออกรายงานของแท็บปัจจุบันเป็น PDF',
                  style: TextStyle(fontSize: 13, color: Color(0xFF666666)),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _buildPdfAction(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String get _pdfTitle {
    switch (_currentTab) {
      case 0:
        return 'รายงานภาพรวมการขาย';
      case 1:
        return 'รายงานภาพรวมการซื้อ';
      case 2:
        return 'รายงานภาพรวมสต๊อก';
      case 3:
        return 'รายงานภาพรวมการเงิน';
      default:
        return 'รายงาน';
    }
  }

  String get _pdfFilenamePrefix {
    switch (_currentTab) {
      case 0:
        return 'reports_sales_overview';
      case 1:
        return 'reports_purchase_overview';
      case 2:
        return 'reports_inventory_overview';
      case 3:
        return 'reports_financial_overview';
      default:
        return 'reports_overview';
    }
  }

  Future<pw.Document> _buildCurrentTabPdf() async {
    switch (_currentTab) {
      case 0:
        final summary = await ref.read(salesSummaryProvider.future);
        final topProducts = await ref.read(topProductsProvider.future);
        final topCustomers = await ref.read(topCustomersProvider.future);
        return ReportsPdfBuilder.buildSales(
          summary: summary,
          topProducts: topProducts,
          topCustomers: topCustomers,
        );
      case 1:
        final summary = await ref.read(purchaseSummaryProvider.future);
        final topSuppliers = await ref.read(topSuppliersProvider.future);
        final purchaseCategories = await ref.read(
          purchaseCategoryProvider.future,
        );
        return ReportsPdfBuilder.buildPurchase(
          summary: summary,
          topSuppliers: topSuppliers,
          purchaseCategories: purchaseCategories,
        );
      case 2:
        final lowStock = await ref.read(lowStockProvider.future);
        final stockMovement = await ref.read(stockMovementProvider.future);
        final stockAging = await ref.read(stockAgingProvider.future);
        return ReportsPdfBuilder.buildInventory(
          lowStock: lowStock,
          stockMovement: stockMovement,
          stockAging: stockAging,
        );
      case 3:
        final filter = _financialFilter;
        final profitLoss = await ref.read(profitLossProvider(filter).future);
        final cashFlow = await ref.read(cashFlowProvider(filter).future);
        final arAging = await ref.read(arAgingProvider(filter).future);
        final apAging = await ref.read(apAgingProvider(filter).future);
        return ReportsPdfBuilder.buildFinancial(
          profitLoss: profitLoss,
          cashFlow: cashFlow,
          arAging: arAging,
          apAging: apAging,
          dateFrom: filter.dateFrom,
          dateTo: filter.dateTo,
        );
      default:
        final summary = await ref.read(salesSummaryProvider.future);
        final topProducts = await ref.read(topProductsProvider.future);
        final topCustomers = await ref.read(topCustomersProvider.future);
        return ReportsPdfBuilder.buildSales(
          summary: summary,
          topProducts: topProducts,
          topCustomers: topCustomers,
        );
    }
  }

  // ── Tab 5: Restaurant ─────────────────────────────────────────────────────
  Widget _buildRestaurantTab() {
    return SingleChildScrollView(
      padding: context.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('สรุปห้องครัววันนี้', Icons.restaurant, Colors.orange),
          ref.watch(restaurantReportProvider).when(
                data: _buildRestaurantSummaryCards,
                loading: _loadingWidget,
                error: (e, _) => _errorWidget('$e'),
              ),
          const SizedBox(height: 24),
          _sectionTitle('เวลาเตรียมอาหารต่อ Station', Icons.timer, Colors.teal),
          ref.watch(restaurantReportProvider).when(
                data: _buildStationPrepTime,
                loading: _loadingWidget,
                error: (e, _) => _errorWidget('$e'),
              ),
          const SizedBox(height: 24),
          _sectionTitle('เมนูยอดนิยมวันนี้ Top 10', Icons.star, Colors.amber),
          ref.watch(restaurantReportProvider).when(
                data: _buildTopMenuItems,
                loading: _loadingWidget,
                error: (e, _) => _errorWidget('$e'),
              ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildRestaurantSummaryCards(Map<String, dynamic> data) {
    if (data.isEmpty) return _emptyWidget('ยังไม่มีข้อมูลวันนี้');
    final totalOrders = data['total_orders'] as int? ?? 0;
    final totalItems = data['total_items'] as int? ?? 0;
    final avgPrepMins = (data['avg_prep_time_minutes'] as num?)?.toDouble() ?? 0;
    final avgOrderMins = (data['avg_order_time_minutes'] as num?)?.toDouble() ?? 0;

    return GridView.count(
      crossAxisCount: context.isMobile ? 2 : 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: context.isMobile ? 1.8 : 2.2,
      children: [
        _summaryCard('ออเดอร์วันนี้', '$totalOrders', Icons.receipt_long, Colors.blue),
        _summaryCard('รายการอาหาร', '$totalItems', Icons.fastfood, Colors.orange),
        _summaryCard(
          'เตรียมเฉลี่ย',
          avgPrepMins > 0 ? '${avgPrepMins.toStringAsFixed(1)} นาที' : '-',
          Icons.timer,
          Colors.teal,
        ),
        _summaryCard(
          'เสร็จเฉลี่ย/ออเดอร์',
          avgOrderMins > 0 ? '${avgOrderMins.toStringAsFixed(1)} นาที' : '-',
          Icons.hourglass_bottom,
          Colors.purple,
        ),
      ],
    );
  }

  Widget _buildStationPrepTime(Map<String, dynamic> data) {
    if (data.isEmpty) return _emptyWidget('ยังไม่มีข้อมูล');
    final byStation = (data['avg_prep_by_station'] as Map<String, dynamic>?) ?? {};
    final itemsByStation = (data['items_by_station'] as Map<String, dynamic>?) ?? {};
    if (byStation.isEmpty) return _emptyWidget('ยังไม่มีข้อมูลเวลาต่อ station');

    final maxMins = byStation.values
        .map((v) => (v as num).toDouble())
        .fold(0.0, (a, b) => a > b ? a : b);

    return _panelCard(
      child: Padding(
        padding: context.cardPadding,
        child: Column(
          children: byStation.entries.map((e) {
            final station = e.key;
            final mins = (e.value as num).toDouble();
            final count = (itemsByStation[station] as int?) ?? 0;
            final fraction = maxMins > 0 ? mins / maxMins : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _stationLabel(station),
                          style: _cardTitleStyle(fontSize: 12),
                        ),
                      ),
                      Text(
                        '${mins.toStringAsFixed(1)} นาที  ($count รายการ)',
                        style: _cardSubtitleStyle(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: fraction,
                      minHeight: 8,
                      backgroundColor: Colors.grey.shade200,
                      color: _stationColor(station),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTopMenuItems(Map<String, dynamic> data) {
    if (data.isEmpty) return _emptyWidget('ยังไม่มีข้อมูล');
    final topItems = (data['top_items'] as List<dynamic>?) ?? [];
    if (topItems.isEmpty) return _emptyWidget('ยังไม่มีข้อมูลเมนู');

    return Column(
      children: topItems.asMap().entries.map((entry) {
        final rank = entry.key + 1;
        final item = entry.value as Map<String, dynamic>;
        return _rankCard(
          rank: rank,
          title: item['product_name'] as String? ?? '',
          subtitle: 'อันดับ $rank',
          trailing: '${item['count']} รายการ',
          trailingColor: rank <= 3 ? Colors.orange : AppTheme.primaryColor,
        );
      }).toList(),
    );
  }

  String _stationLabel(String station) {
    switch (station.toLowerCase()) {
      case 'kitchen':
        return 'ครัวหลัก';
      case 'bar':
        return 'บาร์/เครื่องดื่ม';
      case 'dessert':
        return 'ของหวาน';
      case 'cashier':
        return 'แคชเชียร์';
      default:
        return station;
    }
  }

  Color _stationColor(String station) {
    switch (station.toLowerCase()) {
      case 'kitchen':
        return Colors.orange;
      case 'bar':
        return Colors.blue;
      case 'dessert':
        return Colors.pink;
      case 'cashier':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  // ── Tab 1: Sales ───────────────────────────────────────────────────────────
  Widget _buildSalesTab() {
    final canAccessDividend = _canAccessDividend();
    return SingleChildScrollView(
      padding: context.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('สรุปยอดขาย', Icons.attach_money, Colors.green),
          ref
              .watch(salesSummaryProvider)
              .when(
                data: _buildSalesSummaryCards,
                loading: _loadingWidget,
                error: (e, _) => _errorWidget('$e'),
              ),
          const SizedBox(height: 24),
          _sectionTitle('สินค้าขายดี Top 5', Icons.star, Colors.amber),
          ref
              .watch(topProductsProvider)
              .when(
                data: _buildTopProducts,
                loading: _loadingWidget,
                error: (e, _) => _errorWidget('$e'),
              ),
          const SizedBox(height: 24),
          _sectionTitle('ลูกค้าซื้อบ่อย Top 5', Icons.people, Colors.purple),
          ref
              .watch(topCustomersProvider)
              .when(
                data: _buildTopCustomers,
                loading: _loadingWidget,
                error: (e, _) => _errorWidget('$e'),
              ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const CustomerPurchaseSummaryPage(),
                ),
              ),
              icon: const Icon(Icons.bar_chart, size: 18),
              label: const Text('ดูรายงานสรุปยอดซื้อทุกลูกค้า'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.purple,
                side: const BorderSide(color: Colors.purple),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          if (canAccessDividend) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CustomerDividendSummaryPage(),
                  ),
                ),
                icon: const Icon(Icons.savings_outlined, size: 18),
                label: const Text('ดูรายงานสรุปยอดปันผลคืนลูกค้า'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF00897B),
                  side: const BorderSide(color: Color(0xFF00897B)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CustomerDividendRunListPage(),
                  ),
                ),
                icon: const Icon(Icons.fact_check_outlined, size: 18),
                label: const Text('ดูงวดปันผลที่บันทึกแล้ว'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF00695C),
                  side: const BorderSide(color: Color(0xFF00695C)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSalesSummaryCards(SalesSummaryModel s) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cols = width >= 700 ? 4 : 2;
        const spacing = 8.0;
        final cardW = (width - spacing * (cols - 1)) / cols;
        final cards = [
          _summaryCard('ยอดขายรวม', '฿${_fmt.format(s.totalSales)}', Icons.attach_money, Colors.green),
          _summaryCard('จำนวนออเดอร์', _fmtInt.format(s.totalOrders), Icons.shopping_cart, Colors.blue),
          _summaryCard('เฉลี่ย/ออเดอร์', '฿${_fmt.format(s.avgOrderValue)}', Icons.analytics, Colors.orange),
          _summaryCard('ส่วนลดรวม', '฿${_fmt.format(s.totalDiscount)}', Icons.discount, Colors.red),
        ];
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: cards.map((c) => SizedBox(width: cardW, child: c)).toList(),
        );
      },
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
      padding: context.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('สรุปการจัดซื้อ', Icons.shopping_bag, Colors.red),
          ref
              .watch(purchaseSummaryProvider)
              .when(
                data: _buildPurchaseSummaryCards,
                loading: _loadingWidget,
                error: (e, _) => _errorWidget('$e'),
              ),
          const SizedBox(height: 24),
          _sectionTitle(
            'ซัพพลายเออร์สูงสุด Top 5',
            Icons.business,
            Colors.cyan,
          ),
          ref
              .watch(topSuppliersProvider)
              .when(
                data: _buildTopSuppliers,
                loading: _loadingWidget,
                error: (e, _) => _errorWidget('$e'),
              ),
          const SizedBox(height: 24),
          _sectionTitle(
            'หมวดหมู่สินค้าที่จัดซื้อมากสุด',
            Icons.category_outlined,
            Colors.deepPurple,
          ),
          ref
              .watch(purchaseCategoryProvider)
              .when(
                data: _buildPurchaseCategories,
                loading: _loadingWidget,
                error: (e, _) => _errorWidget('$e'),
              ),
          const SizedBox(height: 12),
          _buildActionGrid(
            actions: [
              _ReportAction(
                label: 'เปิดใบสั่งซื้อ',
                icon: Icons.receipt_long_outlined,
                color: Colors.red,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PurchaseOrderListPage(),
                  ),
                ),
              ),
              _ReportAction(
                label: 'เปิดรับสินค้า',
                icon: Icons.inventory_2_outlined,
                color: Colors.blue,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const GoodsReceiptListPage(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseSummaryCards(Map<String, dynamic> data) {
    if (data.isEmpty) return _emptyWidget('ยังไม่มีข้อมูล');
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cols = width >= 600 ? 3 : width >= 400 ? 2 : 1;
        const spacing = 8.0;
        final cardW = (width - spacing * (cols - 1)) / cols;
        final cards = [
          _summaryCard('ใบสั่งซื้อทั้งหมด', _fmtInt.format(data['total_po'] ?? 0), Icons.receipt, Colors.red),
          _summaryCard('มูลค่าสั่งซื้อรวม', '฿${_fmt.format((data['total_po_amount'] ?? 0.0) as num)}', Icons.payments, Colors.orange),
          _summaryCard('ชำระแล้ว', '฿${_fmt.format((data['total_paid'] ?? 0.0) as num)}', Icons.check_circle, Colors.green),
          _summaryCard('คงค้าง', '฿${_fmt.format((data['total_outstanding'] ?? 0.0) as num)}', Icons.pending_actions, Colors.deepOrange),
          _summaryCard('ใบรับสินค้า', _fmtInt.format(data['total_gr'] ?? 0), Icons.inventory_2, Colors.blue),
        ];
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: cards.map((c) => SizedBox(width: cardW, child: c)).toList(),
        );
      },
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

  Widget _buildPurchaseCategories(List<Map<String, dynamic>> list) {
    if (list.isEmpty) return _emptyWidget('ยังไม่มีข้อมูลหมวดหมู่สินค้า');
    return Column(
      children: list.take(5).map((item) {
        final amount = (item['total_amount'] as num?) ?? 0;
        final qty = (item['total_qty'] as num?) ?? 0;
        return _dataCard(
          child: ListTile(
            dense: context.isMobile,
            leading: _metricBadge(
              label: _formatQty(qty),
              color: Colors.deepPurple,
            ),
            title: Text(
              item['category'] as String? ?? 'ไม่มีหมวดหมู่',
              style: _cardTitleStyle(),
            ),
            subtitle: Text(
              'ปริมาณรวม ${_formatQty(qty)} หน่วย',
              style: _cardSubtitleStyle(),
            ),
            trailing: Text(
              '฿${_fmt.format(amount)}',
              style: const TextStyle(
                color: Colors.deepPurple,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Tab 3: Inventory ───────────────────────────────────────────────────────
  Widget _buildInventoryTab() {
    return SingleChildScrollView(
      padding: context.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            'สินค้าใกล้หมด (≤10 ชิ้น)',
            Icons.warning,
            Colors.orange,
          ),
          ref
              .watch(lowStockProvider)
              .when(
                data: _buildLowStock,
                loading: _loadingWidget,
                error: (e, _) => _errorWidget('$e'),
              ),
          const SizedBox(height: 24),
          _sectionTitle(
            'ความเคลื่อนไหวสต๊อกล่าสุด',
            Icons.swap_vert_circle_outlined,
            Colors.indigo,
          ),
          ref
              .watch(stockMovementProvider)
              .when(
                data: _buildStockMovements,
                loading: _loadingWidget,
                error: (e, _) => _errorWidget('$e'),
              ),
          const SizedBox(height: 24),
          _sectionTitle(
            'สินค้าค้างสต๊อก (≥90 วัน)',
            Icons.hourglass_empty,
            Colors.brown,
          ),
          ref
              .watch(stockAgingProvider)
              .when(
                data: _buildStockAging,
                loading: _loadingWidget,
                error: (e, _) => _errorWidget('$e'),
              ),
          const SizedBox(height: 12),
          _buildActionGrid(
            actions: [
              _ReportAction(
                label: 'เปิดหน้าสต๊อก',
                icon: Icons.warehouse_outlined,
                color: Colors.orange,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StockBalancePage()),
                ),
              ),
              _ReportAction(
                label: 'ดู movement',
                icon: Icons.timeline_outlined,
                color: Colors.indigo,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const StockMovementHistoryPage(),
                  ),
                ),
              ),
              _ReportAction(
                label: 'จัดการสินค้า',
                icon: Icons.inventory_2_outlined,
                color: Colors.green,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProductListPage()),
                ),
              ),
            ],
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
        final accent = qty <= 0 ? AppTheme.errorColor : AppTheme.warningColor;
        return _dataCard(
          child: ListTile(
            dense: context.isMobile,
            leading: _metricBadge(label: _formatQty(qty), color: accent),
            title: Text(
              item['product_name'] as String? ?? '',
              style: _cardTitleStyle(),
            ),
            subtitle: Text(
              item['product_code'] as String? ?? '',
              style: _cardSubtitleStyle(),
            ),
            trailing: Text(
              item['base_unit'] as String? ?? '',
              style: TextStyle(
                fontSize: 12,
                color: accent,
                fontWeight: FontWeight.w700,
              ),
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

        return _dataCard(
          child: ListTile(
            dense: context.isMobile,
            leading: _metricBadge(label: '${days}d', color: badgeColor),
            title: Text(
              item['product_name'] as String? ?? '',
              style: _cardTitleStyle(),
            ),
            subtitle: Text(
              'คงเหลือ: ${_formatQty((item['quantity'] as num?) ?? 0)} ${item['base_unit'] ?? ''}',
              style: _cardSubtitleStyle(),
            ),
            trailing: item['last_movement'] != null
                ? Text(
                    DateFormat(
                      'dd/MM/yy',
                    ).format(DateTime.parse(item['last_movement'] as String)),
                    style: _metaTextStyle(),
                  )
                : Text('ไม่มีข้อมูล', style: _metaTextStyle()),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStockMovements(List<Map<String, dynamic>> list) {
    if (list.isEmpty) return _emptyWidget('ยังไม่มีความเคลื่อนไหวสต๊อกล่าสุด');
    return Column(
      children: list.take(6).map((item) {
        final movementType = item['movement_type'] as String? ?? '-';
        final quantity = (item['quantity'] as num?) ?? 0;
        final balanceAfter = (item['balance_after'] as num?) ?? 0;
        final createdAt = item['created_at'] as String?;
        return _dataCard(
          child: ListTile(
            dense: context.isMobile,
            leading: _metricBadge(
              label: movementType,
              color: _movementTypeColor(movementType),
            ),
            title: Text(
              item['product_name'] as String? ?? '',
              style: _cardTitleStyle(),
            ),
            subtitle: Text(
              'จำนวน ${_formatQty(quantity)} | คงเหลือ ${_formatQty(balanceAfter)}',
              style: _cardSubtitleStyle(),
            ),
            trailing: createdAt == null
                ? null
                : Text(
                    DateFormat('dd/MM HH:mm').format(DateTime.parse(createdAt)),
                    style: _metaTextStyle(),
                  ),
          ),
        );
      }).toList(),
    );
  }

  // ── Tab 4: Financial ───────────────────────────────────────────────────────
  Widget _buildFinancialTab() {
    final filter = _financialFilter;

    return SingleChildScrollView(
      padding: context.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _financialFilterBar(),
          const SizedBox(height: 16),
          _sectionTitle('กำไร-ขาดทุน', Icons.trending_up, Colors.green),
          ref
              .watch(profitLossProvider(filter))
              .when(
                data: _buildProfitLoss,
                loading: _loadingWidget,
                error: (e, _) => _errorWidget('$e'),
              ),
          const SizedBox(height: 24),
          _sectionTitle('กระแสเงินสด', Icons.water_drop, Colors.blue),
          ref
              .watch(cashFlowProvider(filter))
              .when(
                data: _buildCashFlow,
                loading: _loadingWidget,
                error: (e, _) => _errorWidget('$e'),
              ),
          const SizedBox(height: 24),
          _sectionTitle(
            'ลูกหนี้คงค้าง (AR Aging)',
            Icons.person_outline,
            Colors.teal,
          ),
          ref
              .watch(arAgingProvider(filter))
              .when(
                data: (list) => _buildAgingTable(list, isAR: true),
                loading: _loadingWidget,
                error: (e, _) => _errorWidget('$e'),
              ),
          const SizedBox(height: 24),
          _sectionTitle(
            'เจ้าหนี้คงค้าง (AP Aging)',
            Icons.business,
            Colors.brown,
          ),
          ref
              .watch(apAgingProvider(filter))
              .when(
                data: (list) => _buildAgingTable(list, isAR: false),
                loading: _loadingWidget,
                error: (e, _) => _errorWidget('$e'),
              ),
        ],
      ),
    );
  }

  Widget _financialFilterBar() {
    const options = [
      ('ALL', 'ทั้งหมด'),
      ('TODAY', 'วันนี้'),
      ('LAST_7_DAYS', '7 วัน'),
      ('LAST_30_DAYS', '30 วัน'),
      ('THIS_MONTH', 'เดือนนี้'),
      ('THIS_YEAR', 'ปีนี้'),
      ('CUSTOM', 'กำหนดเอง'),
    ];

    return _panelCard(
      child: Padding(
        padding: context.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ประเภทวันที่', style: _cardTitleStyle(fontSize: 13)),
            const SizedBox(height: 4),
            Text(
              'ใช้กับรายงานการเงินทั้งหมดในแท็บนี้',
              style: _cardSubtitleStyle(),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: options
                  .map(
                    (option) => ChoiceChip(
                      label: Text(option.$2),
                      selected: _financialDatePreset == option.$1,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: _financialDatePreset == option.$1
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: _financialDatePreset == option.$1
                            ? AppTheme.primary
                            : AppTheme.subtextColorOf(context),
                      ),
                      selectedColor: AppTheme.primary.withValues(alpha: 0.12),
                      side: BorderSide(color: AppTheme.borderColorOf(context)),
                      backgroundColor: Theme.of(context).cardColor,
                      onSelected: (_) {
                        setState(() {
                          _financialDatePreset = option.$1;
                          if (option.$1 != 'CUSTOM') {
                            _financialDateFrom = null;
                            _financialDateTo = null;
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
                _dateFilterChip(
                  label: _financialDateFrom != null
                      ? 'ตั้งแต่: ${DateFormat('dd/MM/yyyy').format(_financialDateFrom!)}'
                      : 'ตั้งแต่วันที่',
                  active: _financialDateFrom != null,
                  onTap: () => _pickFinancialDate(true),
                  onClear: _financialDateFrom != null
                      ? () {
                          setState(() {
                            _financialDatePreset = 'CUSTOM';
                            _financialDateFrom = null;
                          });
                        }
                      : null,
                ),
                _dateFilterChip(
                  label: _financialDateTo != null
                      ? 'ถึง: ${DateFormat('dd/MM/yyyy').format(_financialDateTo!)}'
                      : 'ถึงวันที่',
                  active: _financialDateTo != null,
                  onTap: () => _pickFinancialDate(false),
                  onClear: _financialDateTo != null
                      ? () {
                          setState(() {
                            _financialDatePreset = 'CUSTOM';
                            _financialDateTo = null;
                          });
                        }
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfitLoss(Map<String, dynamic> data) {
    if (data.isEmpty) return _emptyWidget('ยังไม่มีข้อมูล');

    final revenue = (data['revenue'] as num?)?.toDouble() ?? 0;
    final netRevenue = (data['net_revenue'] as num?)?.toDouble() ?? 0;
    final cogs = (data['cogs'] as num?)?.toDouble() ?? 0;
    final grossProfit = (data['gross_profit'] as num?)?.toDouble() ?? 0;
    final grossMargin = (data['gross_margin_pct'] as num?)?.toDouble() ?? 0;
    final netProfit = (data['net_profit'] as num?)?.toDouble() ?? 0;

    return _panelCard(
      child: Padding(
        padding: context.cardPadding,
        child: Column(
          children: [
            _plRow('รายได้รวม', revenue, AppTheme.successColor, bold: false),
            _plRow(
              '(-) ส่วนลด',
              data['discount'] as num? ?? 0,
              AppTheme.errorColor,
              isNegative: true,
            ),
            _plRow(
              'รายได้สุทธิ',
              netRevenue,
              AppTheme.successColor,
              bold: true,
            ),
            const Divider(),
            _plRow(
              '(-) ต้นทุนสินค้า (COGS)',
              cogs,
              AppTheme.errorColor,
              isNegative: true,
            ),
            _plRow(
              'กำไรขั้นต้น',
              grossProfit,
              grossProfit >= 0 ? AppTheme.successColor : AppTheme.errorColor,
              bold: true,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'อัตรากำไรขั้นต้น',
                    style: TextStyle(color: AppTheme.subtextColorOf(context)),
                  ),
                  Text(
                    '${grossMargin.toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: grossMargin >= 0
                          ? AppTheme.successColor
                          : AppTheme.errorColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            _plRow(
              'กำไรสุทธิ',
              netProfit,
              netProfit >= 0 ? AppTheme.successColor : AppTheme.errorColor,
              bold: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _plRow(
    String label,
    num value,
    Color color, {
    bool bold = false,
    bool isNegative = false,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 360;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${isNegative ? '-' : ''}฿${_fmt.format(value.abs())}',
                        style: TextStyle(
                          color: color,
                          fontWeight: bold
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: bold ? 15 : 13,
                        ),
                      ),
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: bold
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${isNegative ? '-' : ''}฿${_fmt.format(value.abs())}',
                      style: TextStyle(
                        color: color,
                        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                        fontSize: bold ? 15 : 13,
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _agingBreakdownRow(String label, double amount, Color color) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 360;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            label,
                            style: _cardTitleStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '฿${_fmt.format(amount)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              label,
                              style: _cardTitleStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '฿${_fmt.format(amount)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildCashFlow(Map<String, dynamic> data) {
    if (data.isEmpty) return _emptyWidget('ยังไม่มีข้อมูล');

    final inflow = data['inflow'] as Map<String, dynamic>? ?? {};
    final outflow = data['outflow'] as Map<String, dynamic>? ?? {};
    final netCash = (data['net_cash_flow'] as num?)?.toDouble() ?? 0;

    // ยอดขายเครดิตที่ยังไม่รับเงิน — ไม่รวมในกระแสเงินสด
    final creditPending = (data['credit_sales_pending'] as num?)?.toDouble() ?? 0;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        _panelCard(
          child: Padding(
            padding: context.cardPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'รายรับ (Inflow)',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.successColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                _plRow(
                  '  ยอดขาย POS (เงินสด/โอน/บัตร)',
                  (inflow['pos_sales'] as num?) ?? 0,
                  AppTheme.successColor,
                ),
                _plRow(
                  '  รับชำระ AR',
                  (inflow['ar_receipts'] as num?) ?? 0,
                  AppTheme.successColor,
                ),
                _plRow(
                  'รวมรายรับ',
                  (inflow['total'] as num?) ?? 0,
                  AppTheme.successColor,
                  bold: true,
                ),
                const Divider(),
                Text(
                  'รายจ่าย (Outflow)',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.errorColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                _plRow(
                  '  จ่ายชำระ AP',
                  (outflow['ap_payments'] as num?) ?? 0,
                  AppTheme.errorColor,
                  isNegative: true,
                ),
                _plRow(
                  'รวมรายจ่าย',
                  (outflow['total'] as num?) ?? 0,
                  AppTheme.errorColor,
                  bold: true,
                  isNegative: true,
                ),
                const Divider(),
                _plRow(
                  'กระแสเงินสดสุทธิ',
                  netCash,
                  netCash >= 0 ? AppTheme.successColor : AppTheme.errorColor,
                  bold: true,
                ),
              ],
            ),
          ),
        ),
        // ── ยอดขายเครดิตที่รอรับเงิน (ไม่รวมในกระแสเงินสด) ─────
        if (creditPending > 0) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1A2535)
                  : const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppTheme.warning.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 18,
                  color: AppTheme.warning,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ยอดขายเครดิตที่รอรับเงิน',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'ยอดนี้ยังไม่รวมในกระแสเงินสด จะรวมเมื่อลูกค้าชำระแล้ว',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? Colors.white38 : Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '฿${_fmt.format(creditPending)}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.warning,
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF0F1E0F)
                  : const Color(0xFFF1F8E9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppTheme.success.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 16,
                  color: AppTheme.success,
                ),
                const SizedBox(width: 8),
                Text(
                  'ยอดขายเครดิตไม่รวมในกระแสเงินสด จนกว่าลูกค้าจะชำระ',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAgingTable(
    List<Map<String, dynamic>> list, {
    required bool isAR,
  }) {
    if (list.isEmpty) {
      return _emptyWidget(
        isAR ? 'ไม่มีลูกหนี้คงค้าง ✅' : 'ไม่มีเจ้าหนี้คงค้าง ✅',
      );
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

    final totalOutstanding = list.fold<double>(
      0,
      (s, i) => s + ((i['outstanding'] as num?)?.toDouble() ?? 0),
    );

    return Column(
      children: [
        // Summary by bucket
        _panelCard(
          child: Padding(
            padding: context.cardPadding,
            child: Column(
              children: [
                ...bucketOrder.where((b) => buckets.containsKey(b)).map((b) {
                  final color = _agingBucketColor(b);
                  return _agingBreakdownRow(b, buckets[b]!, color);
                }),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'รวมค้างชำระ',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '฿${_fmt.format(totalOutstanding)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppTheme.errorColor,
                      ),
                    ),
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
          final outstanding = (item['outstanding'] as num?)?.toDouble() ?? 0;
          final name = isAR
              ? item['customer_name'] as String? ?? ''
              : item['supplier_name'] as String? ?? '';
          final bucket = item['aging_bucket'] as String? ?? '';
          final amountColor = _agingBucketColor(bucket);

          return _dataCard(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 420;

                return Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.isMobile ? 12 : 14,
                    vertical: context.isMobile ? 10 : 12,
                  ),
                  child: stacked
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: _cardTitleStyle(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${item['invoice_no'] ?? ''} | $bucket',
                              style: _cardSubtitleStyle(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '฿${_fmt.format(outstanding)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: amountColor,
                                    ),
                                  ),
                                ),
                                if (overdue > 0)
                                  const Text(
                                    'เลยกำหนด',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: AppTheme.errorColor,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    name,
                                    style: _cardTitleStyle(),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${item['invoice_no'] ?? ''} | $bucket',
                                    style: _cardSubtitleStyle(),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                minWidth: context.isMobile ? 84 : 96,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '฿${_fmt.format(outstanding)}',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: amountColor,
                                    ),
                                  ),
                                  if (overdue > 0) ...[
                                    const SizedBox(height: 4),
                                    const Text(
                                      'เลยกำหนด',
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: AppTheme.errorColor,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                );
              },
            ),
          );
        }),
        if (list.length > 10)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '... และอีก ${list.length - 10} รายการ',
              style: TextStyle(
                color: AppTheme.subtextColorOf(context),
                fontSize: 11,
              ),
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
    final width = MediaQuery.sizeOf(context).width;
    final isTightDesktop = context.isDesktopOrWider && width < 1080;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 14),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: isTightDesktop ? 12.5 : 13.0,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border.all(color: AppTheme.borderColorOf(context)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: color,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _cardSubtitleStyle(),
                ),
              ],
            ),
          ),
        ],
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

    return _dataCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 420;
          final width = MediaQuery.sizeOf(context).width;
          final isTightDesktop = context.isDesktopOrWider && width < 1080;

          return ListTile(
            dense: context.isMobile || isTightDesktop,
            contentPadding: EdgeInsets.symmetric(
              horizontal: isTightDesktop ? 12 : 16,
              vertical: isTightDesktop ? 2 : 4,
            ),
            leading: CircleAvatar(
              radius: isTightDesktop ? 18 : 20,
              backgroundColor: rankColors[(rank - 1).clamp(0, 4)],
              child: Text(
                '$rank',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(title, style: _cardTitleStyle()),
            subtitle: Text(
              stacked ? '$subtitle\n$trailing' : subtitle,
              style: _cardSubtitleStyle(),
            ),
            trailing: stacked
                ? null
                : Text(
                    trailing,
                    style: TextStyle(
                      fontSize: context.isMobile ? 13 : 14,
                      fontWeight: FontWeight.bold,
                      color: trailingColor,
                    ),
                  ),
            isThreeLine: stacked,
          );
        },
      ),
    );
  }

  Widget _loadingWidget() => _panelCard(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: SizedBox(
          width: context.isMobile ? 24 : 28,
          height: context.isMobile ? 24 : 28,
          child: const CircularProgressIndicator(strokeWidth: 2.5),
        ),
      ),
    ),
  );

  Widget _errorWidget(String msg) => _panelCard(
    child: Padding(
      padding: context.cardPadding,
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppTheme.errorColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'เกิดข้อผิดพลาด: $msg',
              style: const TextStyle(color: AppTheme.errorColor),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _emptyWidget(String msg) => _panelCard(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Center(
        child: Text(
          msg,
          style: TextStyle(color: AppTheme.subtextColorOf(context)),
        ),
      ),
    ),
  );

  Widget _panelCard({required Widget child}) {
    return Card(
      elevation: 0,
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.borderColorOf(context)),
      ),
      child: child,
    );
  }

  Widget _dataCard({required Widget child}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _panelCard(child: child),
    );
  }

  Widget _buildActionGrid({required List<_ReportAction> actions}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 900
            ? 3
            : width >= 560
            ? 2
            : 1;
        const spacing = 8.0;
        final itemWidth = (width - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: actions
              .map((action) => SizedBox(
                    width: itemWidth,
                    child: _reportActionCard(action),
                  ))
              .toList(),
        );
      },
    );
  }

  Widget _reportActionCard(_ReportAction action) {
    return InkWell(
      onTap: action.onTap,
      borderRadius: BorderRadius.circular(12),
      child: _panelCard(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: action.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(action.icon, color: action.color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  action.label,
                  style: _cardTitleStyle(fontSize: 12.5),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: AppTheme.subtextColorOf(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _movementTypeColor(String type) {
    switch (type) {
      case 'IN':
      case 'TRANSFER_IN':
        return Colors.green;
      case 'OUT':
      case 'TRANSFER_OUT':
      case 'SALE':
        return Colors.red;
      case 'ADJUST':
        return Colors.blue;
      default:
        return Colors.indigo;
    }
  }

  Widget _metricBadge({required String label, required Color color}) {
    return Container(
      constraints: const BoxConstraints(minWidth: 38),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _dateFilterChip({
    required String label,
    required bool active,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? AppTheme.primary.withValues(alpha: 0.10)
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? AppTheme.primary : AppTheme.borderColorOf(context),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 14,
              color: active
                  ? AppTheme.primary
                  : AppTheme.subtextColorOf(context),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                color: active
                    ? AppTheme.primary
                    : AppTheme.subtextColorOf(context),
              ),
            ),
            if (onClear != null) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onClear,
                child: Icon(
                  Icons.close,
                  size: 14,
                  color: active
                      ? AppTheme.primary
                      : AppTheme.subtextColorOf(context),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  TextStyle _cardTitleStyle({double fontSize = 13}) {
    final width = MediaQuery.sizeOf(context).width;
    final isTightDesktop = context.isDesktopOrWider && width < 1080;
    return TextStyle(
      fontSize: isTightDesktop ? fontSize - 0.5 : fontSize,
      fontWeight: FontWeight.w600,
      color: Theme.of(context).colorScheme.onSurface,
    );
  }

  TextStyle _cardSubtitleStyle() {
    final width = MediaQuery.sizeOf(context).width;
    final isTightDesktop = context.isDesktopOrWider && width < 1080;
    return TextStyle(
      fontSize: isTightDesktop ? 10.5 : 11,
      color: AppTheme.subtextColorOf(context),
    );
  }

  TextStyle _metaTextStyle() {
    final width = MediaQuery.sizeOf(context).width;
    final isTightDesktop = context.isDesktopOrWider && width < 1080;
    return TextStyle(
      fontSize: isTightDesktop ? 10.5 : 11,
      color: AppTheme.subtextColorOf(context),
    );
  }

  String _formatQty(num value) {
    final quantity = value.toDouble();
    if (quantity == quantity.roundToDouble()) {
      return _fmtInt.format(quantity);
    }
    return _fmtQty.format(quantity);
  }

  // ── Export ─────────────────────────────────────────────────────────────────
  Future<void> _exportReport(BuildContext context) async {
    final licenseStatus = ref.read(licenseServiceProvider).asData?.value;
    if (licenseStatus != null &&
        !licenseStatus.canUseFeature(LicenseFeature.exportReport)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('หมดช่วงทดลองแล้ว ต้องมี License ก่อนส่งออกรายงาน'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.of(context).pushNamed('/license');
      }
      return;
    }

    final export = await _buildCurrentTabCsv();
    final path = await CsvExport.exportToCsv(
      filename: export.$1,
      headers: export.$2,
      rows: export.$3,
      chooseLocation: true,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(path != null ? 'Export สำเร็จ: $path' : 'Export ไม่สำเร็จ'),
          backgroundColor: path != null ? null : Colors.red,
        ),
      );
    }
  }

  Future<(String, List<String>, List<List<String>>)> _buildCurrentTabCsv() async {
    switch (_currentTab) {
      case 1:
        final summary = await ref.read(purchaseSummaryProvider.future);
        final topSuppliers = await ref.read(topSuppliersProvider.future);
        final purchaseCategories = await ref.read(
          purchaseCategoryProvider.future,
        );
        return (
          'purchase_report',
          ['หมวด', 'รายการ', 'ค่า1', 'ค่า2'],
          [
            ['สรุปการจัดซื้อ', 'ใบสั่งซื้อทั้งหมด', '${summary['total_po'] ?? 0}', ''],
            [
              'สรุปการจัดซื้อ',
              'มูลค่าสั่งซื้อรวม',
              '฿${_fmt.format((summary['total_po_amount'] ?? 0) as num)}',
              '',
            ],
            [
              'สรุปการจัดซื้อ',
              'ชำระแล้ว',
              '฿${_fmt.format((summary['total_paid'] ?? 0) as num)}',
              '',
            ],
            [
              'สรุปการจัดซื้อ',
              'คงค้าง',
              '฿${_fmt.format((summary['total_outstanding'] ?? 0) as num)}',
              '',
            ],
            ['สรุปการจัดซื้อ', 'ใบรับสินค้า', '${summary['total_gr'] ?? 0}', ''],
            ...topSuppliers.asMap().entries.map(
              (entry) => [
                'ซัพพลายเออร์สูงสุด',
                '${entry.key + 1}. ${entry.value['supplier_name'] ?? '-'}',
                '${entry.value['po_count'] ?? 0} PO',
                '฿${_fmt.format((entry.value['total_amount'] ?? 0) as num)}',
              ],
            ),
            ...purchaseCategories.asMap().entries.map(
              (entry) => [
                'หมวดหมู่จัดซื้อ',
                '${entry.key + 1}. ${entry.value['category'] ?? '-'}',
                _formatQty((entry.value['total_qty'] ?? 0) as num),
                '฿${_fmt.format((entry.value['total_amount'] ?? 0) as num)}',
              ],
            ),
          ],
        );
      case 2:
        final lowStock = await ref.read(lowStockProvider.future);
        final stockMovement = await ref.read(stockMovementProvider.future);
        final stockAging = await ref.read(stockAgingProvider.future);
        return (
          'inventory_report',
          ['หมวด', 'รายการ', 'ค่า1', 'ค่า2'],
          [
            ...lowStock.map(
              (item) => [
                'สินค้าใกล้หมด',
                '${item['product_name'] ?? '-'}',
                _formatQty((item['current_stock'] ?? 0) as num),
                '${item['base_unit'] ?? '-'}',
              ],
            ),
            ...stockMovement.map(
              (item) => [
                'ความเคลื่อนไหวสต๊อก',
                '${item['product_name'] ?? '-'}',
                '${item['movement_type'] ?? '-'} ${_formatQty((item['quantity'] ?? 0) as num)}',
                'คงเหลือ ${_formatQty((item['balance_after'] ?? 0) as num)}',
              ],
            ),
            ...stockAging.map(
              (item) => [
                'สินค้าค้างสต๊อก',
                '${item['product_name'] ?? '-'}',
                '${item['days_no_movement'] ?? 0} วัน',
                'คงเหลือ ${_formatQty((item['quantity'] ?? 0) as num)} ${item['base_unit'] ?? ''}',
              ],
            ),
          ],
        );
      case 3:
        final filter = _financialFilter;
        final profitLoss = await ref.read(profitLossProvider(filter).future);
        final cashFlow = await ref.read(cashFlowProvider(filter).future);
        final arAging = await ref.read(arAgingProvider(filter).future);
        final apAging = await ref.read(apAgingProvider(filter).future);
        return (
          'financial_report',
          ['หมวด', 'รายการ', 'ค่า1', 'ค่า2'],
          [
            [
              'กำไรขาดทุน',
              'รายได้สุทธิ',
              '฿${_fmt.format((profitLoss['net_revenue'] ?? 0) as num)}',
              '',
            ],
            [
              'กำไรขาดทุน',
              'กำไรสุทธิ',
              '฿${_fmt.format((profitLoss['net_profit'] ?? 0) as num)}',
              '',
            ],
            [
              'กระแสเงินสด',
              'กระแสเงินสดสุทธิ',
              '฿${_fmt.format((cashFlow['net_cash_flow'] ?? 0) as num)}',
              '',
            ],
            ...arAging.take(30).map(
              (item) => [
                'ลูกหนี้คงค้าง',
                '${item['invoice_no'] ?? '-'} / ${item['customer_name'] ?? '-'}',
                '฿${_fmt.format((item['outstanding'] ?? 0) as num)}',
                '${item['aging_bucket'] ?? '-'}',
              ],
            ),
            ...apAging.take(30).map(
              (item) => [
                'เจ้าหนี้คงค้าง',
                '${item['invoice_no'] ?? '-'} / ${item['supplier_name'] ?? '-'}',
                '฿${_fmt.format((item['outstanding'] ?? 0) as num)}',
                '${item['aging_bucket'] ?? '-'}',
              ],
            ),
          ],
        );
      case 0:
      default:
        final summary = await ref.read(salesSummaryProvider.future);
        final topProducts = await ref.read(topProductsProvider.future);
        final topCustomers = await ref.read(topCustomersProvider.future);
        return (
          'sales_report',
          ['หมวด', 'รายการ', 'ค่า1', 'ค่า2'],
          [
            ['สรุปยอดขาย', 'ยอดขายรวม', '฿${_fmt.format(summary.totalSales)}', ''],
            ['สรุปยอดขาย', 'จำนวนออเดอร์', '${summary.totalOrders}', ''],
            [
              'สรุปยอดขาย',
              'ยอดเฉลี่ย/ออเดอร์',
              '฿${_fmt.format(summary.avgOrderValue)}',
              '',
            ],
            ['สรุปยอดขาย', 'ส่วนลดรวม', '฿${_fmt.format(summary.totalDiscount)}', ''],
            ...topProducts.map(
              (p) => [
                'สินค้าขายดี',
                p.productName,
                _formatQty(p.totalQuantity),
                '฿${_fmt.format(p.totalSales)}',
              ],
            ),
            ...topCustomers.map(
              (c) => [
                'ลูกค้าซื้อบ่อย',
                c.customerName,
                '${c.orderCount} ออเดอร์',
                '฿${_fmt.format(c.totalSales)}',
              ],
            ),
          ],
        );
    }
  }
}

class _ReportAction {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ReportAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}
