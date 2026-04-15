import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pos_erp/shared/widgets/pagination_bar.dart';

import '../../../settings/presentation/pages/settings_page.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/pdf/pdf_report_button.dart';
import '../../../../shared/utils/responsive_utils.dart';
import '../../../../shared/widgets/escape_pop_scope.dart';
import '../../../../shared/widgets/mobile_home_button.dart';
import '../providers/stock_provider.dart';
import '../widgets/stock_in_dialog.dart';
import '../widgets/stock_out_dialog.dart';
import '../widgets/stock_adjust_dialog.dart';
import '../widgets/stock_transfer_dialog.dart';
import '../widgets/stock_product_history_dialog.dart';
import 'stock_movement_history_page.dart';
import 'stock_balance_pdf_report.dart';
import '../../data/models/stock_balance_model.dart';

const _orange = AppTheme.primaryColor;
const _success = AppTheme.successColor;
const _error = AppTheme.errorColor;
const _warning = AppTheme.warningColor;

class StockBalancePage extends ConsumerStatefulWidget {
  const StockBalancePage({super.key});

  @override
  ConsumerState<StockBalancePage> createState() => _StockBalancePageState();
}

class _StockBalancePageState extends ConsumerState<StockBalancePage> {
  static const List<double> _baseDefaultColWidths = [
    120,
    200,
    140,
    106,
    70,
    140,
    136,
    86,
    120,
  ];
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _hScroll = ScrollController();
  final NumberFormat _qtyFmt = NumberFormat('#,##0');
  final NumberFormat _moneyFmt = NumberFormat('#,##0.00');
  String _searchQuery = '';
  String _selectedWarehouse = 'WH001'; // ✅ เหมือนไฟล์เดิม
  bool _isTableView = true;
  bool _initializedViewMode = false;
  bool _showLowStockOnly = false;
  String _sortColumn = 'productCode';
  bool _sortAsc = true;

  // ── Pagination ──────────────────────────────────────────────────
  int _currentPage = 1;
  bool _userResized = false; // ป้องกัน auto-fit override ค่าที่ user ลากไว้

  // ลำดับ: [รหัส, ชื่อ, คลัง, คงเหลือ, หน่วย, ต้นทุน/หน่วย, มูลค่าสต๊อก, สถานะ, จัดการ]
  final List<double> _colWidths = List<double>.from(_baseDefaultColWidths);
  static const List<double> _colMinW = [
    110, // รหัสสินค้า
    120, // ชื่อสินค้า
    86, // คลัง
    100, // คงเหลือ
    60, // หน่วย
    136, // ต้นทุน/หน่วย
    130, // มูลค่าสต๊อก
    80, // สถานะ
    44, // จัดการ
  ];
  static const List<double> _colMaxW = [
    220,
    300,
    240,
    160,
    120,
    200,
    210,
    140,
    120,
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initializedViewMode) return;
    _isTableView = !context.isMobile;
    _initializedViewMode = true;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _hScroll.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  // Filter + Sort (รักษา logic รวมยอด "ทุกคลัง" จากไฟล์เดิม)
  // ─────────────────────────────────────────────────────────────
  List<StockBalanceModel> _applyFilters(
    List<StockBalanceModel> stocks,
    int lowThreshold,
    bool alertOn,
  ) {
    // 1. กรองคลัง — เหมือน logic เดิม
    var result = stocks.where((s) {
      if (_selectedWarehouse != 'ALL' && s.warehouseId != _selectedWarehouse) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        if (!s.productName.toLowerCase().contains(q) &&
            !s.productCode.toLowerCase().contains(q)) {
          return false;
        }
      }
      if (_showLowStockOnly && !(alertOn && s.balance < lowThreshold)) {
        return false;
      }
      return true;
    }).toList();

    // 2. รวมยอด "ทุกคลัง" — WAC ถ่วงน้ำหนักจากทุกคลัง
    if (_selectedWarehouse == 'ALL') {
      final Map<String, StockBalanceModel> combined = {};
      for (var s in result) {
        if (combined.containsKey(s.productId)) {
          final ex = combined[s.productId]!;
          final newBal = ex.balance + s.balance;
          // WAC = (qty_A × cost_A + qty_B × cost_B) / (qty_A + qty_B)
          final newWac = newBal > 0
              ? (ex.balance * ex.avgCost + s.balance * s.avgCost) / newBal
              : 0.0;
          combined[s.productId] = StockBalanceModel(
            productId: ex.productId,
            productCode: ex.productCode,
            productName: ex.productName,
            barcode: ex.barcode,
            baseUnit: ex.baseUnit,
            warehouseId: 'ALL',
            warehouseName: 'ทุกคลัง',
            balance: newBal,
            avgCost: newWac,
          );
        } else {
          combined[s.productId] = StockBalanceModel(
            productId: s.productId,
            productCode: s.productCode,
            productName: s.productName,
            barcode: s.barcode,
            baseUnit: s.baseUnit,
            warehouseId: 'ALL',
            warehouseName: 'ทุกคลัง',
            balance: s.balance,
            avgCost: s.avgCost,
          );
        }
      }
      result = combined.values.toList();
    }

