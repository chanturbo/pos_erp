import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_erp/shared/theme/app_theme.dart';
import '../providers/product_provider.dart';
import '../../data/models/product_model.dart';
import 'product_form_page.dart';
import 'product_pdf_report.dart'; // ✅ PDF report
import '../../../../shared/pdf/pdf_report_button.dart';


class ProductListPage extends ConsumerStatefulWidget {
  const ProductListPage({super.key});

  @override
  ConsumerState<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends ConsumerState<ProductListPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool   _isTableView   = true;
  bool   _isActiveOnly  = false; // filter เฉพาะสินค้าที่ใช้งาน
  bool   _userResized   = false; // ✅ ป้องกัน auto-adjust override ค่าที่ user ลากไว้
  String _sortColumn   = 'productCode';
  bool   _sortAsc      = true;

  // ✅ ความกว้างคอลัมน์ที่ resize ได้ (ค่าเริ่มต้นก่อน auto-fit)
  // ลำดับ: [รหัส, ชื่อ, หน่วย, ราคา, ต้นทุน, สต๊อก, สถานะ, จัดการ]
  final List<double> _colWidths = [90, 200, 60, 90, 80, 56, 72, 88];
  static const List<double> _colMinW  = [80, 140, 60, 80, 80, 50, 60, 88];
  static const List<double> _colMaxW  = [220, 500, 140, 180, 180, 100, 120, 88];

