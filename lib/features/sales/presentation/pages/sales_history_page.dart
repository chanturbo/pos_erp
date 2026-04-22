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
import 'package:pos_erp/shared/utils/responsive_utils.dart';
import 'package:pos_erp/shared/widgets/pagination_bar.dart';
import 'package:pos_erp/shared/widgets/mobile_home_button.dart';
import 'package:pos_erp/features/settings/presentation/pages/settings_page.dart';

// ─────────────────────────────────────────────────────────────────
// SalesHistoryPage
// ─────────────────────────────────────────────────────────────────
class SalesHistoryPage extends ConsumerStatefulWidget {
  final DateTime? initialDateFrom;
  final DateTime? initialDateTo;

  const SalesHistoryPage({super.key, this.initialDateFrom, this.initialDateTo});

  @override
  ConsumerState<SalesHistoryPage> createState() => _SalesHistoryPageState();
}

class _SalesHistoryPageState extends ConsumerState<SalesHistoryPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  // ── Filters ─────────────────────────────────────────────────────
  late DateTime? _dateFrom = widget.initialDateFrom;
  late DateTime? _dateTo = widget.initialDateTo;
  String _paymentFilter = 'ALL'; // ALL | CASH | CARD | TRANSFER
  String _statusFilter = 'ALL'; // ALL | COMPLETED | PENDING | CANCELLED
  String _orderTypeFilter = 'ALL'; // ALL | RETAIL | RESTAURANT

  // ── Sort ────────────────────────────────────────────────────────
  String _sortColumn = 'date'; // date | orderNo | customer | amount | status
  bool _sortAsc = false;

  // ── Pagination ──────────────────────────────────────────────────
  int _currentPage = 1;

  // ── Column widths [วันที่, เลขที่, ลูกค้า, ชำระ, ยอด, สถานะ, จัดการ]
  final List<double> _colWidths = [140, 130, 180, 100, 118, 96, 70];
  static const List<double> _colMinW = [110, 100, 120, 80, 100, 88, 70];
  static const List<double> _colMaxW = [200, 200, 320, 140, 170, 120, 70];
  final _hScroll = ScrollController();
  final _fmt = NumberFormat('#,##0.00');
  final _dateFmt = DateFormat('dd/MM/yyyy HH:mm');

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
        final match =
            o.orderNo.toLowerCase().contains(q) ||
            (o.customerName?.toLowerCase().contains(q) ?? false);
        if (!match) return false;
      }
      // date range
      if (_dateFrom != null) {
        if (o.orderDate.isBefore(_dateFrom!)) return false;
      }
      if (_dateTo != null) {
        final endOfDay = DateTime(
          _dateTo!.year,
          _dateTo!.month,
          _dateTo!.day,
          23,
          59,
          59,
        );
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
      // order type
      if (_orderTypeFilter == 'RETAIL' && o.tableId != null) return false;
      if (_orderTypeFilter == 'RESTAURANT' && o.tableId == null) return false;
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
      _statusFilter != 'ALL' ||
      _orderTypeFilter != 'ALL';

  void _clearFilters() {
    setState(() {
      _dateFrom = null;
      _dateTo = null;
      _paymentFilter = 'ALL';
      _statusFilter = 'ALL';
      _orderTypeFilter = 'ALL';
      _currentPage = 1;
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
    final pageSize = ref.watch(settingsProvider).listPageSize;
    final colors = _SalesHistoryColors.of(context);
    final isDesktop = MediaQuery.of(context).size.width >= 600;
    final filterFmt = DateFormat('dd/MM/yy');

    // Filter chips widget สำหรับใส่ inline บน Desktop / Tablet
    // ใช้ Row เพื่อให้ chips ไม่แตกบรรทัด
    final inlineFilters = isDesktop
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DateChip(
                label: _dateFrom != null
                    ? 'ตั้งแต่: ${filterFmt.format(_dateFrom!)}'
                    : 'ตั้งแต่วันที่',
                icon: Icons.calendar_today,
                active: _dateFrom != null,
                onTap: () => _pickDate(true),
                onClear: _dateFrom != null
                    ? () => setState(() {
                        _dateFrom = null;
                        _currentPage = 1;
                      })
                    : null,
              ),
              const SizedBox(width: 8),
              _DateChip(
                label: _dateTo != null
                    ? 'ถึง: ${filterFmt.format(_dateTo!)}'
                    : 'ถึงวันที่',
                icon: Icons.calendar_month,
                active: _dateTo != null,
                onTap: () => _pickDate(false),
                onClear: _dateTo != null
                    ? () => setState(() {
                        _dateTo = null;
                        _currentPage = 1;
                      })
                    : null,
              ),
              const SizedBox(width: 8),
              _DropdownChip<String>(
                icon: Icons.payment,
                value: _paymentFilter,
                items: const [
                  ('ALL', 'ทุกประเภทชำระ'),
                  ('CASH', '💵 เงินสด'),
                  ('CARD', '💳 บัตร'),
                  ('TRANSFER', '📲 โอน'),
                ],
                onChanged: (v) => setState(() {
                  _paymentFilter = v;
                  _currentPage = 1;
                }),
              ),
              const SizedBox(width: 8),
              _DropdownChip<String>(
                icon: Icons.flag_outlined,
                value: _statusFilter,
                items: const [
                  ('ALL', 'ทุกสถานะ'),
                  ('COMPLETED', '✅ สำเร็จ'),
                  ('PENDING', '⏳ รอดำเนินการ'),
                  ('CANCELLED', '❌ ยกเลิก'),
                ],
                onChanged: (v) => setState(() {
                  _statusFilter = v;
                  _currentPage = 1;
                }),
              ),
              const SizedBox(width: 8),
              _DropdownChip<String>(
                icon: Icons.storefront_outlined,
                value: _orderTypeFilter,
                items: const [
                  ('ALL', 'ทุกประเภทร้าน'),
                  ('RETAIL', '🛒 ค้าปลีก'),
                  ('RESTAURANT', '🍽️ ร้านอาหาร'),
                ],
                onChanged: (v) => setState(() {
                  _orderTypeFilter = v;
                  _currentPage = 1;
                }),
              ),
            ],
          )
        : null;

    return Scaffold(
      backgroundColor: colors.scaffoldBg,
      body: Column(
        children: [
          // ── Top Bar ──────────────────────────────────────────────
          _SalesHistoryTopBar(
            searchController: _searchController,
            searchQuery: _searchQuery,
            hasFilter: _hasFilter,
            onSearchChanged: (v) => setState(() {
              _searchQuery = v;
              _currentPage = 1;
            }),
            onSearchCleared: () {
              _searchController.clear();
              setState(() {
                _searchQuery = '';
                _currentPage = 1;
              });
            },
            onRefresh: () => ref.read(salesHistoryProvider.notifier).refresh(),
            onClearFilter: _hasFilter ? _clearFilters : null,
          ),

          // ── Filter Bar (แสดงเฉพาะ mobile / tablet แคบ) ──────────
          if (!isDesktop)
            _FilterBar(
              dateFrom: _dateFrom,
              dateTo: _dateTo,
              paymentFilter: _paymentFilter,
              statusFilter: _statusFilter,
              orderTypeFilter: _orderTypeFilter,
              onPickFrom: () => _pickDate(true),
              onPickTo: () => _pickDate(false),
              onClearFrom: () => setState(() {
                _dateFrom = null;
                _currentPage = 1;
              }),
              onClearTo: () => setState(() {
                _dateTo = null;
                _currentPage = 1;
              }),
              onPaymentChanged: (v) => setState(() {
                _paymentFilter = v;
                _currentPage = 1;
              }),
              onStatusChanged: (v) => setState(() {
                _statusFilter = v;
                _currentPage = 1;
              }),
              onOrderTypeChanged: (v) => setState(() {
                _orderTypeFilter = v;
                _currentPage = 1;
              }),
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

                // Pagination slice
                final totalPages = (filtered.length / pageSize).ceil();
                final safePage = _currentPage.clamp(1, totalPages);
                final pageStart = (safePage - 1) * pageSize;
                final pageEnd = (pageStart + pageSize).clamp(
                  0,
                  filtered.length,
                );
                final pageItems = filtered.sublist(pageStart, pageEnd);

                final screenW = MediaQuery.of(context).size.width - 32;
                final totalW =
                    40.0 +
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
                        color: colors.cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colors.border),
                        boxShadow: [
                          if (!colors.isDark)
                            BoxShadow(
                              color: AppTheme.navy.withValues(alpha: 0.04),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // ── Summary chip row ───────────────────
                          _SummaryBar(
                            summary: summary,
                            fmt: _fmt,
                            inlineFilters: inlineFilters,
                          ),

                          Divider(height: 1, color: colors.border),

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
                                          _currentPage = 1;
                                        }),
                                        onResize: (i, w) => setState(() {
                                          _colWidths[i] = w;
                                        }),
                                        onReset: () => setState(() {
                                          _colWidths.setAll(0, [
                                            140,
                                            130,
                                            180,
                                            100,
                                            110,
                                            100,
                                            70,
                                          ]);
                                        }),
                                      ),
                                      Divider(height: 1, color: colors.border),
                                      Expanded(
                                        child: ListView.separated(
                                          itemCount: pageItems.length,
                                          separatorBuilder: (_, _) => Divider(
                                            height: 1,
                                            color: colors.border,
                                          ),
                                          itemBuilder: (context, i) {
                                            return _SalesOrderRow(
                                              order: pageItems[i],
                                              colWidths: _colWidths,
                                              dateFmt: _dateFmt,
                                              fmt: _fmt,
                                              onTap: () => Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      OrderDetailsPage(
                                                        orderId: pageItems[i]
                                                            .orderId,
                                                      ),
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

                          // ── Footer / Pagination ────────────────
                          PaginationBar(
                            currentPage: safePage,
                            totalItems: filtered.length,
                            pageSize: pageSize,
                            onPageChanged: (p) =>
                                setState(() => _currentPage = p),
                            trailing: PdfReportButton(
                              emptyMessage: 'ไม่มีข้อมูลการขาย',
                              title: 'รายงานประวัติการขาย',
                              filename: () =>
                                  PdfFilename.generate('sales_history_report'),
                              // ✅ ใช้ filtered ที่แสดงบนหน้าจออยู่แล้ว
                              // ไม่ใช้ ref.read() เพราะตอน provider reload
                              // asData จะเป็น null แม้หน้าจอยังแสดงข้อมูลเดิม
                              buildPdf: () => SalesHistoryPdfBuilder.build(
                                List<SalesOrderModel>.from(filtered),
                                dateFrom: _dateFrom,
                                dateTo: _dateTo,
                                paymentFilter: _paymentFilter,
                                statusFilter: _statusFilter,
                              ),
                              hasData: filtered.isNotEmpty,
                            ),
                          ),
                        ],
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
    final colors = _SalesHistoryColors.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: colors.emptyIconBg,
              shape: BoxShape.circle,
              border: Border.all(color: colors.border),
            ),
            child: Icon(
              Icons.inventory_2_outlined,
              size: 38,
              color: colors.emptyIcon,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            noData ? 'ยังไม่มีรายการขาย' : 'ไม่พบรายการที่ตรงกับเงื่อนไข',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: colors.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            noData
                ? 'เมื่อมีการขาย รายการจะปรากฏที่หน้านี้'
                : 'ลองปรับคำค้นหา หรือรีเซตตัวกรองเพื่อดูข้อมูลเพิ่ม',
            style: TextStyle(fontSize: 13, color: colors.subtext),
          ),
          if (_hasFilter) ...[
            const SizedBox(height: 12),
            ElevatedButton.icon(
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
    final colors = _SalesHistoryColors.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: AppTheme.error),
          const SizedBox(height: 16),
          Text(
            'เกิดข้อผิดพลาด: $e',
            style: TextStyle(color: colors.text),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => ref.read(salesHistoryProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh),
            label: const Text('ลองใหม่'),
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
    final colors = _SalesHistoryColors.of(context);

    return Container(
      decoration: BoxDecoration(color: colors.topBarBg),
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
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
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
        if (hasFilter) _ClearFilterBtn(onTap: onClearFilter!),
        const SizedBox(width: 6),
        _RefreshBtn(onTap: onRefresh),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.5)),
          ),
          child: const Text(
            'Sales History',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryLight,
            ),
          ),
        ),
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
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const Spacer(),
            if (hasFilter) _ClearFilterBtn(onTap: onClearFilter!),
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
  final String orderTypeFilter;
  final VoidCallback onPickFrom;
  final VoidCallback onPickTo;
  final VoidCallback onClearFrom;
  final VoidCallback onClearTo;
  final ValueChanged<String> onPaymentChanged;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onOrderTypeChanged;

  const _FilterBar({
    required this.dateFrom,
    required this.dateTo,
    required this.paymentFilter,
    required this.statusFilter,
    required this.orderTypeFilter,
    required this.onPickFrom,
    required this.onPickTo,
    required this.onClearFrom,
    required this.onClearTo,
    required this.onPaymentChanged,
    required this.onStatusChanged,
    required this.onOrderTypeChanged,
  });

  static final _fmt = DateFormat('dd/MM/yy');

  @override
  Widget build(BuildContext context) {
    final colors = _SalesHistoryColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.searchBarBg,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
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

          // ── ประเภทร้าน ────────────────────────────────────────
          _DropdownChip<String>(
            icon: Icons.storefront_outlined,
            value: orderTypeFilter,
            items: const [
              ('ALL', 'ทุกประเภทร้าน'),
              ('RETAIL', '🛒 ค้าปลีก'),
              ('RESTAURANT', '🍽️ ร้านอาหาร'),
            ],
            onChanged: onOrderTypeChanged,
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
  final Widget? inlineFilters;

  const _SummaryBar({
    required this.summary,
    required this.fmt,
    this.inlineFilters,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _SalesHistoryColors.of(context);
    final count = summary['count'] as int;
    final completedCount = summary['completedCount'] as int;
    final total = summary['total'] as double;

    final chips = [
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
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(color: colors.summaryBg),
      child: inlineFilters != null
          ? LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(mainAxisSize: MainAxisSize.min, children: chips),
                      const SizedBox(width: 16),
                      inlineFilters!,
                    ],
                  ),
                ),
              ),
            )
          : Wrap(spacing: 12, runSpacing: 8, children: chips),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _SummaryChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _SalesHistoryColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.summaryChipBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
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
    final colors = _SalesHistoryColors.of(context);
    return Container(
      decoration: BoxDecoration(color: colors.tableHeaderBg),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // ลำดับ fixed
          const SizedBox(
            width: 40,
            height: 40,
            child: Center(
              child: Text(
                '#',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
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
                final newW = (colWidths[i] + delta).clamp(
                  colMinW[i],
                  colMaxW[i],
                );
                onResize(i, newW);
              },
            );
          }),

          // ปุ่ม reset
          Tooltip(
            message: 'รีเซตความกว้างคอลัมน์',
            waitDuration: const Duration(milliseconds: 600),
            child: InkWell(
              onTap: onReset,
              borderRadius: BorderRadius.circular(4),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(
                  Icons.settings_backup_restore,
                  size: 14,
                  color: Colors.white54,
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
    final inactiveColor = _SalesHistoryColors.of(context).headerText;
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
                        vertical: 4,
                        horizontal: 2,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              widget.label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: labelColor,
                              ),
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
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: inactiveColor,
                      ),
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
                    color: _hovering ? activeColor : Colors.white24,
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
    final colors = _SalesHistoryColors.of(context);
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
          color: _hovering ? colors.rowHoverBg : colors.cardBg,
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
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSub),
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // ── เลขที่ใบขาย ────────────────────────────────────
              SizedBox(
                width: w[1],
                child: Text(
                  o.orderNo,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.text,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // ── ลูกค้า ─────────────────────────────────────────
              SizedBox(
                width: w[2],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    o.customerName != null
                        ? Row(
                            children: [
                              const Icon(
                                Icons.person_outline,
                                size: 13,
                                color: AppTheme.textSub,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  o.customerName!,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: colors.text,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          )
                        : Text(
                            o.tableId != null ? 'Walk-in (โต๊ะ)' : 'Walk-in',
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.textSub),
                          ),
                    if (o.serviceType != null) ...[
                      const SizedBox(height: 3),
                      _ServiceTypeBadge(serviceType: o.serviceType!),
                    ],
                  ],
                ),
              ),

              // ── ประเภทชำระ ─────────────────────────────────────
              SizedBox(
                width: w[3],
                child: _PaymentBadge(type: o.paymentType),
              ),

              // ── ยอดรวม ─────────────────────────────────────────
              SizedBox(
                width: w[4],
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '฿${widget.fmt.format(o.totalAmount)}',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isCancelled
                            ? colors.amountCancelledText
                            : colors.amountText,
                        decoration: isCancelled
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),

              // ── สถานะ ──────────────────────────────────────────
              SizedBox(
                width: w[5],
                child: Center(child: _StatusBadge(status: o.status)),
              ),

              // ── ดูรายละเอียด ───────────────────────────────────
              SizedBox(
                width: w[6],
                child: Center(
                  child: Tooltip(
                    message: 'ดูรายละเอียด',
                    waitDuration: const Duration(milliseconds: 600),
                    child: InkWell(
                      onTap: widget.onTap,
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.08),
                          border: Border.all(
                            color: AppTheme.primary.withValues(alpha: 0.18),
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.open_in_new,
                          size: 15,
                          color: AppTheme.primary,
                        ),
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
    final colors = _SalesHistoryColors.of(context);
    final (label, color, bg) = switch (type) {
      'CASH' => ('เงินสด', AppTheme.success, AppTheme.successContainer),
      'CARD' => ('บัตร', AppTheme.info, AppTheme.infoContainer),
      'TRANSFER' => ('โอน', const Color(0xFF6A1B9A), const Color(0xFFF3E5F5)),
      _ => (type, AppTheme.textSub, colors.neutralChipBg),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final colors = _SalesHistoryColors.of(context);
    final (label, color, bg) = switch (status) {
      'COMPLETED' => ('สำเร็จ', AppTheme.success, AppTheme.successContainer),
      'PENDING' => ('รอดำเนินการ', AppTheme.warning, const Color(0xFFFFF8E1)),
      'CANCELLED' => ('ยกเลิก', AppTheme.error, AppTheme.errorContainer),
      _ => (status, AppTheme.textSub, colors.neutralChipBg),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.16)),
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
}

class _ServiceTypeBadge extends StatelessWidget {
  final String serviceType;
  const _ServiceTypeBadge({required this.serviceType});

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (serviceType.toUpperCase()) {
      'DINE_IN' => ('ทานที่ร้าน', const Color(0xFF6A1B9A), Icons.table_restaurant),
      'TAKEAWAY' => ('ซื้อกลับ', AppTheme.warning, Icons.takeout_dining),
      'DELIVERY' => ('ส่งถึงบ้าน', AppTheme.info, Icons.delivery_dining),
      _ => (serviceType, AppTheme.textSub, Icons.storefront_outlined),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
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
    final colors = _SalesHistoryColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: active
              ? AppTheme.primary.withValues(alpha: 0.08)
              : colors.neutralChipBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? AppTheme.primary : colors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: active ? AppTheme.primary : colors.subtext,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: active ? AppTheme.primary : colors.subtext,
              ),
            ),
            if (onClear != null) ...[
              const SizedBox(width: 6),
              InkWell(
                onTap: onClear,
                child: Icon(
                  Icons.close,
                  size: 13,
                  color: active ? AppTheme.primary : colors.subtext,
                ),
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
    final colors = _SalesHistoryColors.of(context);
    final isActive = items.first.$1 != value;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isActive
            ? AppTheme.primary.withValues(alpha: 0.08)
            : colors.neutralChipBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isActive ? AppTheme.primary : colors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          dropdownColor: colors.cardBg,
          icon: Icon(
            Icons.arrow_drop_down,
            size: 16,
            color: isActive ? AppTheme.primary : colors.subtext,
          ),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isActive ? AppTheme.primary : colors.subtext,
          ),
          items: items
              .map(
                (e) => DropdownMenuItem<T>(
                  value: e.$1,
                  child: Text(e.$2, style: const TextStyle(fontSize: 12)),
                ),
              )
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
    height: 40,
    child: TextField(
      controller: controller,
      style: TextStyle(
        fontSize: 13,
        color: _SalesHistoryColors.of(context).text,
      ),
      decoration: InputDecoration(
        hintText: 'ค้นหาเลขที่ใบขาย, ชื่อลูกค้า...',
        hintStyle: TextStyle(
          fontSize: 13,
          color: _SalesHistoryColors.of(context).subtext,
        ),
        prefixIcon: Icon(
          Icons.search,
          size: 17,
          color: _SalesHistoryColors.of(context).subtext,
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
          borderSide: const BorderSide(color: AppTheme.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppTheme.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
        ),
        filled: true,
        fillColor: _SalesHistoryColors.of(context).inputFill,
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
    waitDuration: const Duration(milliseconds: 600),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: _SalesHistoryColors.of(context).navButtonBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _SalesHistoryColors.of(context).navButtonBorder,
          ),
        ),
        child: const Icon(Icons.refresh, size: 17, color: Colors.white70),
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
    waitDuration: const Duration(milliseconds: 600),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.filter_alt_off, size: 15, color: Colors.white),
            const SizedBox(width: 5),
            const Text(
              'ล้างตัวกรอง',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
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
  Widget build(BuildContext context) => context.isMobile
      ? buildMobileHomeCompactButton(context)
      : InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: _SalesHistoryColors.of(context).navButtonBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _SalesHistoryColors.of(context).navButtonBorder,
              ),
            ),
            child: const Icon(
              Icons.arrow_back,
              size: 17,
              color: Colors.white70,
            ),
          ),
        );
}

class _PageIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 30,
    height: 30,
    decoration: BoxDecoration(
      color: AppTheme.primary.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppTheme.primary.withValues(alpha: 0.28)),
    ),
    child: const Icon(Icons.history, size: 17, color: AppTheme.primaryLight),
  );
}

class _SalesHistoryColors {
  final bool isDark;
  final Color scaffoldBg;
  final Color cardBg;
  final Color border;
  final Color text;
  final Color subtext;
  final Color topBarBg;
  final Color searchBarBg;
  final Color tableHeaderBg;
  final Color headerText;
  final Color summaryBg;
  final Color summaryChipBg;
  final Color inputFill;
  final Color rowHoverBg;
  final Color emptyIconBg;
  final Color emptyIcon;
  final Color neutralChipBg;
  final Color navButtonBg;
  final Color navButtonBorder;
  final Color amountText;
  final Color amountCancelledText;

  const _SalesHistoryColors({
    required this.isDark,
    required this.scaffoldBg,
    required this.cardBg,
    required this.border,
    required this.text,
    required this.subtext,
    required this.topBarBg,
    required this.searchBarBg,
    required this.tableHeaderBg,
    required this.headerText,
    required this.summaryBg,
    required this.summaryChipBg,
    required this.inputFill,
    required this.rowHoverBg,
    required this.emptyIconBg,
    required this.emptyIcon,
    required this.neutralChipBg,
    required this.navButtonBg,
    required this.navButtonBorder,
    required this.amountText,
    required this.amountCancelledText,
  });

  factory _SalesHistoryColors.of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _SalesHistoryColors(
      isDark: isDark,
      scaffoldBg: isDark ? AppTheme.darkBg : AppTheme.surface,
      cardBg: isDark ? const Color(0xFF2C2C2C) : Colors.white,
      border: isDark ? const Color(0xFF333333) : AppTheme.border,
      text: isDark ? const Color(0xFFE0E0E0) : const Color(0xFF1A1A1A),
      subtext: isDark ? const Color(0xFF9E9E9E) : AppTheme.textSub,
      topBarBg: isDark ? AppTheme.navyDark : AppTheme.navy,
      searchBarBg: isDark ? AppTheme.darkTopBar : Colors.white,
      tableHeaderBg: isDark ? AppTheme.navyDark : AppTheme.navy,
      headerText: isDark ? const Color(0xFFE0E0E0) : Colors.white70,
      summaryBg: isDark ? const Color(0xFF181818) : const Color(0xFFFFF8F5),
      summaryChipBg: isDark ? const Color(0xFF2C2C2C) : Colors.white,
      inputFill: isDark ? AppTheme.darkElement : Colors.white,
      rowHoverBg: isDark
          ? AppTheme.primaryLight.withValues(alpha: 0.15)
          : AppTheme.primaryLight,
      emptyIconBg: isDark ? AppTheme.darkCard : AppTheme.surface,
      emptyIcon: isDark ? const Color(0xFF9E9E9E) : Colors.grey,
      neutralChipBg: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F0F0),
      navButtonBg: isDark
          ? Colors.white.withValues(alpha: 0.08)
          : AppTheme.navyLight,
      navButtonBorder: isDark ? Colors.white24 : AppTheme.navy,
      amountText: isDark ? AppTheme.primaryLight : AppTheme.info,
      amountCancelledText: isDark ? const Color(0xFFB0B0B0) : AppTheme.textSub,
    );
  }
}
