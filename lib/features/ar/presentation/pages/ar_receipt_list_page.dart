import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pos_erp/shared/theme/app_theme.dart';
import 'package:pos_erp/shared/utils/responsive_utils.dart';
import 'package:pos_erp/shared/widgets/app_dialogs.dart';
import 'package:pos_erp/shared/widgets/pagination_bar.dart';
import 'package:pos_erp/shared/widgets/escape_pop_scope.dart';
import 'package:pos_erp/shared/pdf/pdf_export_service.dart';
import 'package:pos_erp/shared/pdf/pdf_report_button.dart';
import 'package:pos_erp/shared/widgets/mobile_home_button.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import '../../data/models/ar_receipt_model.dart';
import '../providers/ar_receipt_provider.dart';
import 'ar_receipt_form_page.dart';
import 'ar_receipt_pdf_report.dart';

class ArReceiptListPage extends ConsumerStatefulWidget {
  const ArReceiptListPage({super.key});

  @override
  ConsumerState<ArReceiptListPage> createState() => _ArReceiptListPageState();
}

class _ArReceiptListPageState extends ConsumerState<ArReceiptListPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _methodFilter = 'ALL';
  String? _customerFilter;
  String _dateFilter = 'ALL';
  DateTimeRange? _customDateRange;
  bool _isCardView = false;
  int _currentPage = 1;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ArReceiptModel> _filter(List<ArReceiptModel> src) {
    return src.where((r) {
      final matchSearch =
          r.receiptNo.toLowerCase().contains(_searchQuery) ||
          r.customerName.toLowerCase().contains(_searchQuery);
      final matchMethod =
          _methodFilter == 'ALL' || r.paymentMethod == _methodFilter;
      final matchCustomer =
          _customerFilter == null || r.customerName == _customerFilter;
      final matchDate = _matchesDateFilter(r.receiptDate);
      return matchSearch && matchMethod && matchCustomer && matchDate;
    }).toList()..sort((a, b) => b.receiptDate.compareTo(a.receiptDate));
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

  Future<void> _selectCustomerFilter(List<ArReceiptModel> items) async {
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
                  color: name == _customerFilter ? AppTheme.tealColor : null,
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

  @override
  Widget build(BuildContext context) {
    final receiptsAsync = ref.watch(arReceiptListProvider);
    final pageSize = ref.watch(settingsProvider).listPageSize;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : const Color(0xFFF5F5F5),
      body: EscapePopScope(
        child: Column(
          children: [
            _RecListTopBar(
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
                  ref.read(arReceiptListProvider.notifier).refresh(),
              onAdd: _createNewReceipt,
            ),
            _buildSummaryBar(receiptsAsync),
            Expanded(
              child: receiptsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => _buildError(e),
                data: (receipts) {
                  final filtered = _filter(receipts);
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
                          emptyMessage: 'ไม่มีข้อมูลการรับเงิน',
                          title: 'รายงานการรับเงิน',
                          filename: () =>
                              PdfFilename.generate('ar_receipt_report'),
                          buildPdf: () => ArReceiptPdfBuilder.build(filtered),
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

  Widget _buildSummaryBar(AsyncValue<List<ArReceiptModel>> async) {
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
                  _RecActionChip(
                    label: _customerFilter ?? 'ลูกค้า',
                    icon: Icons.person_outline,
                    active: _customerFilter != null,
                    color: AppTheme.tealColor,
                    onTap: () => _selectCustomerFilter(all),
                  ),
                  _RecActionChip(
                    label: _dateFilterLabel,
                    icon: Icons.calendar_today_outlined,
                    active: _dateFilter != 'ALL',
                    color: AppTheme.info,
                    onTap: _selectDateFilter,
                  ),
                  _RecFilterChip(
                    label: 'ทั้งหมด',
                    count: all.length,
                    color: AppTheme.tealColor,
                    selected: _methodFilter == 'ALL',
                    onTap: () => setState(() {
                      _methodFilter = 'ALL';
                      _currentPage = 1;
                    }),
                  ),
                  _RecFilterChip(
                    label: 'เงินสด',
                    count: countMethod('CASH'),
                    color: AppTheme.success,
                    selected: _methodFilter == 'CASH',
                    onTap: () => setState(() {
                      _methodFilter = 'CASH';
                      _currentPage = 1;
                    }),
                  ),
                  _RecFilterChip(
                    label: 'โอนเงิน',
                    count: countMethod('TRANSFER'),
                    color: AppTheme.info,
                    selected: _methodFilter == 'TRANSFER',
                    onTap: () => setState(() {
                      _methodFilter = 'TRANSFER';
                      _currentPage = 1;
                    }),
                  ),
                  _RecFilterChip(
                    label: 'เช็ค',
                    count: countMethod('CHEQUE'),
                    color: AppTheme.warning,
                    selected: _methodFilter == 'CHEQUE',
                    onTap: () => setState(() {
                      _methodFilter = 'CHEQUE';
                      _currentPage = 1;
                    }),
                  ),
                  _RecFilterChip(
                    label: 'บัตรเครดิต',
                    count: countMethod('CREDIT_CARD'),
                    color: AppTheme.primary,
                    selected: _methodFilter == 'CREDIT_CARD',
                    onTap: () => setState(() {
                      _methodFilter = 'CREDIT_CARD';
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
                  _RecValueStat(
                    label: 'กรองแล้ว',
                    value: '${filtered.length} รายการ',
                    color: AppTheme.tealColor,
                  ),
                  _RecValueStat(
                    label: 'ยอดรับรวม',
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

  Widget _buildCardView(List<ArReceiptModel> items) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) => _RecCard(
        receipt: items[i],
        onTap: () => _viewDetails(items[i]),
        onDelete: () => _deleteReceipt(items[i]),
        onPrintPdf: () => _openReceiptPdf(items[i]),
      ),
    );
  }

  Widget _buildListView(List<ArReceiptModel> items) {
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
                  'เลขที่ / ลูกค้า',
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
                  'วิธีรับ',
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
                  'ยอดรับ',
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
              final r = items[i];
              final isEven = i.isEven;
              final methodColor = _getMethodColor(r.paymentMethod);
              return InkWell(
                onTap: () => _viewDetails(r),
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
                                  r.receiptNo,
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
                                  r.customerName,
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
                              DateFormat('dd/MM/yy').format(r.receiptDate),
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
                              child: _buildMethodBadge(r.paymentMethod, isDark),
                            ),
                          ),
                          SizedBox(
                            width: 90,
                            child: Text(
                              '฿${NumberFormat('#,##0.00', 'th_TH').format(r.totalAmount)}',
                              style: const TextStyle(
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
                              onPressed: () => _openReceiptPdf(r),
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

  Color _getMethodColor(String m) {
    switch (m) {
      case 'CASH':
        return AppTheme.success;
      case 'TRANSFER':
        return AppTheme.info;
      case 'CHEQUE':
        return AppTheme.warning;
      case 'CREDIT_CARD':
        return AppTheme.primary;
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
      case 'CREDIT_CARD':
        label = 'บัตร';
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
                ? 'ยังไม่มีประวัติการรับเงิน'
                : 'ไม่พบรายการ "$_searchQuery"',
            style: TextStyle(
              color: isDark ? const Color(0xFF888888) : Colors.grey[500],
            ),
          ),
          if (_searchQuery.isEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'กดปุ่ม + เพื่อบันทึกรับเงินใหม่',
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
          onPressed: () => ref.read(arReceiptListProvider.notifier).refresh(),
          child: const Text('ลองใหม่'),
        ),
      ],
    ),
  );

  Future<void> _openReceiptPdf(ArReceiptModel receipt) async {
    final full = await ref.read(
      arReceiptDetailProvider(receipt.receiptId).future,
    );
    final pdfReceipt = full ?? receipt;
    if (!mounted) return;
    await PdfExportService.showPreview(
      context,
      title: 'ใบรับเงิน ${pdfReceipt.receiptNo}',
      filename: PdfFilename.generate('ar_receipt_${pdfReceipt.receiptNo}'),
      buildPdf: () => ArReceiptPdfBuilder.build([pdfReceipt]),
    );
  }

  Future<void> _createNewReceipt() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ArReceiptFormPage()),
    );
    ref.read(arReceiptListProvider.notifier).refresh();
  }

  Future<void> _viewDetails(ArReceiptModel receipt) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final receiptDetails = await ref.read(
      arReceiptDetailProvider(receipt.receiptId).future,
    );

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
          title: receipt.receiptNo,
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
                  label: 'วันที่รับ',
                  value: fmtDate.format(receipt.receiptDate),
                  isDark: isDark,
                ),
                if (receipt.bankName != null)
                  _DetailRow(
                    label: 'ธนาคาร',
                    value: receipt.bankName!,
                    isDark: isDark,
                  ),
                if (receipt.transferRef != null)
                  _DetailRow(
                    label: 'เลขที่อ้างอิง',
                    value: receipt.transferRef!,
                    isDark: isDark,
                  ),
                if (receipt.chequeNo != null)
                  _DetailRow(
                    label: 'เลขที่เช็ค',
                    value: receipt.chequeNo!,
                    isDark: isDark,
                  ),
                if (receipt.chequeDate != null)
                  _DetailRow(
                    label: 'วันที่เช็ค',
                    value: fmtDate.format(receipt.chequeDate!),
                    isDark: isDark,
                  ),
                if (receipt.remark != null && receipt.remark!.isNotEmpty)
                  _DetailRow(
                    label: 'หมายเหตุ',
                    value: receipt.remark!,
                    isDark: isDark,
                  ),
                const SizedBox(height: 8),
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
                        'ยอดรับทั้งหมด',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.white70
                              : const Color(0xFF1A1A1A),
                        ),
                      ),
                      Text(
                        '฿${fmt.format(receipt.totalAmount)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.tealColor,
                        ),
                      ),
                    ],
                  ),
                ),
                if (receiptDetails?.allocations != null &&
                    receiptDetails!.allocations!.isNotEmpty) ...[
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
                  ...receiptDetails.allocations!.map(
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
                            alloc.invoiceNo?.isNotEmpty == true
                                ? 'Invoice: ${alloc.invoiceNo}'
                                : 'Invoice: ${alloc.invoiceId}',
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
              await _deleteReceipt(receipt);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _deleteReceipt(ArReceiptModel receipt) async {
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
          'ต้องการลบ ${receipt.receiptNo} ออกจากระบบ?\nยอดในใบแจ้งหนี้จะถูกคืน',
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
        .read(arReceiptListProvider.notifier)
        .deleteReceipt(receipt.receiptId);

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

class _RecCard extends StatelessWidget {
  final ArReceiptModel receipt;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onPrintPdf;

  const _RecCard({
    required this.receipt,
    required this.onTap,
    required this.onDelete,
    required this.onPrintPdf,
  });

  Color get _methodColor {
    switch (receipt.paymentMethod) {
      case 'CASH':
        return AppTheme.success;
      case 'TRANSFER':
        return AppTheme.info;
      case 'CHEQUE':
        return AppTheme.warning;
      case 'CREDIT_CARD':
        return AppTheme.primary;
      default:
        return AppTheme.tealColor;
    }
  }

  String get _methodLabel {
    switch (receipt.paymentMethod) {
      case 'CASH':
        return 'เงินสด';
      case 'TRANSFER':
        return 'โอนเงิน';
      case 'CHEQUE':
        return 'เช็ค';
      case 'CREDIT_CARD':
        return 'บัตรเครดิต';
      default:
        return receipt.paymentMethod;
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
    final name = receipt.customerName;
    final avatarColor = colors[name.codeUnitAt(0) % colors.length];
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'C';

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
                          receipt.receiptNo,
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
                          receipt.customerName,
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
              Row(
                children: [
                  Expanded(
                    child: _InfoChip(
                      icon: Icons.calendar_today_outlined,
                      text: DateFormat(
                        'dd/MM/yyyy',
                      ).format(receipt.receiptDate),
                      isDark: isDark,
                    ),
                  ),
                  Expanded(
                    child: _InfoChip(
                      icon: Icons.access_time_outlined,
                      text: DateFormat('HH:mm').format(receipt.createdAt),
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
              if (receipt.remark != null && receipt.remark!.isNotEmpty) ...[
                const SizedBox(height: 6),
                _InfoChip(
                  icon: Icons.note_outlined,
                  text: receipt.remark!,
                  isDark: isDark,
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ยอดรับ',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark
                                ? const Color(0xFFAAAAAA)
                                : AppTheme.textSub,
                          ),
                        ),
                        Text(
                          '฿${fmt.format(receipt.totalAmount)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.tealColor,
                          ),
                        ),
                      ],
                    ),
                  ),
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

class _RecListTopBar extends StatelessWidget {
  final TextEditingController searchController;
  final String searchQuery;
  final bool isCardView;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchCleared;
  final VoidCallback onToggleView;
  final VoidCallback onRefresh;
  final VoidCallback onAdd;

  const _RecListTopBar({
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
        const _PageIcon(),
        const SizedBox(width: 10),
        Text(
          'ประวัติการรับเงิน',
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
            const _PageIcon(),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'ประวัติการรับเงิน',
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
  const _PageIcon();

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
        hintText: 'ค้นหาเลขที่ใบรับเงิน, ลูกค้า...',
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
            'บันทึกรับเงิน',
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

class _RecFilterChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _RecFilterChip({
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

class _RecValueStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _RecValueStat({
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

class _RecActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  const _RecActionChip({
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