  // ✅ ScrollControllers สำหรับแสดง scrollbar
  final _hScroll = ScrollController();

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
    return result.where((p) =>
        p.productName.toLowerCase().contains(q) ||
        p.productCode.toLowerCase().contains(q) ||
        (p.barcode?.toLowerCase().contains(q) ?? false)).toList();
  }

  List<ProductModel> _sort(List<ProductModel> src) {
    final list = List<ProductModel>.from(src);
    list.sort((a, b) {
      int c;
      switch (_sortColumn) {
        case 'productCode':  c = a.productCode.compareTo(b.productCode); break;
        case 'productName':  c = a.productName.compareTo(b.productName); break;
        case 'priceLevel1':  c = a.priceLevel1.compareTo(b.priceLevel1); break;
        case 'standardCost': c = a.standardCost.compareTo(b.standardCost); break;
        default: c = 0;
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
    });
  }

  // ─────────────────────────────────────────────────────────────
  // Delete — ใช้ pattern เดียวกับไฟล์ที่แนบมา
  // ─────────────────────────────────────────────────────────────
  Future<void> _confirmDelete(ProductModel product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: Text('ต้องการลบสินค้า "${product.productName}" ใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final ok = await ref
        .read(productListProvider.notifier)
        .deleteProduct(product.productId);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? 'ลบสินค้าสำเร็จ' : 'ลบสินค้าไม่สำเร็จ'),
      backgroundColor: ok ? AppTheme.success : AppTheme.error,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ─────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final productAsync = ref.watch(productListProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          // ── Top Bar (เหมือน customer_list_page) ────────────
          _ProductListTopBar(
            searchController: _searchController,
            searchQuery: _searchQuery,
            isActiveOnly: _isActiveOnly,
            isTableView: _isTableView,
            onSearchChanged: (v) => setState(() => _searchQuery = v),
            onSearchCleared: () {
              _searchController.clear();
              setState(() => _searchQuery = '');
            },
            onToggleActive: () =>
                setState(() => _isActiveOnly = !_isActiveOnly),
            onToggleView: () =>
                setState(() => _isTableView = !_isTableView),
            onRefresh: () =>
                ref.read(productListProvider.notifier).refresh(),
            onAdd: () async {
              await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ProductFormPage()));
            },
          ),

          // ── Summary chips ────────────────────────────────────
          _buildSummaryBar(productAsync),

          // ── Content ─────────────────────────────────────────
          Expanded(
            child: productAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _buildError(e),
              data: (products) {
                final filtered = _filter(products);
                if (filtered.isEmpty) return _buildEmpty();
                return Stack(
                  children: [
                    _isTableView
                        ? _buildTableView(_sort(filtered))
                        : _buildCardView(_sort(filtered)),
                    // ปุ่ม PDF
                    Positioned(
                      bottom: 16,
                      right: 16,
                      child: PdfReportButton(
                        emptyMessage: 'ไม่มีข้อมูลสินค้า',
                        title:    'รายงานสินค้า',
                        filename: () => PdfFilename.generate('product_report'),
                        buildPdf: () => ProductPdfBuilder.build(filtered),
                        hasData:  filtered.isNotEmpty,
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
  // Summary Bar — แถว chips สรุปจำนวน
  // ─────────────────────────────────────────────────────────────
  Widget _buildSummaryBar(AsyncValue productAsync) {
    return productAsync.maybeWhen(
      data: (products) {
        final all      = products as List<ProductModel>;
        final filtered = _filter(all);
        return Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Row(
            children: [
              _SummaryChip('ทั้งหมด', all.length, AppTheme.navy),
              const SizedBox(width: 8),
              _SummaryChip('กรองแล้ว', filtered.length, AppTheme.primaryDark),
              const SizedBox(width: 8),
              _SummaryChip('ใช้งาน',
                  all.where((p) => p.isActive).length, AppTheme.success),
              const SizedBox(width: 8),
              _SummaryChip('ปิดใช้',
                  all.where((p) => !p.isActive).length, AppTheme.error),
            ],
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
  void _autoFitColWidths(List<ProductModel> rows, double screenW) {
    // ── Header minimum widths (hardcoded จากการวัดจริง) ───────────
    // วัดจาก NotoSansThai fontSize=12, w600
    // = label width + padding(16) + sort icon(16) [เฉพาะคอลัมน์ที่ sort ได้]
    // [รหัสสินค้า, ชื่อสินค้า, หน่วย, ราคาขาย, ต้นทุน, สต๊อก, สถานะ, จัดการ]
    const headerMinW = [112.0, 112.0, 60.0, 96.0, 84.0, 58.0, 62.0, 88.0];
    //  รหัสสินค้า: 10 Thai + sort = ~112
    //  ชื่อสินค้า: 10 Thai + sort = ~112
    //  หน่วย:      5 Thai         = ~60
    //  ราคาขาย:   7 Thai + sort  = ~96   ← ปัญหาเดิม ต้องไม่ต่ำกว่านี้
    //  ต้นทุน:    6 Thai + sort  = ~84
    //  สต๊อก:     5 Thai         = ~58
    //  สถานะ:     5 Thai         = ~62
    //  จัดการ:    6 Thai (no sort)= ~88 (ตรงกับ colMinW)

    // เริ่มต้น maxW = headerMinW — content ย่อต่ำกว่านี้ไม่ได้
    final maxW = List<double>.from(headerMinW);

    // ── Content widths ────────────────────────────────────────────
    const codeCharW = 7.8;  // monospace fontSize 13
    const nameCharW = 7.2;  // regular fontSize 13
    const unitCharW = 7.2;
    const numCharW  = 7.4;  // ตัวเลข
    const cPad      = 20.0; // horizontal padding ต่อ cell

    for (final p in rows) {
      final codeW  = p.productCode.length * codeCharW + cPad;
      final nameW  = p.productName.length * nameCharW + cPad;
      final unitW  = p.baseUnit.length * unitCharW + cPad;
      final priceW = '฿${p.priceLevel1.toStringAsFixed(2)}'.length * numCharW + cPad;
      final costW  = '฿${p.standardCost.toStringAsFixed(2)}'.length * numCharW + cPad;

      if (codeW  > maxW[0]) maxW[0] = codeW;
      if (nameW  > maxW[1]) maxW[1] = nameW;
      if (unitW  > maxW[2]) maxW[2] = unitW;
      if (priceW > maxW[3]) maxW[3] = priceW;
      if (costW  > maxW[4]) maxW[4] = costW;
      // [5] สต๊อก, [6] สถานะ, [7] จัดการ — ไม่มี text content → headerMinW เป็น floor อยู่แล้ว
    }

    // ── Clamp: floor = max(headerMinW, colMinW), ceil = colMaxW ───
    for (int i = 0; i < maxW.length; i++) {
      final floor = headerMinW[i] > _colMinW[i] ? headerMinW[i] : _colMinW[i];
      maxW[i] = maxW[i].clamp(floor, _colMaxW[i]);
    }

    // กระจาย space ที่เหลือให้คอลัมน์ชื่อ (index 1)
    const totalFixed = 76.0; // No.(48) + reset(28)
    final totalCols  = maxW.fold(0.0, (s, w) => s + w);
    final available  = screenW - totalFixed;
    if (totalCols < available) {
      final floor1 = headerMinW[1] > _colMinW[1] ? headerMinW[1] : _colMinW[1];
      maxW[1] = (maxW[1] + (available - totalCols)).clamp(floor1, _colMaxW[1]);
    }

    for (int i = 0; i < _colWidths.length; i++) {
      _colWidths[i] = maxW[i];
    }
  }

  Widget _buildTableView(List<ProductModel> products) {
    // ✅ Auto-fit colWidths ตามเนื้อหา เฉพาะครั้งแรก / ยังไม่ resize
    final screenW = MediaQuery.of(context).size.width;
    if (!_userResized) _autoFitColWidths(products, screenW);

    final totalW = 48.0 +
        _colWidths.fold(0.0, (s, w) => s + w) +
        28.0;
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
                _colWidths.setAll(0, [90, 200, 60, 90, 80, 56, 72, 88]);
                _userResized = false; // ✅ reset → auto-fit ทำงานอีกครั้ง
              }),
            ),
            // Rows — shrinkWrap ได้เพราะ Column รู้ขนาดจาก SizedBox แล้ว
            Expanded(
              child: ListView.builder(
                itemCount: products.length,
                itemBuilder: (_, i) => _ProductTableRow(
                  product: products[i],
                  no: i + 1,
                  isEven: i.isEven,
                  colWidths: _colWidths,
                  onEdit: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => ProductFormPage(product: products[i])),
                  ),
                  onDelete: () => _confirmDelete(products[i]),
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
  Widget _buildCardView(List<ProductModel> products) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: products.length,
      itemBuilder: (_, i) {
        final p = products[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: AppTheme.border),
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            // Avatar — รหัสย่อแทน CircleAvatar เดิม
            leading: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: AppTheme.primaryDark.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppTheme.primaryDark.withValues(alpha: 0.25)),
              ),
              child: Center(
                child: Text(
                  p.productCode.length >= 2
                      ? p.productCode.substring(0, 2)
                      : p.productCode,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryDark,
                      fontSize: 13),
                ),
              ),
            ),
            title: Text(p.productName,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A))), // ✅ เข้มเสมอ
            subtitle: Text(
              'รหัส: ${p.productCode}  ·  หน่วย: ${p.baseUnit}',
              style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF666666))), // ✅ เข้มเสมอ
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ราคา + สถานะ
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('฿${p.priceLevel1.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.info)),
                    _StatusBadge(active: p.isActive),
                  ],
                ),
                const SizedBox(width: 4),
                // Edit button
                IconButton(
                  icon: const Icon(Icons.edit_outlined,
                      size: 18, color: AppTheme.info),
                  tooltip: 'แก้ไข',
                  constraints:
                      const BoxConstraints(minWidth: 36, minHeight: 36),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => ProductFormPage(product: p)),
                  ),
                ),
                // Delete button
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 18, color: AppTheme.error),
                  tooltip: 'ลบ',
                  constraints:
                      const BoxConstraints(minWidth: 36, minHeight: 36),
                  onPressed: () => _confirmDelete(p),
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
  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchQuery.isEmpty
                  ? Icons.inventory_2_outlined
                  : Icons.search_off_outlined,
              size: 72,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isEmpty
                  ? 'ยังไม่มีสินค้า'
                  : 'ไม่พบสินค้า "$_searchQuery"',
              style: TextStyle(color: Colors.grey[500]),
            ),
            if (_searchQuery.isEmpty) ...[
              const SizedBox(height: 4),
              Text('กดปุ่ม + เพื่อเพิ่มสินค้าใหม่',
                  style: TextStyle(fontSize: 12, color: Colors.grey[400])),
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

  Widget _buildError(Object e) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 72, color: AppTheme.error),
            const SizedBox(height: 12),
            Text('เกิดข้อผิดพลาด: $e'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () =>
                  ref.read(productListProvider.notifier).refresh(),
              child: const Text('ลองใหม่'),
            ),
          ],
        ),
      );
}