    // 3. Sort
    result.sort((a, b) {
      int c;
      switch (_sortColumn) {
        case 'productCode':
          c = a.productCode.compareTo(b.productCode);
          break;
        case 'productName':
          c = a.productName.compareTo(b.productName);
          break;
        case 'balance':
          c = a.balance.compareTo(b.balance);
          break;
        case 'avgCost':
          c = a.avgCost.compareTo(b.avgCost);
          break;
        case 'stockValue':
          c = a.stockValue.compareTo(b.stockValue);
          break;
        default:
          c = 0;
      }
      return _sortAsc ? c : -c;
    });
    return result;
  }

  void _onSort(String col) {
    setState(() {
      if (_sortColumn == col) {
        _sortAsc = !_sortAsc;
      } else {
        _sortColumn = col;
        _sortAsc = true;
      }
      _currentPage = 1;
    });
  }

  double _measureTextWidth(
    BuildContext context,
    String text, {
    required TextStyle style,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      maxLines: 1,
    )..layout();
    return painter.width;
  }

  List<double> _defaultColWidthsFor(BuildContext context) {
    final compactActions = MediaQuery.sizeOf(context).width < 1180;
    return [
      _baseDefaultColWidths[0],
      _baseDefaultColWidths[1],
      _baseDefaultColWidths[2],
      _baseDefaultColWidths[3],
      _baseDefaultColWidths[4],
      _baseDefaultColWidths[5],
      _baseDefaultColWidths[6],
      _baseDefaultColWidths[7],
      compactActions ? 44 : _baseDefaultColWidths[8],
    ];
  }

  void _autoFitColWidths(List<StockBalanceModel> rows, _StockColors colors) {
    // (label, isSortable) — ลำดับต้องตรงกับ _colWidths
    final headers = [
      ('รหัสสินค้า', true),
      ('ชื่อสินค้า', true),
      ('คลัง', false),
      ('คงเหลือ', true),
      ('หน่วย', false),
      ('ต้นทุน/หน่วย', true),
      ('มูลค่าสต๊อก', true),
      ('สถานะ', false),
      ('', false), // actions (last)
    ];
    const headerStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.4,
    );
    final codeStyle = TextStyle(
      fontSize: 13,
      fontFamily: 'monospace',
      fontWeight: FontWeight.w500,
      color: colors.subtext,
    );
    final nameStyle = TextStyle(fontSize: 13, color: colors.text);
    final subtext12 = TextStyle(fontSize: 12, color: colors.subtext);
    final qtyStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.bold,
      color: AppTheme.success,
    );
    final moneyStyle = TextStyle(fontSize: 12, color: colors.text);
    final costStyle = TextStyle(
      fontSize: 12,
      color: colors.isDark ? AppTheme.primaryLight : AppTheme.info,
    );
    const badgeStyle = TextStyle(fontSize: 11, fontWeight: FontWeight.w600);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final compactActions = screenWidth < 1180;
    final tightDesktop = screenWidth < 1080;

    // เหมือน product_list_page: basePadding + sortChrome + resizeHandle + buffer
    const basePadding = 16.0;
    const sortChrome = 20.0; // gap(4) + icon(12) + 4px buffer
    const resizeHandle = 14.0;
    const headerBuffer = 10.0;

    final maxW = List<double>.generate(headers.length, (i) {
      final label = headers[i].$1;
      final isSortable = headers[i].$2;
      final isLast = i == headers.length - 1;
      final labelW = label.isEmpty
          ? 0.0
          : _measureTextWidth(context, label, style: headerStyle);
      return labelW +
          basePadding +
          (isSortable ? sortChrome : 0.0) +
          (isLast ? 0.0 : resizeHandle) +
          headerBuffer;
    });

    for (final s in rows) {
      final codeW =
          _measureTextWidth(context, s.productCode, style: codeStyle) + 20;
      final barcodeW = (s.barcode != null && s.barcode!.isNotEmpty)
          ? _measureTextWidth(
                  context,
                  s.barcode!,
                  style: const TextStyle(fontSize: 11),
                ) +
                16
          : 0.0;
      final nameW = [
        _measureTextWidth(context, s.productName, style: nameStyle) + 20,
        barcodeW,
      ].reduce((a, b) => a > b ? a : b);
      final whW =
          _measureTextWidth(context, s.warehouseName, style: subtext12) + 20;
      final qtyW =
          _measureTextWidth(
            context,
            _qtyFmt.format(s.balance),
            style: qtyStyle.copyWith(
              color: s.balance < 0 ? AppTheme.error : AppTheme.success,
            ),
          ) +
          20;
      final unitW =
          _measureTextWidth(context, s.baseUnit, style: subtext12) + 20;
      final costText = s.avgCost > 0 ? '฿${_moneyFmt.format(s.avgCost)}' : '-';
      final costW =
          _measureTextWidth(
            context,
            costText,
            style: s.avgCost > 0 ? costStyle : subtext12,
          ) +
          20;
      final stockValueText = s.avgCost > 0
          ? '฿${NumberFormat('#,##0').format(s.stockValue)}'
          : '-';
      final stockValueW =
          _measureTextWidth(
            context,
            stockValueText,
            style: s.avgCost > 0
                ? moneyStyle.copyWith(fontWeight: FontWeight.w600)
                : subtext12,
          ) +
          20;
      final statusLabel = s.balance < 0 ? 'ติดลบ' : 'สต๊อกต่ำ';
      final statusW =
          _measureTextWidth(context, statusLabel, style: badgeStyle) + 34;
      final actionW = compactActions
          ? 44.0
          : tightDesktop
          ? 104.0
          : 120.0;

      if (codeW > maxW[0]) maxW[0] = codeW;
      if (nameW > maxW[1]) maxW[1] = nameW;
      if (whW > maxW[2]) maxW[2] = whW;
      if (qtyW > maxW[3]) maxW[3] = qtyW;
      if (unitW > maxW[4]) maxW[4] = unitW;
      if (costW > maxW[5]) maxW[5] = costW;
      if (stockValueW > maxW[6]) maxW[6] = stockValueW;
      if (statusW > maxW[7]) maxW[7] = statusW;
      if (actionW > maxW[8]) maxW[8] = actionW;
    }

    for (int i = 0; i < maxW.length; i++) {
      maxW[i] = maxW[i].clamp(_colMinW[i], _colMaxW[i]);
    }

    for (int i = 0; i < _colWidths.length; i++) {
      _colWidths[i] = maxW[i];
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final stockAsync = ref.watch(stockBalanceProvider);
    final settings = ref.watch(settingsProvider);

    final colors = _StockColors.of(context);

    return Scaffold(
      backgroundColor: colors.scaffoldBg,
      body: EscapePopScope(
        child: Column(
          children: [
            // ── Top Bar (navy) ────────────────────────────────────
            _buildTopBar(context, colors),

            // ── Filter / Search / Summary toolbar ────────────────
            _buildToolbar(stockAsync, settings, colors),

            // ── Content ─────────────────────────────────────────
            Expanded(
              child: stockAsync.when(
                loading: () => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: AppTheme.primary),
                      const SizedBox(height: 16),
                      Text(
                        'กำลังโหลดสต๊อก...',
                        style: TextStyle(color: colors.subtext),
                      ),
                    ],
                  ),
                ),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: _error),
                      const SizedBox(height: 16),
                      Text(
                        'เกิดข้อผิดพลาด: $e',
                        style: TextStyle(color: colors.text),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('ลองใหม่'),
                        onPressed: () =>
                            ref.read(stockBalanceProvider.notifier).refresh(),
                      ),
                    ],
                  ),
                ),
                data: (stocks) {
                  final filtered = _applyFilters(
                    stocks,
                    settings.lowStockThreshold,
                    settings.enableLowStockAlert,
                  );
                  if (filtered.isEmpty) return _buildEmpty(colors);
                  final totalPages = (filtered.length / settings.listPageSize)
                      .ceil();
                  final safePage = _currentPage.clamp(1, totalPages);
                  final pageStart = (safePage - 1) * settings.listPageSize;
                  final pageEnd = (pageStart + settings.listPageSize).clamp(
                    0,
                    filtered.length,
                  );
                  final pageItems = filtered.sublist(pageStart, pageEnd);
                  final compactDesktop =
                      context.isDesktopOrWider &&
                      MediaQuery.sizeOf(context).width < 1180;
                  final effectiveTableView = _isTableView && !compactDesktop;

                  return Column(
                    children: [
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          decoration: BoxDecoration(
                            color: colors.cardBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: colors.border),
                            boxShadow: colors.isDark
                                ? null
                                : [
                                    BoxShadow(
                                      color: AppTheme.navy.withValues(
                                        alpha: 0.04,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                          ),
                          child: effectiveTableView
                              ? _buildTableView(pageItems, settings, colors)
                              : _buildCardView(pageItems, settings, colors),
                        ),
                      ),
                      // ── Footer / Pagination ──────────────────────
                      PaginationBar(
                        currentPage: safePage,
                        totalItems: filtered.length,
                        pageSize: settings.listPageSize,
                        onPageChanged: (p) => setState(() => _currentPage = p),
                        trailing: PdfReportButton(
                          emptyMessage: 'ไม่มีข้อมูลสต๊อก',
                          title: 'รายงานสต๊อกสินค้า',
                          filename: () => PdfFilename.generate('stock_report'),
                          buildPdf: () => StockBalancePdfBuilder.build(
                            filtered,
                            lowStockThreshold: settings.lowStockThreshold,
                            highlightLowStock: settings.enableLowStockAlert,
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
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Top Bar (navy)
  // ─────────────────────────────────────────────────────────────
  static const _kTopBarBreak = 720.0;

  Widget _buildTopBar(BuildContext context, _StockColors colors) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= _kTopBarBreak;

    return Container(
      color: colors.topBarBg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: isWide
          ? _buildTopBarWide(context, colors)
          : _buildTopBarNarrow(context, colors),
    );
  }

  // ── Shared sub-widgets ──────────────────────────────────────
  Widget _pageIcon() => Container(
    padding: const EdgeInsets.all(6),
    decoration: BoxDecoration(
      color: AppTheme.primary.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Icon(
      Icons.inventory_2_outlined,
      size: 16,
      color: AppTheme.primaryLight,
    ),
  );

  Widget _stockBadge() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: AppTheme.primary.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: AppTheme.primary.withValues(alpha: 0.5)),
    ),
    child: const Text(
      'Stock',
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppTheme.primaryLight,
      ),
    ),
  );

  List<Widget> _actionButtons(_StockColors colors) => [
    _TopBarBtn(
      icon: _showLowStockOnly
          ? Icons.warning_amber_rounded
          : Icons.warning_amber_outlined,
      tooltip: _showLowStockOnly ? 'แสดงทั้งหมด' : 'แสดงเฉพาะสต๊อกต่ำ',
      colors: colors,
      active: _showLowStockOnly,
      onTap: () => setState(() {
        _showLowStockOnly = !_showLowStockOnly;
        _currentPage = 1;
      }),
    ),
    const SizedBox(width: 6),
    _TopBarBtn(
      icon: _isTableView
          ? Icons.view_agenda_outlined
          : Icons.table_rows_outlined,
      tooltip: _isTableView ? 'สลับเป็นการ์ด' : 'สลับเป็นตาราง',
      colors: colors,
      onTap: () => setState(() => _isTableView = !_isTableView),
    ),
    const SizedBox(width: 6),
    _TopBarBtn(
      icon: Icons.history,
      tooltip: 'ประวัติการเคลื่อนไหวสต๊อก',
      colors: colors,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const StockMovementHistoryPage()),
      ),
    ),
    const SizedBox(width: 6),
    _TopBarBtn(
      icon: Icons.refresh,
      tooltip: 'รีเฟรชข้อมูล',
      colors: colors,
      onTap: () => ref.read(stockBalanceProvider.notifier).refresh(),
    ),
  ];

  Widget _searchField(_StockColors colors, {bool inTopBar = false}) {
    return SizedBox(
      height: 40,
      child: TextField(
        controller: _searchController,
        style: TextStyle(fontSize: 13, color: colors.text),
        decoration: InputDecoration(
          hintText: 'ค้นหาชื่อ / รหัสสินค้า...',
          hintStyle: TextStyle(fontSize: 13, color: colors.subtext),
          prefixIcon: Icon(Icons.search, size: 17, color: colors.subtext),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, size: 15, color: colors.subtext),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                      _currentPage = 1;
                    });
                  },
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
        onChanged: (v) => setState(() {
          _searchQuery = v;
          _currentPage = 1;
        }),
      ),
    );
  }

  Widget _warehouseDropdown(_StockColors colors, {bool inTopBar = false}) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(8),
        color: colors.inputFill,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedWarehouse,
          isDense: true,
          dropdownColor: colors.cardBg,
          style: TextStyle(fontSize: 13, color: colors.text),
          iconEnabledColor: colors.subtext,
          items: [
            DropdownMenuItem(
              value: 'ALL',
              child: Text('ทุกคลัง', style: TextStyle(color: colors.text)),
            ),
            DropdownMenuItem(
              value: 'WH001',
              child: Text('คลังหลัก', style: TextStyle(color: colors.text)),
            ),
            DropdownMenuItem(
              value: 'WH002',
              child: Text('คลังสยาม', style: TextStyle(color: colors.text)),
            ),
          ],
          onChanged: (v) => setState(() {
            _selectedWarehouse = v!;
            _currentPage = 1;
          }),
        ),
      ),
    );
  }

  // ── Wide (>= 720): single row ──────────────────────────────
  Widget _buildTopBarWide(BuildContext context, _StockColors colors) {
    final canPop = Navigator.of(context).canPop();
    return Row(
      children: [
        if (canPop && buildMobileHomeLeading(context) != null) ...[
          buildMobileHomeLeading(context)!,
          const SizedBox(width: 10),
        ],
        _pageIcon(),
        const SizedBox(width: 10),
        const Text(
          'สต๊อกคงเหลือ',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const Spacer(),
        // Search field
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 240),
          child: _searchField(colors, inTopBar: true),
        ),
        const SizedBox(width: 8),
        // Warehouse dropdown
        _warehouseDropdown(colors, inTopBar: true),
        const SizedBox(width: 8),
        // Action buttons
        ..._actionButtons(colors),
        const SizedBox(width: 8),
        _stockBadge(),
      ],
    );
  }

  // ── Narrow (< 720): double row ─────────────────────────────
  Widget _buildTopBarNarrow(BuildContext context, _StockColors colors) {
    final canPop = Navigator.of(context).canPop();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (canPop && buildMobileHomeLeading(context) != null) ...[
              buildMobileHomeLeading(context)!,
              const SizedBox(width: 8),
            ],
            _pageIcon(),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'สต๊อกคงเหลือ',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            ..._actionButtons(colors),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _searchField(colors, inTopBar: true)),
            const SizedBox(width: 8),
            _warehouseDropdown(colors, inTopBar: true),
          ],
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Toolbar: Search + Warehouse dropdown + Summary
  // ─────────────────────────────────────────────────────────────
  // ── Summary bar only (search/warehouse ย้ายไป top bar แล้ว) ──
  Widget _buildToolbar(AsyncValue stockAsync, settings, _StockColors colors) {
    final summaryBar = stockAsync.whenOrNull(
      data: (stocks) {
        final filtered = _applyFilters(
          stocks,
          settings.lowStockThreshold,
          settings.enableLowStockAlert,
        );
        final lowCount = filtered
            .where(
              (s) =>
                  settings.enableLowStockAlert &&
                  s.balance < settings.lowStockThreshold,
            )
            .length;
        final totalValue = filtered.fold<double>(
          0,
          (sum, s) => sum + s.stockValue,
        );
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: colors.summaryBg,
            border: Border(bottom: BorderSide(color: colors.border)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _SummaryChip(
                'รายการ',
                filtered.length,
                AppTheme.info,
                icon: Icons.receipt_long,
              ),
              if (totalValue > 0) _ValueChip(totalValue),
              if (lowCount > 0)
                _SummaryChip(
                  'สต๊อกต่ำ',
                  lowCount,
                  _error,
                  icon: Icons.warning_amber_rounded,
                ),
            ],
          ),
        );
      },
    );
    return summaryBar ?? const SizedBox.shrink();
  }

  // ─────────────────────────────────────────────────────────────
  // TABLE VIEW
  // ─────────────────────────────────────────────────────────────
  Widget _buildTableView(
    List<StockBalanceModel> stocks,
    settings,
    _StockColors colors,
  ) {
    final int threshold = settings.lowStockThreshold;
    final bool alertOn = settings.enableLowStockAlert;
    if (!_userResized) _autoFitColWidths(stocks, colors);

    final screenW = MediaQuery.sizeOf(context).width - 32;
    final totalW = 48.0 + _colWidths.fold(0.0, (sum, w) => sum + w) + 28.0;
    final tableW = totalW > screenW ? totalW : screenW;

    return Scrollbar(
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
              _StockResizableHeader(
                colWidths: _colWidths,
                colMinW: _colMinW,
                colMaxW: _colMaxW,
                sortColumn: _sortColumn,
                sortAsc: _sortAsc,
                onSort: _onSort,
                onResize: (i, w) => setState(() {
                  _colWidths[i] = w;
                  _userResized = true;
                }),
                onReset: () => setState(() {
                  _colWidths.setAll(0, _defaultColWidthsFor(context));
                  _userResized = false;
                }),
              ),
              Divider(height: 1, color: colors.border),
              Expanded(
                child: ListView.separated(
                  itemCount: stocks.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: colors.border),
                  itemBuilder: (_, i) {
                    final s = stocks[i];
                    final isLow = alertOn && s.balance < threshold;
                    return _StockTableRow(
                      stock: s,
                      no: i + 1,
                      isEven: i.isEven,
                      isLow: isLow,
                      colWidths: _colWidths,
                      onTap: () => _showStockActions(context, s),
                      onStockIn: () => showDialog(
                        context: context,
                        builder: (_) => StockInDialog(stock: s),
                      ),
                      onStockOut: () => showDialog(
                        context: context,
                        builder: (_) => StockOutDialog(stock: s),
                      ),
                      onTransfer: () => showDialog(
                        context: context,
                        builder: (_) => StockTransferDialog(stock: s),
                      ),
                      onAdjust: () => showDialog(
                        context: context,
                        builder: (_) => StockAdjustDialog(stock: s),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // CARD VIEW (ListView)
  // ─────────────────────────────────────────────────────────────
  Widget _buildCardView(
    List<StockBalanceModel> stocks,
    settings,
    _StockColors colors,
  ) {
    final int threshold = settings.lowStockThreshold;
    final bool alertOn = settings.enableLowStockAlert;

    final avatarColors = [
      AppTheme.primary,
      AppTheme.info,
      AppTheme.success,
      AppTheme.warning,
      AppTheme.purpleColor,
      AppTheme.tealColor,
    ];

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: stocks.length,
      separatorBuilder: (_, _) => Divider(height: 1, color: colors.border),
      itemBuilder: (context, i) {
        final s = stocks[i];
        final isLow = alertOn && s.balance < threshold;
        final initial = s.productName.isNotEmpty
            ? s.productName.substring(0, 1).toUpperCase()
            : '?';
        final avatarColor =
            avatarColors[s.productName.codeUnitAt(0) % avatarColors.length];

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
              children: [
                Stack(
                  clipBehavior: Clip.none,
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
                    if (isLow)
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: _warning,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colors.cardBg,
                              width: 1.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.warning_amber_rounded,
                            size: 8,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              s.productName,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: colors.text,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isLow
                                  ? AppTheme.errorContainer
                                  : AppTheme.successContainer,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color:
                                    (isLow ? AppTheme.error : AppTheme.success)
                                        .withValues(alpha: 0.18),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: isLow
                                        ? const Color(0xFFF44336)
                                        : const Color(0xFF4CAF50),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isLow ? 'สต๊อกต่ำ' : 'ปกติ',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: isLow
                                        ? const Color(0xFFC62828)
                                        : const Color(0xFF2E7D32),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'รหัส: ${s.productCode}',
                        style: TextStyle(fontSize: 11, color: colors.subtext),
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.warehouse_outlined,
                            size: 11,
                            color: colors.subtext,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              s.warehouseName,
                              style: TextStyle(
                                fontSize: 11,
                                color: colors.subtext,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Text(
                            s.balance.toStringAsFixed(0),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isLow ? AppTheme.error : AppTheme.info,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '/ ${s.baseUnit}',
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.subtext,
                            ),
                          ),
                          if (s.avgCost > 0) ...[
                            const SizedBox(width: 8),
                            Text(
                              'ต้นทุน: ฿${s.avgCost.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: colors.subtext,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (s.stockValue > 0)
                        Text(
                          'มูลค่าสต๊อก: ฿${s.stockValue.toStringAsFixed(2)}',
                          style: TextStyle(fontSize: 11, color: colors.subtext),
                        ),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _StockActionIconBtn(
                      icon: Icons.open_in_new,
                      color: AppTheme.primary,
                      tooltip: 'ดูรายละเอียด',
                      onTap: () => _showStockActions(context, s),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Stock Actions Bottom Sheet — ✅ เหมือนไฟล์เดิม
  // ─────────────────────────────────────────────────────────────
  void _showStockActions(BuildContext context, StockBalanceModel stock) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  const Icon(Icons.inventory_2, size: 18, color: AppTheme.navy),
                  const SizedBox(width: 8),
                  Text(
                    stock.productName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${stock.balance.toStringAsFixed(0)} ${stock.baseUnit}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: _success,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.add_box, color: _success),
              title: const Text('รับสินค้าเข้า'),
              onTap: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (_) => StockInDialog(stock: stock),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.remove_circle, color: _orange),
              title: const Text('เบิกสินค้าออก'),
              onTap: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (_) => StockOutDialog(stock: stock),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.swap_horiz, color: Color(0xFF6A1B9A)),
              title: const Text('โอนย้ายสินค้า'),
              onTap: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (_) => StockTransferDialog(stock: stock),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit, color: Color(0xFF1565C0)),
              title: const Text('ปรับสต๊อก'),
              onTap: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (_) => StockAdjustDialog(stock: stock),
                );
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(
                Icons.history,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : AppTheme.navy,
              ),
              title: const Text('ดูประวัติสต๊อก'),
              onTap: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (_) => StockProductHistoryDialog(stock: stock),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Empty state
  // ─────────────────────────────────────────────────────────────
  Widget _buildEmpty(_StockColors colors) => Center(
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
            color: colors.subtext,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _showLowStockOnly ? 'ไม่มีสินค้าที่สต๊อกต่ำ' : 'ไม่พบข้อมูลสต๊อก',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: colors.text,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _showLowStockOnly
              ? 'สินค้าทุกรายการยังมีสต๊อกเพียงพอ'
              : 'ลองค้นหาด้วยคำอื่น หรือล้างตัวกรอง',
          style: TextStyle(fontSize: 13, color: colors.subtext),
        ),
        if (_searchQuery.isNotEmpty || _showLowStockOnly) ...[
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.clear, size: 16),
            label: const Text('ล้างตัวกรอง'),
            onPressed: () => setState(() {
              _searchController.clear();
              _searchQuery = '';
              _showLowStockOnly = false;
              _currentPage = 1;
            }),
          ),
        ],
      ],
    ),
  );
}

// ════════════════════════════════════════════════════════════════
// _StockTableRow
// ════════════════════════════════════════════════════════════════
class _StockTableRow extends StatefulWidget {
  final StockBalanceModel stock;
  final int no;
  final bool isEven;
  final bool isLow;
  final List<double> colWidths;
  final VoidCallback onTap;
  final VoidCallback onStockIn;
  final VoidCallback onStockOut;
  final VoidCallback onTransfer;
  final VoidCallback onAdjust;

  const _StockTableRow({
    required this.stock,
    required this.no,
    required this.isEven,
    required this.isLow,
    required this.colWidths,
    required this.onTap,
    required this.onStockIn,
    required this.onStockOut,
    required this.onTransfer,
    required this.onAdjust,
  });

  @override
  State<_StockTableRow> createState() => _StockTableRowState();
}

class _StockTableRowState extends State<_StockTableRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final stock = widget.stock;
    final no = widget.no;
    final isEven = widget.isEven;
    final isLow = widget.isLow;
    final colors = _StockColors.of(context);
    final w = widget.colWidths;

    final nameColor = colors.text;
    final codeColor = colors.subtext;
    final whColor = colors.subtext;
    final unitColor = colors.text;
    final noColor = colors.isDark
        ? const Color(0xFF666666)
        : const Color(0xFFBBBBBB);

    final lightLowBg = const Color(0xFFFFF8E1);
    final darkLowBg = const Color(0xFF3E2E00);
    final normalBg = isLow
        ? (colors.isDark ? darkLowBg : lightLowBg)
        : (isEven ? colors.rowBg : colors.rowAltBg);

    final screenWidth = MediaQuery.sizeOf(context).width;
    final compactActions = screenWidth < 1180;
    final tightDesktop = screenWidth < 1080;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: _hovered ? colors.rowHoverBg : normalBg,
            border: isLow
                ? const Border(left: BorderSide(color: _warning, width: 3))
                : null,
          ),
          child: Row(
            children: [
              // No.
              SizedBox(
                width: 48,
                child: Center(
                  child: Text(
                    '$no',
                    style: TextStyle(fontSize: 12, color: noColor),
                  ),
                ),
              ),
              // รหัส
              SizedBox(
                width: w[0],
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 11,
                    horizontal: 8,
                  ),
                  child: Text(
                    stock.productCode,
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w500,
                      color: codeColor,
                    ),
                  ),
                ),
              ),
              // ชื่อ + barcode
              SizedBox(
                width: w[1],
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        stock.productName,
                        style: TextStyle(fontSize: 13, color: nameColor),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (stock.barcode != null && stock.barcode!.isNotEmpty)
                        Text(
                          stock.barcode!,
                          style: TextStyle(fontSize: 11, color: colors.subtext),
                        ),
                    ],
                  ),
                ),
              ),
              // คลัง
              SizedBox(
                width: w[2],
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    stock.warehouseName,
                    style: TextStyle(fontSize: 12, color: whColor),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              // คงเหลือ
              SizedBox(
                width: w[3],
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      NumberFormat('#,##0').format(stock.balance),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isLow ? _error : _success,
                      ),
                    ),
                  ),
                ),
              ),
              // หน่วย
              SizedBox(
                width: w[4],
                child: Center(
                  child: Text(
                    stock.baseUnit,
                    style: TextStyle(fontSize: 12, color: unitColor),
                  ),
                ),
              ),
              // ต้นทุน/หน่วย (WAC)
              SizedBox(
                width: w[5],
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      stock.avgCost > 0
                          ? '฿${stock.avgCost.toStringAsFixed(2)}'
                          : '-',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.isDark
                            ? AppTheme.primaryLight
                            : AppTheme.info,
                      ),
                    ),
                  ),
                ),
              ),
              // มูลค่าสต๊อก
              SizedBox(
                width: w[6],
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      stock.avgCost > 0
                          ? '฿${stock.stockValue.toStringAsFixed(0)}'
                          : '-',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: nameColor,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: w[7],
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: _StockStatusBadge(isLow: isLow),
                    ),
                  ),
                ),
              ),
              // Actions
              SizedBox(
                width: w[8],
                child: compactActions
                    ? Center(
                        child: _StockActionsMenu(
                          onStockIn: widget.onStockIn,
                          onStockOut: widget.onStockOut,
                          onTransfer: widget.onTransfer,
                          onAdjust: widget.onAdjust,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _StockActionBtn(
                            icon: Icons.add_box_outlined,
                            color: _success,
                            tooltip: 'รับเข้า',
                            onTap: widget.onStockIn,
                            compact: tightDesktop,
                          ),
                          _StockActionBtn(
                            icon: Icons.remove_circle_outline,
                            color: _orange,
                            tooltip: 'เบิกออก',
                            onTap: widget.onStockOut,
                            compact: tightDesktop,
                          ),
                          _StockActionBtn(
                            icon: Icons.swap_horiz,
                            color: const Color(0xFF6A1B9A),
                            tooltip: 'โอนย้าย',
                            onTap: widget.onTransfer,
                            compact: tightDesktop,
                          ),
                          _StockActionBtn(
                            icon: Icons.edit_outlined,
                            color: const Color(0xFF1565C0),
                            tooltip: 'ปรับสต๊อก',
                            onTap: widget.onAdjust,
                            compact: tightDesktop,
                          ),
                        ],
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
// Shared Sub-widgets
// ─────────────────────────────────────────────────────────────────

class _StockActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  final bool compact;
  const _StockActionBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: EdgeInsets.all(compact ? 4 : 6),
        child: Icon(icon, size: compact ? 16 : 17, color: color),
      ),
    ),
  );
}

