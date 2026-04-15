import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pos_erp/shared/theme/app_theme.dart';
import 'package:pos_erp/shared/widgets/app_dialogs.dart';
import 'package:pos_erp/shared/widgets/pagination_bar.dart';
import '../providers/product_provider.dart';
import '../../data/models/product_model.dart';
import 'product_form_page.dart';
import 'product_group_management_page.dart';
import 'product_pdf_report.dart'; // ✅ PDF report
import '../../../../shared/pdf/pdf_report_button.dart';
import '../../../../shared/utils/responsive_utils.dart';
import '../../../../shared/widgets/mobile_home_button.dart';
import '../../../../features/settings/presentation/pages/settings_page.dart';
import '../../../../features/inventory/presentation/providers/stock_provider.dart';
import '../../../../features/inventory/data/models/stock_balance_model.dart';

class ProductListPage extends ConsumerStatefulWidget {
  const ProductListPage({super.key});

  @override
  ConsumerState<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends ConsumerState<ProductListPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedWarehouse = 'ALL';
  bool _isTableView = true;
  bool _initializedViewMode = false;
  bool _isActiveOnly = false; // filter เฉพาะสินค้าที่ใช้งาน
  bool _userResized =
      false; // ✅ ป้องกัน auto-adjust override ค่าที่ user ลากไว้
  String _sortColumn = 'productCode';
  bool _sortAsc = true;

  // ── Pagination ──────────────────────────────────────────────────
  int _currentPage = 1;

  // ลำดับ: [รหัส, ชื่อ, คงเหลือ, หน่วย, ราคา, ต้นทุน, มูลค่า, สถานะ, จัดการ]
  final List<double> _colWidths = [120, 200, 100, 60, 110, 96, 110, 76, 88];
  static const List<double> _colMinW = [110, 120, 96, 56, 100, 90, 96, 72, 88];
  static const List<double> _colMaxW = [
    220,
    300,
    140,
    140,
    180,
    180,
    200,
    120,
    88,
  ];

  // ✅ ScrollControllers สำหรับแสดง scrollbar
  final _hScroll = ScrollController();

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
  // Filter + Sort helpers
  // ─────────────────────────────────────────────────────────────
  List<ProductModel> _filter(List<ProductModel> src) {
    var result = src;
    if (_isActiveOnly) result = result.where((p) => p.isActive).toList();
    if (_searchQuery.isEmpty) return result;
    final q = _searchQuery.toLowerCase();
    return result
        .where(
          (p) =>
              p.productName.toLowerCase().contains(q) ||
              p.productCode.toLowerCase().contains(q) ||
              (p.barcode?.toLowerCase().contains(q) ?? false),
        )
        .toList();
  }

