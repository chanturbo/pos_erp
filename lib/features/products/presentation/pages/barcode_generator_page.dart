// lib/features/products/presentation/pages/barcode_generator_page.dart
//
// สร้างและพิมพ์บาร์โค้ดสินค้าหลายรายการในหน้าเดียว — พิมพ์ A4 แนวตั้ง

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import '../../../../shared/pdf/barcode_pdf_builder.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/mobile_home_button.dart';
import '../../data/models/product_model.dart';
import '../providers/product_provider.dart';

// ─────────────────────────────────────────────────────────────────
// Item model — สินค้า 1 รายการในรายการพิมพ์
// ─────────────────────────────────────────────────────────────────
class _BarcodeItem {
  final String id;
  String name;
  String barcodeValue;
  int qty;

  _BarcodeItem({
    required this.id,
    required this.name,
    required this.barcodeValue,
    this.qty = 1,
  });

  _BarcodeItem copyWith({String? name, String? barcodeValue, int? qty}) =>
      _BarcodeItem(
        id: id,
        name: name ?? this.name,
        barcodeValue: barcodeValue ?? this.barcodeValue,
        qty: qty ?? this.qty,
      );
}

// ─────────────────────────────────────────────────────────────────
// BarcodeGeneratorPage
// ─────────────────────────────────────────────────────────────────
class BarcodeGeneratorPage extends ConsumerStatefulWidget {
  const BarcodeGeneratorPage({super.key});

  @override
  ConsumerState<BarcodeGeneratorPage> createState() =>
      _BarcodeGeneratorPageState();
}

class _BarcodeGeneratorPageState extends ConsumerState<BarcodeGeneratorPage> {
  final List<_BarcodeItem> _items = [];
  BarcodePdfType _type          = BarcodePdfType.code128;
  int            _columnsPerRow = 3;
  bool           _isPrinting    = false;

  int get _totalSlips => _items.fold(0, (s, i) => s + i.qty);

  // ── add / remove ─────────────────────────────────────────────
  void _addItem({String name = '', String barcode = ''}) {
    setState(() => _items.add(_BarcodeItem(
          id: UniqueKey().toString(),
          name: name,
          barcodeValue: barcode,
        )));
  }

  void _addFromProduct(ProductModel p) {
    _addItem(name: p.productName, barcode: p.barcode ?? p.productCode);
  }

  void _removeItem(String id) =>
      setState(() => _items.removeWhere((i) => i.id == id));

  void _updateItem(String id, {String? name, String? barcodeValue, int? qty}) {
    setState(() {
      final idx = _items.indexWhere((i) => i.id == id);
      if (idx >= 0) _items[idx] = _items[idx].copyWith(name: name, barcodeValue: barcodeValue, qty: qty);
    });
  }

