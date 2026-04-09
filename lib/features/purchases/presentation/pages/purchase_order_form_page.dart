import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pos_erp/shared/theme/app_theme.dart';
import 'package:pos_erp/shared/utils/responsive_utils.dart';
import 'package:pos_erp/shared/widgets/app_dialogs.dart';
import 'package:pos_erp/shared/widgets/escape_pop_scope.dart';
import 'package:pos_erp/shared/widgets/mobile_home_button.dart';
import '../../data/models/purchase_order_model.dart';
import '../../data/models/purchase_order_item_model.dart';
import '../providers/purchase_provider.dart';
import '../../../suppliers/presentation/providers/supplier_provider.dart';
import '../../../products/data/models/product_model.dart';
import '../../../products/presentation/providers/product_provider.dart';
import '../../../inventory/presentation/providers/stock_provider.dart';
import '../../../../../shared/services/mobile_scanner_service.dart';

class PurchaseOrderFormPage extends ConsumerStatefulWidget {
  final PurchaseOrderModel? order;
  const PurchaseOrderFormPage({super.key, this.order});

  @override
  ConsumerState<PurchaseOrderFormPage> createState() =>
      _PurchaseOrderFormPageState();
}

class _PurchaseOrderFormPageState extends ConsumerState<PurchaseOrderFormPage> {
  final _formKey = GlobalKey<FormState>();

  DateTime _poDate = DateTime.now();
  String? _supplierId;
  String? _supplierName;
  String _warehouseId = 'WH001';
  String _warehouseName = 'คลังสาขาหลัก';
  String? _remark;
  final _remarkController = TextEditingController();

  final List<PurchaseOrderItemModel> _items = [];
  bool _isLoading = false;
  bool _isLoadingItems = false;
  bool _isCardView = false;
  bool _includeVat = false; // toggle VAT 7%

  @override
  void initState() {
    super.initState();
    if (widget.order != null) {
      _loadOrderHeaderData();
      // fetch full details (with items) from API
      WidgetsBinding.instance.addPostFrameCallback((_) => _fetchOrderItems());
    }
  }

  /// โหลด header data ทันที (ไม่ต้องรอ API)
  void _loadOrderHeaderData() {
    final order = widget.order!;
    _poDate = order.poDate;
    _supplierId = order.supplierId;
    _supplierName = order.supplierName;
    _remark = order.remark;
    _remarkController.text = order.remark ?? '';
    // ถ้า order มี items มาแล้ว (จาก navigate with full data)
    if (order.items != null && order.items!.isNotEmpty) {
      _items.addAll(order.items!);
    }
  }

  /// fetch รายการสินค้าจาก API (items มักไม่มาใน list endpoint)
  Future<void> _fetchOrderItems() async {
    if (!mounted) return;
    setState(() => _isLoadingItems = true);
    final poId = widget.order!.poId;
    final notifier = ref.read(purchaseListProvider.notifier);
    final fullOrder = await notifier.getPurchaseOrderDetails(poId);
    if (!mounted) return;
    setState(() {
      _isLoadingItems = false;
      if (fullOrder?.items != null && fullOrder!.items!.isNotEmpty) {
        _items.clear();
        _items.addAll(fullOrder.items!);
      }
    });
  }