  List<ProductModel> _sort(
    List<ProductModel> src,
    Map<String, _ProductStockSnapshot> stockMap,
  ) {
    final list = List<ProductModel>.from(src);
    list.sort((a, b) {
      int c;
      switch (_sortColumn) {
        case 'productCode':
          c = a.productCode.compareTo(b.productCode);
          break;
        case 'productName':
          c = a.productName.compareTo(b.productName);
          break;
        case 'priceLevel1':
          c = a.priceLevel1.compareTo(b.priceLevel1);
          break;
        case 'standardCost':
          c = a.standardCost.compareTo(b.standardCost);
          break;
        case 'balance':
          c = (stockMap[a.productId]?.qty ?? 0).compareTo(
            stockMap[b.productId]?.qty ?? 0,
          );
          break;
        case 'stockValue':
          c = (a.standardCost * (stockMap[a.productId]?.qty ?? 0)).compareTo(
            b.standardCost * (stockMap[b.productId]?.qty ?? 0),
          );
          break;
        default:
          c = 0;
      }
      return _sortAsc ? c : -c;
    });
    return list;
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

  Map<String, _ProductStockSnapshot> _stockMap(List<StockBalanceModel> stocks) {
    final map = <String, _ProductStockSnapshot>{};
    for (final s in stocks) {
      if (_selectedWarehouse != 'ALL' && s.warehouseId != _selectedWarehouse) {
        continue;
      }
      final prev = map[s.productId] ?? const _ProductStockSnapshot();
      map[s.productId] = _ProductStockSnapshot(qty: prev.qty + s.balance);
    }
    return map;
  }

  String get _selectedWarehouseLabel => switch (_selectedWarehouse) {
    'WH001' => 'คลังหลัก',
    'WH002' => 'คลังสยาม',
    _ => 'ทุกคลัง',
  };

  // ─────────────────────────────────────────────────────────────
  // Delete — ใช้ pattern เดียวกับไฟล์ที่แนบมา
  // ─────────────────────────────────────────────────────────────
  Future<void> _confirmDelete(ProductModel product) async {
    // ── Pre-check ก่อนแสดง dialog ────────────────────────────────
    final check = await ref
        .read(productListProvider.notifier)
        .checkDeleteProduct(product.productId);
    if (!mounted) return;

    final hasHistory = check['has_history'] == true;
    final salesCount = (check['sales_count'] as int?) ?? 0;
    final movCount = (check['movement_count'] as int?) ?? 0;

    // ── สร้าง detail text ─────────────────────────────────────────
    final details = [
      if (salesCount > 0) 'ประวัติการขาย $salesCount รายการ',
      if (movCount > 0) 'ความเคลื่อนไหวสต๊อก $movCount รายการ',
    ].join(' และ ');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AppDialog(
        title: buildAppDialogTitle(
          context,
          title: hasHistory ? 'ปิดการใช้งานสินค้า' : 'ลบสินค้าถาวร',
          icon: hasHistory ? Icons.archive_outlined : Icons.delete_outline,
          iconColor: hasHistory ? AppTheme.warningColor : AppTheme.error,
        ),
        content: hasHistory
            ? Text(
                'สินค้า "${product.productName}" มี$details\n\n'
                'ไม่สามารถลบได้ ระบบจะปิดการใช้งานแทนเพื่อเก็บประวัติไว้',
              )
            : Text(
                'ต้องการลบสินค้า "${product.productName}" '
                'ออกจากระบบอย่างถาวรใช่หรือไม่?',
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton.icon(
            icon: Icon(
              hasHistory ? Icons.pause_circle_outline : Icons.delete_forever,
              size: 16,
            ),
            label: Text(hasHistory ? 'ปิดการใช้งาน' : 'ลบถาวร'),
            style: FilledButton.styleFrom(
              backgroundColor: hasHistory
                  ? AppTheme.warningColor
                  : AppTheme.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final message = await ref
        .read(productListProvider.notifier)
        .deleteProduct(product.productId);

    if (!mounted) return;
    final ok = message != null;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? message : 'ดำเนินการไม่สำเร็จ'),
        backgroundColor: ok ? AppTheme.success : AppTheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final productAsync = ref.watch(productListProvider);
    final stockAsync = ref.watch(stockBalanceProvider);
    final pageSize = ref.watch(settingsProvider).listPageSize;
    final colors = _ProductListColors.of(context);

    return Scaffold(
      backgroundColor: colors.scaffoldBg,
      body: Column(
        children: [
          // ── Top Bar (เหมือน customer_list_page) ────────────
          _ProductListTopBar(
            searchController: _searchController,
            searchQuery: _searchQuery,
            selectedWarehouse: _selectedWarehouse,
            isActiveOnly: _isActiveOnly,
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
            onToggleActive: () => setState(() {
              _isActiveOnly = !_isActiveOnly;
              _currentPage = 1;
            }),
            onWarehouseChanged: (v) => setState(() {
              _selectedWarehouse = v;
              _currentPage = 1;
            }),
            onToggleView: () => setState(() => _isTableView = !_isTableView),
            onRefresh: () => ref.read(productListProvider.notifier).refresh(),
            onManageGroups: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ProductGroupManagementPage(),
                ),
              );
            },
            onAdd: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProductFormPage()),
              );
            },
          ),

          // ── Summary chips + financial bar ────────────────────
          _buildSummaryBar(productAsync, stockAsync),

          // ── Content ─────────────────────────────────────────
          Expanded(
            child: productAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _buildError(e),
              data: (products) {
                final filtered = _filter(products);
                if (filtered.isEmpty) return _buildEmpty();
                final stockMap = _stockMap(stockAsync.value ?? const []);
                final sorted = _sort(filtered, stockMap);
                final totalPages = (sorted.length / pageSize).ceil();
                final safePage = _currentPage.clamp(1, totalPages);
                final pageStart = (safePage - 1) * pageSize;
                final pageEnd = (pageStart + pageSize).clamp(0, sorted.length);
                final pageItems = sorted.sublist(pageStart, pageEnd);
                return Column(
                  children: [
                    Expanded(
                      child: Container(
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
                        child: _isTableView
                            ? _buildTableView(
                                visibleProducts: pageItems,
                                allFittedProducts: sorted,
                                stockMap: stockMap,
                              )
                            : _buildCardView(pageItems, stockMap),
                      ),
                    ),
                    // ── Footer / Pagination ──────────────────────
                    PaginationBar(
                      currentPage: safePage,
                      totalItems: sorted.length,
                      pageSize: pageSize,
                      onPageChanged: (p) => setState(() => _currentPage = p),
                      trailing: PdfReportButton(
                        emptyMessage: 'ไม่มีข้อมูลสินค้า',
                        title: 'รายงานสินค้า',
                        filename: () => PdfFilename.generate('product_report'),
                        buildPdf: () {
                          final stockMap = _stockMap(
                            stockAsync.value ?? const [],
                          );
                          double cost = 0, selling = 0;
                          for (final p in filtered) {
                            final qty = stockMap[p.productId]?.qty ?? 0;
                            cost += p.standardCost * qty;
                            selling += p.priceLevel1 * qty;
                          }
                          final qtyMap = {
                            for (final e in stockMap.entries)
                              e.key: e.value.qty,
                          };
                          return ProductPdfBuilder.build(
                            List<ProductModel>.from(filtered),
                            stockQtyMap: qtyMap,
                            totalCost: cost,
                            totalSelling: selling,
                            totalProfit: selling - cost,
                          );
                        },
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

  // ─────────────────────────────────────────────────────────────
  // Summary Bar — chips จำนวน + แถวมูลค่าสินค้าคลัง
  // ─────────────────────────────────────────────────────────────
  Widget _buildSummaryBar(
    AsyncValue productAsync,
    AsyncValue<List<StockBalanceModel>> stockAsync,
  ) {
    final colors = _ProductListColors.of(context);
    return productAsync.maybeWhen(
      data: (products) {
        final all = products as List<ProductModel>;
        final filtered = _filter(all);

        final stockMap = _stockMap(stockAsync.value ?? const []);

        double totalCost = 0;
        double totalSelling = 0;
        double totalQty = 0;
        for (final p in filtered) {
          final snapshot =
              stockMap[p.productId] ?? const _ProductStockSnapshot();
          final qty = snapshot.qty;
          totalQty += qty;
          totalCost += p.standardCost * qty;
          totalSelling += p.priceLevel1 * qty;
        }
        final profit = totalSelling - totalCost;

        return Container(
          decoration: BoxDecoration(
            color: colors.summaryBg,
            border: Border(bottom: BorderSide(color: colors.border)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // ซ้าย — จำนวนสินค้า
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _SummaryChip('ทั้งหมด', all.length, AppTheme.info),
                        const SizedBox(width: 8),
                        _SummaryChip(
                          'กรองแล้ว',
                          filtered.length,
                          AppTheme.primary,
                        ),
                        const SizedBox(width: 8),
                        _SummaryChip(
                          'ใช้งาน',
                          all.where((p) => p.isActive).length,
                          AppTheme.success,
                        ),
                        const SizedBox(width: 8),
                        _SummaryChip(
                          'ปิดใช้',
                          all.where((p) => !p.isActive).length,
                          AppTheme.error,
                        ),
                        const SizedBox(width: 8),
                        _SummaryChip(
                          _selectedWarehouseLabel,
                          totalQty.round(),
                          AppTheme.info,
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    // ขวา — มูลค่าสินค้าในคลัง
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ValueStat(
                          label: 'ต้นทุนรวม ($_selectedWarehouseLabel)',
                          value: totalCost,
                          color: AppTheme.navy,
                          emphasis: _ValueStatEmphasis.medium,
                        ),
                        const SizedBox(width: 8),
                        _ValueStat(
                          label: 'มูลค่าขาย',
                          value: totalSelling,
                          color: AppTheme.primaryDark,
                          emphasis: _ValueStatEmphasis.medium,
                        ),
                        const SizedBox(width: 8),
                        _ValueStat(
                          label: profit >= 0
                              ? 'กำไรคาดการณ์'
                              : 'ขาดทุนคาดการณ์',
                          value: profit.abs(),
                          color: profit >= 0
                              ? AppTheme.success
                              : AppTheme.error,
                          sign: profit >= 0 ? '+' : '-',
                          emphasis: _ValueStatEmphasis.high,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TABLE VIEW
  // ─────────────────────────────────────────────────────────────
  // Auto-fit colWidths ตามความยาวข้อความจริงใน list
  // ─────────────────────────────────────────────────────────────
  void _autoFitColWidths(
    List<ProductModel> rows,
    Map<String, _ProductStockSnapshot> stockMap,
  ) {
    final headers = [
      ('รหัสสินค้า', true),
      ('ชื่อสินค้า', true),
      ('คงเหลือ', true),
      ('หน่วย', false),
      ('ราคาขาย', true),
      ('ต้นทุน', true),
      ('มูลค่า', true),
      ('สถานะ', false),
      ('', false),
    ];
    final headerStyle = const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.4,
    );
    final codeStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: _ProductListColors.of(context).subtext,
    );
    final nameStyle = TextStyle(
      fontSize: 13,
      color: _ProductListColors.of(context).text,
    );
    final subtextStyle = TextStyle(
      fontSize: 12,
      color: _ProductListColors.of(context).subtext,
    );
    final priceStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: _ProductListColors.of(context).amountText,
    );
    final statusStyle = const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
    );

    final maxW = List<double>.generate(headers.length, (i) {
      final label = headers[i].$1;
      final isSortable = headers[i].$2;
      final isLast = i == headers.length - 1;
      final labelW = label.isEmpty
          ? 0.0
          : _measureTextWidth(context, label, style: headerStyle);

      // Header cell uses: horizontal padding 8+8, sort icon/gap when sortable,
      // and resize handle width on every column except the last one.
      // +10 buffer for Thai font pixel rounding & icon rendering variance.
      const basePadding = 16.0;
      const sortChrome = 20.0; // gap(4) + icon(12) + 4px buffer
      const resizeHandle = 14.0;
      const headerBuffer = 10.0;
      return labelW +
          basePadding +
          (isSortable ? sortChrome : 0.0) +
          (isLast ? 0.0 : resizeHandle) +
          headerBuffer;
    });

    for (final p in rows) {
      final codeW =
          _measureTextWidth(context, p.productCode, style: codeStyle) + 20;
      final barcodeW = (p.barcode != null && p.barcode!.isNotEmpty)
          ? _measureTextWidth(
                  context,
                  p.barcode!,
                  style: const TextStyle(fontSize: 11),
                ) +
                16
          : 0.0;
      final nameW = [
        _measureTextWidth(context, p.productName, style: nameStyle) + 20,
        barcodeW,
      ].reduce((a, b) => a > b ? a : b);
      final unitW =
          _measureTextWidth(context, p.baseUnit, style: subtextStyle) + 20;
      final priceW =
          _measureTextWidth(
            context,
            '฿${p.priceLevel1.toStringAsFixed(2)}',
            style: priceStyle,
          ) +
          20;
      final costW =
          _measureTextWidth(
            context,
            '฿${p.standardCost.toStringAsFixed(2)}',
            style: subtextStyle,
          ) +
          20;
      final snapshot = stockMap[p.productId] ?? const _ProductStockSnapshot();
      final stockValue = p.standardCost * snapshot.qty;
      final qtyW =
          _measureTextWidth(
            context,
            NumberFormat('#,##0').format(snapshot.qty),
            style: priceStyle,
          ) +
          20;
      final valueW =
          _measureTextWidth(
            context,
            '฿${NumberFormat('#,##0.00').format(stockValue)}',
            style: subtextStyle,
          ) +
          20;
      final statusLabel = p.isActive ? 'ใช้งาน' : 'ปิดใช้';
      final statusW =
          _measureTextWidth(context, statusLabel, style: statusStyle) + 34;

      if (codeW > maxW[0]) maxW[0] = codeW;
      if (nameW > maxW[1]) maxW[1] = nameW;
      if (qtyW > maxW[2]) maxW[2] = qtyW;
      if (unitW > maxW[3]) maxW[3] = unitW;
      if (priceW > maxW[4]) maxW[4] = priceW;
      if (costW > maxW[5]) maxW[5] = costW;
      if (valueW > maxW[6]) maxW[6] = valueW;
      if (statusW > maxW[7]) maxW[7] = statusW;
      maxW[8] = 88;
    }

    for (int i = 0; i < maxW.length; i++) {
      maxW[i] = maxW[i].clamp(_colMinW[i], _colMaxW[i]);
    }

    for (int i = 0; i < _colWidths.length; i++) {
      _colWidths[i] = maxW[i];
    }
  }

  Widget _buildTableView({
    required List<ProductModel> visibleProducts,
    required List<ProductModel> allFittedProducts,
    required Map<String, _ProductStockSnapshot> stockMap,
  }) {
    // หักลบ margin ซ้าย-ขวา 16px ออกจาก screenW เพื่อให้ tableW ตรงกับพื้นที่จริง
    final screenW = MediaQuery.of(context).size.width - 32;
    if (!_userResized) _autoFitColWidths(allFittedProducts, stockMap);

    final totalW = 48.0 + _colWidths.fold(0.0, (s, w) => s + w) + 28.0;
    final tableW = totalW > screenW ? totalW : screenW;

    // ✅ แนวตั้ง scroll ด้านนอก (Scaffold body), แนวนอน scroll ด้านใน
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
              // Header
              _ProductResizableHeader(
                colWidths: _colWidths,
                colMinW: _colMinW,
                colMaxW: _colMaxW,
                sortColumn: _sortColumn,
                sortAsc: _sortAsc,
                onSort: _onSort,
                onResize: (i, w) => setState(() {
                  _colWidths[i] = w;
                  _userResized = true; // ✅ user resize แล้ว หยุด auto-adjust
                }),
                onReset: () => setState(() {
                  _colWidths.setAll(0, [120, 200, 100, 60, 110, 96, 110, 76, 88]);
                  _userResized = false; // ✅ reset → auto-fit ทำงานอีกครั้ง
                }),
              ),
              Divider(height: 1, color: _ProductListColors.of(context).border),
              // Rows — shrinkWrap ได้เพราะ Column รู้ขนาดจาก SizedBox แล้ว
              Expanded(
                child: ListView.separated(
                  itemCount: visibleProducts.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    color: _ProductListColors.of(context).border,
                  ),
                  itemBuilder: (_, i) => _ProductTableRow(
                    product: visibleProducts[i],
                    stock:
                        stockMap[visibleProducts[i].productId] ??
                        const _ProductStockSnapshot(),
                    no: i + 1,
                    isEven: i.isEven,
                    colWidths: _colWidths,
                    onEdit: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ProductFormPage(product: visibleProducts[i]),
                      ),
                    ),
                    onDelete: () => _confirmDelete(visibleProducts[i]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // CARD VIEW — ใช้ ListTile pattern เดิมจากไฟล์ที่แนบมา + ปรับ style
  // ─────────────────────────────────────────────────────────────
  Widget _buildCardView(
    List<ProductModel> products,
    Map<String, _ProductStockSnapshot> stockMap,
  ) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: products.length,
      separatorBuilder: (_, _) =>
          Divider(height: 1, color: _ProductListColors.of(context).border),
      itemBuilder: (context, i) {
        final p = products[i];
        final initial = p.productName.isNotEmpty
            ? p.productName.substring(0, 1).toUpperCase()
            : '?';
        // สีตาม initial เหมือน customer card
        final avatarPalette = [
          AppTheme.primary,
          AppTheme.info,
          AppTheme.success,
          AppTheme.warning,
          AppTheme.purpleColor,
          AppTheme.tealColor,
        ];
        final avatarColor =
            avatarPalette[p.productName.codeUnitAt(0) % avatarPalette.length];

        final colors = _ProductListColors.of(context);
        final stock = stockMap[p.productId] ?? const _ProductStockSnapshot();
        final stockValue = p.standardCost * stock.qty;

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
                // ── Avatar ──────────────────────────────────────
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
                    // badge เมื่อไม่ได้ควบคุมสต๊อก
                    if (!p.isStockControl)
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: AppTheme.textSub,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: const Icon(
                            Icons.remove_circle_outline,
                            size: 8,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),

                // ── Info ─────────────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ชื่อ + status badge
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              p.productName,
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
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: p.isActive
                                  ? AppTheme.successContainer
                                  : AppTheme.errorContainer,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color:
                                    (p.isActive
                                            ? AppTheme.success
                                            : AppTheme.error)
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
                                    color: p.isActive
                                        ? const Color(0xFF4CAF50)
                                        : const Color(0xFFF44336),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  p.isActive ? 'ใช้งาน' : 'ปิดใช้',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: p.isActive
                                        ? const Color(0xFF2E7D32)
                                        : const Color(0xFFC62828),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),

                      // รหัสสินค้า
                      Text(
                        'รหัส: ${p.productCode}',
                        style: TextStyle(fontSize: 11, color: colors.subtext),
                      ),

                      // barcode (ถ้ามี)
                      if (p.barcode != null && p.barcode!.isNotEmpty)
                        Row(
                          children: [
                            Icon(
                              Icons.qr_code,
                              size: 11,
                              color: colors.subtext,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              p.barcode!,
                              style: TextStyle(
                                fontSize: 11,
                                color: colors.subtext,
                              ),
                            ),
                          ],
                        ),

                      // ราคา + หน่วย
                      Row(
                        children: [
                          Text(
                            '฿${p.priceLevel1.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: colors.amountText,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '/ ${p.baseUnit}',
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.subtext,
                            ),
                          ),
                          if (p.standardCost > 0) ...[
                            const SizedBox(width: 8),
                            Text(
                              'ต้นทุน: ฿${p.standardCost.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: colors.subtext,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$_selectedWarehouseLabel: ${stock.qty.toStringAsFixed(0)} ${p.baseUnit} · มูลค่า ฿${stockValue.toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 11, color: colors.subtext),
                      ),
                    ],
                  ),
                ),

                // ── Actions ──────────────────────────────────────
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ActionIconBtn(
                      icon: Icons.edit_outlined,
                      color: AppTheme.info,
                      tooltip: 'แก้ไข',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProductFormPage(product: p),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    _ActionIconBtn(
                      icon: Icons.delete_outline,
                      color: AppTheme.error,
                      tooltip: 'ลบ',
                      onTap: () => _confirmDelete(p),
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
  // Empty / Error states — รักษา style จากไฟล์ที่แนบมา
  // ─────────────────────────────────────────────────────────────
  Widget _buildEmpty() {
    final colors = _ProductListColors.of(context);
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
              _searchQuery.isEmpty
                  ? Icons.inventory_2_outlined
                  : Icons.search_off_outlined,
              size: 38,
              color: colors.emptyIcon,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty
                ? 'ยังไม่มีสินค้า'
                : 'ไม่พบสินค้า "$_searchQuery"',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: colors.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _searchQuery.isEmpty
                ? 'กดปุ่มเพิ่มสินค้าเพื่อสร้างรายการแรก'
                : 'ลองปรับคำค้นหาหรือล้างตัวกรองเพื่อดูข้อมูลเพิ่ม',
            style: TextStyle(fontSize: 13, color: colors.subtext),
          ),
          if (_searchQuery.isEmpty) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('เพิ่มสินค้า'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProductFormPage()),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildError(Object e) {
    final colors = _ProductListColors.of(context);
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
            onPressed: () => ref.read(productListProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh),
            label: const Text('ลองใหม่'),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// _ProductListTopBar — responsive top bar (เหมือน customer_list)
// ════════════════════════════════════════════════════════════════
class _ProductListTopBar extends StatelessWidget {
  final TextEditingController searchController;
  final String searchQuery;
  final String selectedWarehouse;
  final bool isActiveOnly;
  final bool isTableView;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchCleared;
  final VoidCallback onToggleActive;
  final ValueChanged<String> onWarehouseChanged;
  final VoidCallback onToggleView;
  final VoidCallback onRefresh;
  final VoidCallback onManageGroups;
  final VoidCallback onAdd;

  const _ProductListTopBar({
    required this.searchController,
    required this.searchQuery,
    required this.selectedWarehouse,
    required this.isActiveOnly,
    required this.isTableView,
    required this.onSearchChanged,
    required this.onSearchCleared,
    required this.onToggleActive,
    required this.onWarehouseChanged,
    required this.onToggleView,
    required this.onRefresh,
    required this.onManageGroups,
    required this.onAdd,
  });

  static const _kBreak = 720.0;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= _kBreak;
    final canPop = Navigator.of(context).canPop();
    final colors = _ProductListColors.of(context);

    return Container(
      decoration: BoxDecoration(color: colors.topBarBg),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: isWide
          ? _buildSingleRow(context, canPop)
          : _buildDoubleRow(context, canPop),
    );
  }

  Widget _buildSingleRow(BuildContext context, bool canPop) {
    return Row(
      children: [
        if (canPop) ...[
          _PBackBtn(onTap: () => Navigator.of(context).pop()),
          const SizedBox(width: 10),
        ],
        _PPageIcon(),
        const SizedBox(width: 10),
        const Text(
          'รายการสินค้า',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const Spacer(),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: _PSearchField(
            controller: searchController,
            query: searchQuery,
            onChanged: onSearchChanged,
            onCleared: onSearchCleared,
          ),
        ),
        const SizedBox(width: 8),
        _PWarehouseDropdown(
          value: selectedWarehouse,
          onChanged: onWarehouseChanged,
        ),
        const SizedBox(width: 8),
        // Toggle active-only
        _PToggleBtn(
          icon: Icons.check_circle_outline,
          tooltip: isActiveOnly ? 'แสดงทั้งหมด' : 'เฉพาะที่ใช้งาน',
          active: isActiveOnly,
          activeColor: AppTheme.success,
          onTap: onToggleActive,
        ),
        const SizedBox(width: 6),
        // Toggle table/card view
        _PToggleBtn(
          icon: isTableView
              ? Icons.view_agenda_outlined
              : Icons.table_rows_outlined,
          tooltip: isTableView ? 'Card View' : 'Table View',
          active: false,
          activeColor: AppTheme.navy,
          onTap: onToggleView,
        ),
        const SizedBox(width: 6),
        _PRefreshBtn(onTap: onRefresh),
        const SizedBox(width: 6),
        _PManageGroupsBtn(onTap: onManageGroups),
        const SizedBox(width: 6),
        _PAddBtn(onTap: onAdd),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.5)),
          ),
          child: const Text(
            'Products',
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

  Widget _buildDoubleRow(BuildContext context, bool canPop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (canPop) ...[
              _PBackBtn(onTap: () => Navigator.of(context).pop()),
              const SizedBox(width: 8),
            ],
            _PPageIcon(),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'รายการสินค้า',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _PToggleBtn(
              icon: Icons.check_circle_outline,
              tooltip: isActiveOnly ? 'แสดงทั้งหมด' : 'เฉพาะที่ใช้งาน',
              active: isActiveOnly,
              activeColor: AppTheme.success,
              onTap: onToggleActive,
            ),
            const SizedBox(width: 4),
            _PToggleBtn(
              icon: isTableView
                  ? Icons.view_agenda_outlined
                  : Icons.table_rows_outlined,
              tooltip: isTableView ? 'Card View' : 'Table View',
              active: false,
              activeColor: AppTheme.navy,
              onTap: onToggleView,
            ),
            const SizedBox(width: 4),
            _PRefreshBtn(onTap: onRefresh),
            const SizedBox(width: 4),
            _PManageGroupsBtn(onTap: onManageGroups, compact: true),
            const SizedBox(width: 4),
            _PAddBtn(onTap: onAdd, compact: true),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _PSearchField(
                controller: searchController,
                query: searchQuery,
                onChanged: onSearchChanged,
                onCleared: onSearchCleared,
              ),
            ),
            const SizedBox(width: 8),
            _PWarehouseDropdown(
              value: selectedWarehouse,
              onChanged: onWarehouseChanged,
            ),
          ],
        ),
      ],
    );
  }
}

// ── Product TopBar sub-widgets ─────────────────────────────────

class _PBackBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _PBackBtn({required this.onTap});
  @override
  Widget build(BuildContext context) => context.isMobile
      ? buildMobileHomeCompactButton(context)
      : InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: _ProductListColors.of(context).navButtonBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _ProductListColors.of(context).navButtonBorder,
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

class _PPageIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(7),
    decoration: BoxDecoration(
      color: AppTheme.primary.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppTheme.primary.withValues(alpha: 0.28)),
    ),
    child: const Icon(
      Icons.inventory_2_outlined,
      color: AppTheme.primaryLight,
      size: 18,
    ),
  );
}

class _PSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onCleared;
  const _PSearchField({
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
        color: _ProductListColors.of(context).text,
      ),
      decoration: InputDecoration(
        hintText: 'ค้นหาชื่อ / รหัส / บาร์โค้ด...',
        hintStyle: TextStyle(
          fontSize: 13,
          color: _ProductListColors.of(context).subtext,
        ),
        prefixIcon: Icon(
          Icons.search,
          size: 17,
          color: _ProductListColors.of(context).subtext,
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
          borderSide: BorderSide(color: _ProductListColors.of(context).border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _ProductListColors.of(context).border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
        ),
        filled: true,
        fillColor: _ProductListColors.of(context).inputFill,
      ),
      onChanged: onChanged,
    ),
  );
}

class _PToggleBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;
  const _PToggleBtn({
    required this.icon,
    required this.tooltip,
    required this.active,
    required this.activeColor,
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
          color: active
              ? activeColor.withValues(alpha: 0.1)
              : _ProductListColors.of(context).navButtonBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active
                ? activeColor
                : _ProductListColors.of(context).navButtonBorder,
          ),
        ),
        child: Icon(
          icon,
          size: 17,
          color: active ? activeColor : Colors.white70,
        ),
      ),
    ),
  );
}

class _PWarehouseDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _PWarehouseDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colors = _ProductListColors.of(context);
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: colors.inputFill,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.navButtonBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          dropdownColor: colors.cardBg,
          style: TextStyle(fontSize: 13, color: colors.text),
          iconEnabledColor: colors.subtext,
          items: const [
            DropdownMenuItem(value: 'ALL', child: Text('ทุกคลัง')),
            DropdownMenuItem(value: 'WH001', child: Text('คลังหลัก')),
            DropdownMenuItem(value: 'WH002', child: Text('คลังสยาม')),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

class _PRefreshBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _PRefreshBtn({required this.onTap});
  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'รีเฟรช',
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: _ProductListColors.of(context).navButtonBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _ProductListColors.of(context).navButtonBorder,
          ),
        ),
        child: const Icon(Icons.refresh, size: 17, color: Colors.white70),
      ),
    ),
  );
}

