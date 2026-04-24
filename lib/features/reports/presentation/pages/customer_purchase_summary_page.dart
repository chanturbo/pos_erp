// customer_purchase_summary_page.dart
// รายงานสรุปยอดซื้อลูกค้า — รายบุคคล + รวมทั้งหมด พร้อม date filter และ PDF export

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/client/api_client.dart';
import '../../../../shared/pdf/pdf_report_button.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/escape_pop_scope.dart';
import '../../../../shared/widgets/mobile_home_button.dart';
import '../../../../shared/widgets/pagination_bar.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import 'customer_purchase_summary_pdf.dart';

const _kPageSize = 20;

// ── Data model ────────────────────────────────────────────────────
class CustomerPurchaseSummaryRow {
  final String customerId;
  final String customerName;
  final int orderCount;
  final double totalAmount;
  final double paidAmount;    // ยอดรับชำระแล้วทั้งหมด รวมยอดที่รับจากเครดิต
  final double creditAmount;  // ยอดคงค้างเครดิต (ยังไม่ได้เก็บเงิน)
  final DateTime? lastOrderDate;

  const CustomerPurchaseSummaryRow({
    required this.customerId,
    required this.customerName,
    required this.orderCount,
    required this.totalAmount,
    required this.paidAmount,
    required this.creditAmount,
    this.lastOrderDate,
  });

  factory CustomerPurchaseSummaryRow.fromJson(Map<String, dynamic> j) =>
      CustomerPurchaseSummaryRow(
        customerId: j['customer_id'] as String? ?? '',
        customerName: j['customer_name'] as String? ?? '-',
        orderCount: (j['order_count'] as num?)?.toInt() ?? 0,
        totalAmount: (j['total_amount'] as num?)?.toDouble() ?? 0,
        paidAmount: (j['paid_amount'] as num?)?.toDouble() ?? 0,
        creditAmount: (j['credit_amount'] as num?)?.toDouble() ?? 0,
        lastOrderDate: j['last_order_date'] != null
            ? DateTime.tryParse(j['last_order_date'] as String)
            : null,
      );
}

// ── Provider ─────────────────────────────────────────────────────
final _customerPurchaseProvider = FutureProvider.autoDispose
    .family<List<CustomerPurchaseSummaryRow>, _DateRange>((ref, range) async {
  final api = ref.read(apiClientProvider);
  final params = <String, dynamic>{};
  if (range.start != null) {
    params['start_date'] = DateFormat('yyyy-MM-dd').format(range.start!);
  }
  if (range.end != null) {
    params['end_date'] = DateFormat('yyyy-MM-dd').format(range.end!);
  }
  final res = await api.get(
    '/api/reports/sales-by-customer',
    queryParameters: params.isEmpty ? null : params,
  );
  if (res.statusCode == 200) {
    final list = res.data['data'] as List? ?? [];
    return list
        .map((j) =>
            CustomerPurchaseSummaryRow.fromJson(j as Map<String, dynamic>))
        .toList();
  }
  return [];
});

// ── _DateRange — key สำหรับ provider.family ───────────────────────
// ⚠️ ต้องใช้ date-only (midnight) เท่านั้น
// ถ้าใส่ DateTime.now() (มี time component) key จะเปลี่ยนทุก ms → infinite loop
class _DateRange {
  final DateTime? start;
  final DateTime? end;
  const _DateRange({this.start, this.end});

  @override
  bool operator ==(Object other) =>
      other is _DateRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}

// ── Page ─────────────────────────────────────────────────────────
class CustomerPurchaseSummaryPage extends ConsumerStatefulWidget {
  const CustomerPurchaseSummaryPage({super.key});

  @override
  ConsumerState<CustomerPurchaseSummaryPage> createState() =>
      _CustomerPurchaseSummaryPageState();
}

