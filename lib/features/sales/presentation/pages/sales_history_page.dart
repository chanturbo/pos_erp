// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/sales_provider.dart';
import '../../data/models/sales_order_model.dart';
import 'order_details_page.dart';
import 'sales_history_pdf_report.dart';
import 'package:pos_erp/shared/theme/app_theme.dart';
import 'package:pos_erp/shared/pdf/pdf_report_button.dart';

// ─────────────────────────────────────────────────────────────────
// SalesHistoryPage
// ─────────────────────────────────────────────────────────────────
class SalesHistoryPage extends ConsumerStatefulWidget {
  const SalesHistoryPage({super.key});

  @override
  ConsumerState<SalesHistoryPage> createState() => _SalesHistoryPageState();
}

class _SalesHistoryPageState extends ConsumerState<SalesHistoryPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  // ── Filters ─────────────────────────────────────────────────────
  DateTime? _dateFrom;
  DateTime? _dateTo;
  String _paymentFilter = 'ALL'; // ALL | CASH | CARD | TRANSFER
  String _statusFilter = 'ALL';  // ALL | COMPLETED | PENDING | CANCELLED

  // ── Sort ────────────────────────────────────────────────────────
  String _sortColumn = 'date'; // date | orderNo | customer | amount | status
  bool _sortAsc = false;

  // ── Column widths [วันที่, เลขที่, ลูกค้า, ชำระ, ยอด, สถานะ, จัดการ]
  final List<double> _colWidths = [140, 130, 180, 100, 110, 100, 70];
  static const List<double> _colMinW = [110, 100, 120, 80, 90, 80, 70];
  static const List<double> _colMaxW = [200, 200, 320, 140, 160, 130, 70];
  bool _userResized = false;

  final _hScroll = ScrollController();
  final _fmt = NumberFormat('#,##0.00');
  final _dateFmt = DateFormat('dd/MM/yyyy HH:mm');
  final _shortDateFmt = DateFormat('dd/MM/yy');

  @override
  void dispose() {
    _searchController.dispose();
    _hScroll.dispose();
    super.dispose();
  }

  // ── Filter & Sort ────────────────────────────────────────────────
  List<SalesOrderModel> _applyFilter(List<SalesOrderModel> orders) {
    return orders.where((o) {
      // search
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final match = o.orderNo.toLowerCase().contains(q) ||
            (o.customerName?.toLowerCase().contains(q) ?? false);
        if (!match) return false;
      }
      // date range
      if (_dateFrom != null) {
        if (o.orderDate.isBefore(_dateFrom!)) return false;
      }
      if (_dateTo != null) {
        final endOfDay =
            DateTime(_dateTo!.year, _dateTo!.month, _dateTo!.day, 23, 59, 59);
        if (o.orderDate.isAfter(endOfDay)) return false;
      }
      // payment
      if (_paymentFilter != 'ALL' && o.paymentType != _paymentFilter) {
        return false;
      }
      // status
      if (_statusFilter != 'ALL' && o.status != _statusFilter) {
        return false;
      }
      return true;
    }).toList();
  }

  List<SalesOrderModel> _applySort(List<SalesOrderModel> list) {
    list.sort((a, b) {
      int cmp;
      switch (_sortColumn) {
        case 'date':
          cmp = a.orderDate.compareTo(b.orderDate);
        case 'orderNo':
          cmp = a.orderNo.compareTo(b.orderNo);
        case 'customer':
          cmp = (a.customerName ?? '').compareTo(b.customerName ?? '');
        case 'amount':
          cmp = a.totalAmount.compareTo(b.totalAmount);
        case 'status':
          cmp = a.status.compareTo(b.status);
        default:
          cmp = 0;
      }
      return _sortAsc ? cmp : -cmp;
    });
    return list;
  }

  void _autoFitColWidths(List<SalesOrderModel> orders, double screenW) {
    // ไม่ทำอะไรถ้า user เคย resize แล้ว
  }

  // ── Date picker ──────────────────────────────────────────────────
  Future<void> _pickDate(bool isFrom) async {
    final initial = isFrom
        ? (_dateFrom ?? DateTime.now())
        : (_dateTo ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _dateFrom = picked;
        } else {
          _dateTo = picked;
        }
      });
    }
  }

  bool get _hasFilter =>
      _dateFrom != null ||
      _dateTo != null ||
      _paymentFilter != 'ALL' ||
      _statusFilter != 'ALL';

  void _clearFilters() {
    setState(() {
      _dateFrom = null;
      _dateTo = null;
      _paymentFilter = 'ALL';
      _statusFilter = 'ALL';
    });
  }

  // ── Summary bar ──────────────────────────────────────────────────
  Map<String, dynamic> _calcSummary(List<SalesOrderModel> orders) {
    final completed = orders.where((o) => o.status == 'COMPLETED');
    return {
      'count': orders.length,
      'completedCount': completed.length,
      'total': completed.fold(0.0, (s, o) => s + o.totalAmount),
    };
  }

  @override
  Widget build(BuildContext context) {
    final salesAsync = ref.watch(salesHistoryProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          // ── Top Bar ──────────────────────────────────────────────
          _SalesHistoryTopBar(
            searchController: _searchController,
            searchQuery: _searchQuery,
            hasFilter: _hasFilter,
            onSearchChanged: (v) => setState(() => _searchQuery = v),
            onSearchCleared: () {
              _searchController.clear();
              setState(() => _searchQuery = '');
            },
            onRefresh: () => ref.read(salesHistoryProvider.notifier).refresh(),
            onClearFilter: _hasFilter ? _clearFilters : null,
          ),

          // ── Filter Bar ───────────────────────────────────────────
          _FilterBar(
            dateFrom: _dateFrom,
            dateTo: _dateTo,
            paymentFilter: _paymentFilter,
            statusFilter: _statusFilter,
            onPickFrom: () => _pickDate(true),
            onPickTo: () => _pickDate(false),
            onClearFrom: () => setState(() => _dateFrom = null),
            onClearTo: () => setState(() => _dateTo = null),
            onPaymentChanged: (v) => setState(() => _paymentFilter = v),
            onStatusChanged: (v) => setState(() => _statusFilter = v),
          ),

          // ── Body ─────────────────────────────────────────────────
          Expanded(
            child: salesAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppTheme.primary),
              ),
              error: (e, _) => _buildError(e),
              data: (orders) {
                final filtered = _applySort(_applyFilter(orders));
                final summary = _calcSummary(filtered);

                if (filtered.isEmpty) return _buildEmpty(orders.isEmpty);

                final screenW = MediaQuery.of(context).size.width - 32;
                final totalW = 40.0 +
                    16.0 +
                    _colWidths.fold(0.0, (s, w) => s + w) +
                    28.0 +
                    32.0;
                final tableW = totalW > screenW ? totalW : screenW;

                return Stack(
                  children: [
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),

                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Column(
                        children: [
                          // ── Summary chip row ───────────────────
                          _SummaryBar(summary: summary, fmt: _fmt),

                          const Divider(height: 1, color: AppTheme.border),

                          // ── Table ──────────────────────────────
                          Expanded(
                            child: Scrollbar(
                              controller: _hScroll,
                              thumbVisibility: true,
                              trackVisibility: true,
                              child: SingleChildScrollView(
                                controller: _hScroll,
                                scrollDirection: Axis.horizontal,
                                child: SizedBox(
                                  width: tableW,
                                  child: Column(
                                    children: [
                                      _SalesTableHeader(
                                        colWidths: _colWidths,
                                        colMinW: _colMinW,
                                        colMaxW: _colMaxW,
                                        sortColumn: _sortColumn,
                                        sortAsc: _sortAsc,
                                        onSort: (col) => setState(() {
                                          if (_sortColumn == col) {
                                            _sortAsc = !_sortAsc;
                                          } else {
                                            _sortColumn = col;
                                            _sortAsc = col != 'date';
                                          }
                                        }),
                                        onResize: (i, w) => setState(() {
                                          _colWidths[i] = w;
                                          _userResized = true;
                                        }),
                                        onReset: () => setState(() {
                                          _colWidths.setAll(0, [
                                            140, 130, 180, 100, 110, 100, 70,
                                          ]);
                                          _userResized = false;
                                        }),
                                      ),
                                      const Divider(
                                          height: 1, color: AppTheme.border),
                                      Expanded(
                                        child: ListView.separated(
                                          itemCount: filtered.length,
                                          separatorBuilder: (_, __) =>
                                              const Divider(
                                                  height: 1,
                                                  color: AppTheme.border),
                                          itemBuilder: (context, i) {
                                            return _SalesOrderRow(
                                              order: filtered[i],
                                              colWidths: _colWidths,
                                              dateFmt: _dateFmt,
                                              fmt: _fmt,
                                              onTap: () => Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      OrderDetailsPage(
                                                          orderId: filtered[i]
                                                              .orderId),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // ── Footer ─────────────────────────────
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            decoration: const BoxDecoration(
                              color: AppTheme.headerBg,
                              borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(12),
                                bottomRight: Radius.circular(12),
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  'แสดง ${filtered.length} จาก ${orders.length} รายการ',
                                  style: const TextStyle(
                                      fontSize: 12, color: AppTheme.textSub),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ✅ PDF Button — ลอยมุมขวาล่าง เหมือน CustomerListPage
                    Positioned(
                      bottom: 24,
                      right: 24,
                      child: PdfReportButton(
                        emptyMessage: 'ไม่มีข้อมูลการขาย',
                        title: 'รายงานประวัติการขาย',
                        filename: () =>
                            PdfFilename.generate('sales_history_report'),
                        buildPdf: () => SalesHistoryPdfBuilder.build(
                          filtered,
                          dateFrom: _dateFrom,
                          dateTo: _dateTo,
                          paymentFilter: _paymentFilter,
                          statusFilter: _statusFilter,
                        ),
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
    );
  }

  Widget _buildEmpty(bool noData) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long,
              size: 80, color: Colors.grey.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text(
            noData ? 'ยังไม่มีรายการขาย' : 'ไม่พบรายการที่ตรงกับเงื่อนไข',
            style: const TextStyle(fontSize: 15, color: AppTheme.textSub),
          ),
          if (_hasFilter) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _clearFilters,
              icon: const Icon(Icons.filter_alt_off, size: 16),
              label: const Text('ล้างตัวกรอง'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildError(Object e) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 72, color: Colors.red),
          const SizedBox(height: 16),
          Text('เกิดข้อผิดพลาด: $e'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () =>
                ref.read(salesHistoryProvider.notifier).refresh(),
            child: const Text('ลองใหม่'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Top Bar
// ─────────────────────────────────────────────────────────────────
class _SalesHistoryTopBar extends StatelessWidget {
  final TextEditingController searchController;
  final String searchQuery;
  final bool hasFilter;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchCleared;
  final VoidCallback onRefresh;
  final VoidCallback? onClearFilter;

  const _SalesHistoryTopBar({
    required this.searchController,
    required this.searchQuery,
    required this.hasFilter,
    required this.onSearchChanged,
    required this.onSearchCleared,
    required this.onRefresh,
    this.onClearFilter,
  });

  static const _kBreak = 600.0;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= _kBreak;
    final canPop = Navigator.of(context).canPop();

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: isWide
          ? _buildWide(context, canPop)
          : _buildNarrow(context, canPop),
    );
  }

  Widget _buildWide(BuildContext context, bool canPop) {
    return Row(
      children: [
        if (canPop) ...[
          _BackBtn(onTap: () => Navigator.of(context).pop()),
          const SizedBox(width: 10),
        ],
        _PageIcon(),
        const SizedBox(width: 10),
        const Text(
          'ประวัติการขาย',
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A)),
        ),
        const Spacer(),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 260),
          child: _SearchField(
            controller: searchController,
            query: searchQuery,
            onChanged: onSearchChanged,
            onCleared: onSearchCleared,
          ),
        ),
        const SizedBox(width: 8),
        if (hasFilter)
          _ClearFilterBtn(onTap: onClearFilter!),
        const SizedBox(width: 6),
        _RefreshBtn(onTap: onRefresh),
      ],
    );
  }

  Widget _buildNarrow(BuildContext context, bool canPop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (canPop) ...[
              _BackBtn(onTap: () => Navigator.of(context).pop()),
              const SizedBox(width: 8),
            ],
            _PageIcon(),
            const SizedBox(width: 8),
            const Text(
              'ประวัติการขาย',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A)),
            ),
            const Spacer(),
            if (hasFilter)
              _ClearFilterBtn(onTap: onClearFilter!),
            const SizedBox(width: 6),
            _RefreshBtn(onTap: onRefresh),
          ],
        ),
        const SizedBox(height: 10),
        _SearchField(
          controller: searchController,
          query: searchQuery,
          onChanged: onSearchChanged,
          onCleared: onSearchCleared,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Filter Bar — ช่วงเวลา + ลูกค้า + ประเภทชำระ + สถานะ
// ─────────────────────────────────────────────────────────────────
class _FilterBar extends StatelessWidget {
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String paymentFilter;
  final String statusFilter;
  final VoidCallback onPickFrom;
  final VoidCallback onPickTo;
  final VoidCallback onClearFrom;
  final VoidCallback onClearTo;
  final ValueChanged<String> onPaymentChanged;
  final ValueChanged<String> onStatusChanged;

  const _FilterBar({
    required this.dateFrom,
    required this.dateTo,
    required this.paymentFilter,
    required this.statusFilter,
    required this.onPickFrom,
    required this.onPickTo,
    required this.onClearFrom,
    required this.onClearTo,
    required this.onPaymentChanged,
    required this.onStatusChanged,
  });

  static final _fmt = DateFormat('dd/MM/yy');

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // ── ตั้งแต่วันที่ ─────────────────────────────────────
          _DateChip(
            label: dateFrom != null
                ? 'ตั้งแต่: ${_fmt.format(dateFrom!)}'
                : 'ตั้งแต่วันที่',
            icon: Icons.calendar_today,
            active: dateFrom != null,
            onTap: onPickFrom,
            onClear: dateFrom != null ? onClearFrom : null,
          ),

          // ── ถึงวันที่ ─────────────────────────────────────────
          _DateChip(
            label: dateTo != null
                ? 'ถึง: ${_fmt.format(dateTo!)}'
                : 'ถึงวันที่',
            icon: Icons.calendar_month,
            active: dateTo != null,
            onTap: onPickTo,
            onClear: dateTo != null ? onClearTo : null,
          ),

          // ── ประเภทชำระเงิน ────────────────────────────────────
          _DropdownChip<String>(
            icon: Icons.payment,
            value: paymentFilter,
            items: const [
              ('ALL', 'ทุกประเภทชำระ'),
              ('CASH', '💵 เงินสด'),
              ('CARD', '💳 บัตร'),
              ('TRANSFER', '📲 โอน'),
            ],
            onChanged: onPaymentChanged,
          ),

          // ── สถานะ ─────────────────────────────────────────────
          _DropdownChip<String>(
            icon: Icons.flag_outlined,
            value: statusFilter,
            items: const [
              ('ALL', 'ทุกสถานะ'),
              ('COMPLETED', '✅ สำเร็จ'),
              ('PENDING', '⏳ รอดำเนินการ'),
              ('CANCELLED', '❌ ยกเลิก'),
            ],
            onChanged: onStatusChanged,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Summary Bar
// ─────────────────────────────────────────────────────────────────
class _SummaryBar extends StatelessWidget {
  final Map<String, dynamic> summary;
  final NumberFormat fmt;

  const _SummaryBar({required this.summary, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final count = summary['count'] as int;
    final completedCount = summary['completedCount'] as int;
    final total = summary['total'] as double;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFFFFF8F5),
      child: Row(
        children: [
          _SummaryChip(
            icon: Icons.receipt_long,
            label: '$count รายการ',
            color: AppTheme.info,
          ),
          const SizedBox(width: 12),
          _SummaryChip(
            icon: Icons.check_circle_outline,
            label: '$completedCount สำเร็จ',
            color: AppTheme.success,
          ),
          const SizedBox(width: 12),
          _SummaryChip(
            icon: Icons.attach_money,
            label: '฿${fmt.format(total)}',
            color: AppTheme.primary,
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _SummaryChip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: color),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Table Header (resizable + sortable)
// ─────────────────────────────────────────────────────────────────
class _SalesTableHeader extends StatelessWidget {
  final List<double> colWidths;
  final List<double> colMinW;
  final List<double> colMaxW;
  final String sortColumn;
  final bool sortAsc;
  final void Function(String) onSort;
  final void Function(int, double) onResize;
  final VoidCallback onReset;

  static const _cols = [
    ('วันที่-เวลา', 'date'),
    ('เลขที่ใบขาย', 'orderNo'),
    ('ลูกค้า', 'customer'),
    ('ชำระด้วย', ''),
    ('ยอดรวม', 'amount'),
    ('สถานะ', 'status'),
    ('ดูรายละเอียด', ''),
  ];

  const _SalesTableHeader({
    required this.colWidths,
    required this.colMinW,
    required this.colMaxW,
    required this.sortColumn,
    required this.sortAsc,
    required this.onSort,
    required this.onResize,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.navy,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // ลำดับ fixed
          const SizedBox(
            width: 40,
            height: 40,
            child: Center(
              child: Text('#',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70)),
            ),
          ),
          const SizedBox(width: 16),

          ...List.generate(_cols.length, (i) {
            final (label, sortKey) = _cols[i];
            final isActive = sortKey.isNotEmpty && sortColumn == sortKey;
            return _ResizableHeaderCell(
              label: label,
              sortKey: sortKey,
              width: colWidths[i],
              minWidth: colMinW[i],
              maxWidth: colMaxW[i],
              isActive: isActive,
              sortAsc: sortAsc,
              isLast: i == _cols.length - 1,
              onSort: sortKey.isNotEmpty ? () => onSort(sortKey) : null,
              onResize: (delta) {
                final newW =
                    (colWidths[i] + delta).clamp(colMinW[i], colMaxW[i]);
                onResize(i, newW);
              },
            );
          }),

          // ปุ่ม reset
          Tooltip(
            message: 'รีเซตความกว้างคอลัมน์',
            child: InkWell(
              onTap: onReset,
              borderRadius: BorderRadius.circular(4),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.settings_backup_restore,
                    size: 14, color: Colors.white54),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Resizable Header Cell
// ─────────────────────────────────────────────────────────────────
class _ResizableHeaderCell extends StatefulWidget {
  final String label;
  final String sortKey;
  final double width;
  final double minWidth;
  final double maxWidth;
  final bool isActive;
  final bool sortAsc;
  final bool isLast;
  final VoidCallback? onSort;
  final void Function(double delta) onResize;

  const _ResizableHeaderCell({
    required this.label,
    required this.sortKey,
    required this.width,
    required this.minWidth,
    required this.maxWidth,
    required this.isActive,
    required this.sortAsc,
    required this.isLast,
    required this.onSort,
    required this.onResize,
  });

  @override
  State<_ResizableHeaderCell> createState() => _ResizableHeaderCellState();
}

class _ResizableHeaderCellState extends State<_ResizableHeaderCell> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    const activeColor = Color(0xFFFF9D45);
    const inactiveColor = Colors.white70;
    final labelColor = widget.isActive ? activeColor : inactiveColor;
    final canSort = widget.onSort != null;

    return SizedBox(
      width: widget.width,
      height: 40,
      child: Row(
        children: [
          Expanded(
            child: canSort
                ? InkWell(
                    onTap: widget.onSort,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 4, horizontal: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              widget.label,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: labelColor),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Icon(
                            widget.isActive
                                ? (widget.sortAsc
                                    ? Icons.arrow_upward_rounded
                                    : Icons.arrow_downward_rounded)
                                : Icons.unfold_more_rounded,
                            size: 13,
                            color: widget.isActive
                                ? activeColor
                                : Colors.white38,
                          ),
                        ],
                      ),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Text(
                      widget.label,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: inactiveColor),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
          ),
          if (!widget.isLast)
            MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              onEnter: (_) => setState(() => _hovering = true),
              onExit: (_) => setState(() => _hovering = false),
              child: GestureDetector(
                onHorizontalDragUpdate: (d) => widget.onResize(d.delta.dx),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 4,
                  height: _hovering ? 28 : 20,
                  decoration: BoxDecoration(
                    color:
                        _hovering ? activeColor : Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Sales Order Row
// ─────────────────────────────────────────────────────────────────
class _SalesOrderRow extends StatefulWidget {
  final SalesOrderModel order;
  final List<double> colWidths;
  final DateFormat dateFmt;
  final NumberFormat fmt;
  final VoidCallback onTap;

  const _SalesOrderRow({
    required this.order,
    required this.colWidths,
    required this.dateFmt,
    required this.fmt,
    required this.onTap,
  });

  @override
  State<_SalesOrderRow> createState() => _SalesOrderRowState();
}

class _SalesOrderRowState extends State<_SalesOrderRow> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final w = widget.colWidths;
    final isCompleted = o.status == 'COMPLETED';
    final isCancelled = o.status == 'CANCELLED';

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          color: _hovering
              ? AppTheme.primary.withValues(alpha: 0.05)
              : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              // ── ลำดับ ──────────────────────────────────────────
              SizedBox(
                width: 40,
                child: CircleAvatar(
                  radius: 14,
                  backgroundColor: isCompleted
                      ? AppTheme.successContainer
                      : isCancelled
                          ? AppTheme.errorContainer
                          : const Color(0xFFFFF8E1),
                  child: Icon(
                    isCompleted
                        ? Icons.check
                        : isCancelled
                            ? Icons.close
                            : Icons.hourglass_empty,
                    size: 14,
                    color: isCompleted
                        ? AppTheme.success
                        : isCancelled
                            ? AppTheme.error
                            : AppTheme.warning,
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // ── วันที่-เวลา ────────────────────────────────────
              SizedBox(
                width: w[0],
                child: Text(
                  widget.dateFmt.format(o.orderDate),
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textSub),
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // ── เลขที่ใบขาย ────────────────────────────────────
              SizedBox(
                width: w[1],
                child: Text(
                  o.orderNo,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // ── ลูกค้า ─────────────────────────────────────────
              SizedBox(
                width: w[2],
                child: o.customerName != null
                    ? Row(
                        children: [
                          const Icon(Icons.person_outline,
                              size: 13, color: AppTheme.textSub),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              o.customerName!,
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF1A1A1A)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      )
                    : const Text('Walk-in',
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.textSub)),
              ),

              // ── ประเภทชำระ ─────────────────────────────────────
              SizedBox(
                width: w[3],
                child: _PaymentBadge(type: o.paymentType),
              ),

              // ── ยอดรวม ─────────────────────────────────────────
              SizedBox(
                width: w[4],
                child: Text(
                  '฿${widget.fmt.format(o.totalAmount)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isCancelled
                        ? AppTheme.textSub
                        : AppTheme.info,
                    decoration:
                        isCancelled ? TextDecoration.lineThrough : null,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // ── สถานะ ──────────────────────────────────────────
              SizedBox(
                width: w[5],
                child: _StatusBadge(status: o.status),
              ),

              // ── ดูรายละเอียด ───────────────────────────────────
              SizedBox(
                width: w[6],
                child: Center(
                  child: Tooltip(
                    message: 'ดูรายละเอียด',
                    child: InkWell(
                      onTap: widget.onTap,
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.open_in_new,
                            size: 15, color: AppTheme.primary),
                      ),
                    ),
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

// ─────────────────────────────────────────────────────────────────
// Small Widgets
// ─────────────────────────────────────────────────────────────────

class _PaymentBadge extends StatelessWidget {
  final String type;
  const _PaymentBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final (label, color, bg) = switch (type) {
      'CASH' => ('เงินสด', AppTheme.success, AppTheme.successContainer),
      'CARD' => ('บัตร', AppTheme.info, AppTheme.infoContainer),
      'TRANSFER' => ('โอน', const Color(0xFF6A1B9A), const Color(0xFFF3E5F5)),
      _ => (type, AppTheme.textSub, const Color(0xFFF5F5F5)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color, bg) = switch (status) {
      'COMPLETED' => (
          'สำเร็จ',
          AppTheme.success,
          AppTheme.successContainer
        ),
      'PENDING' => (
          'รอดำเนินการ',
          AppTheme.warning,
          const Color(0xFFFFF8E1)
        ),
      'CANCELLED' => (
          'ยกเลิก',
          AppTheme.error,
          AppTheme.errorContainer
        ),
      _ => (status, AppTheme.textSub, const Color(0xFFF5F5F5)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color)),
        ],
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _DateChip({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: active
              ? AppTheme.primary.withValues(alpha: 0.08)
              : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? AppTheme.primary : AppTheme.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color: active ? AppTheme.primary : AppTheme.textSub),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: active ? AppTheme.primary : AppTheme.textSub,
              ),
            ),
            if (onClear != null) ...[
              const SizedBox(width: 6),
              InkWell(
                onTap: onClear,
                child: Icon(Icons.close,
                    size: 13,
                    color: active ? AppTheme.primary : AppTheme.textSub),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DropdownChip<T> extends StatelessWidget {
  final IconData icon;
  final T value;
  final List<(T, String)> items;
  final ValueChanged<T> onChanged;

  const _DropdownChip({
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = items.first.$1 != value;
    final currentLabel =
        items.firstWhere((e) => e.$1 == value, orElse: () => items.first).$2;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isActive
            ? AppTheme.primary.withValues(alpha: 0.08)
            : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive ? AppTheme.primary : AppTheme.border,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          icon: Icon(Icons.arrow_drop_down,
              size: 16,
              color: isActive ? AppTheme.primary : AppTheme.textSub),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isActive ? AppTheme.primary : AppTheme.textSub,
          ),
          items: items
              .map((e) => DropdownMenuItem<T>(
                    value: e.$1,
                    child: Text(e.$2,
                        style: const TextStyle(fontSize: 12)),
                  ))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onCleared;

  const _SearchField({
    required this.controller,
    required this.query,
    required this.onChanged,
    required this.onCleared,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 38,
        child: TextField(
          controller: controller,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: 'ค้นหาเลขที่ใบขาย, ชื่อลูกค้า...',
            hintStyle:
                const TextStyle(fontSize: 13, color: AppTheme.textSub),
            prefixIcon: const Icon(Icons.search,
                size: 17, color: AppTheme.textSub),
            suffixIcon: query.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 15),
                    onPressed: onCleared,
                  )
                : null,
            contentPadding: EdgeInsets.zero,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppTheme.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppTheme.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  const BorderSide(color: AppTheme.primary, width: 1.5),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          onChanged: onChanged,
        ),
      );
}

class _RefreshBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _RefreshBtn({required this.onTap});

  @override
  Widget build(BuildContext context) => Tooltip(
        message: 'รีเฟรช',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.border),
            ),
            child:
                const Icon(Icons.refresh, size: 17, color: AppTheme.textSub),
          ),
        ),
      );
}

class _ClearFilterBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _ClearFilterBtn({required this.onTap});

  @override
  Widget build(BuildContext context) => Tooltip(
        message: 'ล้างตัวกรองทั้งหมด',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: AppTheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFEF9A9A)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.filter_alt_off,
                    size: 15, color: AppTheme.error),
                const SizedBox(width: 5),
                const Text(
                  'ล้างตัวกรอง',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.error,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      );
}

class _BackBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _BackBtn({required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.border),
          ),
          child: const Icon(Icons.arrow_back,
              size: 17, color: AppTheme.textSub),
        ),
      );
}

class _PageIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.history,
            size: 17, color: AppTheme.primary),
      );
}