class _PAddBtn extends StatelessWidget {
  final VoidCallback onTap;
  final bool compact;
  const _PAddBtn({required this.onTap, this.compact = false});
  @override
  Widget build(BuildContext context) => ElevatedButton.icon(
    onPressed: onTap,
    icon: const Icon(Icons.add, size: 18),
    label: compact
        ? const SizedBox.shrink()
        : const Text(
            'เพิ่มสินค้า',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
    style: ElevatedButton.styleFrom(
      backgroundColor: compact
          ? _ProductListColors.of(context).navButtonBg
          : AppTheme.primary,
      foregroundColor: compact ? Colors.white70 : Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 18,
        vertical: 13,
      ),
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      side: compact
          ? BorderSide(color: _ProductListColors.of(context).navButtonBorder)
          : null,
      elevation: 0,
    ),
  );
}

class _PManageGroupsBtn extends StatelessWidget {
  final VoidCallback onTap;
  final bool compact;

  const _PManageGroupsBtn({required this.onTap, this.compact = false});

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onTap,
    icon: const Icon(Icons.category_outlined, size: 18),
    label: compact
        ? const SizedBox.shrink()
        : const Text(
            'หมวดสินค้า',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
    style: OutlinedButton.styleFrom(
      foregroundColor: compact ? Colors.white70 : AppTheme.primaryColor,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 16,
        vertical: 13,
      ),
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      backgroundColor: compact
          ? _ProductListColors.of(context).navButtonBg
          : null,
      side: BorderSide(
        color: compact
            ? _ProductListColors.of(context).navButtonBorder
            : AppTheme.primaryColor.withValues(alpha: 0.28),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );
}

class _ProductStockSnapshot {
  final double qty;