class _CustomerPurchaseSummaryPageState
    extends ConsumerState<CustomerPurchaseSummaryPage> {
  final _fmt = NumberFormat('#,##0.00', 'th_TH');
  final _fmtInt = NumberFormat('#,##0', 'th_TH');
  final _fmtDate = DateFormat('dd/MM/yyyy', 'th_TH');

  // date filter
  String _preset = 'THIS_MONTH';
  DateTime? _customStart;
  DateTime? _customEnd;

  // search
  String _search = '';
  final _searchCtrl = TextEditingController();

  // sort
  int _sortColumn = 2; // paid_amount
  bool _sortAsc = false;

  // pagination
  int _currentPage = 1;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── computed date range (date-only / midnight) ────────────────────
  _DateRange get _dateRange {
    if (_preset == 'CUSTOM') {
      return _DateRange(start: _customStart, end: _customEnd);
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_preset) {
      case 'TODAY':
        return _DateRange(start: today, end: today);
      case 'THIS_WEEK':
        final monday = today.subtract(Duration(days: today.weekday - 1));
        return _DateRange(start: monday, end: today);
      case 'THIS_MONTH':
        return _DateRange(start: DateTime(now.year, now.month, 1), end: today);
      case 'THIS_YEAR':
        return _DateRange(start: DateTime(now.year, 1, 1), end: today);
      default:
        return const _DateRange();
    }
  }

  String get _presetLabel {
    switch (_preset) {
      case 'TODAY':
        return 'วันนี้';
      case 'THIS_WEEK':
        return 'สัปดาห์นี้';
      case 'THIS_MONTH':
        return 'เดือนนี้';
      case 'THIS_YEAR':
        return 'ปีนี้';
      case 'ALL':
        return 'ทั้งหมด';
      case 'CUSTOM':
        final s = _customStart != null ? _fmtDate.format(_customStart!) : '?';
        final e = _customEnd != null ? _fmtDate.format(_customEnd!) : '?';
        return '$s – $e';
      default:
        return 'ทั้งหมด';
    }
  }

  // ── filter + sort ────────────────────────────────────────────────
  List<CustomerPurchaseSummaryRow> _apply(
      List<CustomerPurchaseSummaryRow> rows) {
    var filtered = rows.where((r) {
      if (_search.isEmpty) return true;
      return r.customerName.toLowerCase().contains(_search.toLowerCase());
    }).toList();

    filtered.sort((a, b) {
      int cmp;
      switch (_sortColumn) {
        case 0:
          cmp = a.customerName.compareTo(b.customerName);
        case 1:
          cmp = a.orderCount.compareTo(b.orderCount);
        case 2:
          cmp = a.paidAmount.compareTo(b.paidAmount);
        case 3:
          cmp = a.creditAmount.compareTo(b.creditAmount);
        default:
          cmp = 0;
      }
      return _sortAsc ? cmp : -cmp;
    });
    return filtered;
  }

  // ── pick custom date range ───────────────────────────────────────
  Future<void> _pickCustomRange() async {
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: (_customStart != null && _customEnd != null)
          ? DateTimeRange(start: _customStart!, end: _customEnd!)
          : null,
      locale: const Locale('th', 'TH'),
    );
    if (result != null) {
      setState(() {
        _preset = 'CUSTOM';
        _customStart =
            DateTime(result.start.year, result.start.month, result.start.day);
        _customEnd =
            DateTime(result.end.year, result.end.month, result.end.day);
        _currentPage = 1;
      });
    }
  }

  void _onSort(int col) {
    setState(() {
      if (_sortColumn == col) {
        _sortAsc = !_sortAsc;
      } else {
        _sortColumn = col;
        _sortAsc = col == 0;
      }
      _currentPage = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = ref.watch(settingsProvider);
    final range = _dateRange;
    final async = ref.watch(_customerPurchaseProvider(range));

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : const Color(0xFFF0F2F5),
      body: EscapePopScope(
        child: Column(
          children: [
            // ── AppBar ──────────────────────────────────────────
            AppBar(
              leading: buildMobileHomeLeading(context),
              title: const Text('สรุปยอดซื้อลูกค้า'),
              backgroundColor:
                  isDark ? AppTheme.darkCard : const Color(0xFF1565C0),
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            // ── Filter bar ──────────────────────────────────────
            _FilterBar(
              preset: _preset,
              label: _presetLabel,
              searchCtrl: _searchCtrl,
              isDark: isDark,
              onPresetChanged: (p) {
                if (p == 'CUSTOM') {
                  _pickCustomRange();
                } else {
                  setState(() {
                    _preset = p;
                    _currentPage = 1;
                  });
                }
              },
              onSearchChanged: (v) => setState(() {
                _search = v;
                _currentPage = 1;
              }),
              onPickCustom: _pickCustomRange,
            ),
            // ── Body ─────────────────────────────────────────────
            Expanded(
              child: async.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Text('เกิดข้อผิดพลาด: $e',
                      style: const TextStyle(color: Colors.red)),
                ),
                data: (rows) {
                  final filtered = _apply(rows);
                  final safePage =
                      _currentPage.clamp(1, filtered.isEmpty ? 1 : (filtered.length / _kPageSize).ceil());
                  final start = (safePage - 1) * _kPageSize;
                  final pageRows = filtered.skip(start).take(_kPageSize).toList();

                  return _buildContent(
                    context,
                    pageRows: pageRows,
                    allFiltered: filtered,
                    allRows: rows,
                    safePage: safePage,
                    isDark: isDark,
                    settings: settings,
                    range: range,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context, {
    required List<CustomerPurchaseSummaryRow> pageRows,
    required List<CustomerPurchaseSummaryRow> allFiltered,
    required List<CustomerPurchaseSummaryRow> allRows,
    required int safePage,
    required bool isDark,
    required dynamic settings,
    required _DateRange range,
  }) {
    final totalPaid =
        allFiltered.fold<double>(0, (s, r) => s + r.paidAmount);
    final totalCredit =
        allFiltered.fold<double>(0, (s, r) => s + r.creditAmount);
    final totalOrders =
        allFiltered.fold<int>(0, (s, r) => s + r.orderCount);

    return Column(
      children: [
        // ── Summary strip ─────────────────────────────────────
        _SummaryStrip(
          customerCount: allFiltered.length,
          totalPaid: totalPaid,
          totalCredit: totalCredit,
          totalOrders: totalOrders,
          fmt: _fmt,
          fmtInt: _fmtInt,
          isDark: isDark,
        ),
        // ── Table ─────────────────────────────────────────────
        Expanded(
          child: allFiltered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.people_outline,
                          size: 56,
                          color: isDark ? Colors.white30 : Colors.grey[400]),
                      const SizedBox(height: 12),
                      Text(
                        _search.isNotEmpty
                            ? 'ไม่พบลูกค้าที่ค้นหา'
                            : 'ไม่มีข้อมูลในช่วงเวลานี้',
                        style: TextStyle(
                            color:
                                isDark ? Colors.white54 : Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  // vertical scroll สำหรับกรณีหน้าจอสูงไม่พอ
                  primary: true,
                  padding: const EdgeInsets.all(16),
                  child: _DataTable(
                    rows: pageRows,
                    startNo: (safePage - 1) * _kPageSize + 1,
                    fmt: _fmt,
                    fmtDate: _fmtDate,
                    isDark: isDark,
                    sortColumn: _sortColumn,
                    sortAsc: _sortAsc,
                    onSort: _onSort,
                  ),
                ),
        ),
        // ── Pagination bar + PDF button (bottom right) ────────
        PaginationBar(
          currentPage: safePage,
          totalItems: allFiltered.length,
          pageSize: _kPageSize,
          onPageChanged: (p) => setState(() => _currentPage = p),
          trailing: PdfReportButton(
            emptyMessage: 'ไม่มีข้อมูลลูกค้า',
            title: 'รายงานสรุปยอดซื้อลูกค้า',
            filename: () =>
                PdfFilename.generate('customer_purchase_summary'),
            buildPdf: () => CustomerPurchaseSummaryPdfBuilder.build(
              rows: allFiltered,
              periodLabel: _presetLabel,
              companyName: settings.companyName,
              dateFrom: range.start,
              dateTo: range.end,
            ),
            hasData: allFiltered.isNotEmpty,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// _FilterBar
// ─────────────────────────────────────────────────────────────────
class _FilterBar extends StatelessWidget {
  final String preset;
  final String label;
  final TextEditingController searchCtrl;
  final bool isDark;
  final ValueChanged<String> onPresetChanged;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onPickCustom;

  const _FilterBar({
    required this.preset,
    required this.label,
    required this.searchCtrl,
    required this.isDark,
    required this.onPresetChanged,
    required this.onSearchChanged,
    required this.onPickCustom,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? AppTheme.darkCard : Colors.white;
    final border = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0);

    return Container(
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final item in [
                  ('TODAY', 'วันนี้'),
                  ('THIS_WEEK', 'สัปดาห์นี้'),
                  ('THIS_MONTH', 'เดือนนี้'),
                  ('THIS_YEAR', 'ปีนี้'),
                  ('ALL', 'ทั้งหมด'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(item.$2,
                          style: const TextStyle(fontSize: 12)),
                      selected: preset == item.$1,
                      onSelected: (_) => onPresetChanged(item.$1),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.date_range, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          preset == 'CUSTOM' ? label : 'กำหนดเอง',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    selected: preset == 'CUSTOM',
                    onSelected: (_) => onPickCustom(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: searchCtrl,
            decoration: InputDecoration(
              hintText: 'ค้นหาชื่อลูกค้า...',
              hintStyle: TextStyle(
                  color: isDark ? Colors.white38 : Colors.grey[400]),
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              filled: true,
              fillColor: isDark
                  ? const Color(0xFF2A2A2A)
                  : const Color(0xFFF5F5F5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: border),
              ),
            ),
            onChanged: onSearchChanged,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// _SummaryStrip — ยอดรวม 4 ช่อง (แยกรับชำระแล้ว vs คงค้างเครดิต)
// ─────────────────────────────────────────────────────────────────
class _SummaryStrip extends StatelessWidget {
  final int customerCount;
  final double totalPaid;
  final double totalCredit;
  final int totalOrders;
  final NumberFormat fmt;
  final NumberFormat fmtInt;
  final bool isDark;

  const _SummaryStrip({
    required this.customerCount,
    required this.totalPaid,
    required this.totalCredit,
    required this.totalOrders,
    required this.fmt,
    required this.fmtInt,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? AppTheme.darkCard : Colors.white;

    final chips = [
      _StatChip(
        label: 'ลูกค้า',
        value: '$customerCount ราย',
        icon: Icons.people_outline,
        iconColor: Colors.purple,
        isDark: isDark,
      ),
      _StatChip(
        label: 'ออเดอร์รวม',
        value: fmtInt.format(totalOrders),
        icon: Icons.receipt_long_outlined,
        iconColor: Colors.blue,
        isDark: isDark,
      ),
      _StatChip(
        label: 'รับชำระแล้ว',
        value: '฿${fmt.format(totalPaid)}',
        icon: Icons.payments_outlined,
        iconColor: Colors.green,
        isDark: isDark,
      ),
      _StatChip(
        label: 'คงค้างเครดิต',
        value: '฿${fmt.format(totalCredit)}',
        icon: Icons.hourglass_top_outlined,
        iconColor: Colors.orange,
        isDark: isDark,
      ),
    ];

    return Container(
      color: bg,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      // LayoutBuilder คำนวณ chip width ตามพื้นที่จริง
      // ≥ 544dp → 4 chips ต่อแถว  |  < 544dp → 2 chips ต่อแถว (2×2)
      child: LayoutBuilder(
        builder: (context, constraints) {
          const gap = 8.0;
          const minChipWidth = 130.0;
          final available = constraints.maxWidth;

          int perRow = 4;
          double chipW = (available - gap * (perRow - 1)) / perRow;
          if (chipW < minChipWidth) {
            perRow = 2;
            chipW = (available - gap * (perRow - 1)) / perRow;
          }

          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: chips
                .map((c) => SizedBox(width: chipW, child: c))
                .toList(),
          );
        },
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final bool isDark;

  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = isDark ? const Color(0xFF1E1E2A) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2A2A3A) : const Color(0xFFE3E8F0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                )
              ],
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: isDark ? 0.18 : 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 17, color: iconColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                    height: 1.1,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// _DataTable — ตารางข้อมูลพร้อม sort, IntrinsicColumnWidth
// คอลัมน์ขนาดอัตโนมัติตามเนื้อหา + ลูกค้าขยายเต็มพื้นที่ที่เหลือ
// ─────────────────────────────────────────────────────────────────
class _DataTable extends StatelessWidget {
  final List<CustomerPurchaseSummaryRow> rows;
  final int startNo;
  final NumberFormat fmt;
  final DateFormat fmtDate;
  final bool isDark;
  final int sortColumn;
  final bool sortAsc;
  final ValueChanged<int> onSort;

  const _DataTable({
    required this.rows,
    required this.startNo,
    required this.fmt,
    required this.fmtDate,
    required this.isDark,
    required this.sortColumn,
    required this.sortAsc,
    required this.onSort,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? AppTheme.darkCard : Colors.white;
    final hdrBg =
        isDark ? const Color(0xFF1A2A3A) : const Color(0xFF1565C0);
    final altBg =
        isDark ? const Color(0xFF1A1A2A) : const Color(0xFFF8F9FF);
    final borderColor =
        isDark ? const Color(0xFF2A2A3A) : const Color(0xFFE3E8F0);

    // ── สร้าง rows ก่อน (ไม่ขึ้นกับ constraints) ────────────────
    final headerRow = TableRow(
      decoration: BoxDecoration(color: hdrBg),
      children: [
        _hdrCell('#',             -1, sortColumn, sortAsc, onSort),
        _hdrCell('ลูกค้า',        0,  sortColumn, sortAsc, onSort),
        _hdrCell('ออเดอร์',       1,  sortColumn, sortAsc, onSort),
        _hdrCell('รับชำระแล้ว',   2,  sortColumn, sortAsc, onSort),
        _hdrCell('คงค้างเครดิต', 3,  sortColumn, sortAsc, onSort),
        _hdrCell('ซื้อล่าสุด',   -1, sortColumn, sortAsc, onSort),
      ],
    );

    final dataRows = rows.asMap().entries.map((entry) {
      final i = entry.key;
      final r = entry.value;
      final rowBg = i.isOdd ? altBg : bg;

      return TableRow(
        decoration: BoxDecoration(
          color: rowBg,
          border: Border(
              bottom: BorderSide(color: borderColor, width: 0.5)),
        ),
        children: [
          _cell('${startNo + i}',
              align: TextAlign.center,
              color: isDark ? Colors.white38 : Colors.grey[500]),
          _cell(r.customerName,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF1A237E)),
          _cell('${r.orderCount}',
              align: TextAlign.center,
              color: isDark ? Colors.white70 : Colors.blueGrey[700]),
          _cell('฿${fmt.format(r.paidAmount)}',
              align: TextAlign.right,
              fontWeight: FontWeight.bold,
              color: isDark
                  ? const Color(0xFF81C784)
                  : const Color(0xFF2E7D32)),
          _cell(
            r.creditAmount > 0
                ? '฿${fmt.format(r.creditAmount)}'
                : '-',
            align: TextAlign.right,
            fontWeight:
                r.creditAmount > 0 ? FontWeight.bold : FontWeight.normal,
            color: r.creditAmount > 0
                ? (isDark
                    ? const Color(0xFFFFB74D)
                    : const Color(0xFFE65100))
                : (isDark ? Colors.white38 : Colors.grey[400]),
          ),
          _cell(
            r.lastOrderDate != null
                ? fmtDate.format(r.lastOrderDate!)
                : '-',
            align: TextAlign.center,
            color: isDark ? Colors.white54 : Colors.grey[600],
          ),
        ],
      );
    }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        // minWidth = พื้นที่จริงที่มีอยู่ เพื่อให้ตารางขยายเต็มหน้าจอ
        final minWidth =
            constraints.hasBoundedWidth ? constraints.maxWidth : 0.0;

        return Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2))
                  ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              // primary: false เพื่อไม่แย่งกับ vertical scroll ด้านนอก
              primary: false,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: minWidth),
                child: Table(
                  // defaultColumnWidth: ขนาดตามเนื้อหาจริง (header + data)
                  // column 1 (ลูกค้า): flex: 1.0 → ขยายรับพื้นที่ที่เหลือ
                  defaultColumnWidth: const IntrinsicColumnWidth(),
                  columnWidths: const {
                    1: IntrinsicColumnWidth(flex: 1.0),
                  },
                  children: [headerRow, ...dataRows],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static Widget _hdrCell(String label, int colIdx, int sortCol, bool sortAsc,
      ValueChanged<int> onSort) {
    final canSort = colIdx >= 0;
    return InkWell(
      onTap: canSort ? () => onSort(colIdx) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
            if (canSort && sortCol == colIdx) ...[
              const SizedBox(width: 4),
              Icon(
                sortAsc ? Icons.arrow_upward : Icons.arrow_downward,
                size: 12,
                color: Colors.white70,
              ),
            ],
          ],
        ),
      ),
    );
  }

  static Widget _cell(
    String text, {
    TextAlign align = TextAlign.left,
    FontWeight fontWeight = FontWeight.normal,
    Color? color,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Text(
          text,
          textAlign: align,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: fontWeight,
            color: color,
          ),
        ),
      );
}
