import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pos_erp/shared/theme/app_theme.dart';
import 'package:pos_erp/shared/utils/responsive_utils.dart';
import 'package:pos_erp/shared/widgets/app_dialogs.dart';
import 'package:pos_erp/shared/widgets/pagination_bar.dart';
import 'package:pos_erp/shared/widgets/escape_pop_scope.dart';
import 'package:pos_erp/shared/pdf/pdf_report_button.dart';
import 'package:pos_erp/shared/pdf/pdf_export_service.dart';
import 'package:pos_erp/shared/widgets/mobile_home_button.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import '../providers/ap_invoice_provider.dart';
import '../../data/models/ap_invoice_model.dart';
import 'ap_invoice_form_page.dart';
import 'ap_invoice_pdf_report.dart';

class ApInvoiceListPage extends ConsumerStatefulWidget {
  const ApInvoiceListPage({super.key});

  @override
  ConsumerState<ApInvoiceListPage> createState() => _ApInvoiceListPageState();
}

class _ApInvoiceListPageState extends ConsumerState<ApInvoiceListPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'ALL';
  String? _supplierFilter;
  String _dateFilter = 'ALL';
  DateTimeRange? _customDateRange;
  bool _isCardView = false;
  int _currentPage = 1;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ApInvoiceModel> _filter(List<ApInvoiceModel> src) {
    return src.where((inv) {
      final matchesSearch =
          inv.invoiceNo.toLowerCase().contains(_searchQuery) ||
          inv.supplierName.toLowerCase().contains(_searchQuery);
      final matchesStatus =
          _statusFilter == 'ALL' ||
          (_statusFilter == 'OVERDUE'
              ? inv.isOverdue
              : inv.status == _statusFilter);
      final matchesSupplier =
          _supplierFilter == null || inv.supplierName == _supplierFilter;
      final matchesDate = _matchesDateFilter(inv.invoiceDate);
      return matchesSearch && matchesStatus && matchesSupplier && matchesDate;
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

  Future<void> _selectSupplierFilter(List<ApInvoiceModel> items) async {
    final suppliers = items
        .map((e) => e.supplierName.trim())
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
              title: const Text('ทุกซัพพลายเออร์'),
              onTap: () => Navigator.pop(context, ''),
            ),
            ...suppliers.map(
              (name) => ListTile(
                leading: Icon(
                  Icons.business_outlined,
                  color: name == _supplierFilter ? AppTheme.error : null,
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
      _supplierFilter = selected.isEmpty ? null : selected;
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

  // ─────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final invoicesAsync = ref.watch(apInvoiceListProvider);
    final pageSize = ref.watch(settingsProvider).listPageSize;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : const Color(0xFFF5F5F5),
      body: EscapePopScope(
        child: Column(
          children: [
            // ── Top Bar ──────────────────────────────────────────
            _APListTopBar(
              searchController: _searchController,
              searchQuery: _searchQuery,
              isCardView: _isCardView,
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
              onToggleView: () => setState(() => _isCardView = !_isCardView),
              onRefresh: () =>
                  ref.read(apInvoiceListProvider.notifier).refresh(),
              onAdd: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ApInvoiceFormPage()),
              ).then((_) => ref.read(apInvoiceListProvider.notifier).refresh()),
            ),

            // ── Summary + Status Filter Bar ──────────────────────
            _buildSummaryBar(invoicesAsync),

            // ── Content ─────────────────────────────────────────
            Expanded(
              child: invoicesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => _buildError(e),
                data: (invoices) {
                  final filtered = _filter(invoices);
                  if (filtered.isEmpty) return _buildEmpty();
                  final totalPages = (filtered.length / pageSize).ceil().clamp(
                    1,
                    9999,
                  );
                  final safePage = _currentPage.clamp(1, totalPages);
                  final start = (safePage - 1) * pageSize;
                  final end = (start + pageSize).clamp(0, filtered.length);
                  final pageItems = filtered.sublist(start, end);
                  return Column(
                    children: [
                      Expanded(
                        child: _isCardView
                            ? _buildCardView(pageItems)
                            : _buildListView(pageItems),
                      ),
                      PaginationBar(
                        currentPage: safePage,
                        totalItems: filtered.length,
                        pageSize: pageSize,
                        onPageChanged: (p) => setState(() => _currentPage = p),
                        trailing: PdfReportButton(
                          emptyMessage: 'ไม่มีข้อมูลใบแจ้งหนี้',
                          title: 'รายงานใบแจ้งหนี้ค้างชำระ',
                          filename: () =>
                              PdfFilename.generate('ap_invoice_report'),
                          buildPdf: () => ApInvoicePdfBuilder.build(filtered),
                          hasData: filtered.isNotEmpty,
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

  // ─────────────────────────────────────────────────────────────
  // Summary Bar + Status Filter
  // ─────────────────────────────────────────────────────────────
  Widget _buildSummaryBar(AsyncValue<List<ApInvoiceModel>> invoicesAsync) {
    return invoicesAsync.maybeWhen(
      data: (all) {
        final filtered = _filter(all);
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final fmt = NumberFormat('#,##0.00', 'th_TH');
        final totalRemaining = filtered.fold<double>(
          0,
          (s, i) => s + i.remainingAmount,
        );

        int countByStatus(String s) => all.where((i) => i.status == s).length;
        final overdueCount = all.where((i) => i.isOverdue).length;

        return Container(
          color: isDark ? AppTheme.darkCard : Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final filterWrap = Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _APActionChip(
                    label: _supplierFilter ?? 'ซัพพลายเออร์',
                    icon: Icons.business_outlined,
                    active: _supplierFilter != null,
                    color: AppTheme.error,
                    onTap: () => _selectSupplierFilter(all),
                  ),
                  _APActionChip(
                    label: _dateFilterLabel,
                    icon: Icons.calendar_today_outlined,
                    active: _dateFilter != 'ALL',
                    color: AppTheme.primaryDark,
                    onTap: _selectDateFilter,
                  ),
                  _APFilterChip(
                    label: 'ทั้งหมด',
                    count: all.length,
                    color: AppTheme.navy,
                    selected: _statusFilter == 'ALL',
                    onTap: () => setState(() {
                      _statusFilter = 'ALL';
                      _currentPage = 1;
                    }),
                  ),
                  _APFilterChip(
                    label: 'ยังไม่จ่าย',
                    count: countByStatus('UNPAID'),
                    color: AppTheme.error,
                    selected: _statusFilter == 'UNPAID',
                    onTap: () => setState(() {
                      _statusFilter = 'UNPAID';
                      _currentPage = 1;
                    }),
                  ),
                  _APFilterChip(
                    label: 'บางส่วน',
                    count: countByStatus('PARTIAL'),
                    color: AppTheme.warning,
                    selected: _statusFilter == 'PARTIAL',
                    onTap: () => setState(() {
                      _statusFilter = 'PARTIAL';
                      _currentPage = 1;
                    }),
                  ),
                  _APFilterChip(
                    label: 'จ่ายแล้ว',
                    count: countByStatus('PAID'),
                    color: AppTheme.success,
                    selected: _statusFilter == 'PAID',
                    onTap: () => setState(() {
                      _statusFilter = 'PAID';
                      _currentPage = 1;
                    }),
                  ),
                  if (overdueCount > 0)
                    _APFilterChip(
                      label: 'เลยกำหนด',
                      count: overdueCount,
                      color: AppTheme.error,
                      selected: _statusFilter == 'OVERDUE',
                      onTap: () => setState(() {
                        _statusFilter = 'OVERDUE';
                        _currentPage = 1;
                      }),
                    ),
                ],
              );

              final statsWrap = Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  _APValueStat(
                    label: 'กรองแล้ว',
                    value: '${filtered.length} ใบ',
                    color: AppTheme.primaryDark,
                  ),
                  _APValueStat(
                    label: 'ยอดค้างชำระ',
                    value: '฿${fmt.format(totalRemaining)}',
                    color: AppTheme.error,
                  ),
                ],
              );

              final isCompact = constraints.maxWidth < 900;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isCompact) ...[
                    filterWrap,
                    const SizedBox(height: 8),
                    Align(alignment: Alignment.centerRight, child: statsWrap),
                  ] else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: filterWrap),
                        const SizedBox(width: 12),
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: constraints.maxWidth * 0.42,
                          ),
                          child: Align(
                            alignment: Alignment.topRight,
                            child: statsWrap,
                          ),
                        ),
                      ],
                    ),
                ],
              );
            },
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // CARD VIEW
  // ─────────────────────────────────────────────────────────────
  Widget _buildCardView(List<ApInvoiceModel> items) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) => _APCard(
        invoice: items[i],
        onTap: () => _openForm(items[i]),
        onDelete: () => _deleteInvoice(items[i]),
        onPrintPdf: () => _openInvoicePdf(items[i]),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // LIST VIEW (compact)
  // ─────────────────────────────────────────────────────────────
  Widget _buildListView(List<ApInvoiceModel> items) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        // Header row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: isDark ? AppTheme.darkElement : AppTheme.headerBg,
          child: Row(
            children: [
              const SizedBox(width: 14),
              Expanded(
                flex: 3,
                child: Text(
                  'เลขที่ / ซัพพลายเออร์',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFFAAAAAA) : AppTheme.textSub,
                  ),
                ),
              ),
              SizedBox(
                width: 68,
                child: Text(
                  'ครบกำหนด',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFFAAAAAA) : AppTheme.textSub,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(
                width: 76,
                child: Text(
                  'สถานะ',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFFAAAAAA) : AppTheme.textSub,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(
                width: 90,
                child: Text(
                  'ค้างชำระ',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFFAAAAAA) : AppTheme.textSub,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, i) {
              final inv = items[i];
              final isEven = i.isEven;
              final canAct = inv.status != 'PAID';
              return InkWell(
                onTap: () => _openForm(inv),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isEven
                        ? (isDark ? AppTheme.darkCard : Colors.white)
                        : (isDark
                              ? AppTheme.darkElement
                              : const Color(0xFFF9F9F9)),
                    border: Border(
                      bottom: BorderSide(
                        color: isDark
                            ? const Color(0xFF2C2C2C)
                            : AppTheme.border,
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── แถว 1: ข้อมูลหลัก ────────────────
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 34,
                            decoration: BoxDecoration(
                              color: _getStatusColor(inv.status),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        inv.invoiceNo,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? Colors.white
                                              : const Color(0xFF1A1A1A),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (inv.isOverdue) ...[
                                      const SizedBox(width: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 5,
                                          vertical: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppTheme.error.withValues(
                                            alpha: 0.12,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: const Text(
                                          'เลยกำหนด',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.error,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                Text(
                                  inv.supplierName,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? const Color(0xFFAAAAAA)
                                        : AppTheme.textSub,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 68,
                            child: Text(
                              inv.dueDate != null
                                  ? DateFormat('dd/MM/yy').format(inv.dueDate!)
                                  : '-',
                              style: TextStyle(
                                fontSize: 11,
                                color: inv.isOverdue
                                    ? AppTheme.error
                                    : (isDark
                                          ? const Color(0xFFAAAAAA)
                                          : AppTheme.textSub),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          SizedBox(
                            width: 76,
                            child: Center(child: _buildStatusBadge(inv.status)),
                          ),
                          SizedBox(
                            width: 90,
                            child: Text(
                              '฿${NumberFormat('#,##0.00', 'th_TH').format(inv.remainingAmount)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: inv.remainingAmount > 0
                                    ? AppTheme.error
                                    : AppTheme.success,
                              ),
                              textAlign: TextAlign.right,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      // ── แถว 2: ปุ่ม action ─────────────────
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          SizedBox(
                            width: 52,
                            height: 34,
                            child: OutlinedButton(
                              onPressed: () => _openInvoicePdf(inv),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.primaryDark,
                                side: const BorderSide(color: AppTheme.primaryDark),
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                            ),
                          ),
                          if (canAct) ...[
                            const SizedBox(width: 8),
                            if (inv.status == 'UNPAID') ...[
                              SizedBox(
                                width: 52,
                                height: 34,
                                child: OutlinedButton(
                                  onPressed: () => _deleteInvoice(inv),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.error,
                                    side: const BorderSide(color: AppTheme.error),
                                    padding: EdgeInsets.zero,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Icon(Icons.delete_outline, size: 18),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            SizedBox(
                              width: 108,
                              height: 34,
                              child: ElevatedButton.icon(
                                onPressed: () => _openForm(inv),
                                icon: const Icon(Icons.payment, size: 14),
                                label: const Text(
                                  'บันทึกชำระ',
                                  style: TextStyle(fontSize: 12),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.info,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────
  Color _getStatusColor(String status) {
    switch (status) {
      case 'UNPAID':
        return AppTheme.error;
      case 'PARTIAL':
        return AppTheme.warning;
      case 'PAID':
        return AppTheme.success;
      default:
        return AppTheme.textSub;
    }
  }

  Widget _buildStatusBadge(String status) {
    final color = _getStatusColor(status);
    String label;
    switch (status) {
      case 'UNPAID':
        label = 'ยังไม่จ่าย';
        break;
      case 'PARTIAL':
        label = 'บางส่วน';
        break;
      case 'PAID':
        label = 'จ่ายแล้ว';
        break;
      default:
        label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _searchQuery.isEmpty
                ? Icons.receipt_long_outlined
                : Icons.search_off_outlined,
            size: 72,
            color: isDark ? const Color(0xFF444444) : Colors.grey[300],
          ),
          const SizedBox(height: 12),
          Text(
            _searchQuery.isEmpty
                ? 'ยังไม่มีใบแจ้งหนี้'
                : 'ไม่พบใบแจ้งหนี้ "$_searchQuery"',
            style: TextStyle(
              color: isDark ? const Color(0xFF888888) : Colors.grey[500],
            ),
          ),
          if (_searchQuery.isEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'กดปุ่ม + เพื่อสร้างใบแจ้งหนี้ใหม่',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? const Color(0xFF666666) : Colors.grey[400],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildError(Object e) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline, size: 72, color: AppTheme.error),
        const SizedBox(height: 12),
        Text('เกิดข้อผิดพลาด: $e'),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: () => ref.read(apInvoiceListProvider.notifier).refresh(),
          child: const Text('ลองใหม่'),
        ),
      ],
    ),
  );

  // ─────────────────────────────────────────────────────────────
  // Actions
  // ─────────────────────────────────────────────────────────────
  Future<void> _openForm(ApInvoiceModel invoice) async {
    final fullInvoice =
        await ref.read(apInvoiceListProvider.notifier).getInvoiceDetails(
          invoice.invoiceId,
        );
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ApInvoiceFormPage(invoice: fullInvoice ?? invoice),
      ),
    );
    if (!mounted) return;
    ref.read(apInvoiceListProvider.notifier).refresh();
  }

  Future<void> _openInvoicePdf(ApInvoiceModel invoice) async {
    final full = await ref
        .read(apInvoiceListProvider.notifier)
        .getInvoiceDetails(invoice.invoiceId);
    final pdfInvoice = full ?? invoice;
    if (!mounted) return;
    await PdfExportService.showPreview(
      context,
      title: 'ใบแจ้งหนี้ ${pdfInvoice.invoiceNo}',
      filename: PdfFilename.generate('ap_invoice_${pdfInvoice.invoiceNo}'),
      buildPdf: () => ApInvoicePdfBuilder.build([pdfInvoice]),
    );
  }

  Future<void> _deleteInvoice(ApInvoiceModel invoice) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: buildAppDialogTitle(
          ctx,
          title: 'ยืนยันการลบ',
          icon: Icons.delete_outline,
          iconColor: AppTheme.error,
        ),
        content: Text(
          'ต้องการลบใบแจ้งหนี้ ${invoice.invoiceNo} ออกจากระบบ?',
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'ยกเลิก',
              style: TextStyle(
                color: isDark ? Colors.white60 : AppTheme.textSub,
              ),
            ),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.delete_forever, size: 16),
            label: const Text('ลบ'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final success = await ref
        .read(apInvoiceListProvider.notifier)
        .deleteInvoice(invoice.invoiceId);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'ลบใบแจ้งหนี้สำเร็จ' : 'ลบใบแจ้งหนี้ไม่สำเร็จ'),
        backgroundColor: success ? AppTheme.success : AppTheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// _APCard — Card view item
// ════════════════════════════════════════════════════════════════
class _APCard extends StatelessWidget {
  final ApInvoiceModel invoice;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onPrintPdf;

  const _APCard({
    required this.invoice,
    required this.onTap,
    required this.onDelete,
    required this.onPrintPdf,
  });

  Color get _statusColor {
    switch (invoice.status) {
      case 'UNPAID':
        return AppTheme.error;
      case 'PARTIAL':
        return AppTheme.warning;
      case 'PAID':
        return AppTheme.success;
      default:
        return AppTheme.textSub;
    }
  }

  String get _statusLabel {
    switch (invoice.status) {
      case 'UNPAID':
        return 'ยังไม่จ่าย';
      case 'PARTIAL':
        return 'จ่ายบางส่วน';
      case 'PAID':
        return 'จ่ายครบแล้ว';
      default:
        return invoice.status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fmt = NumberFormat('#,##0.00', 'th_TH');

    final colors = [
      AppTheme.error,
      AppTheme.warning,
      AppTheme.info,
      AppTheme.primary,
      AppTheme.purpleColor,
      AppTheme.tealColor,
    ];
    final name = invoice.supplierName;
    final avatarColor = colors[name.codeUnitAt(0) % colors.length];
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'S';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: invoice.isOverdue
              ? AppTheme.error.withValues(alpha: 0.35)
              : (isDark ? const Color(0xFF333333) : AppTheme.border),
        ),
      ),
      color: isDark ? AppTheme.darkCard : Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Row 1: Avatar + Info + Badges ─────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: avatarColor,
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          invoice.invoiceNo,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          invoice.supplierName,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? const Color(0xFFAAAAAA)
                                : AppTheme.textSub,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _StatusBadge(label: _statusLabel, color: _statusColor),
                      if (invoice.isOverdue) ...[
                        const SizedBox(height: 4),
                        _StatusBadge(label: 'เลยกำหนด', color: AppTheme.error),
                      ],
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 10),
              Divider(
                height: 1,
                color: isDark ? const Color(0xFF2C2C2C) : AppTheme.border,
              ),
              const SizedBox(height: 10),

              // ── Row 2: Dates ────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _InfoChip(
                      icon: Icons.calendar_today_outlined,
                      text: DateFormat(
                        'dd/MM/yyyy',
                      ).format(invoice.invoiceDate),
                      isDark: isDark,
                    ),
                  ),
                  Expanded(
                    child: _InfoChip(
                      icon: Icons.event_outlined,
                      text: invoice.dueDate != null
                          ? 'ครบกำหนด ${DateFormat('dd/MM/yyyy').format(invoice.dueDate!)}'
                          : 'ไม่ระบุกำหนด',
                      isDark: isDark,
                      color: invoice.isOverdue ? AppTheme.error : null,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // ── Row 3: Amounts ──────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _AmountTile(
                      label: 'ยอดรวม',
                      value: '฿${fmt.format(invoice.totalAmount)}',
                      labelColor: isDark
                          ? const Color(0xFFAAAAAA)
                          : AppTheme.textSub,
                      valueColor: isDark
                          ? Colors.white
                          : const Color(0xFF1A1A1A),
                    ),
                  ),
                  Expanded(
                    child: _AmountTile(
                      label: 'จ่ายแล้ว',
                      value: '฿${fmt.format(invoice.paidAmount)}',
                      labelColor: isDark
                          ? const Color(0xFFAAAAAA)
                          : AppTheme.textSub,
                      valueColor: AppTheme.success,
                    ),
                  ),
                  Expanded(
                    child: _AmountTile(
                      label: 'ค้างชำระ',
                      value: '฿${fmt.format(invoice.remainingAmount)}',
                      labelColor: isDark
                          ? const Color(0xFFAAAAAA)
                          : AppTheme.textSub,
                      valueColor: invoice.remainingAmount > 0
                          ? AppTheme.error
                          : AppTheme.success,
                    ),
                  ),
                ],
              ),

              // ── Row 4: Action buttons ───────────────────────────
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SizedBox(
                    width: 52,
                    height: 34,
                    child: OutlinedButton(
                      onPressed: onPrintPdf,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryDark,
                        side: const BorderSide(color: AppTheme.primaryDark),
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                    ),
                  ),
                  if (invoice.status != 'PAID') ...[
                    const SizedBox(width: 8),
                    if (invoice.status == 'UNPAID') ...[
                      SizedBox(
                        width: 52,
                        height: 34,
                        child: OutlinedButton(
                          onPressed: onDelete,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.error,
                            side: const BorderSide(color: AppTheme.error),
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Icon(Icons.delete_outline, size: 18),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    SizedBox(
                      width: 112,
                      height: 34,
                      child: ElevatedButton.icon(
                        onPressed: onTap,
                        icon: const Icon(Icons.payment, size: 14),
                        label: const Text(
                          'บันทึกชำระ',
                          style: TextStyle(fontSize: 12),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.info,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// _APListTopBar — responsive top bar
// ════════════════════════════════════════════════════════════════
class _APListTopBar extends StatelessWidget {
  final TextEditingController searchController;
  final String searchQuery;
  final bool isCardView;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchCleared;
  final VoidCallback onToggleView;
  final VoidCallback onRefresh;
  final VoidCallback onAdd;

  const _APListTopBar({
    required this.searchController,
    required this.searchQuery,
    required this.isCardView,
    required this.onSearchChanged,
    required this.onSearchCleared,
    required this.onToggleView,
    required this.onRefresh,
    required this.onAdd,
  });

  static const _kBreak = 640.0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isWide = MediaQuery.of(context).size.width >= _kBreak;
    final canPop = Navigator.of(context).canPop();

    return Container(
      color: isDark ? AppTheme.darkTopBar : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: isWide
          ? _buildSingleRow(context, canPop, isDark)
          : _buildDoubleRow(context, canPop, isDark),
    );
  }

  Widget _buildSingleRow(BuildContext context, bool canPop, bool isDark) {
    return Row(
      children: [
        if (canPop) ...[_APBackBtn(isDark: isDark), const SizedBox(width: 10)],
        _APPageIcon(),
        const SizedBox(width: 10),
        Text(
          'ใบแจ้งหนี้ค้างชำระ',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF1A1A1A),
          ),
        ),
        const Spacer(),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: _APSearchField(
            controller: searchController,
            query: searchQuery,
            onChanged: onSearchChanged,
            onCleared: onSearchCleared,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 8),
        _APIconBtn(
          icon: isCardView
              ? Icons.view_list_outlined
              : Icons.grid_view_outlined,
          tooltip: isCardView ? 'List View' : 'Card View',
          isDark: isDark,
          onTap: onToggleView,
        ),
        const SizedBox(width: 6),
        _APIconBtn(
          icon: Icons.refresh,
          tooltip: 'รีเฟรช',
          isDark: isDark,
          onTap: onRefresh,
        ),
        const SizedBox(width: 6),
        _APAddBtn(onTap: onAdd),
      ],
    );
  }

  Widget _buildDoubleRow(BuildContext context, bool canPop, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (canPop) ...[
              _APBackBtn(isDark: isDark),
              const SizedBox(width: 8),
            ],
            _APPageIcon(),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'ใบแจ้งหนี้ค้างชำระ',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _APIconBtn(
              icon: isCardView
                  ? Icons.view_list_outlined
                  : Icons.grid_view_outlined,
              tooltip: isCardView ? 'List View' : 'Card View',
              isDark: isDark,
              onTap: onToggleView,
            ),
            const SizedBox(width: 4),
            _APIconBtn(
              icon: Icons.refresh,
              tooltip: 'รีเฟรช',
              isDark: isDark,
              onTap: onRefresh,
            ),
            const SizedBox(width: 4),
            _APAddBtn(onTap: onAdd, compact: true),
          ],
        ),
        const SizedBox(height: 10),
        _APSearchField(
          controller: searchController,
          query: searchQuery,
          onChanged: onSearchChanged,
          onCleared: onSearchCleared,
          isDark: isDark,
        ),
      ],
    );
  }
}

// ── TopBar sub-widgets ─────────────────────────────────────────

class _APBackBtn extends StatelessWidget {
  final bool isDark;
  const _APBackBtn({required this.isDark});
  @override
  Widget build(BuildContext context) => context.isMobile
      ? buildMobileHomeCompactButton(context, isDark: isDark)
      : InkWell(
          onTap: () => Navigator.of(context).pop(),
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
              Icons.arrow_back_ios_new,
              size: 15,
              color: isDark ? const Color(0xFFAAAAAA) : const Color(0xFF8A8A8A),
            ),
          ),
        );
}

class _APPageIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(7),
    decoration: BoxDecoration(
      color: AppTheme.error.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Icon(
      Icons.receipt_long_outlined,
      color: AppTheme.error,
      size: 18,
    ),
  );
}

class _APSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onCleared;
  final bool isDark;

  const _APSearchField({
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
        hintText: 'ค้นหาเลขที่ใบแจ้งหนี้, ซัพพลายเออร์...',
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
          borderSide: const BorderSide(color: AppTheme.error, width: 1.5),
        ),
        filled: true,
        fillColor: isDark ? AppTheme.darkElement : Colors.white,
      ),
      onChanged: onChanged,
    ),
  );
}

class _APIconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isDark;
  final VoidCallback onTap;

  const _APIconBtn({
    required this.icon,
    required this.tooltip,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: InkWell(
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
    ),
  );
}

class _APAddBtn extends StatelessWidget {
  final VoidCallback onTap;
  final bool compact;
  const _APAddBtn({required this.onTap, this.compact = false});
  @override
  Widget build(BuildContext context) => ElevatedButton.icon(
    onPressed: onTap,
    icon: const Icon(Icons.add, size: 18),
    label: compact
        ? const SizedBox.shrink()
        : const Text(
            'สร้างใบแจ้งหนี้',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
    style: ElevatedButton.styleFrom(
      backgroundColor: AppTheme.error,
      foregroundColor: Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 16,
        vertical: 13,
      ),
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      elevation: 0,
    ),
  );
}

// ════════════════════════════════════════════════════════════════
// Shared small widgets
// ════════════════════════════════════════════════════════════════

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    ),
  );
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isDark;
  final Color? color;
  const _InfoChip({
    required this.icon,
    required this.text,
    required this.isDark,
    this.color,
  });
  @override
  Widget build(BuildContext context) {
    final c = color ?? (isDark ? const Color(0xFFAAAAAA) : AppTheme.textSub);
    return Row(
      children: [
        Icon(icon, size: 13, color: c),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 11, color: c),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _AmountTile extends StatelessWidget {
  final String label;
  final String value;
  final Color labelColor;
  final Color valueColor;
  const _AmountTile({
    required this.label,
    required this.value,
    required this.labelColor,
    required this.valueColor,
  });
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyle(fontSize: 10, color: labelColor)),
      Text(
        value,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: valueColor,
        ),
      ),
    ],
  );
}

class _APFilterChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _APFilterChip({
    required this.label,
    required this.count,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  static Color _visible(Color c, bool isDark) {
    if (!isDark) return c;
    final hsl = HSLColor.fromColor(c);
    if (hsl.lightness < 0.50) {
      return hsl
          .withLightness(0.68)
          .withSaturation((hsl.saturation * 0.75).clamp(0.0, 1.0))
          .toColor();
    }
    return c;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final vc = _visible(color, isDark);

    if (!selected) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkElement : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? const Color(0xFF4A4A4A) : AppTheme.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : AppTheme.textSub,
                ),
              ),
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF5A5A5A) : AppTheme.textSub,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: vc.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: vc, width: 1.5),
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
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: vc,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _APValueStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _APValueStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? const Color(0xFFAAAAAA) : AppTheme.textSub,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _APActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  const _APActionChip({
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