  @override
  void dispose() {
    _remarkController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isEdit = widget.order != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Preload products so the dialog opens immediately on first tap
    ref.watch(productListProvider);

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : const Color(0xFFF5F5F5),
      body: EscapePopScope(
        child: Column(
          children: [
            // ── Title Bar ─────────────────────────────────────────
            _POFormTitleBar(isEdit: isEdit),

            // ── Form Body ─────────────────────────────────────────
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Section 1 — ข้อมูลทั่วไป
                      _SectionCard(
                        icon: Icons.receipt_long_outlined,
                        iconColor: AppTheme.primaryDark,
                        title: 'ข้อมูลทั่วไป',
                        child: _buildGeneralSection(),
                      ),
                      const SizedBox(height: 14),

                      // Section 2 — รายการสินค้า
                      _SectionCard(
                        icon: Icons.shopping_cart_outlined,
                        iconColor: AppTheme.info,
                        title: 'รายการสินค้า',
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Toggle card/list
                            _SmallIconBtn(
                              icon: _isCardView
                                  ? Icons.view_list_outlined
                                  : Icons.grid_view_outlined,
                              tooltip: _isCardView ? 'List View' : 'Card View',
                              isDark: isDark,
                              onTap: () =>
                                  setState(() => _isCardView = !_isCardView),
                            ),
                            const SizedBox(width: 6),
                            // Add item
                            ElevatedButton.icon(
                              onPressed: _addItem,
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text(
                                'เพิ่ม',
                                style: TextStyle(fontSize: 13),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.info,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 14,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ],
                        ),
                        child: _buildItemsSection(),
                      ),
                      const SizedBox(height: 14),

                      // Section 3 — สรุปยอด (เมื่อมีรายการ)
                      if (_items.isNotEmpty) ...[
                        _SectionCard(
                          icon: Icons.calculate_outlined,
                          iconColor: AppTheme.success,
                          title: 'สรุปยอด',
                          child: _buildSummarySection(),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Section 4 — หมายเหตุ
                      _SectionCard(
                        icon: Icons.note_outlined,
                        iconColor: AppTheme.textSub,
                        title: 'หมายเหตุ',
                        child: _POTextField(
                          controller: _remarkController,
                          hint: 'บันทึกเพิ่มเติม (ถ้ามี)',
                          icon: Icons.edit_note,
                          maxLines: 3,
                          isDark: isDark,
                          onChanged: (v) => _remark = v,
                        ),
                      ),
                      const SizedBox(height: 80), // pad for bottom bar
                    ],
                  ),
                ),
              ),
            ),

            // ── Bottom Action Bar ─────────────────────────────────
            Container(
              color: isDark ? AppTheme.darkTopBar : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      side: BorderSide(
                        color: isDark ? Colors.white24 : AppTheme.border,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'ยกเลิก',
                      style: TextStyle(
                        color: isDark ? Colors.white60 : AppTheme.textSub,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _savePurchaseOrder,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_outlined, size: 18),
                    label: Text(
                      isEdit ? 'บันทึก' : 'สร้างใบสั่งซื้อ',
                      style: const TextStyle(fontSize: 14),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
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

  // ─────────────────────────────────────────────────────────────
  // General Section
  // ─────────────────────────────────────────────────────────────
  Widget _buildGeneralSection() {
    final suppliersAsync = ref.watch(supplierListProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // วันที่ PO
        _POFieldLabel(label: 'วันที่ใบสั่งซื้อ', isDark: isDark),
        const SizedBox(height: 6),
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: _poDate,
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
            );
            if (date != null) setState(() => _poDate = date);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkElement : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? Colors.white24 : AppTheme.border,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 17,
                  color: isDark ? Colors.white54 : AppTheme.textSub,
                ),
                const SizedBox(width: 8),
                Text(
                  DateFormat('dd/MM/yyyy').format(_poDate),
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: isDark ? Colors.white38 : AppTheme.textSub,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // ซัพพลายเออร์
        _POFieldLabel(label: 'ซัพพลายเออร์ *', isDark: isDark),
        const SizedBox(height: 6),
        suppliersAsync.when(
          data: (suppliers) => _PODropdown<String>(
            value: _supplierId,
            hint: 'เลือกซัพพลายเออร์',
            icon: Icons.business_outlined,
            isDark: isDark,
            items: suppliers
                .map(
                  (s) => DropdownMenuItem(
                    value: s.supplierId,
                    child: Text(
                      s.supplierName,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) {
              final s = suppliers.firstWhere((s) => s.supplierId == v);
              setState(() {
                _supplierId = v;
                _supplierName = s.supplierName;
              });
            },
            validator: (v) => v == null ? 'กรุณาเลือกซัพพลายเออร์' : null,
          ),
          loading: () => LinearProgressIndicator(
            color: AppTheme.primary,
            backgroundColor: isDark ? AppTheme.darkElement : AppTheme.border,
          ),
          error: (_, _) => Text(
            'โหลดซัพพลายเออร์ไม่สำเร็จ',
            style: TextStyle(color: AppTheme.error, fontSize: 12),
          ),
        ),
        const SizedBox(height: 14),

        // คลังสินค้าเริ่มต้น (dropdown)
        _POFieldLabel(label: 'คลังสินค้าเริ่มต้น *', isDark: isDark),
        const SizedBox(height: 6),
        ref
            .watch(stockBalanceProvider)
            .when(
              data: (stocks) {
                // unique warehouses from stock balance
                final seen = <String>{};
                final warehouses = stocks
                    .where((s) => seen.add(s.warehouseId))
                    .map((s) => {'id': s.warehouseId, 'name': s.warehouseName})
                    .toList();
                if (warehouses.isEmpty) {
                  warehouses.add({'id': 'WH001', 'name': 'คลังสาขาหลัก'});
                }
                return _PODropdown<String>(
                  value: _warehouseId,
                  hint: 'เลือกคลังสินค้า',
                  icon: Icons.warehouse_outlined,
                  isDark: isDark,
                  items: warehouses
                      .map(
                        (w) => DropdownMenuItem(
                          value: w['id'],
                          child: Text(
                            w['name']!,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    final w = warehouses.firstWhere((w) => w['id'] == v);
                    setState(() {
                      _warehouseId = v!;
                      _warehouseName = w['name']!;
                    });
                  },
                );
              },
              loading: () => LinearProgressIndicator(
                color: AppTheme.primary,
                backgroundColor: isDark
                    ? AppTheme.darkElement
                    : AppTheme.border,
              ),
              error: (_, _) => _PODropdown<String>(
                value: _warehouseId,
                hint: 'คลังสินค้า',
                icon: Icons.warehouse_outlined,
                isDark: isDark,
                items: [
                  DropdownMenuItem(
                    value: 'WH001',
                    child: Text(
                      'คลังสาขาหลัก',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ],
                onChanged: (v) {},
              ),
            ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Items Section
  // ─────────────────────────────────────────────────────────────
  Widget _buildItemsSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoadingItems) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.add_shopping_cart_outlined,
                size: 48,
                color: isDark ? const Color(0xFF444444) : Colors.grey[300],
              ),
              const SizedBox(height: 8),
              Text(
                'ยังไม่มีรายการสินค้า\nกดปุ่ม "เพิ่ม" เพื่อเพิ่มสินค้า',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? const Color(0xFF888888) : Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: _items.asMap().entries.map((entry) {
        final i = entry.key;
        final item = entry.value;
        return _isCardView
            ? _buildItemCard(item, i, isDark)
            : _buildItemRow(item, i, isDark);
      }).toList(),
    );
  }

  // Card view item
  Widget _buildItemCard(PurchaseOrderItemModel item, int index, bool isDark) {
    final fmt = NumberFormat('#,##0.00', 'th_TH');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkElement : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? Colors.white12 : AppTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.info.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.inventory_2_outlined,
                    size: 16,
                    color: AppTheme.info,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.productName ?? '-',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.productCode ?? '',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white54 : AppTheme.textSub,
                        ),
                      ),
                    ],
                  ),
                ),
                // Delete
                InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => setState(() => _items.removeAt(index)),
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.delete_outline,
                      size: 16,
                      color: AppTheme.error,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Divider(
              height: 1,
              color: isDark ? Colors.white12 : AppTheme.border,
            ),
            const SizedBox(height: 10),
            // ข้อมูลจำนวน ราคา รวม
            Row(
              children: [
                Expanded(
                  child: _ItemStat(
                    label: 'จำนวน',
                    value:
                        '${item.quantity.toStringAsFixed(0)} ${item.unit ?? ''}',
                    isDark: isDark,
                  ),
                ),
                Expanded(
                  child: _ItemStat(
                    label: 'ราคา/หน่วย',
                    value: '฿${fmt.format(item.unitPrice)}',
                    isDark: isDark,
                  ),
                ),
                Expanded(
                  child: _ItemStat(
                    label: 'รวม',
                    value: '฿${fmt.format(item.amount)}',
                    isDark: isDark,
                    highlight: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // List view item (compact)
  Widget _buildItemRow(PurchaseOrderItemModel item, int index, bool isDark) {
    final fmt = NumberFormat('#,##0.00', 'th_TH');
    final isEven = index.isEven;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: isEven
            ? (isDark ? AppTheme.darkElement : const Color(0xFFF9FAFB))
            : (isDark ? AppTheme.darkCard : Colors.white),
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white12 : AppTheme.border,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // No.
          SizedBox(
            width: 24,
            child: Text(
              '${index + 1}',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white38 : AppTheme.textSub,
              ),
            ),
          ),
          // Name + Code
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName ?? '-',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  item.productCode ?? '',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.white54 : AppTheme.textSub,
                  ),
                ),
              ],
            ),
          ),
          // Qty
          SizedBox(
            width: 50,
            child: Text(
              '${item.quantity.toStringAsFixed(0)} ${item.unit ?? ''}',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          // Amount
          SizedBox(
            width: 80,
            child: Text(
              '฿${fmt.format(item.amount)}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.info,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 4),
          // Delete
          InkWell(
            borderRadius: BorderRadius.circular(4),
            onTap: () => setState(() => _items.removeAt(index)),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.close,
                size: 15,
                color: isDark ? Colors.white38 : AppTheme.textSub,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Summary Section
  // ─────────────────────────────────────────────────────────────
  Widget _buildSummarySection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtotal = _items.fold<double>(0, (s, item) => s + item.amount);
    final vat = _includeVat ? subtotal * 0.07 : 0.0;
    final total = subtotal + vat;
    final fmt = NumberFormat('#,##0.00', 'th_TH');

    return Column(
      children: [
        // ── VAT Toggle ──────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'คิด VAT 7%',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white70 : AppTheme.textSub,
              ),
            ),
            Switch.adaptive(
              value: _includeVat,
              activeThumbColor: AppTheme.info,
              activeTrackColor: AppTheme.info.withValues(alpha: 0.4),
              onChanged: (v) => setState(() => _includeVat = v),
            ),
          ],
        ),
        _SummaryRow(
          label: 'ยอดรวมก่อน VAT',
          value: '฿${fmt.format(subtotal)}',
          isDark: isDark,
        ),
        const SizedBox(height: 8),
        _SummaryRow(
          label: 'VAT 7%',
          value: '฿${fmt.format(vat)}',
          isDark: isDark,
        ),
        Divider(height: 20, color: isDark ? Colors.white12 : AppTheme.border),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'ยอดรวมทั้งสิ้น',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1A1A1A),
              ),
            ),
            Text(
              '฿${fmt.format(total)}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.info,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Add Item
  // ─────────────────────────────────────────────────────────────
  Future<void> _addItem() async {
    final products = ref.read(productListProvider).value;
    if (products == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กำลังโหลดข้อมูลสินค้า...'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _ProductSelectionDialog(products: products),
    );
    if (result != null) {
      setState(() {
        _items.add(result['item'] as PurchaseOrderItemModel);
      });
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Save
  // ─────────────────────────────────────────────────────────────
  Future<void> _savePurchaseOrder() async {
    if (!_formKey.currentState!.validate()) return;

    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณาเพิ่มรายการสินค้าอย่างน้อย 1 รายการ'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final subtotal = _items.fold<double>(0, (s, item) => s + item.amount);
    final vat = _includeVat ? subtotal * 0.07 : 0.0;
    final total = subtotal + vat;

    final order = PurchaseOrderModel(
      poId: widget.order?.poId ?? '',
      poNo: widget.order?.poNo ?? '',
      poDate: _poDate,
      supplierId: _supplierId!,
      warehouseId: _warehouseId,
      userId: 'USR001',
      subtotal: subtotal,
      discountAmount: 0,
      vatAmount: vat,
      totalAmount: total,
      status: 'DRAFT',
      paymentStatus: 'UNPAID',
      remark: _remark,
      createdAt: widget.order?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      supplierName: _supplierName,
      warehouseName: _warehouseName,
      items: _items,
    );

    final success = widget.order == null
        ? await ref
              .read(purchaseListProvider.notifier)
              .createPurchaseOrder(order)
        : await ref
              .read(purchaseListProvider.notifier)
              .updatePurchaseOrder(order);

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.order == null
                  ? 'สร้างใบสั่งซื้อสำเร็จ'
                  : 'แก้ไขใบสั่งซื้อสำเร็จ',
            ),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('บันทึกไม่สำเร็จ กรุณาลองใหม่'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

// ════════════════════════════════════════════════════════════════
// Title Bar
// ════════════════════════════════════════════════════════════════
class _POFormTitleBar extends StatelessWidget {
  final bool isEdit;
  const _POFormTitleBar({required this.isEdit});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canPop = Navigator.of(context).canPop();

    return Container(
      color: isDark ? AppTheme.darkTopBar : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          if (canPop) ...[
            context.isMobile
                ? buildMobileHomeCompactButton(context, isDark: isDark)
                : InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.arrow_back,
                        size: 20,
                        color: isDark ? Colors.white70 : AppTheme.textSub,
                      ),
                    ),
                  ),
            const SizedBox(width: 10),
          ],
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              color: AppTheme.primaryDark,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            isEdit ? 'แก้ไขใบสั่งซื้อ' : 'สร้างใบสั่งซื้อ',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1A1A1A),
            ),
          ),
          const Spacer(),
          if (canPop)
            InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.close,
                  size: 20,
                  color: isDark ? Colors.white54 : AppTheme.textSub,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// Section Card
// ════════════════════════════════════════════════════════════════
class _SectionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget child;
  final Widget? trailing;

  const _SectionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white12 : AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkElement : AppTheme.headerBg,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.white12 : AppTheme.border,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, size: 15, color: iconColor),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: iconColor,
                  ),
                ),
                if (trailing != null) ...[const Spacer(), trailing!],
              ],
            ),
          ),
          // Body
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// Small helpers
// ════════════════════════════════════════════════════════════════

