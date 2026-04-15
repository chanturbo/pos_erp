import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pos_erp/features/settings/presentation/pages/settings_page.dart';
import 'package:pos_erp/shared/pdf/pdf_report_button.dart';
import 'package:pos_erp/shared/theme/app_theme.dart';
import 'package:pos_erp/shared/utils/responsive_utils.dart';
import 'package:pos_erp/shared/widgets/escape_pop_scope.dart';
import 'package:pos_erp/shared/widgets/mobile_home_button.dart';
import 'package:pos_erp/shared/widgets/pagination_bar.dart';

import '../../../../core/client/api_client.dart';
import '../../data/models/stock_movement_model.dart';
import 'stock_movement_history_pdf_report.dart';

Color _movTypeColor(String type) {
  switch (type) {
    case 'IN':
      return const Color(0xFF2E7D32);
    case 'OUT':
      return const Color(0xFFE65100);
    case 'TRANSFER_IN':
    case 'TRANSFER_OUT':
    case 'TRANSFER':
      return const Color(0xFF6A1B9A);
    case 'ADJUST':
      return const Color(0xFF1565C0);
    case 'SALE':
      return const Color(0xFFC62828);
    default:
      return Colors.grey;
  }
}

IconData _movTypeIcon(String type) {
  switch (type) {
    case 'IN':
      return Icons.add_box_rounded;
    case 'OUT':
      return Icons.remove_circle_rounded;
    case 'TRANSFER_IN':
    case 'TRANSFER_OUT':
    case 'TRANSFER':
      return Icons.swap_horiz_rounded;
    case 'ADJUST':
      return Icons.tune_rounded;
    case 'SALE':
      return Icons.shopping_cart_rounded;
    default:
      return Icons.inventory_2_rounded;
  }
}

String _movTypeLabel(String type) {
  switch (type) {
    case 'IN':
      return 'รับเข้า';
    case 'OUT':
      return 'เบิกออก';
    case 'TRANSFER_IN':
      return 'รับโอน';
    case 'TRANSFER_OUT':
      return 'โอนออก';
    case 'TRANSFER':
      return 'โอนย้าย';
    case 'ADJUST':
      return 'ปรับสต๊อก';
    case 'SALE':
      return 'ขาย';
    default:
      return type;
  }
}

final movementHistoryProvider = FutureProvider<List<StockMovementModel>>((
  ref,
) async {
  final apiClient = ref.read(apiClientProvider);
  final response = await apiClient.get('/api/stock/movements');
  if (response.statusCode == 200) {
    final data = response.data['data'] as List;
    return data.map((json) => StockMovementModel.fromJson(json)).toList();
  }
  return [];
});

class StockMovementHistoryPage extends ConsumerStatefulWidget {
  const StockMovementHistoryPage({super.key});

  @override
  ConsumerState<StockMovementHistoryPage> createState() =>
      _StockMovementHistoryPageState();
}