class _StockActionsMenu extends StatelessWidget {
  final VoidCallback onStockIn;
  final VoidCallback onStockOut;
  final VoidCallback onTransfer;
  final VoidCallback onAdjust;

  const _StockActionsMenu({
    required this.onStockIn,
    required this.onStockOut,
    required this.onTransfer,
    required this.onAdjust,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<VoidCallback>(
      tooltip: 'จัดการสต๊อก',
      padding: EdgeInsets.zero,
      icon: const Icon(Icons.more_horiz, size: 18),
      onSelected: (callback) => callback(),
      itemBuilder: (context) => [
        PopupMenuItem<VoidCallback>(
          value: onStockIn,
          child: const ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.add_box_outlined, color: _success),
            title: Text('รับเข้า'),
          ),
        ),
        PopupMenuItem<VoidCallback>(
          value: onStockOut,
          child: const ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.remove_circle_outline, color: _orange),
            title: Text('เบิกออก'),
          ),
        ),
        PopupMenuItem<VoidCallback>(
          value: onTransfer,
          child: const ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.swap_horiz, color: Color(0xFF6A1B9A)),
            title: Text('โอนย้าย'),
          ),
        ),
        PopupMenuItem<VoidCallback>(
          value: onAdjust,
          child: const ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.edit_outlined, color: Color(0xFF1565C0)),
            title: Text('ปรับสต๊อก'),
          ),
        ),
      ],
    );
  }
}