  const _ProductStockSnapshot({this.qty = 0});
}

// ════════════════════════════════════════════════════════════════
// _ProductTableRow — แยก widget เพื่อให้ rebuild เฉพาะ row ที่เปลี่ยน
// ════════════════════════════════════════════════════════════════
class _ProductTableRow extends StatefulWidget {
  final ProductModel product;
  final _ProductStockSnapshot stock;
  final int no;
  final bool isEven;
  final List<double> colWidths; // ✅ รับ width จาก parent
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProductTableRow({
    required this.product,
    required this.stock,
    required this.no,
    required this.isEven,
    required this.colWidths,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_ProductTableRow> createState() => _ProductTableRowState();
}

class _ProductTableRowState extends State<_ProductTableRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final stock = widget.stock;
    final stockValue = p.standardCost * stock.qty;
    final colors = _ProductListColors.of(context);
    final w = widget.colWidths;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onDoubleTap: widget.onEdit,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          color: _hovered ? colors.rowHoverBg : colors.cardBg,
          child: Row(
            children: [
              // No. (fixed)
              SizedBox(
                width: 48,
                child: Center(
                  child: Text(
                    '${widget.no}',
                    style: TextStyle(fontSize: 12, color: colors.rowIndexText),
                  ),
                ),
              ),
              // รหัส — w[0]
              SizedBox(
                width: w[0],
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 8,
                  ),
                  child: Text(
                    p.productCode,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: colors.subtext,
                    ),
                  ),
                ),
              ),
              // ชื่อ + barcode — w[1]
              SizedBox(
                width: w[1],
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.productName,
                        style: TextStyle(fontSize: 13, color: colors.text),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (p.barcode != null && p.barcode!.isNotEmpty)
                        Text(
                          p.barcode!,
                          style: TextStyle(fontSize: 11, color: colors.subtext),
                        ),
                    ],
                  ),
                ),
              ),
              // คงเหลือ — w[2]
              SizedBox(
                width: w[2],
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      NumberFormat('#,##0').format(stock.qty),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.amountText,
                      ),
                    ),
                  ),
                ),
              ),
              // หน่วย — w[3]
              SizedBox(
                width: w[3],
                child: Center(
                  child: Text(
                    p.baseUnit,
                    style: TextStyle(fontSize: 12, color: colors.text),
                  ),
                ),
              ),
              // ราคาขาย — w[4]
              SizedBox(
                width: w[4],
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '฿${p.priceLevel1.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.amountText,
                      ),
                    ),
                  ),
                ),
              ),
              // ต้นทุน — w[5]
              SizedBox(
                width: w[5],
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '฿${p.standardCost.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 12, color: colors.costText),
                    ),
                  ),
                ),
              ),
              // มูลค่า — w[6]
              SizedBox(
                width: w[6],
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '฿${NumberFormat('#,##0.00').format(stockValue)}',
                      style: TextStyle(fontSize: 12, color: colors.costText),
                    ),
                  ),
                ),
              ),
              // สถานะ — w[7]
              SizedBox(
                width: w[7],
                child: Center(child: _StatusBadge(active: p.isActive)),
              ),
              // Actions — w[8] fixed
              SizedBox(
                width: w[8],
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ActionIconBtn(
                      icon: Icons.edit_outlined,
                      color: AppTheme.info,
                      tooltip: 'แก้ไข',
                      onTap: widget.onEdit,
                    ),
                    _ActionIconBtn(
                      icon: Icons.delete_outline,
                      color: AppTheme.error,
                      tooltip: 'ลบ',
                      onTap: widget.onDelete,
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

// ════════════════════════════════════════════════════════════════
// Shared Sub-widgets (reused by stock_balance_page if needed)
// ════════════════════════════════════════════════════════════════

// ════════════════════════════════════════════════════════════════
// _ProductResizableHeader — header ที่ลากขยาย/ย่อคอลัมน์ได้
// ════════════════════════════════════════════════════════════════
class _ProductResizableHeader extends StatelessWidget {
  final List<double> colWidths;
  final List<double> colMinW;
  final List<double> colMaxW;
  final String sortColumn;
  final bool sortAsc;
  final void Function(String) onSort;
  final void Function(int, double) onResize;
  final VoidCallback onReset;

  // ชื่อคอลัมน์ + column key สำหรับ sort ('' = ไม่ sort)
  static const _cols = [
    ('รหัสสินค้า', 'productCode'),
    ('ชื่อสินค้า', 'productName'),
    ('คงเหลือ', 'balance'),
    ('หน่วย', ''),
    ('ราคาขาย', 'priceLevel1'),
    ('ต้นทุน', 'standardCost'),
    ('มูลค่า', 'stockValue'),
    ('สถานะ', ''),
    ('', ''), // actions
  ];

  const _ProductResizableHeader({
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
      decoration: BoxDecoration(
        color: _ProductListColors.of(context).tableHeaderBg,
      ),
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

            return _ProductResizableCell(
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

// ─────────────────────────────────────────────────────────────────
// _ProductResizableCell
// ─────────────────────────────────────────────────────────────────
class _ProductResizableCell extends StatefulWidget {
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

  const _ProductResizableCell({
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
  State<_ProductResizableCell> createState() => _ProductResizableCellState();
}

class _ProductResizableCellState extends State<_ProductResizableCell> {
  bool _hovering = false;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final labelColor = widget.isActive
        ? const Color(0xFFFF9D45)
        : _ProductListColors.of(context).headerText;
    final dividerColor = _dragging || _hovering
        ? const Color(0xFFFF9D45)
        : Colors.white24;

    return SizedBox(
      width: widget.width,
      child: Row(
        children: [
          // Label (กด sort ได้ถ้ามี sortKey)
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
                  child: Container(
                    width: _dragging ? 3 : 2,
                    height: _dragging
                        ? 28
                        : _hovering
                        ? 24
                        : 16,
                    decoration: BoxDecoration(
                      color: dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool active;
  const _StatusBadge({required this.active});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: active ? AppTheme.successContainer : AppTheme.errorContainer,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: (active ? AppTheme.success : AppTheme.error).withValues(
          alpha: 0.16,
        ),
      ),
    ),
    child: Text(
      active ? 'ใช้งาน' : 'ปิด',
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: active ? const Color(0xFF1B5E20) : const Color(0xFFB71C1C),
      ),
    ),
  );
}

class _ActionIconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  const _ActionIconBtn({
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

// ── มูลค่าสินค้า (ต้นทุน / ราคาขาย / กำไร) ──────────────────────────────────
class _ValueStat extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final String sign;
  final _ValueStatEmphasis emphasis;

  const _ValueStat({
    required this.label,
    required this.value,
    required this.color,
    this.sign = '',
    this.emphasis = _ValueStatEmphasis.medium,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayColor = _summaryDisplayColor(color, isDark);
    final bgColor = switch (emphasis) {
      _ValueStatEmphasis.high => displayColor.withValues(
        alpha: isDark ? 0.18 : 0.12,
      ),
      _ValueStatEmphasis.medium => _ProductListColors.of(context).summaryChipBg,
    };
    final borderColor = switch (emphasis) {
      _ValueStatEmphasis.high => displayColor.withValues(
        alpha: isDark ? 0.34 : 0.24,
      ),
      _ValueStatEmphasis.medium => _ProductListColors.of(context).border,
    };
    final valueSize = emphasis == _ValueStatEmphasis.high ? 14.5 : 13.0;
    final labelOpacity = emphasis == _ValueStatEmphasis.high ? 0.92 : 0.76;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: emphasis == _ValueStatEmphasis.high ? 12 : 10,
        vertical: emphasis == _ValueStatEmphasis.high ? 7 : 6,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: displayColor.withValues(alpha: labelOpacity),
            ),
          ),
          const SizedBox(height: 1),
          Text(
            '$sign฿${fmt.format(value)}',
            style: TextStyle(
              fontSize: valueSize,
              fontWeight: FontWeight.bold,
              color: displayColor,
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
  const _SummaryChip(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayColor = _summaryDisplayColor(color, isDark);
    final textColor = displayColor.withValues(alpha: isDark ? 0.78 : 0.88);
    final badgeColor = displayColor.withValues(alpha: isDark ? 0.88 : 1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _ProductListColors.of(context).summaryChipBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _ProductListColors.of(context).border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: textColor)),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                color: isDark && displayColor == AppTheme.primaryLight
                    ? AppTheme.onPrimaryContainer
                    : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _ValueStatEmphasis { medium, high }

Color _summaryDisplayColor(Color base, bool isDark) {
  if (!isDark) return base;
  return switch (base) {
    AppTheme.navy => const Color(0xFFE0E0E0),
    AppTheme.primaryDark => AppTheme.primaryLight,
    AppTheme.primary => AppTheme.primaryLight,
    AppTheme.info => const Color(0xFF7CB7FF),
    AppTheme.success => const Color(0xFF7FD483),
    AppTheme.error => const Color(0xFFFF8A80),
    _ => base,
  };
}

class _ProductListColors {
  final bool isDark;
  final Color scaffoldBg;
  final Color cardBg;
  final Color border;
  final Color text;
  final Color subtext;
  final Color topBarBg;
  final Color summaryBg;
  final Color summaryChipBg;
  final Color inputFill;
  final Color emptyIconBg;
  final Color emptyIcon;
  final Color navButtonBg;
  final Color navButtonBorder;
  final Color rowHoverBg;
  final Color tableHeaderBg;
  final Color headerText;
  final Color amountText;
  final Color costText;
  final Color rowIndexText;

  const _ProductListColors({
    required this.isDark,
    required this.scaffoldBg,
    required this.cardBg,
    required this.border,
    required this.text,
    required this.subtext,
    required this.topBarBg,
    required this.summaryBg,
    required this.summaryChipBg,
    required this.inputFill,
    required this.emptyIconBg,
    required this.emptyIcon,
    required this.navButtonBg,
    required this.navButtonBorder,
    required this.rowHoverBg,
    required this.tableHeaderBg,
    required this.headerText,
    required this.amountText,
    required this.costText,
    required this.rowIndexText,
  });

  factory _ProductListColors.of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _ProductListColors(
      isDark: isDark,
      scaffoldBg: isDark ? AppTheme.darkBg : AppTheme.surface,
      cardBg: isDark ? const Color(0xFF2C2C2C) : Colors.white,
      border: isDark ? const Color(0xFF333333) : AppTheme.border,
      text: isDark ? const Color(0xFFE0E0E0) : const Color(0xFF1A1A1A),
      subtext: isDark ? const Color(0xFF9E9E9E) : AppTheme.textSub,
      topBarBg: isDark ? AppTheme.navyDark : AppTheme.navy,
      summaryBg: isDark ? const Color(0xFF181818) : const Color(0xFFFFF8F5),
      summaryChipBg: isDark ? const Color(0xFF2C2C2C) : Colors.white,
      inputFill: isDark ? AppTheme.darkElement : Colors.white,
      emptyIconBg: isDark ? AppTheme.darkCard : AppTheme.surface,
      emptyIcon: isDark ? const Color(0xFF9E9E9E) : Colors.grey,
      navButtonBg: isDark
          ? Colors.white.withValues(alpha: 0.08)
          : AppTheme.navyLight,
      navButtonBorder: isDark ? Colors.white24 : AppTheme.navy,
      rowHoverBg: isDark
          ? AppTheme.primaryLight.withValues(alpha: 0.15)
          : AppTheme.primaryLight,
      tableHeaderBg: isDark ? AppTheme.navyDark : AppTheme.navy,
      headerText: isDark ? const Color(0xFFE0E0E0) : Colors.white70,
      amountText: isDark ? AppTheme.primaryLight : AppTheme.info,
      costText: isDark ? const Color(0xFFBDBDBD) : const Color(0xFF666666),
      rowIndexText: isDark ? const Color(0xFF8F8F8F) : const Color(0xFFBBBBBB),
    );
  }
}