  // ── validate & print ─────────────────────────────────────────
  Future<void> _print() async {
    if (_items.isEmpty) {
      _snack('ยังไม่มีสินค้าในรายการ', error: true);
      return;
    }
    final invalid = _items.where((i) => i.name.trim().isEmpty || i.barcodeValue.trim().isEmpty).toList();
    if (invalid.isNotEmpty) {
      _snack('กรุณากรอกชื่อสินค้าและค่าบาร์โค้ดให้ครบ', error: true);
      return;
    }
    if (_type == BarcodePdfType.ean13) {
      final bad = _items.where((i) => !RegExp(r'^\d{12,13}$').hasMatch(i.barcodeValue.trim())).toList();
      if (bad.isNotEmpty) {
        _snack('EAN-13 ต้องเป็นตัวเลข 12–13 หลัก (${bad.first.name})', error: true);
        return;
      }
    }

    // สร้าง label list โดย expand ตาม qty ของแต่ละรายการ
    final labels = _items.expand((item) => BarcodePdfBuilder.expand(
          BarcodeLabel(name: item.name.trim(), barcodeValue: item.barcodeValue.trim()),
          item.qty,
        )).toList();

    setState(() => _isPrinting = true);
    try {
      await Printing.layoutPdf(
        onLayout: (_) async {
          final doc = await BarcodePdfBuilder.build(
            labels,
            columnsPerRow: _columnsPerRow,
            type: _type,
          );
          return doc.save();
        },
        name: 'barcodes_${DateTime.now().millisecondsSinceEpoch}',
      );
    } catch (e) {
      if (mounted) _snack('พิมพ์ไม่สำเร็จ: $e', error: true);
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      backgroundColor: error ? Colors.red[700] : null,
    ));
  }

  // ─────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final products = ref.watch(productListProvider).value ?? [];

    return Scaffold(
      appBar: AppBar(
        leading: buildMobileHomeLeading(context),
        title: const Text('สร้างบาร์โค้ดสินค้า'),
        actions: [
          if (_totalSlips > 0)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Center(
                child: Text(
                  'รวม $_totalSlips สลิป',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          if (_isPrinting)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            IconButton(
              icon: const Icon(Icons.print_outlined),
              tooltip: 'พิมพ์ A4',
              onPressed: _items.isEmpty ? null : _print,
            ),
        ],
      ),
      body: Column(
        children: [
          // ── ตั้งค่าการพิมพ์ ──────────────────────────────────
          _PrintSettingsBar(
            type: _type,
            columnsPerRow: _columnsPerRow,
            isDark: isDark,
            onTypeChanged: (t) => setState(() => _type = t),
            onColumnsChanged: (c) => setState(() => _columnsPerRow = c),
          ),

          // ── รายการสินค้า ─────────────────────────────────────
          Expanded(
            child: _items.isEmpty
                ? _EmptyState(onAdd: () => _addItem())
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                    itemCount: _items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _ItemRow(
                      item: _items[i],
                      isDark: isDark,
                      onRemove: () => _removeItem(_items[i].id),
                      onNameChanged: (v) =>
                          _updateItem(_items[i].id, name: v),
                      onBarcodeChanged: (v) =>
                          _updateItem(_items[i].id, barcodeValue: v),
                      onQtyChanged: (v) =>
                          _updateItem(_items[i].id, qty: v),
                    ),
                  ),
          ),
        ],
      ),

      // ── Bottom bar — เพิ่มสินค้า + พิมพ์ ────────────────────
      bottomNavigationBar: _BottomBar(
        products: products,
        totalSlips: _totalSlips,
        isPrinting: _isPrinting,
        hasItems: _items.isNotEmpty,
        onAddManual: () => _addItem(),
        onAddFromProduct: _addFromProduct,
        onPrint: _print,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// _PrintSettingsBar — barcode type + columns
// ─────────────────────────────────────────────────────────────────
class _PrintSettingsBar extends StatelessWidget {
  final BarcodePdfType type;
  final int columnsPerRow;
  final bool isDark;
  final ValueChanged<BarcodePdfType> onTypeChanged;
  final ValueChanged<int> onColumnsChanged;

  const _PrintSettingsBar({
    required this.type,
    required this.columnsPerRow,
    required this.isDark,
    required this.onTypeChanged,
    required this.onColumnsChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade50;
    return Container(
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Wrap(
        spacing: 16,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // barcode type
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('ประเภท: ', style: TextStyle(fontSize: 12,
                  color: isDark ? Colors.white70 : Colors.black54)),
              SegmentedButton<BarcodePdfType>(
                showSelectedIcon: false,
                style: const ButtonStyle(
                  visualDensity: VisualDensity(horizontal: -2, vertical: -2),
                ),
                segments: const [
                  ButtonSegment(value: BarcodePdfType.code128, label: Text('Code128')),
                  ButtonSegment(value: BarcodePdfType.ean13,   label: Text('EAN-13')),
                  ButtonSegment(value: BarcodePdfType.qrCode,  label: Text('QR')),
                ],
                selected: {type},
                onSelectionChanged: (s) => onTypeChanged(s.first),
              ),
            ],
          ),
          // columns
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('คอลัมน์: ', style: TextStyle(fontSize: 12,
                  color: isDark ? Colors.white70 : Colors.black54)),
              SegmentedButton<int>(
                showSelectedIcon: false,
                style: const ButtonStyle(
                  visualDensity: VisualDensity(horizontal: -2, vertical: -2),
                ),
                segments: const [
                  ButtonSegment(value: 2, label: Text('2')),
                  ButtonSegment(value: 3, label: Text('3')),
                  ButtonSegment(value: 4, label: Text('4')),
                ],
                selected: {columnsPerRow},
                onSelectionChanged: (s) => onColumnsChanged(s.first),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// _ItemRow — แถวสินค้า 1 รายการ
// ─────────────────────────────────────────────────────────────────
class _ItemRow extends StatefulWidget {
  final _BarcodeItem item;
  final bool isDark;
  final VoidCallback onRemove;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<String> onBarcodeChanged;
  final ValueChanged<int> onQtyChanged;

  const _ItemRow({
    required this.item,
    required this.isDark,
    required this.onRemove,
    required this.onNameChanged,
    required this.onBarcodeChanged,
    required this.onQtyChanged,
  });

  @override
  State<_ItemRow> createState() => _ItemRowState();
}

class _ItemRowState extends State<_ItemRow> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _barcodeCtrl;
  late final TextEditingController _qtyCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl    = TextEditingController(text: widget.item.name);
    _barcodeCtrl = TextEditingController(text: widget.item.barcodeValue);
    _qtyCtrl     = TextEditingController(text: widget.item.qty.toString());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _barcodeCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  void _stepQty(int delta) {
    final v = int.tryParse(_qtyCtrl.text) ?? 1;
    final next = (v + delta).clamp(1, 999);
    _qtyCtrl.text = next.toString();
    widget.onQtyChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final border = widget.isDark ? Colors.white12 : Colors.black12;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                // ── ชื่อสินค้า ───────────────────────────────
                Expanded(
                  flex: 5,
                  child: TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'ชื่อสินค้า',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: widget.onNameChanged,
                  ),
                ),
                const SizedBox(width: 8),
                // ── บาร์โค้ด ─────────────────────────────────
                Expanded(
                  flex: 4,
                  child: TextField(
                    controller: _barcodeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'ค่าบาร์โค้ด',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: widget.onBarcodeChanged,
                  ),
                ),
                const SizedBox(width: 8),
                // ── จำนวน ────────────────────────────────────
                SizedBox(
                  width: 110,
                  child: Row(
                    children: [
                      _StepBtn(icon: Icons.remove, onTap: () => _stepQty(-1)),
                      Expanded(
                        child: TextField(
                          controller: _qtyCtrl,
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: const InputDecoration(
                            isDense: true,
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(vertical: 10),
                          ),
                          onChanged: (v) {
                            final n = int.tryParse(v);
                            if (n != null && n > 0) widget.onQtyChanged(n);
                          },
                        ),
                      ),
                      _StepBtn(icon: Icons.add, onTap: () => _stepQty(1)),
                    ],
                  ),
                ),
                // ── ลบ ───────────────────────────────────────
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: 'ลบรายการนี้',
                  onPressed: widget.onRemove,
                ),
              ],
            ),
            // label hint
            Padding(
              padding: const EdgeInsets.only(top: 4, right: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.info_outline, size: 11,
                      color: widget.isDark ? Colors.white38 : Colors.black38),
                  const SizedBox(width: 4),
                  Text(
                    'จำนวน ${widget.item.qty} สลิป',
                    style: TextStyle(
                      fontSize: 11,
                      color: widget.isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _StepBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 16),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────
// _EmptyState
// ─────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.qr_code_2_outlined, size: 64,
                color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text('ยังไม่มีสินค้าในรายการ',
                style: TextStyle(fontSize: 15, color: Colors.grey)),
            const SizedBox(height: 4),
            const Text('เพิ่มสินค้าด้านล่างเพื่อเริ่มสร้างบาร์โค้ด',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('เพิ่มรายการแรก'),
            ),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────
// _BottomBar — เพิ่มสินค้า + ปุ่มพิมพ์
// ─────────────────────────────────────────────────────────────────
class _BottomBar extends StatelessWidget {
  final List<ProductModel> products;
  final int totalSlips;
  final bool isPrinting;
  final bool hasItems;
  final VoidCallback onAddManual;
  final ValueChanged<ProductModel> onAddFromProduct;
  final VoidCallback onPrint;

  const _BottomBar({
    required this.products,
    required this.totalSlips,
    required this.isPrinting,
    required this.hasItems,
    required this.onAddManual,
    required this.onAddFromProduct,
    required this.onPrint,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            // เพิ่มจากสินค้าในระบบ
            _AddFromProductBtn(
                products: products, onSelected: onAddFromProduct),
            const SizedBox(width: 8),
            // เพิ่มรายการเอง
            OutlinedButton.icon(
              onPressed: onAddManual,
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('กรอกเอง'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
              ),
            ),
            const Spacer(),
            // พิมพ์
            FilledButton.icon(
              onPressed: (hasItems && !isPrinting) ? onPrint : null,
              icon: isPrinting
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.print_outlined, size: 18),
              label: Text(
                hasItems
                    ? 'พิมพ์ A4 ($totalSlips สลิป)'
                    : 'พิมพ์ A4',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// _AddFromProductBtn — popup เลือกสินค้าจากระบบ
// ─────────────────────────────────────────────────────────────────
class _AddFromProductBtn extends StatefulWidget {
  final List<ProductModel> products;
  final ValueChanged<ProductModel> onSelected;

  const _AddFromProductBtn({
    required this.products,
    required this.onSelected,
  });

  @override
  State<_AddFromProductBtn> createState() => _AddFromProductBtnState();
}

class _AddFromProductBtnState extends State<_AddFromProductBtn> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _show() {
    _searchCtrl.clear();
    setState(() => _query = '');
    showModalBottomSheet<ProductModel>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          builder: (_, sc) => Column(
            children: [
              // handle
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  controller: _searchCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'ค้นหาสินค้า...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (v) => setModal(() => _query = v.toLowerCase()),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  controller: sc,
                  itemCount: _filtered.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final p = _filtered[i];
                    return ListTile(
                      dense: true,
                      leading: const Icon(
                          Icons.inventory_2_outlined, size: 20),
                      title: Text(p.productName,
                          style: const TextStyle(fontSize: 13)),
                      subtitle: Text(
                        '${p.productCode}'
                        '${p.barcode != null ? " • ${p.barcode}" : ""}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        widget.onSelected(p);
                      },
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

  List<ProductModel> get _filtered {
    if (_query.isEmpty) return widget.products;
    return widget.products.where((p) =>
        p.productName.toLowerCase().contains(_query) ||
        p.productCode.toLowerCase().contains(_query) ||
        (p.barcode?.toLowerCase().contains(_query) ?? false)).toList();
  }

  @override
  Widget build(BuildContext context) => FilledButton.tonalIcon(
        onPressed: _show,
        icon: const Icon(Icons.inventory_2_outlined, size: 16),
        label: const Text('เลือกจากสินค้า'),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      );
}
