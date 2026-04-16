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
import '../providers/ap_payment_provider.dart';
import '../../data/models/ap_payment_model.dart';
import 'ap_payment_form_page.dart';
import 'ap_payment_pdf_report.dart';

class ApPaymentListPage extends ConsumerStatefulWidget {
  const ApPaymentListPage({super.key});

  @override
  ConsumerState<ApPaymentListPage> createState() => _ApPaymentListPageState();
}

class _ApPaymentListPageState extends ConsumerState<ApPaymentListPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _methodFilter = 'ALL';
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

  List<ApPaymentModel> _filter(List<ApPaymentModel> src) {
    return src.where((p) {
      final matchSearch =
          p.paymentNo.toLowerCase().contains(_searchQuery) ||
          p.supplierName.toLowerCase().contains(_searchQuery);
      final matchMethod =
          _methodFilter == 'ALL' || p.paymentMethod == _methodFilter;
      final matchSupplier =
          _supplierFilter == null || p.supplierName == _supplierFilter;
      final matchDate = _matchesDateFilter(p.paymentDate);
      return matchSearch && matchMethod && matchSupplier && matchDate;
    }).toList()..sort((a, b) => b.paymentDate.compareTo(a.paymentDate));
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

  Future<void> _selectSupplierFilter(List<ApPaymentModel> items) async {
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
                  color: name == _supplierFilter ? AppTheme.tealColor : null,
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
  @override
  Widget build(BuildContext context) {
    final paymentsAsync = ref.watch(apPaymentListProvider);
    final pageSize = ref.watch(settingsProvider).listPageSize;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : const Color(0xFFF5F5F5),
      body: EscapePopScope(
        child: Column(
          children: [
            _PayListTopBar(
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
                  ref.read(apPaymentListProvider.notifier).refresh(),
              onAdd: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ApPaymentFormPage()),
              ).then((_) => ref.read(apPaymentListProvider.notifier).refresh()),
            ),

            _buildSummaryBar(paymentsAsync),

            Expanded(
              child: paymentsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => _buildError(e),
                data: (payments) {
                  final filtered = _filter(payments);
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
                          emptyMessage: 'ไม่มีข้อมูลการจ่ายเงิน',
                          title: 'รายงานการจ่ายเงิน',
                          filename: () =>
                              PdfFilename.generate('ap_payment_report'),
                          buildPdf: () => ApPaymentPdfBuilder.build(filtered),
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

  // ─── Summary / Method Filter Bar ──────────────────────────────
  Widget _buildSummaryBar(AsyncValue<List<ApPaymentModel>> async) {
    return async.maybeWhen(
      data: (all) {
        final filtered = _filter(all);
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final fmt = NumberFormat('#,##0.00', 'th_TH');
        final totalAmt = filtered.fold<double>(0, (s, p) => s + p.totalAmount);

        int countMethod(String m) =>
            all.where((p) => p.paymentMethod == m).length;

        return Container(
          color: isDark ? AppTheme.darkCard : Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final filterWrap = Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _PayActionChip(
                    label: _supplierFilter ?? 'ซัพพลายเออร์',
                    icon: Icons.business_outlined,
                    active: _supplierFilter != null,
                    color: AppTheme.tealColor,
                    onTap: () => _selectSupplierFilter(all),
                  ),
                  _PayActionChip(
                    label: _dateFilterLabel,
                    icon: Icons.calendar_today_outlined,
                    active: _dateFilter != 'ALL',
                    color: AppTheme.info,
                    onTap: _selectDateFilter,
                  ),
                  _PayFilterChip(
                    label: 'ทั้งหมด',
                    count: all.length,
                    color: AppTheme.tealColor,
                    selected: _methodFilter == 'ALL',
                    onTap: () => setState(() {
                      _methodFilter = 'ALL';
                      _currentPage = 1;
                    }),
                  ),
                  _PayFilterChip(
                    label: 'เงินสด',
                    count: countMethod('CASH'),
                    color: AppTheme.success,
                    selected: _methodFilter == 'CASH',
                    onTap: () => setState(() {
                      _methodFilter = 'CASH';
                      _currentPage = 1;
                    }),
                  ),
                  _PayFilterChip(
                    label: 'โอนเงิน',
                    count: countMethod('TRANSFER'),
                    color: AppTheme.info,
                    selected: _methodFilter == 'TRANSFER',
                    onTap: () => setState(() {
                      _methodFilter = 'TRANSFER';
                      _currentPage = 1;
                    }),
                  ),
                  _PayFilterChip(
                    label: 'เช็ค',
                    count: countMethod('CHEQUE'),
                    color: AppTheme.warning,
                    selected: _methodFilter == 'CHEQUE',
                    onTap: () => setState(() {
                      _methodFilter = 'CHEQUE';
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
                  _PayValueStat(
                    label: 'กรองแล้ว',
                    value: '${filtered.length} รายการ',
                    color: AppTheme.tealColor,
                  ),
                  _PayValueStat(
                    label: 'ยอดจ่ายรวม',
                    value: '฿${fmt.format(totalAmt)}',
                    color: AppTheme.success,
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

  // ─── Card View ────────────────────────────────────────────────
  Widget _buildCardView(List<ApPaymentModel> items) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) => _PayCard(
        payment: items[i],
        onTap: () => _viewDetails(items[i]),
        onDelete: () => _deletePayment(items[i]),
        onPrintPdf: () => _openPaymentPdf(items[i]),
      ),
    );
  }

  // ─── List View ────────────────────────────────────────────────
  Widget _buildListView(List<ApPaymentModel> items) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
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
                  'วันที่',
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
                  'วิธีจ่าย',
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
                  'ยอดจ่าย',
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
              final p = items[i];
              final isEven = i.isEven;
              final methodColor = _getMethodColor(p.paymentMethod);
              return InkWell(
                onTap: () => _viewDetails(p),
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
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 34,
                            decoration: BoxDecoration(
                              color: methodColor,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.paymentNo,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF1A1A1A),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  p.supplierName,
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
                              DateFormat('dd/MM/yy').format(p.paymentDate),
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? const Color(0xFFAAAAAA)
                                    : AppTheme.textSub,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          SizedBox(
                            width: 76,
                            child: Center(
                              child: _buildMethodBadge(p.paymentMethod, isDark),
                            ),
                          ),
                          SizedBox(
                            width: 90,
                            child: Text(
                              '฿${NumberFormat('#,##0.00', 'th_TH').format(p.totalAmount)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.tealColor,
                              ),
                              textAlign: TextAlign.right,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          SizedBox(
                            width: 52,
                            height: 34,
                            child: OutlinedButton(
                              onPressed: () => _openPaymentPdf(p),
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

  // ─── Helpers ─────────────────────────────────────────────────
  Color _getMethodColor(String m) {
    switch (m) {
      case 'CASH':
        return AppTheme.success;
      case 'TRANSFER':
        return AppTheme.info;
      case 'CHEQUE':
        return AppTheme.warning;
      default:
        return AppTheme.tealColor;
    }
  }

  Widget _buildMethodBadge(String m, bool isDark) {
    final color = _getMethodColor(m);
    String label;
    switch (m) {
      case 'CASH':
        label = 'เงินสด';
        break;
      case 'TRANSFER':
        label = 'โอนเงิน';
        break;
      case 'CHEQUE':
        label = 'เช็ค';
        break;
      default:
        label = m;
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
                ? Icons.payments_outlined
                : Icons.search_off_outlined,
            size: 72,
            color: isDark ? const Color(0xFF444444) : Colors.grey[300],
          ),
          const SizedBox(height: 12),
          Text(
            _searchQuery.isEmpty
                ? 'ยังไม่มีประวัติการจ่ายเงิน'
                : 'ไม่พบรายการ "$_searchQuery"',
            style: TextStyle(
              color: isDark ? const Color(0xFF888888) : Colors.grey[500],
            ),
          ),
          if (_searchQuery.isEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'กดปุ่ม + เพื่อบันทึกการจ่ายเงินใหม่',
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
          onPressed: () => ref.read(apPaymentListProvider.notifier).refresh(),
          child: const Text('ลองใหม่'),
        ),
      ],
    ),
  );

  // ─── Actions ─────────────────────────────────────────────────
  Future<void> _openPaymentPdf(ApPaymentModel payment) async {
    final full = await ref
        .read(apPaymentListProvider.notifier)
        .getPaymentDetails(payment.paymentId);
    final pdfPayment = full ?? payment;
    if (!mounted) return;
    await PdfExportService.showPreview(
      context,
      title: 'ใบจ่ายเงิน ${pdfPayment.paymentNo}',
      filename: PdfFilename.generate('ap_payment_${pdfPayment.paymentNo}'),
      buildPdf: () => ApPaymentPdfBuilder.build([pdfPayment]),
    );
  }

  Future<void> _viewDetails(ApPaymentModel payment) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final paymentDetails = await ref
        .read(apPaymentListProvider.notifier)
        .getPaymentDetails(payment.paymentId);

    if (!mounted) return;

    final fmt = NumberFormat('#,##0.00', 'th_TH');
    final fmtDate = DateFormat('dd/MM/yyyy');
    showDialog(
      context: context,
      builder: (ctx) => AppDialog(
        backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        title: buildAppDialogTitle(
          ctx,
          title: payment.paymentNo,
          icon: Icons.payments_outlined,
          iconColor: AppTheme.tealColor,
        ),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                _DetailRow(
                  label: 'วันที่จ่าย',
                  value: fmtDate.format(payment.paymentDate),
                  isDark: isDark,
                ),
                if (payment.bankName != null)
                  _DetailRow(
                    label: 'ธนาคาร',
                    value: payment.bankName!,
                    isDark: isDark,
                  ),
                if (payment.transferRef != null)
                  _DetailRow(
                    label: 'เลขที่อ้างอิง',
                    value: payment.transferRef!,
                    isDark: isDark,
                  ),
                if (payment.chequeNo != null)
                  _DetailRow(
                    label: 'เลขที่เช็ค',
                    value: payment.chequeNo!,
                    isDark: isDark,
                  ),
                if (payment.remark != null && payment.remark!.isNotEmpty)
                  _DetailRow(
                    label: 'หมายเหตุ',
                    value: payment.remark!,
                    isDark: isDark,
                  ),
                const SizedBox(height: 8),
                // Amount highlight
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.tealColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.tealColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'ยอดจ่ายทั้งหมด',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.white70
                              : const Color(0xFF1A1A1A),
                        ),
                      ),
                      Text(
                        '฿${fmt.format(payment.totalAmount)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.tealColor,
                        ),
                      ),
                    ],
                  ),
                ),

                if (paymentDetails?.allocations != null &&
                    paymentDetails!.allocations!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'การจัดสรรเงิน',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : const Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...paymentDetails.allocations!.map(
                    (alloc) => Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppTheme.darkElement
                            : const Color(0xFFF9F9F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF333333)
                              : AppTheme.border,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Invoice: ${alloc.invoiceId}',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? const Color(0xFFAAAAAA)
                                  : AppTheme.textSub,
                            ),
                          ),
                          Text(
                            '฿${fmt.format(alloc.allocatedAmount)}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.tealColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'ปิด',
              style: TextStyle(
                color: isDark ? Colors.white60 : AppTheme.textSub,
              ),
            ),
          ),
          if (paymentDetails != null)
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
              onPressed: () async {
                Navigator.pop(ctx);
                await _deletePayment(payment);
              },
            ),
        ],
      ),
    );
  }

  Future<void> _deletePayment(ApPaymentModel payment) async {
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
          'ต้องการลบ ${payment.paymentNo} ออกจากระบบ?',
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
        .read(apPaymentListProvider.notifier)
        .deletePayment(payment.paymentId);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'ลบรายการสำเร็จ' : 'ลบไม่สำเร็จ'),
        backgroundColor: success ? AppTheme.success : AppTheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// _PayCard
// ════════════════════════════════════════════════════════════════
class _PayCard extends StatelessWidget {
  final ApPaymentModel payment;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onPrintPdf;

  const _PayCard({
    required this.payment,
    required this.onTap,
    required this.onDelete,
    required this.onPrintPdf,
  });

  Color get _methodColor {
    switch (payment.paymentMethod) {
      case 'CASH':
        return AppTheme.success;
      case 'TRANSFER':
        return AppTheme.info;
      case 'CHEQUE':
        return AppTheme.warning;
      default:
        return AppTheme.tealColor;
    }
  }

  String get _methodLabel {
    switch (payment.paymentMethod) {
      case 'CASH':
        return 'เงินสด';
      case 'TRANSFER':
        return 'โอนเงิน';
      case 'CHEQUE':
        return 'เช็ค';
      default:
        return payment.paymentMethod;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fmt = NumberFormat('#,##0.00', 'th_TH');

    final colors = [
      AppTheme.tealColor,
      AppTheme.info,
      AppTheme.success,
      AppTheme.primary,
      AppTheme.purpleColor,
      AppTheme.warning,
    ];
    final name = payment.supplierName;
    final avatarColor = colors[name.codeUnitAt(0) % colors.length];
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'S';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isDark ? const Color(0xFF333333) : AppTheme.border,
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
              // Row 1: Avatar + Info + Method Badge
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
                          payment.paymentNo,
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
                          payment.supplierName,
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
                  _MethodBadge(label: _methodLabel, color: _methodColor),
                ],
              ),

              const SizedBox(height: 10),
              Divider(
                height: 1,
                color: isDark ? const Color(0xFF2C2C2C) : AppTheme.border,
              ),
              const SizedBox(height: 10),

              // Row 2: Dates
              Row(
                children: [
                  Expanded(
                    child: _InfoChip(
                      icon: Icons.calendar_today_outlined,
                      text: DateFormat(
                        'dd/MM/yyyy',
                      ).format(payment.paymentDate),
                      isDark: isDark,
                    ),
                  ),
                  Expanded(
                    child: _InfoChip(
                      icon: Icons.access_time_outlined,
                      text: DateFormat('HH:mm').format(payment.createdAt),
                      isDark: isDark,
                    ),
                  ),
                ],
              ),

              if (payment.remark != null && payment.remark!.isNotEmpty) ...[
                const SizedBox(height: 6),
                _InfoChip(
                  icon: Icons.note_outlined,
                  text: payment.remark!,
                  isDark: isDark,
                ),
              ],

              const SizedBox(height: 10),

              // Row 3: Amount
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ยอดจ่าย',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark
                                ? const Color(0xFFAAAAAA)
                                : AppTheme.textSub,
                          ),
                        ),
                        Text(
                          '฿${fmt.format(payment.totalAmount)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.tealColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // PDF button
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
                  const SizedBox(width: 8),
                  // Delete button
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
// _PayListTopBar
// ════════════════════════════════════════════════════════════════
class _PayListTopBar extends StatelessWidget {
  final TextEditingController searchController;
  final String searchQuery;
  final bool isCardView;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchCleared;
  final VoidCallback onToggleView;
  final VoidCallback onRefresh;
  final VoidCallback onAdd;

  const _PayListTopBar({
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
        if (canPop) ...[_BackBtn(isDark: isDark), const SizedBox(width: 10)],
        _PageIcon(),
        const SizedBox(width: 10),
        Text(
          'ประวัติการจ่ายเงิน',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF1A1A1A),
          ),
        ),
        const Spacer(),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: _SearchField(
            controller: searchController,
            query: searchQuery,
            onChanged: onSearchChanged,
            onCleared: onSearchCleared,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 8),
        _IconBtn(
          icon: isCardView
              ? Icons.view_list_outlined
              : Icons.grid_view_outlined,
          tooltip: isCardView ? 'List View' : 'Card View',
          isDark: isDark,
          onTap: onToggleView,
        ),
        const SizedBox(width: 6),
        _IconBtn(
          icon: Icons.refresh,
          tooltip: 'รีเฟรช',
          isDark: isDark,
          onTap: onRefresh,
        ),
        const SizedBox(width: 6),
        _AddBtn(onTap: onAdd),
      ],
    );
  }

  Widget _buildDoubleRow(BuildContext context, bool canPop, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (canPop) ...[_BackBtn(isDark: isDark), const SizedBox(width: 8)],
            _PageIcon(),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'ประวัติการจ่ายเงิน',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _IconBtn(
              icon: isCardView
                  ? Icons.view_list_outlined
                  : Icons.grid_view_outlined,
              tooltip: isCardView ? 'List View' : 'Card View',
              isDark: isDark,
              onTap: onToggleView,
            ),
            const SizedBox(width: 4),
            _IconBtn(
              icon: Icons.refresh,
              tooltip: 'รีเฟรช',
              isDark: isDark,
              onTap: onRefresh,
            ),
            const SizedBox(width: 4),
            _AddBtn(onTap: onAdd, compact: true),
          ],
        ),
        const SizedBox(height: 10),
        _SearchField(
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

// ── TopBar helpers ─────────────────────────────────────────────

class _BackBtn extends StatelessWidget {
  final bool isDark;
  const _BackBtn({required this.isDark});
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

class _PageIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(7),
    decoration: BoxDecoration(
      color: AppTheme.tealColor.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Icon(
      Icons.payments_outlined,
      color: AppTheme.tealColor,
      size: 18,
    ),
  );
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
        hintText: 'ค้นหาเลขที่ใบจ่ายเงิน, ซัพพลายเออร์...',
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
          borderSide: const BorderSide(color: AppTheme.tealColor, width: 1.5),
        ),
        filled: true,
        fillColor: isDark ? AppTheme.darkElement : Colors.white,
      ),
      onChanged: onChanged,
    ),
  );
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isDark;
  final VoidCallback onTap;

  const _IconBtn({
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

class _AddBtn extends StatelessWidget {
  final VoidCallback onTap;
  final bool compact;
  const _AddBtn({required this.onTap, this.compact = false});
  @override
  Widget build(BuildContext context) => ElevatedButton.icon(
    onPressed: onTap,
    icon: const Icon(Icons.add, size: 18),
    label: compact
        ? const SizedBox.shrink()
        : const Text(
            'บันทึกจ่ายเงิน',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
    style: ElevatedButton.styleFrom(
      backgroundColor: AppTheme.tealColor,
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

// ── Shared small widgets ───────────────────────────────────────

class _MethodBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _MethodBadge({required this.label, required this.color});
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
  const _InfoChip({
    required this.icon,
    required this.text,
    required this.isDark,
  });
  @override
  Widget build(BuildContext context) {
    final c = isDark ? const Color(0xFFAAAAAA) : AppTheme.textSub;
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

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;
  const _DetailRow({
    required this.label,
    required this.value,
    required this.isDark,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            '$label:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white60 : AppTheme.textSub,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ),
      ],
    ),
  );
}

class _PayFilterChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _PayFilterChip({
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

class _PayValueStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _PayValueStat({
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

class _PayActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  const _PayActionChip({
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