class _POFieldLabel extends StatelessWidget {
  final String label;
  final bool isDark;
  const _POFieldLabel({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: isDark ? Colors.white60 : AppTheme.textSub,
    ),
  );
}

class _POTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final int maxLines;
  final bool isDark;
  final ValueChanged<String>? onChanged;

  const _POTextField({
    required this.controller,
    required this.hint,
    required this.icon,
    required this.isDark,
    this.maxLines = 1,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    maxLines: maxLines,
    style: TextStyle(
      fontSize: 13,
      color: isDark ? Colors.white : Colors.black87,
    ),
    onChanged: onChanged,
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        fontSize: 13,
        color: isDark ? const Color(0xFF666666) : AppTheme.textSub,
      ),
      prefixIcon: Icon(
        icon,
        size: 17,
        color: isDark ? Colors.white38 : AppTheme.textSub,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: isDark ? Colors.white24 : AppTheme.border,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: isDark ? Colors.white24 : AppTheme.border,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
      ),
      filled: true,
      fillColor: isDark ? AppTheme.darkElement : Colors.white,
    ),
  );
}

class _PODropdown<T> extends StatelessWidget {
  final T? value;
  final String hint;
  final IconData icon;
  final bool isDark;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String? Function(T?)? validator;

  const _PODropdown({
    required this.value,
    required this.hint,
    required this.icon,
    required this.isDark,
    required this.items,
    this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<T>(
    initialValue: value,
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        fontSize: 13,
        color: isDark ? const Color(0xFF666666) : AppTheme.textSub,
      ),
      prefixIcon: Icon(
        icon,
        size: 17,
        color: isDark ? Colors.white38 : AppTheme.textSub,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: isDark ? Colors.white24 : AppTheme.border,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: isDark ? Colors.white24 : AppTheme.border,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppTheme.error),
      ),
      filled: true,
      fillColor: isDark ? AppTheme.darkElement : Colors.white,
    ),
    dropdownColor: isDark ? AppTheme.darkCard : Colors.white,
    style: TextStyle(
      fontSize: 13,
      color: isDark ? Colors.white : Colors.black87,
    ),
    items: items,
    onChanged: onChanged,
    validator: validator,
  );
}