class _StockStatusBadge extends StatelessWidget {
  final bool isLow;
  const _StockStatusBadge({required this.isLow});

  @override
  Widget build(BuildContext context) {
    final tightDesktop = MediaQuery.sizeOf(context).width < 1080;
    final color = isLow ? _error : AppTheme.success;
    final bgColor = isLow
        ? _error.withValues(alpha: 0.12)
        : AppTheme.success.withValues(alpha: 0.12);
    final label = isLow ? 'สต๊อกต่ำ' : 'ปกติ';

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tightDesktop ? 6 : 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: tightDesktop ? 3 : 4),
          Text(
            label,
            style: TextStyle(
              fontSize: tightDesktop ? 10 : 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// _StockResizableHeader — header ลากปรับขนาดคอลัมน์ได้ + reset
// ════════════════════════════════════════════════════════════════
class _StockResizableHeader extends StatelessWidget {
  final List<double> colWidths;
  final List<double> colMinW;
  final List<double> colMaxW;
  final String sortColumn;
  final bool sortAsc;
  final void Function(String) onSort;
  final void Function(int, double) onResize;
  final VoidCallback onReset;

  // (label, sortKey) — '' = ไม่ sort
  static const _cols = [
    ('รหัสสินค้า', 'productCode'),
    ('ชื่อสินค้า', 'productName'),
    ('คลัง', ''),
    ('คงเหลือ', 'balance'),
    ('หน่วย', ''),
    ('ต้นทุน/หน่วย', 'avgCost'),
    ('มูลค่าสต๊อก', 'stockValue'),
    ('สถานะ', ''),
    ('', ''), // actions
  ];

  const _StockResizableHeader({
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
    final colors = _StockColors.of(context);
    return Container(
      color: colors.tableHeaderBg,
      child: Row(
        children: [
          // No. fixed
          const SizedBox(
            width: 48,
            child: Center(
              child: Text(
                '#',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          // คอลัมน์ resize ได้
          ...List.generate(_cols.length, (i) {
            final (label, sortKey) = _cols[i];
            final isActive = sortKey.isNotEmpty && sortColumn == sortKey;
            final isLast = i == _cols.length - 1;
            return _StockResizableCell(
              label: label,
              width: colWidths[i],
              minWidth: colMinW[i],
              maxWidth: colMaxW[i],
              sortKey: sortKey,
              isActive: isActive,
              sortAsc: sortAsc,
              isLast: isLast,
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
            child: InkWell(
              onTap: onReset,
              borderRadius: BorderRadius.circular(4),
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(
                  Icons.settings_backup_restore,
                  size: 14,
                  color: Colors.white38,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// _StockResizableCell — cell ใน header ที่ลากปรับขนาดได้
// ════════════════════════════════════════════════════════════════
class _StockResizableCell extends StatefulWidget {
  final String label;
  final double width;
  final double minWidth;
  final double maxWidth;
  final String sortKey;
  final bool isActive;
  final bool sortAsc;
  final bool isLast;
  final VoidCallback? onSort;
  final void Function(double delta) onResize;

  const _StockResizableCell({
    required this.label,
    required this.width,
    required this.minWidth,
    required this.maxWidth,
    required this.sortKey,
    required this.isActive,
    required this.sortAsc,
    required this.isLast,
    required this.onSort,
    required this.onResize,
  });

  @override
  State<_StockResizableCell> createState() => _StockResizableCellState();
}

class _StockResizableCellState extends State<_StockResizableCell> {
  bool _hovering = false;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final labelColor = widget.isActive
        ? const Color(0xFFFF9D45) // AppTheme.primaryLight
        : Colors.white70;
    final dividerColor = _dragging || _hovering
        ? const Color(0xFFFF9D45)
        : Colors.white24;

    return SizedBox(
      width: widget.width,
      child: Row(
        children: [
          // Label + sort icon
          Expanded(
            child: GestureDetector(
              onTap: widget.onSort,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 8,
                ),
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        widget.label,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: labelColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    if (widget.isActive) ...[
                      const SizedBox(width: 4),
                      Icon(
                        widget.sortAsc
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        size: 12,
                        color: labelColor,
                      ),
                    ] else if (widget.sortKey.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.unfold_more,
                        size: 12,
                        color: Colors.white38,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          // Drag handle
          if (!widget.isLast)
            MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              onEnter: (_) => setState(() => _hovering = true),
              onExit: (_) => setState(() {
                _hovering = false;
                _dragging = false;
              }),
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragStart: (_) => setState(() => _dragging = true),
                onHorizontalDragUpdate: (d) => widget.onResize(d.delta.dx),
                onHorizontalDragEnd: (_) => setState(() => _dragging = false),
                onHorizontalDragCancel: () => setState(() => _dragging = false),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: 14,
                  height: 36,
                  alignment: Alignment.center,
                  child: Container(width: 1.5, height: 20, color: dividerColor),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// แสดงมูลค่าสต๊อกรวม (฿ format)
class _ValueChip extends StatelessWidget {
  final double value;
  const _ValueChip(this.value);

  @override
  Widget build(BuildContext context) {
    final formatted = value >= 1000000
        ? '฿${(value / 1000000).toStringAsFixed(2)}M'
        : value >= 1000
        ? '฿${(value / 1000).toStringAsFixed(1)}K'
        : '฿${value.toStringAsFixed(0)}';
    final colors = _StockColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colors.summaryChipBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.attach_money, size: 14, color: AppTheme.primary),
          const SizedBox(width: 4),
          Text(
            'มูลค่าสต๊อก $formatted',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;
  const _SummaryChip(
    this.label,
    this.count,
    this.color, {
    this.icon = Icons.info_outline,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _StockColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colors.summaryChipBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            '$count $label',
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

// ════════════════════════════════════════════════════════════════
// _TopBarBtn — icon button ใน navy top bar
// ════════════════════════════════════════════════════════════════
class _TopBarBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final _StockColors colors;
  final VoidCallback onTap;
  final bool active;

  const _TopBarBtn({
    required this.icon,
    required this.tooltip,
    required this.colors,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 600),
      child: SizedBox(
        width: 34,
        height: 34,
        child: Material(
          color: active
              ? AppTheme.primary.withValues(alpha: 0.25)
              : colors.navButtonBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: active ? AppTheme.primaryLight : colors.navButtonBorder,
            ),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Center(
              child: Icon(
                icon,
                size: 17,
                color: active ? AppTheme.primaryLight : Colors.white70,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StockActionIconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _StockActionIconBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    ),
  );
}

// ════════════════════════════════════════════════════════════════
// _StockColors — color token factory (Light / Dark)
// ════════════════════════════════════════════════════════════════
class _StockColors {
  final bool isDark;
  final Color scaffoldBg;
  final Color cardBg;
  final Color border;
  final Color text;
  final Color subtext;
  final Color topBarBg;
  final Color searchBarBg;
  final Color summaryBg;
  final Color summaryChipBg;
  final Color inputFill;
  final Color rowBg;
  final Color rowAltBg;
  final Color rowHoverBg;
  final Color neutralChipBg;
  final Color navButtonBg;
  final Color navButtonBorder;
  final Color emptyIconBg;
  final Color tableHeaderBg;

  const _StockColors({
    required this.isDark,
    required this.scaffoldBg,
    required this.cardBg,
    required this.border,
    required this.text,
    required this.subtext,
    required this.topBarBg,
    required this.searchBarBg,
    required this.summaryBg,
    required this.summaryChipBg,
    required this.inputFill,
    required this.rowBg,
    required this.rowAltBg,
    required this.rowHoverBg,
    required this.neutralChipBg,
    required this.navButtonBg,
    required this.navButtonBorder,
    required this.emptyIconBg,
    required this.tableHeaderBg,
  });

  factory _StockColors.of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _StockColors(
      isDark: isDark,
      scaffoldBg: isDark ? AppTheme.darkBg : AppTheme.surface,
      cardBg: isDark ? AppTheme.darkCard : Colors.white,
      border: isDark ? const Color(0xFF333333) : AppTheme.border,
      text: isDark ? const Color(0xFFE0E0E0) : const Color(0xFF1A1A1A),
      subtext: isDark ? const Color(0xFF9E9E9E) : AppTheme.textSub,
      topBarBg: isDark ? AppTheme.navyDark : AppTheme.navy,
      searchBarBg: isDark ? AppTheme.darkTopBar : Colors.white,
      summaryBg: isDark ? const Color(0xFF181818) : const Color(0xFFFFF8F5),
      summaryChipBg: isDark ? const Color(0xFF2C2C2C) : Colors.white,
      inputFill: isDark ? AppTheme.darkElement : Colors.white,
      rowBg: isDark ? const Color(0xFF2C2C2C) : Colors.white,
      rowAltBg: isDark ? const Color(0xFF272727) : const Color(0xFFF9F9F7),
      rowHoverBg: isDark
          ? AppTheme.primaryLight.withValues(alpha: 0.15)
          : AppTheme.primaryLight,
      neutralChipBg: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F0F0),
      navButtonBg: isDark
          ? Colors.white.withValues(alpha: 0.08)
          : AppTheme.navyLight,
      navButtonBorder: isDark ? Colors.white24 : AppTheme.navyColor,
      emptyIconBg: isDark ? AppTheme.darkCard : AppTheme.surface,
      tableHeaderBg: isDark ? AppTheme.navyDark : AppTheme.navy,
    );
  }
}
