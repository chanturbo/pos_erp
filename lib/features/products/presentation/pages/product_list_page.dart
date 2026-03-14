import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/product_provider.dart';
import '../../data/models/product_model.dart';
import 'product_form_page.dart';

// ── OAG Identity ─────────────────────────────────────────────────
const _navy    = Color(0xFF16213E);
const _orange  = Color(0xFFE57200);
const _surface = Color(0xFFF4F4F0);
const _border  = Color(0xFFE0E0E0);
const _success = Color(0xFF2E7D32);
const _error   = Color(0xFFC62828);
const _info    = Color(0xFF1565C0);

class ProductListPage extends ConsumerStatefulWidget {
  const ProductListPage({super.key});

  @override
  ConsumerState<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends ConsumerState<ProductListPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool   _isTableView  = true;   // ← default: Table View (compact)
  String _sortColumn   = 'productCode';
  bool   _sortAsc      = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  // Filter + Sort helpers
  // ─────────────────────────────────────────────────────────────
  List<ProductModel> _filter(List<ProductModel> src) {
    if (_searchQuery.isEmpty) return src;
    final q = _searchQuery.toLowerCase();
    return src.where((p) =>
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
            style: ElevatedButton.styleFrom(backgroundColor: _error),
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
      backgroundColor: ok ? _success : _error,
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
      appBar: AppBar(
        title: const Text('จัดการสินค้า'),
        actions: [
          // Toggle view
          Tooltip(
            message: _isTableView ? 'Card View' : 'Table View',
            child: IconButton(
              icon: Icon(_isTableView
                  ? Icons.view_agenda_outlined
                  : Icons.table_rows_outlined),
              onPressed: () => setState(() => _isTableView = !_isTableView),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'รีเฟรช',
            onPressed: () => ref.read(productListProvider.notifier).refresh(),
          ),
        ],
      ),

      body: Column(
        children: [
          // ── Toolbar ─────────────────────────────────────────
          _buildToolbar(productAsync),

          // ── Content ─────────────────────────────────────────
          Expanded(
            child: productAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _buildError(e),
              data: (products) {
                final filtered = _filter(products);
                if (filtered.isEmpty) return _buildEmpty();
                return _isTableView
                    ? _buildTableView(_sort(filtered))
                    : _buildCardView(_sort(filtered));
              },
            ),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _orange,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('เพิ่มสินค้า'),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProductFormPage()),
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Toolbar: Search + Summary chips
  // ─────────────────────────────────────────────────────────────
  Widget _buildToolbar(AsyncValue productAsync) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          SizedBox(
            height: 40,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'ค้นหาชื่อ / รหัส / บาร์โค้ด...',
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),

          // Summary chips
          productAsync.whenOrNull(
                data: (products) {
                  final all      = products as List<ProductModel>;
                  final filtered = _filter(all);
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        _SummaryChip('ทั้งหมด', all.length, _navy),
                        const SizedBox(width: 8),
                        _SummaryChip('กรองแล้ว', filtered.length, _orange),
                        const SizedBox(width: 8),
                        _SummaryChip('Active',
                            all.where((p) => p.isActive).length, _success),
                      ],
                    ),
                  );
                },
              ) ??
              const SizedBox.shrink(),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TABLE VIEW
  // ─────────────────────────────────────────────────────────────
  Widget _buildTableView(List<ProductModel> products) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Header
          Container(
            color: _navy,
            child: Row(
              children: [
                const _HeaderCell('#', width: 48, center: true),
                _SortableHeader('รหัสสินค้า', 'productCode',
                    _sortColumn, _sortAsc, _onSort, flex: 2),
                _SortableHeader('ชื่อสินค้า', 'productName',
                    _sortColumn, _sortAsc, _onSort, flex: 4),
                const _HeaderCell('หน่วย', flex: 1, center: true),
                _SortableHeader('ราคาขาย', 'priceLevel1',
                    _sortColumn, _sortAsc, _onSort,
                    flex: 2, rightAlign: true),
                _SortableHeader('ต้นทุน', 'standardCost',
                    _sortColumn, _sortAsc, _onSort,
                    flex: 2, rightAlign: true),
                const _HeaderCell('สต๊อก', flex: 1, center: true),
                const _HeaderCell('สถานะ', flex: 1, center: true),
                const _HeaderCell('', width: 88),
              ],
            ),
          ),

          // Rows
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: products.length,
            itemBuilder: (_, i) => _ProductTableRow(
              product: products[i],
              no: i + 1,
              isEven: i.isEven,
              onEdit: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ProductFormPage(product: products[i])),
              ),
              onDelete: () => _confirmDelete(products[i]),
            ),
          ),
        ],
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
            side: const BorderSide(color: _border),
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            // Avatar — รหัสย่อแทน CircleAvatar เดิม
            leading: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: _orange.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: _orange.withValues(alpha: 0.25)),
              ),
              child: Center(
                child: Text(
                  p.productCode.length >= 2
                      ? p.productCode.substring(0, 2)
                      : p.productCode,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _orange,
                      fontSize: 13),
                ),
              ),
            ),
            title: Text(p.productName,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: Text(
              'รหัส: ${p.productCode}  ·  หน่วย: ${p.baseUnit}',
              style: const TextStyle(fontSize: 12),
            ),
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
                            color: _info)),
                    _StatusBadge(active: p.isActive),
                  ],
                ),
                const SizedBox(width: 4),
                // Edit button
                IconButton(
                  icon: const Icon(Icons.edit_outlined,
                      size: 18, color: _info),
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
                      size: 18, color: _error),
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
            const Icon(Icons.error_outline, size: 72, color: _error),
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
// _ProductTableRow — แยก widget เพื่อให้ rebuild เฉพาะ row ที่เปลี่ยน
// ════════════════════════════════════════════════════════════════
class _ProductTableRow extends StatelessWidget {
  final ProductModel product;
  final int no;
  final bool isEven;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProductTableRow({
    required this.product,
    required this.no,
    required this.isEven,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final p = product;
    return InkWell(
      onDoubleTap: onEdit,
      hoverColor: _orange.withValues(alpha: 0.05),
      child: Container(
        color: isEven ? Colors.white : _surface,
        child: Row(
          children: [
            // No.
            SizedBox(
              width: 48,
              child: Center(
                child: Text('$no',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey[400])),
              ),
            ),
            // รหัส
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    vertical: 10, horizontal: 8),
                child: Text(p.productCode,
                    style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
              ),
            ),
            // ชื่อ + barcode
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    vertical: 10, horizontal: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.productName,
                        style: const TextStyle(fontSize: 13),
                        overflow: TextOverflow.ellipsis),
                    if (p.barcode != null && p.barcode!.isNotEmpty)
                      Text(p.barcode!,
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey[500])),
                  ],
                ),
              ),
            ),
            // หน่วย
            Expanded(
              flex: 1,
              child: Center(
                  child: Text(p.baseUnit,
                      style: const TextStyle(fontSize: 12))),
            ),
            // ราคาขาย
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text('฿${p.priceLevel1.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _info)),
                ),
              ),
            ),
            // ต้นทุน
            Expanded(
              flex: 2,
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
            // สต๊อก control
            Expanded(
              flex: 1,
              child: Center(
                child: Icon(
                  p.isStockControl ? Icons.inventory_2 : Icons.remove,
                  size: 16,
                  color: p.isStockControl ? _success : Colors.grey[400],
                ),
              ),
            ),
            // สถานะ
            Expanded(
              flex: 1,
              child: Center(child: _StatusBadge(active: p.isActive)),
            ),
            // Actions
            SizedBox(
              width: 88,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ActionIconBtn(
                      icon: Icons.edit_outlined,
                      color: _info,
                      tooltip: 'แก้ไข',
                      onTap: onEdit),
                  _ActionIconBtn(
                      icon: Icons.delete_outline,
                      color: _error,
                      tooltip: 'ลบ',
                      onTap: onDelete),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// Shared Sub-widgets (reused by stock_balance_page if needed)
// ════════════════════════════════════════════════════════════════

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

class _HeaderCell extends StatelessWidget {
  final String label;
  final int flex;
  final double? width;
  final bool center;
  const _HeaderCell(this.label,
      {this.flex = 1, this.width, this.center = false});

  @override
  Widget build(BuildContext context) {
    final text = Text(label,
        style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4));
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: center ? Center(child: text) : text,
    );
    if (width != null) return SizedBox(width: width, child: content);
    return Expanded(flex: flex, child: content);
  }
}

class _SortableHeader extends StatelessWidget {
  final String label;
  final String column;
  final String current;
  final bool ascending;
  final void Function(String) onSort;
  final int flex;
  final bool rightAlign;
  const _SortableHeader(
      this.label, this.column, this.current, this.ascending, this.onSort,
      {this.flex = 1, this.rightAlign = false});

  @override
  Widget build(BuildContext context) {
    final isActive = current == column;
    return Expanded(
      flex: flex,
      child: InkWell(
        onTap: () => onSort(column),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Row(
            mainAxisAlignment: rightAlign
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      color: isActive
                          ? const Color(0xFFFF9D45)
                          : Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4)),
              const SizedBox(width: 4),
              Icon(
                isActive
                    ? (ascending
                        ? Icons.arrow_upward
                        : Icons.arrow_downward)
                    : Icons.unfold_more,
                size: 13,
                color: isActive
                    ? const Color(0xFFFF9D45)
                    : Colors.white38,
              ),
            ],
          ),
        ),
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