class _SmallIconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isDark;
  final VoidCallback onTap;

  const _SmallIconBtn({
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
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkElement : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isDark ? const Color(0xFF444444) : AppTheme.border,
          ),
        ),
        child: Icon(
          icon,
          size: 16,
          color: isDark ? Colors.white54 : AppTheme.textSub,
        ),
      ),
    ),
  );
}

class _ItemStat extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;
  final bool highlight;

  const _ItemStat({
    required this.label,
    required this.value,
    required this.isDark,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: isDark ? Colors.white38 : AppTheme.textSub,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        value,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: highlight
              ? AppTheme.info
              : (isDark ? Colors.white : Colors.black87),
        ),
      ),
    ],
  );
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;

  const _SummaryRow({
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        label,
        style: TextStyle(
          fontSize: 13,
          color: isDark ? Colors.white70 : AppTheme.textSub,
        ),
      ),
      Text(
        value,
        style: TextStyle(
          fontSize: 13,
          color: isDark ? Colors.white70 : Colors.black87,
        ),
      ),
    ],
  );
}

// ════════════════════════════════════════════════════════════════
// Product Selection Dialog
// ════════════════════════════════════════════════════════════════
class _ProductSelectionDialog extends ConsumerStatefulWidget {
  final List products;
  const _ProductSelectionDialog({required this.products});