// ════════════════════════════════════════════════════════════════
// _ProductListTopBar — responsive top bar (เหมือน customer_list)
// ════════════════════════════════════════════════════════════════
class _ProductListTopBar extends StatelessWidget {
  final TextEditingController searchController;
  final String searchQuery;
  final bool isActiveOnly;
  final bool isTableView;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchCleared;
  final VoidCallback onToggleActive;
  final VoidCallback onToggleView;
  final VoidCallback onRefresh;
  final VoidCallback onAdd;

  const _ProductListTopBar({
    required this.searchController,
    required this.searchQuery,
    required this.isActiveOnly,
    required this.isTableView,
    required this.onSearchChanged,
    required this.onSearchCleared,
    required this.onToggleActive,
    required this.onToggleView,
    required this.onRefresh,
    required this.onAdd,
  });

  static const _kBreak = 720.0;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= _kBreak;
    final canPop = Navigator.of(context).canPop();

    return Container(
      color: Colors.white,
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
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A)),
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
        _PAddBtn(onTap: onAdd),
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
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A)),
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
            _PAddBtn(onTap: onAdd, compact: true),
          ],
        ),
        const SizedBox(height: 10),
        _PSearchField(
          controller: searchController,
          query: searchQuery,
          onChanged: onSearchChanged,
          onCleared: onSearchCleared,
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
          child: const Icon(Icons.arrow_back_ios_new,
              size: 15, color: Color(0xFF8A8A8A)),
        ),
      );
}

