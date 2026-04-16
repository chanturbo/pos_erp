import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pos_erp/shared/pdf/pdf_report_button.dart';
import 'package:pos_erp/shared/theme/app_theme.dart';
import 'package:pos_erp/shared/utils/responsive_utils.dart';
import 'package:pos_erp/shared/widgets/escape_pop_scope.dart';
import 'package:pos_erp/shared/widgets/mobile_home_button.dart';
import 'package:pos_erp/shared/widgets/pagination_bar.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import '../../data/models/ar_invoice_model.dart';
import '../providers/ar_invoice_provider.dart';
import 'ar_customer_outstanding_summary_pdf_report.dart';

class ArCustomerOutstandingSummaryPage extends ConsumerStatefulWidget {
  const ArCustomerOutstandingSummaryPage({super.key});

  @override
  ConsumerState<ArCustomerOutstandingSummaryPage> createState() =>
      _ArCustomerOutstandingSummaryPageState();
}

class _ArCustomerOutstandingSummaryPageState
    extends ConsumerState<ArCustomerOutstandingSummaryPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'ALL';
  String? _customerFilter;
  String _dateFilter = 'ALL';
  DateTimeRange? _customDateRange;
  int _currentPage = 1;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ArInvoiceModel> _filter(List<ArInvoiceModel> src) {
    return src.where((inv) {
      final matchesSearch =
          inv.invoiceNo.toLowerCase().contains(_searchQuery) ||
          inv.customerName.toLowerCase().contains(_searchQuery);
      final matchesStatus =
          _statusFilter == 'ALL' ||
          (_statusFilter == 'OVERDUE'
              ? inv.isOverdue
              : inv.status == _statusFilter);
      final matchesCustomer =
          _customerFilter == null || inv.customerName == _customerFilter;
      final matchesDate = _matchesDateFilter(inv.invoiceDate);
      return matchesSearch && matchesStatus && matchesCustomer && matchesDate;
    }).toList()..sort((a, b) => b.invoiceDate.compareTo(a.invoiceDate));
  }

  bool _matchesDateFilter(DateTime date) {
    final value = DateTime(date.year, date.month, date.day);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_dateFilter) {
      case 'TODAY':
        return value == today;
      case 'THIS_MONTH':
        return value.year == today.year && value.month == today.month;
      case 'CUSTOM':
        final range = _customDateRange;
        if (range == null) return true;
        final start = DateTime(
          range.start.year,
          range.start.month,
          range.start.day,
        );
        final end = DateTime(range.end.year, range.end.month, range.end.day);
        return !value.isBefore(start) && !value.isAfter(end);
      default:
        return true;
    }
  }

  String get _dateFilterLabel {
    switch (_dateFilter) {
      case 'TODAY':
        return 'วันนี้';
      case 'THIS_MONTH':
        return 'เดือนนี้';
      case 'CUSTOM':
        final range = _customDateRange;
        if (range == null) return 'ช่วงวันที่';
        final fmt = DateFormat('dd/MM/yy');
        return '${fmt.format(range.start)} - ${fmt.format(range.end)}';
      default:
        return 'วันที่';
    }
  }

  Future<void> _selectCustomerFilter(List<ArInvoiceModel> items) async {
    final customers = items
        .map((e) => e.customerName.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.clear_all),
              title: const Text('ทุกลูกค้า'),
              onTap: () => Navigator.pop(context, ''),
            ),
            ...customers.map(
              (name) => ListTile(
                leading: Icon(
                  Icons.person_outline,
                  color: name == _customerFilter ? AppTheme.primary : null,
                ),
                title: Text(name),
                onTap: () => Navigator.pop(context, name),
              ),
            ),
          ],
        ),
      ),
    );
    if (!mounted || selected == null) return;
    setState(() {
      _customerFilter = selected.isEmpty ? null : selected;
      _currentPage = 1;
    });
  }

  Future<void> _selectDateFilter() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.date_range_outlined),
              title: const Text('ทุกวันที่'),
              onTap: () => Navigator.pop(context, 'ALL'),
            ),
            ListTile(
              leading: const Icon(Icons.today_outlined),
              title: const Text('วันนี้'),
              onTap: () => Navigator.pop(context, 'TODAY'),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month_outlined),
              title: const Text('เดือนนี้'),
              onTap: () => Navigator.pop(context, 'THIS_MONTH'),
            ),
            ListTile(
              leading: const Icon(Icons.edit_calendar_outlined),
              title: const Text('เลือกช่วงวันที่'),
              onTap: () => Navigator.pop(context, 'CUSTOM'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || selected == null) return;
    if (selected == 'CUSTOM') {
      final now = DateTime.now();
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(now.year - 5),
        lastDate: DateTime(now.year + 5),
        initialDateRange:
            _customDateRange ??
            DateTimeRange(
              start: DateTime(now.year, now.month, 1),
              end: now,
            ),
      );
      if (!mounted || picked == null) return;
      setState(() {
        _dateFilter = 'CUSTOM';
        _customDateRange = picked;
        _currentPage = 1;
      });
      return;
    }
    setState(() {
      _dateFilter = selected;
      if (selected != 'CUSTOM') _customDateRange = null;
      _currentPage = 1;
    });
  }

  List<_CustomerOutstandingSummary> _buildCustomerSummaries(
    List<ArInvoiceModel> invoices,
  ) {
    final map = <String, _CustomerOutstandingSummary>{};
    for (final invoice in invoices) {
      if (invoice.remainingAmount <= 0.01) continue;
      final current =
          map[invoice.customerId] ??
          _CustomerOutstandingSummary(
            customerId: invoice.customerId,
            customerName: invoice.customerName,
            invoiceCount: 0,
            outstandingAmount: 0,
            overdueAmount: 0,
          );
      map[invoice.customerId] = current.copyWith(
        invoiceCount: current.invoiceCount + 1,
        outstandingAmount: current.outstandingAmount + invoice.remainingAmount,
        overdueAmount:
            current.overdueAmount +
            (invoice.isOverdue ? invoice.remainingAmount : 0),
      );
    }
    final result = map.values.toList()
      ..sort((a, b) {
        final byAmount = b.outstandingAmount.compareTo(a.outstandingAmount);
        if (byAmount != 0) return byAmount;
        return a.customerName.compareTo(b.customerName);
      });
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final invoicesAsync = ref.watch(arInvoiceListProvider);
    final pageSize = ref.watch(settingsProvider).listPageSize;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : const Color(0xFFF5F5F5),
      body: EscapePopScope(
        child: Column(
          children: [
            _SummaryTopBar(
              searchController: _searchController,
              searchQuery: _searchQuery,
              onSearchChanged: (v) => setState(() {
                _searchQuery = v.toLowerCase();
                _currentPage = 1;
              }),
              onSearchCleared: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                  _currentPage = 1;
                });
              },
              onRefresh: () =>
                  ref.read(arInvoiceListProvider.notifier).refresh(),
            ),
            Expanded(
              child: invoicesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('เกิดข้อผิดพลาด: $e')),
                data: (all) {
                  final filtered = _filter(all);
                  final summaries = _buildCustomerSummaries(filtered);
                  final totalPages = (summaries.length / pageSize).ceil().clamp(
                    1,
                    9999,
                  );
                  final safePage = _currentPage.clamp(1, totalPages);
                  final start = (safePage - 1) * pageSize;
                  final end = (start + pageSize).clamp(0, summaries.length);
                  final pageSummaries = summaries.sublist(start, end);
                  final unpaidInvoices =
                      filtered.where((i) => i.remainingAmount > 0.01).toList();
                  final overdueCount =
                      unpaidInvoices.where((i) => i.isOverdue).length;
                  final totalOutstanding = unpaidInvoices.fold<double>(
                    0,
                    (s, i) => s + i.remainingAmount,
                  );
                  final overdueAmount = unpaidInvoices
                      .where((i) => i.isOverdue)
                      .fold<double>(0, (s, i) => s + i.remainingAmount);
                  final now = DateTime.now();
                  final dueSoonAmount = unpaidInvoices
                      .where(
                        (i) =>
                            !i.isOverdue &&
                            i.dueDate != null &&
                            i.dueDate!.difference(now).inDays <= 7,
                      )
                      .fold<double>(0, (s, i) => s + i.remainingAmount);

                  final pdfRows = summaries
                      .map(
                        (s) => ArCustomerOutstandingSummaryPdfRow(
                          customerName: s.customerName,
                          invoiceCount: s.invoiceCount,
                          outstandingAmount: s.outstandingAmount,
                          overdueAmount: s.overdueAmount,
                        ),
                      )
                      .toList();

                  return Column(
                    children: [
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final compact = constraints.maxWidth < 760;
                                final cards = [
                                  _OutstandingCard(
                                    label: 'ยอดค้างทั้งหมด',
                                    amount: totalOutstanding,
                                    count: unpaidInvoices.length,
                                    color: AppTheme.primaryDark,
                                    icon: Icons.account_balance_wallet_outlined,
                                    isDark: isDark,
                                  ),
                                  _OutstandingCard(
                                    label: 'เลยกำหนด',
                                    amount: overdueAmount,
                                    count: overdueCount,
                                    color: AppTheme.error,
                                    icon: Icons.warning_amber_rounded,
                                    isDark: isDark,
                                  ),
                                  _OutstandingCard(
                                    label: 'ครบใน 7 วัน',
                                    amount: dueSoonAmount,
                                    count: unpaidInvoices
                                        .where(
                                          (i) =>
                                              !i.isOverdue &&
                                              i.dueDate != null &&
                                              i.dueDate!.difference(now).inDays <=
                                                  7,
                                        )
                                        .length,
                                    color: AppTheme.warning,
                                    icon: Icons.schedule_outlined,
                                    isDark: isDark,
                                  ),
                                ];

                                if (compact) {
                                  return Column(
                                    children: [
                                      for (var i = 0; i < cards.length; i++) ...[
                                        cards[i],
                                        if (i != cards.length - 1)
                                          const SizedBox(height: 8),
                                      ],
                                    ],
                                  );
                                }

                                return Row(
                                  children: [
                                    Expanded(child: cards[0]),
                                    const SizedBox(width: 8),
                                    Expanded(child: cards[1]),
                                    const SizedBox(width: 8),
                                    Expanded(child: cards[2]),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                _ActionChip(
                                  label: _customerFilter ?? 'ลูกค้า',
                                  icon: Icons.person_outline,
                                  active: _customerFilter != null,
                                  color: AppTheme.primary,
                                  onTap: () => _selectCustomerFilter(all),
                                ),
                                _ActionChip(
                                  label: _dateFilterLabel,
                                  icon: Icons.calendar_today_outlined,
                                  active: _dateFilter != 'ALL',
                                  color: AppTheme.primaryDark,
                                  onTap: _selectDateFilter,
                                ),
                                _FilterChip(
                                  label: 'ทั้งหมด',
                                  count: all.length,
                                  color: AppTheme.navy,
                                  selected: _statusFilter == 'ALL',
                                  onTap: () => setState(() {
                                    _statusFilter = 'ALL';
                                    _currentPage = 1;
                                  }),
                                ),
                                _FilterChip(
                                  label: 'ยังไม่รับ',
                                  count:
                                      all.where((i) => i.status == 'UNPAID').length,
                                  color: AppTheme.error,
                                  selected: _statusFilter == 'UNPAID',
                                  onTap: () => setState(() {
                                    _statusFilter = 'UNPAID';
                                    _currentPage = 1;
                                  }),
                                ),
                                _FilterChip(
                                  label: 'รับบางส่วน',
                                  count:
                                      all.where((i) => i.status == 'PARTIAL').length,
                                  color: AppTheme.warning,
                                  selected: _statusFilter == 'PARTIAL',
                                  onTap: () => setState(() {
                                    _statusFilter = 'PARTIAL';
                                    _currentPage = 1;
                                  }),
                                ),
                                _FilterChip(
                                  label: 'รับครบแล้ว',
                                  count: all.where((i) => i.status == 'PAID').length,
                                  color: AppTheme.success,
                                  selected: _statusFilter == 'PAID',
                                  onTap: () => setState(() {
                                    _statusFilter = 'PAID';
                                    _currentPage = 1;
                                  }),
                                ),
                                if (all.any((i) => i.isOverdue))
                                  _FilterChip(
                                    label: 'เลยกำหนด',
                                    count: all.where((i) => i.isOverdue).length,
                                    color: AppTheme.error,
                                    selected: _statusFilter == 'OVERDUE',
                                    onTap: () => setState(() {
                                      _statusFilter = 'OVERDUE';
                                      _currentPage = 1;
                                    }),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _SummaryTable(
                              summaries: pageSummaries,
                              isDark: isDark,
                            ),
                          ],
                        ),
                      ),
                      PaginationBar(
                        currentPage: safePage,
                        totalItems: summaries.length,
                        pageSize: pageSize,
                        onPageChanged: (p) => setState(() => _currentPage = p),
                        trailing: PdfReportButton(
                          emptyMessage: 'ไม่มีข้อมูลสรุปลูกค้าค้างชำระ',
                          title: 'รายงานสรุปลูกค้าค้างชำระ',
                          filename: () => PdfFilename.generate(
                            'ar_customer_outstanding_summary',
                          ),
                          buildPdf: () =>
                              ArCustomerOutstandingSummaryPdfBuilder.build(
                                pdfRows,
                              ),
                          hasData: pdfRows.isNotEmpty,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryTopBar extends StatelessWidget {
  final TextEditingController searchController;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchCleared;
  final VoidCallback onRefresh;

  const _SummaryTopBar({
    required this.searchController,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onSearchCleared,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canPop = Navigator.of(context).canPop();
    final isWide = MediaQuery.of(context).size.width >= 720;
    return Container(
      color: isDark ? AppTheme.darkTopBar : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          Row(
            children: [
              if (canPop) ...[
                context.isMobile
                    ? buildMobileHomeCompactButton(context, isDark: isDark)
                    : _IconShell(
                        icon: Icons.arrow_back_ios_new,
                        isDark: isDark,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                const SizedBox(width: 8),
              ],
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.groups_2_outlined,
                  color: AppTheme.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'สรุปลูกค้าค้างชำระ',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                  ),
                ),
              ),
              _IconShell(
                icon: Icons.refresh,
                isDark: isDark,
                onTap: onRefresh,
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (isWide)
            Row(
              children: [
                Expanded(
                  child: _SearchField(
                    controller: searchController,
                    query: searchQuery,
                    onChanged: onSearchChanged,
                    onCleared: onSearchCleared,
                    isDark: isDark,
                  ),
                ),
              ],
            )
          else
            _SearchField(
              controller: searchController,
              query: searchQuery,
              onChanged: onSearchChanged,
              onCleared: onSearchCleared,
              isDark: isDark,
            ),
        ],
      ),
    );
  }
}

class _CustomerOutstandingSummary {
  final String customerId;
  final String customerName;
  final int invoiceCount;
  final double outstandingAmount;
  final double overdueAmount;

  const _CustomerOutstandingSummary({
    required this.customerId,
    required this.customerName,
    required this.invoiceCount,
    required this.outstandingAmount,
    required this.overdueAmount,
  });

  _CustomerOutstandingSummary copyWith({
    String? customerId,
    String? customerName,
    int? invoiceCount,
    double? outstandingAmount,
    double? overdueAmount,
  }) {
    return _CustomerOutstandingSummary(
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      invoiceCount: invoiceCount ?? this.invoiceCount,
      outstandingAmount: outstandingAmount ?? this.outstandingAmount,
      overdueAmount: overdueAmount ?? this.overdueAmount,
    );
  }
}

class _SummaryTable extends StatelessWidget {
  final List<_CustomerOutstandingSummary> summaries;
  final bool isDark;

  const _SummaryTable({required this.summaries, required this.isDark});

  @override
  Widget build(BuildContext context) {
    if (summaries.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF333333) : AppTheme.border,
          ),
        ),
        child: Text(
          'ยังไม่มีลูกค้าที่ค้างชำระตามเงื่อนไขที่กรองอยู่',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white60 : AppTheme.textSub,
          ),
        ),
      );
    }

    final headerStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: isDark ? const Color(0xFFAAAAAA) : AppTheme.textSub,
    );
    final fmt = NumberFormat('#,##0.00', 'th_TH');
    final compact = MediaQuery.of(context).size.width < 760;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF333333) : AppTheme.border,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: compact
            ? Column(
                children: summaries.map((summary) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          isDark ? AppTheme.darkElement : const Color(0xFFF8F8F8),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          summary.customerName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color:
                                isDark ? Colors.white : const Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _MetricRow(
                          label: 'จำนวนใบค้าง',
                          value: '${summary.invoiceCount} ใบ',
                          color: isDark ? Colors.white70 : AppTheme.textSub,
                        ),
                        _MetricRow(
                          label: 'ยอดค้างรวม',
                          value: '฿${fmt.format(summary.outstandingAmount)}',
                          color: AppTheme.primaryDark,
                        ),
                        _MetricRow(
                          label: 'เกินกำหนด',
                          value: '฿${fmt.format(summary.overdueAmount)}',
                          color: summary.overdueAmount > 0
                              ? AppTheme.error
                              : (isDark ? Colors.white38 : Colors.black38),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              )
            : Column(
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                    decoration: BoxDecoration(
                      color:
                          isDark ? AppTheme.darkElement : const Color(0xFFF8F8F8),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(flex: 4, child: Text('ลูกค้า', style: headerStyle)),
                        SizedBox(
                          width: 86,
                          child: Text(
                            'จำนวนใบค้าง',
                            style: headerStyle,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        SizedBox(
                          width: 120,
                          child: Text(
                            'ยอดค้างรวม',
                            style: headerStyle,
                            textAlign: TextAlign.right,
                          ),
                        ),
                        SizedBox(
                          width: 120,
                          child: Text(
                            'เกินกำหนด',
                            style: headerStyle,
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...summaries.map((summary) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: isDark
                                ? const Color(0xFF333333)
                                : const Color(0xFFEAEAEA),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 4,
                            child: Text(
                              summary.customerName,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1A1A1A),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 86,
                            child: Text(
                              '${summary.invoiceCount} ใบ',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                    isDark ? Colors.white70 : AppTheme.textSub,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 120,
                            child: Text(
                              '฿${fmt.format(summary.outstandingAmount)}',
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primaryDark,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 120,
                            child: Text(
                              '฿${fmt.format(summary.overdueAmount)}',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: summary.overdueAmount > 0
                                    ? AppTheme.error
                                    : (isDark ? Colors.white38 : Colors.black38),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
      ),
    );
  }
}

class _OutstandingCard extends StatelessWidget {
  final String label;
  final double amount;
  final int count;
  final Color color;
  final IconData icon;
  final bool isDark;

  const _OutstandingCard({
    required this.label,
    required this.amount,
    required this.count,
    required this.color,
    required this.icon,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00', 'th_TH');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.12 : 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.white54 : AppTheme.textSub,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '฿${fmt.format(amount)}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            '$count ใบ',
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  const _ActionChip({
    required this.label,
    required this.icon,
    required this.active,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? color.withValues(alpha: isDark ? 0.22 : 0.10)
              : (isDark ? AppTheme.darkElement : const Color(0xFFF7F7F7)),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active
                ? color.withValues(alpha: 0.45)
                : (isDark ? const Color(0xFF333333) : AppTheme.border),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: active ? color : AppTheme.textSub),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: active
                    ? color
                    : (isDark ? Colors.white70 : const Color(0xFF1A1A1A)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final vc = selected ? Colors.white : color;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? color
                : (isDark
                    ? AppTheme.darkElement
                    : color.withValues(alpha: 0.08)),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? color
                  : color.withValues(alpha: isDark ? 0.35 : 0.22),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: vc,
                ),
              ),
              const SizedBox(width: 5),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: vc,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: selected ? color : Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 11))),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onCleared;
  final bool isDark;

  const _SearchField({
    required this.controller,
    required this.query,
    required this.onChanged,
    required this.onCleared,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 38,
    child: TextField(
      controller: controller,
      style: TextStyle(
        fontSize: 13,
        color: isDark ? Colors.white : const Color(0xFF1A1A1A),
      ),
      decoration: InputDecoration(
        hintText: 'ค้นหาเลขที่ใบแจ้งหนี้, ลูกค้า...',
        hintStyle: TextStyle(
          fontSize: 13,
          color: isDark ? const Color(0xFF666666) : const Color(0xFF8A8A8A),
        ),
        prefixIcon: Icon(
          Icons.search,
          size: 17,
          color: isDark ? const Color(0xFF666666) : const Color(0xFF8A8A8A),
        ),
        suffixIcon: query.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 15),
                onPressed: onCleared,
              )
            : null,
        contentPadding: EdgeInsets.zero,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
        ),
        filled: true,
        fillColor: isDark ? AppTheme.darkElement : Colors.white,
      ),
      onChanged: onChanged,
    ),
  );
}

class _IconShell extends StatelessWidget {
  final IconData icon;
  final bool isDark;
  final VoidCallback onTap;

  const _IconShell({
    required this.icon,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkElement : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF333333) : AppTheme.border,
        ),
      ),
      child: Icon(
        icon,
        size: 17,
        color: isDark ? const Color(0xFFAAAAAA) : const Color(0xFF8A8A8A),
      ),
    ),
  );
}