class _StockMovementHistoryPageState
    extends ConsumerState<StockMovementHistoryPage> {
  final _searchController = TextEditingController();
  final _hScroll = ScrollController();
  final _dateFmt = DateFormat('dd/MM/yyyy HH:mm');
  final _moneyFmt = NumberFormat('#,##0.00');

  String _searchQuery = '';
  String _filterType = 'ALL';
  DateTime? _dateFrom;
  DateTime? _dateTo;
  bool _isTableView = true;
  String _sortColumn = 'date';
  bool _sortAsc = false;
  int _currentPage = 1;

  final List<double> _colWidths = [150, 120, 120, 110, 90, 120, 70];
  static const List<double> _colMinW = [120, 90, 90, 90, 80, 90, 70];
  static const List<double> _colMaxW = [220, 180, 180, 170, 140, 180, 70];

  @override
  void dispose() {
    _searchController.dispose();
    _hScroll.dispose();
    super.dispose();
  }

  bool get _hasFilter =>
      _searchQuery.isNotEmpty ||
      _filterType != 'ALL' ||
      _dateFrom != null ||
      _dateTo != null;

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom
          ? (_dateFrom ?? DateTime.now())
          : (_dateTo ?? _dateFrom ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _dateFrom = picked;
        if (_dateTo != null && _dateTo!.isBefore(picked)) _dateTo = null;
      } else {
        _dateTo = picked;
      }
      _currentPage = 1;
    });
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _filterType = 'ALL';
      _dateFrom = null;
      _dateTo = null;
      _currentPage = 1;
    });
  }

  List<StockMovementModel> _applyFilter(List<StockMovementModel> all) {
    return all.where((m) {
      if (_filterType != 'ALL' && m.movementType != _filterType) return false;

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matches =
            m.productId.toLowerCase().contains(q) ||
            m.warehouseId.toLowerCase().contains(q) ||
            (m.referenceNo?.toLowerCase().contains(q) ?? false) ||
            (m.remark?.toLowerCase().contains(q) ?? false) ||
            _movTypeLabel(m.movementType).toLowerCase().contains(q);
        if (!matches) return false;
      }

      if (_dateFrom != null && m.movementDate.isBefore(_dateFrom!)) {
        return false;
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
        if (m.movementDate.isAfter(endOfDay)) return false;
      }
      return true;
    }).toList();
  }

  List<StockMovementModel> _applySort(List<StockMovementModel> list) {
    list.sort((a, b) {
      int cmp;
      switch (_sortColumn) {
        case 'date':
          cmp = a.movementDate.compareTo(b.movementDate);
          break;
        case 'type':
          cmp = a.movementType.compareTo(b.movementType);
          break;
        case 'product':
          cmp = a.productId.compareTo(b.productId);
          break;
        case 'warehouse':
          cmp = a.warehouseId.compareTo(b.warehouseId);
          break;
        case 'quantity':
          cmp = a.quantity.compareTo(b.quantity);
          break;
        case 'reference':
          cmp = (a.referenceNo ?? '').compareTo(b.referenceNo ?? '');
          break;
        default:
          cmp = 0;
      }
      return _sortAsc ? cmp : -cmp;
    });
    return list;
  }

  Map<String, dynamic> _calcSummary(List<StockMovementModel> list) {
    int countOf(String t) => list
        .where(
          (m) =>
              m.movementType == t ||
              (t == 'TRANSFER' &&
                  (m.movementType == 'TRANSFER_IN' ||
                      m.movementType == 'TRANSFER_OUT')),
        )
        .length;

    final value = list.fold<double>(0, (sum, m) => sum + m.lineValue);
    return {
      'count': list.length,
      'inCount': countOf('IN'),
      'outCount': countOf('OUT'),
      'transferCount': countOf('TRANSFER'),
      'adjustCount': countOf('ADJUST'),
      'saleCount': countOf('SALE'),
      'value': value,
    };
  }

  @override
  Widget build(BuildContext context) {
    final movementsAsync = ref.watch(movementHistoryProvider);
    final pageSize = ref.watch(settingsProvider).listPageSize;
    final colors = _StockMovementColors.of(context);

    return Scaffold(
      backgroundColor: colors.scaffoldBg,
      body: EscapePopScope(
        child: Column(
          children: [
            _StockMovementTopBar(
              searchController: _searchController,
              searchQuery: _searchQuery,
              hasFilter: _hasFilter,
              isTableView: _isTableView,
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
              onRefresh: () => ref.invalidate(movementHistoryProvider),
              onClearFilter: _hasFilter ? _clearFilters : null,
              onToggleView: () => setState(() => _isTableView = !_isTableView),
            ),
            _FilterBar(
              dateFrom: _dateFrom,
              dateTo: _dateTo,
              filterType: _filterType,
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
              onTypeChanged: (v) => setState(() {
                _filterType = v;
                _currentPage = 1;
              }),
            ),
            Expanded(
              child: movementsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppTheme.primary),
                ),
                error: (e, _) => _buildError(e),
                data: (movements) {
                  final filtered = _applySort(_applyFilter(movements));
                  final summary = _calcSummary(filtered);

                  if (filtered.isEmpty) return _buildEmpty(movements.isEmpty);

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

                  return Container(
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
                        _SummaryBar(summary: summary, moneyFmt: _moneyFmt),
                        Divider(height: 1, color: colors.border),
                        Expanded(
                          child: _isTableView
                              ? Scrollbar(
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
                                          _MovementTableHeader(
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
                                                150,
                                                120,
                                                120,
                                                110,
                                                90,
                                                120,
                                                70,
                                              ]);
                                            }),
                                          ),
                                          Divider(
                                            height: 1,
                                            color: colors.border,
                                          ),
                                          Expanded(
                                            child: ListView.separated(
                                              itemCount: pageItems.length,
                                              separatorBuilder: (_, _) =>
                                                  Divider(
                                                    height: 1,
                                                    color: colors.border,
                                                  ),
                                              itemBuilder: (_, i) =>
                                                  _MovementTableRow(
                                                    movement: pageItems[i],
                                                    no: pageStart + i + 1,
                                                    colWidths: _colWidths,
                                                    dateFmt: _dateFmt,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.all(12),
                                  itemCount: pageItems.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (_, i) => _MovementCard(
                                    movement: pageItems[i],
                                    dateFmt: _dateFmt,
                                  ),
                                ),
                        ),
                        PaginationBar(
                          currentPage: safePage,
                          totalItems: filtered.length,
                          pageSize: pageSize,
                          onPageChanged: (p) =>
                              setState(() => _currentPage = p),
                          trailing: PdfReportButton(
                            emptyMessage:
                                'ไม่มีข้อมูลประวัติการเคลื่อนไหวสต๊อก',
                            title: 'รายงานประวัติการเคลื่อนไหวสต๊อก',
                            filename: () =>
                                PdfFilename.generate('stock_movement_history'),
                            buildPdf: () =>
                                StockMovementHistoryPdfBuilder.build(
                                  filtered,
                                  dateFrom: _dateFrom,
                                  dateTo: _dateTo,
                                  filterType: _filterType,
                                ),
                            hasData: filtered.isNotEmpty,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(bool noData) {
    final colors = _StockMovementColors.of(context);
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
              noData ? Icons.history : Icons.search_off_outlined,
              size: 38,
              color: colors.emptyIcon,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            noData
                ? 'ยังไม่มีประวัติการเคลื่อนไหว'
                : 'ไม่พบรายการที่ตรงกับเงื่อนไข',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: colors.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            noData
                ? 'ประวัติจะแสดงเมื่อมีการรับ เบิก โอน หรือปรับสต๊อก'
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
    final colors = _StockMovementColors.of(context);
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
            onPressed: () => ref.invalidate(movementHistoryProvider),
            icon: const Icon(Icons.refresh),
            label: const Text('ลองใหม่'),
          ),
        ],
      ),
    );
  }
}

class _StockMovementTopBar extends StatelessWidget {
  final TextEditingController searchController;
  final String searchQuery;
  final bool hasFilter;
  final bool isTableView;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchCleared;
  final VoidCallback onRefresh;
  final VoidCallback? onClearFilter;
  final VoidCallback onToggleView;

  const _StockMovementTopBar({
    required this.searchController,
    required this.searchQuery,
    required this.hasFilter,
    required this.isTableView,
    required this.onSearchChanged,
    required this.onSearchCleared,
    required this.onRefresh,
    this.onClearFilter,
    required this.onToggleView,
  });

  static const _kBreak = 600.0;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= _kBreak;
    final canPop = Navigator.of(context).canPop();
    final colors = _StockMovementColors.of(context);

    return Container(
      decoration: BoxDecoration(color: colors.topBarBg),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: isWide
          ? _buildWide(context, colors, canPop)
          : _buildNarrow(context, colors, canPop),
    );
  }

  Widget _buildWide(
    BuildContext context,
    _StockMovementColors colors,
    bool canPop,
  ) {
    return Row(
      children: [
        if (canPop) ...[
          _BackBtn(onTap: () => Navigator.of(context).pop()),
          const SizedBox(width: 10),
        ],
        _PageIcon(),
        const SizedBox(width: 10),
        const Text(
          'ประวัติการเคลื่อนไหวสต๊อก',
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
        if (hasFilter && onClearFilter != null)
          _ClearFilterBtn(onTap: onClearFilter!),
        const SizedBox(width: 6),
        _ViewModeBtn(isTableView: isTableView, onTap: onToggleView),
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
            'Stock History',
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

  Widget _buildNarrow(
    BuildContext context,
    _StockMovementColors colors,
    bool canPop,
  ) {
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
            const Expanded(
              child: Text(
                'ประวัติการเคลื่อนไหวสต๊อก',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (hasFilter && onClearFilter != null)
              _ClearFilterBtn(onTap: onClearFilter!),
            const SizedBox(width: 6),
            _ViewModeBtn(isTableView: isTableView, onTap: onToggleView),
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

class _FilterBar extends StatelessWidget {
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String filterType;
  final VoidCallback onPickFrom;
  final VoidCallback onPickTo;
  final VoidCallback onClearFrom;
  final VoidCallback onClearTo;
  final ValueChanged<String> onTypeChanged;

  const _FilterBar({
    required this.dateFrom,
    required this.dateTo,
    required this.filterType,
    required this.onPickFrom,
    required this.onPickTo,
    required this.onClearFrom,
    required this.onClearTo,
    required this.onTypeChanged,
  });

  static final _fmt = DateFormat('dd/MM/yy');

  @override
  Widget build(BuildContext context) {
    final colors = _StockMovementColors.of(context);
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
          _DateChip(
            label: dateFrom != null
                ? 'ตั้งแต่: ${_fmt.format(dateFrom!)}'
                : 'ตั้งแต่วันที่',
            icon: Icons.calendar_today,
            active: dateFrom != null,
            onTap: onPickFrom,
            onClear: dateFrom != null ? onClearFrom : null,
          ),
          _DateChip(
            label: dateTo != null
                ? 'ถึง: ${_fmt.format(dateTo!)}'
                : 'ถึงวันที่',
            icon: Icons.calendar_month,
            active: dateTo != null,
            onTap: onPickTo,
            onClear: dateTo != null ? onClearTo : null,
          ),
          _DropdownChip<String>(
            icon: Icons.swap_horiz,
            value: filterType,
            items: const [
              ('ALL', 'ทุกประเภท'),
              ('IN', 'รับเข้า'),
              ('OUT', 'เบิกออก'),
              ('ADJUST', 'ปรับสต๊อก'),
              ('TRANSFER_IN', 'รับโอน'),
              ('TRANSFER_OUT', 'โอนออก'),
              ('SALE', 'ขาย'),
            ],
            onChanged: onTypeChanged,
          ),
        ],
      ),
    );
  }
}

class _SummaryBar extends StatelessWidget {
  final Map<String, dynamic> summary;
  final NumberFormat moneyFmt;

  const _SummaryBar({required this.summary, required this.moneyFmt});

  @override
  Widget build(BuildContext context) {
    final chips = [
      _SummaryChip(
        icon: Icons.receipt_long,
        label: '${summary['count']} รายการ',
        color: AppTheme.info,
      ),
      const SizedBox(width: 12),
      _SummaryChip(
        icon: Icons.add_box_rounded,
        label: '${summary['inCount']} รับเข้า',
        color: const Color(0xFF2E7D32),
      ),
      const SizedBox(width: 12),
      _SummaryChip(
        icon: Icons.remove_circle_rounded,
        label: '${summary['outCount']} เบิกออก',
        color: const Color(0xFFE65100),
      ),
      const SizedBox(width: 12),
      _SummaryChip(
        icon: Icons.attach_money,
        label: '฿${moneyFmt.format(summary['value'])}',
        color: AppTheme.primary,
      ),
    ];

    final colors = _StockMovementColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(color: colors.summaryBg),
      child: Wrap(spacing: 12, runSpacing: 8, children: chips),
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
    final colors = _StockMovementColors.of(context);
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

class _MovementTableHeader extends StatelessWidget {
  final List<double> colWidths;
  final List<double> colMinW;
  final List<double> colMaxW;
  final String sortColumn;
  final bool sortAsc;
  final void Function(String) onSort;
  final void Function(int, double) onResize;
  final VoidCallback onReset;

  static const _cols = [
    ('วันที่/เวลา', 'date'),
    ('ประเภท', 'type'),
    ('รหัสสินค้า', 'product'),
    ('คลัง', 'warehouse'),
    ('จำนวน', 'quantity'),
    ('เลขอ้างอิง', 'reference'),
    ('ดู', ''),
  ];

  const _MovementTableHeader({
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
    final colors = _StockMovementColors.of(context);
    return Container(
      decoration: BoxDecoration(color: colors.tableHeaderBg),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
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
    final labelColor = widget.isActive ? activeColor : Colors.white70;
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
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
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

class _MovementTableRow extends StatefulWidget {
  final StockMovementModel movement;
  final int no;
  final List<double> colWidths;
  final DateFormat dateFmt;

  const _MovementTableRow({
    required this.movement,
    required this.no,
    required this.colWidths,
    required this.dateFmt,
  });

  @override
  State<_MovementTableRow> createState() => _MovementTableRowState();
}

class _MovementTableRowState extends State<_MovementTableRow> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final colors = _StockMovementColors.of(context);
    final m = widget.movement;
    final w = widget.colWidths;
    final isPositive = m.quantity >= 0;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        color: _hovering ? colors.rowHoverBg : colors.cardBg,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              child: CircleAvatar(
                radius: 14,
                backgroundColor: _movTypeColor(
                  m.movementType,
                ).withValues(alpha: 0.12),
                child: Icon(
                  _movTypeIcon(m.movementType),
                  size: 14,
                  color: _movTypeColor(m.movementType),
                ),
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: w[0],
              child: Text(
                widget.dateFmt.format(m.movementDate),
                style: TextStyle(fontSize: 12, color: colors.text),
              ),
            ),
            SizedBox(
              width: w[1],
              child: Center(child: _TypeBadge(type: m.movementType)),
            ),
            SizedBox(
              width: w[2],
              child: Text(
                m.productId,
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: colors.text,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(
              width: w[3],
              child: Text(
                m.warehouseId,
                style: TextStyle(fontSize: 12, color: colors.subtext),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(
              width: w[4],
              child: Align(
                alignment: Alignment.center,
                child: Text(
                  '${isPositive ? '+' : ''}${m.quantity.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isPositive ? AppTheme.success : AppTheme.error,
                  ),
                ),
              ),
            ),
            SizedBox(
              width: w[5],
              child: Text(
                m.referenceNo ?? '—',
                style: TextStyle(fontSize: 11, color: colors.subtext),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(
              width: w[6],
              child: Align(
                alignment: Alignment.center,
                child: Tooltip(
                  message: m.remark?.isNotEmpty == true
                      ? m.remark!
                      : 'ไม่มีหมายเหตุ',
                  child: Icon(
                    Icons.info_outline,
                    size: 16,
                    color: colors.subtext,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MovementCard extends StatelessWidget {
  final StockMovementModel movement;
  final DateFormat dateFmt;

  const _MovementCard({required this.movement, required this.dateFmt});

  @override
  Widget build(BuildContext context) {
    final colors = _StockMovementColors.of(context);
    final color = _movTypeColor(movement.movementType);
    final isPositive = movement.quantity >= 0;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: colors.border),
      ),
      color: colors.cardBg,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(
                _movTypeIcon(movement.movementType),
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _TypeBadge(type: movement.movementType),
                      const Spacer(),
                      Text(
                        '${isPositive ? '+' : ''}${movement.quantity.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isPositive ? AppTheme.success : AppTheme.error,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    movement.productId,
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: colors.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 10,
                    runSpacing: 6,
                    children: [
                      _InfoWithIcon(
                        icon: Icons.access_time,
                        text: dateFmt.format(movement.movementDate),
                      ),
                      _InfoWithIcon(
                        icon: Icons.warehouse_outlined,
                        text: movement.warehouseId,
                      ),
                      if (movement.referenceNo != null &&
                          movement.referenceNo!.isNotEmpty)
                        _InfoWithIcon(
                          icon: Icons.tag,
                          text: movement.referenceNo!,
                        ),
                    ],
                  ),
                  if (movement.remark != null &&
                      movement.remark!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      movement.remark!,
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.subtext,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final String type;
  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final color = _movTypeColor(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        _movTypeLabel(type),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _InfoWithIcon extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoWithIcon({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final colors = _StockMovementColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: colors.subtext),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 11, color: colors.subtext)),
      ],
    );
  }
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
  Widget build(BuildContext context) {
    final colors = _StockMovementColors.of(context);
    return SizedBox(
      height: 40,
      child: TextField(
        controller: controller,
        style: TextStyle(fontSize: 13, color: colors.text),
        decoration: InputDecoration(
          hintText: 'ค้นหารหัสสินค้า / อ้างอิง...',
          hintStyle: TextStyle(fontSize: 13, color: colors.subtext),
          prefixIcon: Icon(Icons.search, size: 17, color: colors.subtext),
          suffixIcon: query.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 15),
                  onPressed: onCleared,
                )
              : null,
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: colors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: colors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
          ),
          filled: true,
          fillColor: colors.inputFill,
        ),
        onChanged: onChanged,
      ),
    );
  }
}

class _RefreshBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _RefreshBtn({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = _StockMovementColors.of(context);
    return Tooltip(
      message: 'รีเฟรช',
      waitDuration: const Duration(milliseconds: 600),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: colors.navButtonBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.navButtonBorder),
          ),
          child: const Icon(Icons.refresh, size: 17, color: Colors.white70),
        ),
      ),
    );
  }
}

class _ViewModeBtn extends StatelessWidget {
  final bool isTableView;
  final VoidCallback onTap;

  const _ViewModeBtn({required this.isTableView, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = _StockMovementColors.of(context);
    return Tooltip(
      message: isTableView ? 'Card View' : 'Table View',
      waitDuration: const Duration(milliseconds: 600),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: colors.navButtonBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.navButtonBorder),
          ),
          child: Icon(
            isTableView
                ? Icons.view_agenda_outlined
                : Icons.table_rows_outlined,
            size: 17,
            color: Colors.white70,
          ),
        ),
      ),
    );
  }
}

class _ClearFilterBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _ClearFilterBtn({required this.onTap});

  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'ล้างตัวกรองทั้งหมด',
    preferBelow: false,
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
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.filter_alt_off, size: 15, color: Colors.white),
            SizedBox(width: 5),
            Text(
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
  Widget build(BuildContext context) {
    final colors = _StockMovementColors.of(context);
    return context.isMobile
        ? buildMobileHomeCompactButton(context)
        : InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: colors.navButtonBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colors.navButtonBorder),
              ),
              child: const Icon(
                Icons.arrow_back,
                size: 17,
                color: Colors.white70,
              ),
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
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: active
              ? AppTheme.primaryColor.withValues(alpha: 0.10)
              : const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? AppTheme.primaryColor : AppTheme.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: active ? AppTheme.primaryColor : AppTheme.textSub,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: active ? AppTheme.primaryColor : AppTheme.textSub,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (onClear != null) ...[
              const SizedBox(width: 4),
              InkWell(
                onTap: onClear,
                borderRadius: BorderRadius.circular(10),
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(Icons.close, size: 14, color: AppTheme.textSub),
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
    final colors = _StockMovementColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: colors.isDark
            ? const Color(0xFF2A2A2A)
            : const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          icon: Icon(Icons.arrow_drop_down, size: 18, color: colors.subtext),
          dropdownColor: colors.cardBg,
          style: TextStyle(fontSize: 12, color: colors.text),
          items: items
              .map(
                (item) => DropdownMenuItem<T>(
                  value: item.$1,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 14, color: colors.subtext),
                      const SizedBox(width: 6),
                      Text(
                        item.$2,
                        style: TextStyle(fontSize: 12, color: colors.text),
                      ),
                    ],
                  ),
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

class _StockMovementColors {
  final bool isDark;
  final Color scaffoldBg;
  final Color cardBg;
  final Color border;
  final Color text;
  final Color subtext;
  final Color topBarBg;
  final Color searchBarBg;
  final Color tableHeaderBg;
  final Color summaryBg;
  final Color summaryChipBg;
  final Color inputFill;
  final Color rowHoverBg;
  final Color emptyIconBg;
  final Color emptyIcon;
  final Color navButtonBg;
  final Color navButtonBorder;

  const _StockMovementColors({
    required this.isDark,
    required this.scaffoldBg,
    required this.cardBg,
    required this.border,
    required this.text,
    required this.subtext,
    required this.topBarBg,
    required this.searchBarBg,
    required this.tableHeaderBg,
    required this.summaryBg,
    required this.summaryChipBg,
    required this.inputFill,
    required this.rowHoverBg,
    required this.emptyIconBg,
    required this.emptyIcon,
    required this.navButtonBg,
    required this.navButtonBorder,
  });

  factory _StockMovementColors.of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _StockMovementColors(
      isDark: isDark,
      scaffoldBg: isDark ? AppTheme.darkBg : AppTheme.surface,
      cardBg: isDark ? AppTheme.darkCard : Colors.white,
      border: isDark ? const Color(0xFF333333) : AppTheme.border,
      text: isDark ? const Color(0xFFE0E0E0) : const Color(0xFF1A1A1A),
      subtext: isDark ? const Color(0xFF9E9E9E) : AppTheme.textSub,
      topBarBg: isDark ? AppTheme.navyDark : AppTheme.navy,
      searchBarBg: isDark ? AppTheme.darkTopBar : Colors.white,
      tableHeaderBg: isDark ? AppTheme.navyDark : AppTheme.navy,
      summaryBg: isDark ? const Color(0xFF181818) : const Color(0xFFFFF8F5),
      summaryChipBg: isDark ? const Color(0xFF2C2C2C) : Colors.white,
      inputFill: isDark ? AppTheme.darkElement : Colors.white,
      rowHoverBg: isDark
          ? AppTheme.primaryLight.withValues(alpha: 0.15)
          : AppTheme.primaryLight,
      emptyIconBg: isDark ? AppTheme.darkCard : AppTheme.surface,
      emptyIcon: isDark ? const Color(0xFF9E9E9E) : const Color(0xFF9E9E9E),
      navButtonBg: isDark
          ? Colors.white.withValues(alpha: 0.08)
          : AppTheme.navyLight,
      navButtonBorder: isDark ? Colors.white24 : AppTheme.navy,
    );
  }
}