class _PPageIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: AppTheme.primaryLight,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.inventory_2_outlined,
            color: AppTheme.primary, size: 18),
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
        height: 38,
        child: TextField(
          controller: controller,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: 'ค้นหาชื่อ / รหัส / บาร์โค้ด...',
            hintStyle:
                const TextStyle(fontSize: 13, color: Color(0xFF8A8A8A)),
            prefixIcon: const Icon(Icons.search,
                size: 17, color: Color(0xFF8A8A8A)),
            suffixIcon: query.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 15),
                    onPressed: onCleared,
                  )
                : null,
            contentPadding: EdgeInsets.zero,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: AppTheme.primary, width: 1.5)),
            filled: true,
            fillColor: Colors.white,
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
                  : const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: active ? activeColor : AppTheme.border),
            ),
            child: Icon(icon,
                size: 17,
                color: active ? activeColor : const Color(0xFF8A8A8A)),
          ),
        ),
      );
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
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.border),
            ),
            child: const Icon(Icons.refresh,
                size: 17, color: Color(0xFF8A8A8A)),
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
            : const Text('เพิ่มสินค้า',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(
              horizontal: compact ? 12 : 18, vertical: 13),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
      );
}

// ════════════════════════════════════════════════════════════════
// _ProductTableRow — แยก widget เพื่อให้ rebuild เฉพาะ row ที่เปลี่ยน
// ════════════════════════════════════════════════════════════════
class _ProductTableRow extends StatefulWidget {
  final ProductModel product;
  final int no;
  final bool isEven;
  final List<double> colWidths; // ✅ รับ width จาก parent
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProductTableRow({
    required this.product,
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
    // ── สีที่คงที่ไม่ขึ้นกับ dark mode ─────────────────────────
    // Table/Card ใช้พื้นหลังขาว → ตัวหนังสือต้องเข้มเสมอ
    const nameColor = Color(0xFF1A1A1A);
    const codeColor = Color(0xFF555555);

    final w = widget.colWidths;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onDoubleTap: widget.onEdit,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          color: _hovered
              ? AppTheme.primaryLight
              : (widget.isEven ? Colors.white : const Color(0xFFF9F9F7)),
          child: Row(
            children: [
            // No. (fixed)
            SizedBox(
              width: 48,
              child: Center(
                child: Text('${widget.no}',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFFBBBBBB))),
              ),
            ),
            // รหัส — w[0]
            SizedBox(
              width: w[0],
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    vertical: 10, horizontal: 8),
                child: Text(p.productCode,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: codeColor)),
              ),
            ),
            // ชื่อ + barcode — w[1]
            SizedBox(
              width: w[1],
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    vertical: 10, horizontal: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.productName,
                        style: const TextStyle(
                            fontSize: 13, color: nameColor),
                        overflow: TextOverflow.ellipsis),
                    if (p.barcode != null && p.barcode!.isNotEmpty)
                      Text(p.barcode!,
                          style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF999999))),
                  ],
                ),
              ),
            ),
            // หน่วย — w[2]
            SizedBox(
              width: w[2],
              child: Center(
                  child: Text(p.baseUnit,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF1A1A1A)))),
            ),
            // ราคาขาย — w[3]
            SizedBox(
              width: w[3],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text('฿${p.priceLevel1.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.info)),
                ),
              ),
            ),
            // ต้นทุน — w[4]
            SizedBox(
              width: w[4],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text('฿${p.standardCost.toStringAsFixed(2)}',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[600])),
                ),
              ),
            ),
            // สต๊อก — w[5]
            SizedBox(
              width: w[5],
              child: Center(
                child: Icon(
                  p.isStockControl ? Icons.inventory_2 : Icons.remove,
                  size: 16,
                  color: p.isStockControl ? AppTheme.success : Colors.grey[400],
                ),
              ),
            ),
            // สถานะ — w[6]
            SizedBox(
              width: w[6],
              child: Center(child: _StatusBadge(active: p.isActive)),
            ),
            // Actions — w[7] fixed
            SizedBox(
              width: w[7],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ActionIconBtn(
                      icon: Icons.edit_outlined,
                      color: AppTheme.info,
                      tooltip: 'แก้ไข',
                      onTap: widget.onEdit),
                  _ActionIconBtn(
                      icon: Icons.delete_outline,
                      color: AppTheme.error,
                      tooltip: 'ลบ',
                      onTap: widget.onDelete),
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
    ('หน่วย', ''),
    ('ราคาขาย', 'priceLevel1'),
    ('ต้นทุน', 'standardCost'),
    ('สต๊อก', ''),
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
      color: AppTheme.navy,
      child: Row(
        children: [
          // No. fixed
          const SizedBox(
            width: 48,
            child: Center(
              child: Text('#',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
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
                final newW = (colWidths[i] + delta)
                    .clamp(colMinW[i], colMaxW[i]);
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
                child: Icon(Icons.settings_backup_restore,
                    size: 14, color: Colors.white38),
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

  @override
  Widget build(BuildContext context) {
    final labelColor =
        widget.isActive ? const Color(0xFFFF9D45) : Colors.white70;

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
                    vertical: 10, horizontal: 8),
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
                            letterSpacing: 0.4),
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
                      const Icon(Icons.unfold_more,
                          size: 12, color: Colors.white38),
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
              onExit: (_) => setState(() => _hovering = false),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragUpdate: (d) =>
                    widget.onResize(d.delta.dx),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: 8,
                  height: 28,
                  alignment: Alignment.center,
                  child: Container(
                    width: 2,
                    height: _hovering ? 20 : 12,
                    decoration: BoxDecoration(
                      color: _hovering
                          ? const Color(0xFFFF9D45)
                          : Colors.white24,
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
        padding:
            const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFFB9F6CA)
              : const Color(0xFFFFCDD2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          active ? 'ใช้งาน' : 'ปิด',
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: active
                  ? const Color(0xFF1B5E20)
                  : const Color(0xFFB71C1C)),
        ),
      );
}

class _ActionIconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  const _ActionIconBtn(
      {required this.icon,
      required this.color,
      required this.tooltip,
      required this.onTap});

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: IconButton(
          icon: Icon(icon, size: 18, color: color),
          constraints:
              const BoxConstraints(minWidth: 36, minHeight: 36),
          onPressed: onTap,
        ),
      );
}


class _SummaryChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _SummaryChip(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: color)),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8)),
              child: Text('$count',
                  style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
}