  @override
  ConsumerState<_ProductSelectionDialog> createState() =>
      _ProductSelectionDialogState();
}

class _ProductSelectionDialogState
    extends ConsumerState<_ProductSelectionDialog> {
  String? _selectedProductId;
  final _quantityController = TextEditingController(text: '1');
  final _priceController = TextEditingController();
  String _productSearch = '';
  ProductUnitOption? _selectedUnit;

  dynamic get _product => _selectedProductId == null
      ? null
      : widget.products.firstWhere(
          (p) => p.productId == _selectedProductId,
          orElse: () => null,
        );

  double get _baseQty {
    final qty = double.tryParse(_quantityController.text) ?? 0;
    return qty * (_selectedUnit?.factor ?? 1);
  }

  double get _baseCost {
    final price = double.tryParse(_priceController.text) ?? 0;
    final factor = _selectedUnit?.factor ?? 1;
    return factor == 0 ? price : price / factor;
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filteredProducts = _productSearch.isEmpty
        ? widget.products
        : widget.products.where((p) {
            final q = _productSearch.toLowerCase();
            return (p.productCode?.toLowerCase().contains(q) ?? false) ||
                (p.productName?.toLowerCase().contains(q) ?? false) ||
                (p.barcode?.toLowerCase().contains(q) ?? false);
          }).toList();

    return AppDialog(
      backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Row(
        children: [
          Expanded(
            child: buildAppDialogTitle(
              context,
              title: 'เลือกสินค้า',
              icon: Icons.inventory_2_outlined,
              iconColor: AppTheme.info,
              showClose: false,
            ),
          ),
          const SizedBox(width: 8),
          ScannerButton(
            tooltip: 'สแกนบาร์โค้ดสินค้า',
            useSheet: true,
            onScanned: (value) {
              setState(() {
                _productSearch = value;
                final matched = widget.products.where(
                  (p) =>
                      (p.barcode?.toLowerCase() == value.toLowerCase()) ||
                      (p.productCode?.toLowerCase() == value.toLowerCase()),
                );
                if (matched.length == 1) {
                  _selectedProductId = matched.first.productId;
                  _priceController.text = matched.first.priceLevel1.toString();
                }
              });
            },
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search field
            SizedBox(
              height: 38,
              child: TextField(
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                decoration: InputDecoration(
                  hintText: 'ค้นหาชื่อ / รหัส / บาร์โค้ด...',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: isDark ? const Color(0xFF666666) : AppTheme.textSub,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    size: 17,
                    color: isDark ? Colors.white38 : AppTheme.textSub,
                  ),
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: isDark ? Colors.white24 : AppTheme.border,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: isDark ? Colors.white24 : AppTheme.border,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: AppTheme.primary,
                      width: 1.5,
                    ),
                  ),
                  filled: true,
                  fillColor: isDark ? AppTheme.darkElement : Colors.white,
                ),
                onChanged: (v) => setState(() => _productSearch = v),
              ),
            ),
            const SizedBox(height: 12),

            // Dropdown
            _PODropdown<String>(
              value: _selectedProductId,
              hint: 'เลือกสินค้า',
              icon: Icons.inventory_2_outlined,
              isDark: isDark,
              items: filteredProducts
                  .map<DropdownMenuItem<String>>(
                    (p) => DropdownMenuItem(
                      value: p.productId,
                      child: Text(
                        '${p.productCode} — ${p.productName}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() {
                _selectedProductId = v;
                _selectedUnit = null;
                _priceController.text = '0';
              }),
            ),
            const SizedBox(height: 12),

            // Unit dropdown (shown when product selected)
            if (_product != null) ...[
              _PODropdown<String>(
                value: _selectedUnit?.unit,
                hint: 'หน่วย',
                icon: Icons.straighten_outlined,
                isDark: isDark,
                items: (_product!.allUnits as List<ProductUnitOption>)
                    .map<DropdownMenuItem<String>>(
                      (u) => DropdownMenuItem(
                        value: u.unit,
                        child: Text(
                          u.factor == 1
                              ? u.unit
                              : '${u.unit}  (1 ${u.unit} = ${u.factor.toStringAsFixed(0)} ${_product!.baseUnit})',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() {
                  _selectedUnit =
                      (_product!.allUnits as List<ProductUnitOption>)
                          .firstWhere((u) => u.unit == v);
                }),
              ),
              const SizedBox(height: 12),
            ],

            Row(
              children: [
                Expanded(
                  child: _POTextField(
                    controller: _quantityController,
                    hint: 'จำนวน',
                    icon: Icons.numbers,
                    isDark: isDark,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _POTextField(
                    controller: _priceController,
                    hint: 'ราคา/หน่วย',
                    icon: Icons.attach_money,
                    isDark: isDark,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),

            // Conversion preview card
            if (_product != null &&
                _selectedUnit != null &&
                _selectedUnit!.factor != 1) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.info.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.info.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.swap_horiz,
                      size: 14,
                      color: AppTheme.info,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'รับจริง ${_baseQty.toStringAsFixed(0)} ${_product!.baseUnit}'
                        '  •  ต้นทุน/ฐาน ${_baseCost.toStringAsFixed(2)} บาท',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.info,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'ยกเลิก',
            style: TextStyle(color: isDark ? Colors.white60 : AppTheme.textSub),
          ),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.add, size: 16),
          label: const Text('เพิ่มสินค้า'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.info,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 0,
          ),
          onPressed: () {
            if (_selectedProductId == null) return;
            final product = widget.products.firstWhere(
              (p) => p.productId == _selectedProductId,
            );
            final baseQty = _baseQty;
            final baseCost = _baseCost;
            Navigator.pop(context, {
              'item': PurchaseOrderItemModel(
                itemId: '',
                poId: '',
                lineNo: 0,
                productId: product.productId,
                productCode: product.productCode,
                productName: product.productName,
                unit: product.baseUnit,
                quantity: baseQty,
                unitPrice: baseCost,
                amount: baseCost * baseQty,
                remainingQuantity: baseQty,
              ),
            });
          },
        ),
      ],
    );
  }
}
