import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pos_erp/shared/theme/app_theme.dart';

import '../../../products/presentation/providers/product_provider.dart';
import '../../../suppliers/presentation/providers/supplier_provider.dart';
import '../../data/models/goods_receipt_model.dart';
import '../../data/models/goods_receipt_item_model.dart';
import '../providers/goods_receipt_provider.dart';
import '../providers/purchase_provider.dart';
import '../../../../../shared/services/mobile_scanner_service.dart';

class GoodsReceiptFormPage extends ConsumerStatefulWidget {
  final GoodsReceiptModel? receipt;
  const GoodsReceiptFormPage({super.key, this.receipt});

  @override
  ConsumerState<GoodsReceiptFormPage> createState() =>
      _GoodsReceiptFormPageState();
}

class _GoodsReceiptFormPageState
    extends ConsumerState<GoodsReceiptFormPage> {
  final _formKey = GlobalKey<FormState>();

  DateTime _grDate = DateTime.now();
  String? _poId;
  String? _poNo;
  String? _supplierId;
  String? _supplierName;
  String _warehouseId = 'WH001';
  String _warehouseName = 'คลังสาขาหลัก';
  final _remarkController = TextEditingController();

  final List<GoodsReceiptItemModel> _items = [];
  bool _isLoading = false;
  bool _isViewMode = false;
  bool _isCardView = false;

  @override
  void initState() {
    super.initState();
    if (widget.receipt != null) {
      _loadReceiptData();
      _isViewMode = widget.receipt!.status == 'CONFIRMED';
    }
  }

  void _loadReceiptData() {
    final r = widget.receipt!;
    _grDate = r.grDate;
    _poId = r.poId;
    _poNo = r.poNo;
    _supplierId = r.supplierId;
    _supplierName = r.supplierName;
    _warehouseId = r.warehouseId;
    _warehouseName = r.warehouseName;
    _remarkController.text = r.remark ?? '';
    if (r.items != null) _items.addAll(r.items!);
  }

  @override
  void dispose() {
    _remarkController.dispose();
    super.dispose();
  }

  String get _pageTitle {
    if (_isViewMode) return 'รายละเอียดใบรับสินค้า';
    if (widget.receipt == null) return 'สร้างใบรับสินค้า';
    return 'แก้ไขใบรับสินค้า';
  }

  // ─────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Preload products so the dialog opens immediately on first tap
    ref.watch(productListProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppTheme.darkBg : const Color(0xFFF5F5F5),
      body: Column(
        children: [
          // ── Title Bar ─────────────────────────────────────────
          _GRFormTitleBar(
            title: _pageTitle,
            isViewMode: _isViewMode,
            onHelp: _isViewMode ? null : _showHelp,
          ),

          // ── Form Body ─────────────────────────────────────────
          Expanded(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Section 0 — Method Selection (create mode, no PO yet)
                    if (widget.receipt == null && _poId == null &&
                        _supplierId == null) ...[
                      _GRSectionCard(
                        icon: Icons.alt_route_outlined,
                        iconColor: AppTheme.info,
                        title: 'เลือกวิธีสร้างใบรับสินค้า',
                        child: _buildMethodSelection(isDark),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Section 1 — ข้อมูลทั่วไป
                    _GRSectionCard(
                      icon: Icons.local_shipping_outlined,
                      iconColor: AppTheme.success,
                      title: 'ข้อมูลทั่วไป',
                      child: _buildGeneralSection(isDark),
                    ),
                    const SizedBox(height: 14),

                    // Section 2 — รายการสินค้า
                    _GRSectionCard(
                      icon: Icons.inventory_2_outlined,
                      iconColor: AppTheme.info,
                      title: 'รายการสินค้า',
                      trailing: (!_isViewMode && _supplierId != null)
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _GRSmallIconBtn(
                                  icon: _isCardView
                                      ? Icons.view_list_outlined
                                      : Icons.grid_view_outlined,
                                  tooltip: _isCardView
                                      ? 'List View'
                                      : 'Card View',
                                  isDark: isDark,
                                  onTap: () => setState(
                                      () => _isCardView = !_isCardView),
                                ),
                                const SizedBox(width: 6),
                                ElevatedButton.icon(
                                  onPressed: _addItem,
                                  icon: const Icon(Icons.add, size: 15),
                                  label: const Text('เพิ่ม',
                                      style: TextStyle(fontSize: 12)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.info,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(8)),
                                    elevation: 0,
                                  ),
                                ),
                              ],
                            )
                          : (_isViewMode
                              ? null
                              : _GRSmallIconBtn(
                                  icon: _isCardView
                                      ? Icons.view_list_outlined
                                      : Icons.grid_view_outlined,
                                  tooltip: _isCardView
                                      ? 'List View'
                                      : 'Card View',
                                  isDark: isDark,
                                  onTap: () => setState(
                                      () => _isCardView = !_isCardView),
                                )),
                      child: _buildItemsSection(isDark),
                    ),
                    const SizedBox(height: 14),

                    // Section 3 — สรุปยอด
                    if (_items.isNotEmpty) ...[
                      _GRSectionCard(
                        icon: Icons.summarize_outlined,
                        iconColor: AppTheme.success,
                        title: 'สรุปรายการ',
                        child: _buildSummarySection(isDark),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Section 4 — หมายเหตุ
                    _GRSectionCard(
                      icon: Icons.note_outlined,
                      iconColor: AppTheme.textSub,
                      title: 'หมายเหตุ',
                      child: _isViewMode
                          ? _GRReadOnlyField(
                              label: _remarkController.text.isEmpty
                                  ? '-'
                                  : _remarkController.text,
                              icon: Icons.edit_note,
                              isDark: isDark,
                            )
                          : _GRTextField(
                              controller: _remarkController,
                              hint: 'บันทึกเพิ่มเติม (ถ้ามี)',
                              icon: Icons.edit_note,
                              maxLines: 3,
                              isDark: isDark,
                            ),
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ),

          // ── Bottom Action Bar ─────────────────────────────────
          if (!_isViewMode)
            Container(
              color: isDark ? AppTheme.darkTopBar : Colors.white,
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed:
                        _isLoading ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      side: BorderSide(
                          color: isDark
                              ? Colors.white24
                              : AppTheme.border),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text('ยกเลิก',
                        style: TextStyle(
                            color: isDark
                                ? Colors.white60
                                : AppTheme.textSub)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _saveReceipt,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white),
                          )
                        : const Icon(Icons.save_outlined, size: 18),
                    label: Text(
                      widget.receipt == null
                          ? 'สร้างใบรับสินค้า'
                          : 'บันทึก',
                      style: const TextStyle(fontSize: 14),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Method Selection Section
  // ─────────────────────────────────────────────────────────────
  Widget _buildMethodSelection(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _GRMethodBtn(
            icon: Icons.receipt_long_outlined,
            label: 'จาก Purchase Order',
            sublabel: 'ดึงข้อมูลจาก PO ที่อนุมัติแล้ว',
            color: AppTheme.info,
            isDark: isDark,
            onTap: _selectFromPO,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _GRMethodBtn(
            icon: Icons.edit_outlined,
            label: 'สร้างเอง',
            sublabel: 'ไม่อ้างอิง PO',
            color: AppTheme.primaryDark,
            isDark: isDark,
            onTap: _createManually,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // General Section
  // ─────────────────────────────────────────────────────────────
  Widget _buildGeneralSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // วันที่
        _GRFieldLabel(label: 'วันที่รับสินค้า', isDark: isDark),
        const SizedBox(height: 6),
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: _isViewMode ? null : _selectDate,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: _isViewMode
                  ? (isDark
                      ? AppTheme.darkCard
                      : const Color(0xFFF5F5F5))
                  : (isDark ? AppTheme.darkElement : Colors.white),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: isDark ? Colors.white24 : AppTheme.border),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today_outlined,
                    size: 17,
                    color: isDark ? Colors.white54 : AppTheme.textSub),
                const SizedBox(width: 8),
                Text(
                  DateFormat('dd/MM/yyyy').format(_grDate),
                  style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white : Colors.black87),
                ),
                const Spacer(),
                if (!_isViewMode)
                  Icon(Icons.chevron_right,
                      size: 18,
                      color: isDark
                          ? Colors.white38
                          : AppTheme.textSub),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // PO Reference (ถ้ามี)
        if (_poNo != null) ...[
          _GRFieldLabel(
              label: 'อ้างอิง Purchase Order', isDark: isDark),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.info.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: AppTheme.info.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.receipt_long_outlined,
                    size: 17, color: AppTheme.info),
                const SizedBox(width: 8),
                Text(_poNo!,
                    style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.info,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // ซัพพลายเออร์
        _GRFieldLabel(label: 'ซัพพลายเออร์', isDark: isDark),
        const SizedBox(height: 6),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: isDark
                ? AppTheme.darkCard
                : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: isDark ? Colors.white12 : AppTheme.border),
          ),
          child: Row(
            children: [
              Icon(Icons.business_outlined,
                  size: 17,
                  color: isDark ? Colors.white38 : AppTheme.textSub),
              const SizedBox(width: 8),
              Text(
                _supplierName ?? '-',
                style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white70 : Colors.black87),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // คลังสินค้า
        _GRFieldLabel(label: 'คลังสินค้า', isDark: isDark),
        const SizedBox(height: 6),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: isDark
                ? AppTheme.darkCard
                : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: isDark ? Colors.white12 : AppTheme.border),
          ),
          child: Row(
            children: [
              Icon(Icons.warehouse_outlined,
                  size: 17,
                  color: isDark ? Colors.white38 : AppTheme.textSub),
              const SizedBox(width: 8),
              Text(
                _warehouseName,
                style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white54 : AppTheme.textSub),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Items Section
  // ─────────────────────────────────────────────────────────────
  Widget _buildItemsSection(bool isDark) {
    if (_items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Column(
            children: [
              Icon(
                _supplierId == null
                    ? Icons.alt_route_outlined
                    : Icons.add_shopping_cart_outlined,
                size: 48,
                color: isDark
                    ? const Color(0xFF444444)
                    : Colors.grey[300],
              ),
              const SizedBox(height: 8),
              Text(
                _supplierId == null
                    ? 'กรุณาเลือกวิธีสร้างใบรับสินค้าก่อน'
                    : 'ยังไม่มีรายการสินค้า\nกดปุ่ม "เพิ่ม" เพื่อเพิ่มสินค้า',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? const Color(0xFF888888)
                        : Colors.grey[500]),
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
            : _buildItemListRow(item, i, isDark);
      }).toList(),
    );
  }

  // Item Card View
  Widget _buildItemCard(
      GoodsReceiptItemModel item, int index, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkElement : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: isDark ? Colors.white12 : AppTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.inventory_2_outlined,
                      size: 16, color: AppTheme.success),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.productName,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1A1A1A))),
                      const SizedBox(height: 2),
                      Text(item.productCode,
                          style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? Colors.white54
                                  : AppTheme.textSub)),
                    ],
                  ),
                ),
                if (!_isViewMode)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _GRSmallIconBtn(
                        icon: Icons.edit_outlined,
                        tooltip: 'แก้ไขจำนวน',
                        isDark: isDark,
                        color: AppTheme.info,
                        onTap: () => _editItem(item, index),
                      ),
                      const SizedBox(width: 4),
                      _GRSmallIconBtn(
                        icon: Icons.delete_outline,
                        tooltip: 'ลบ',
                        isDark: isDark,
                        color: AppTheme.error,
                        onTap: () =>
                            setState(() => _items.removeAt(index)),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Divider(
                height: 1,
                color: isDark ? Colors.white12 : AppTheme.border),
            const SizedBox(height: 10),

            // Qty row
            Row(
              children: [
                Expanded(
                  child: _QtyStat(
                    label: 'สั่งซื้อ',
                    qty: item.orderedQuantity,
                    unit: item.unit,
                    color: AppTheme.info,
                    isDark: isDark,
                  ),
                ),
                Expanded(
                  child: _QtyStat(
                    label: 'รับจริง',
                    qty: item.receivedQuantity,
                    unit: item.unit,
                    color: AppTheme.success,
                    isDark: isDark,
                  ),
                ),
                if (item.orderedQuantity > 0)
                  Expanded(
                    child: _QtyStat(
                      label: 'คงเหลือ',
                      qty: item.orderedQuantity - item.receivedQuantity,
                      unit: item.unit,
                      color: AppTheme.warning,
                      isDark: isDark,
                    ),
                  ),
              ],
            ),

            // Lot / Expiry
            if (item.lotNumber != null || item.expiryDate != null) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                children: [
                  if (item.lotNumber != null)
                    _GRBadge(
                      icon: Icons.qr_code,
                      text: 'Lot: ${item.lotNumber}',
                      isDark: isDark,
                    ),
                  if (item.expiryDate != null)
                    _GRBadge(
                      icon: Icons.event_outlined,
                      text:
                          'EXP: ${DateFormat('dd/MM/yyyy').format(item.expiryDate!)}',
                      isDark: isDark,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Item List Row (compact)
  Widget _buildItemListRow(
      GoodsReceiptItemModel item, int index, bool isDark) {
    final isEven = index.isEven;
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
          SizedBox(
            width: 24,
            child: Text('${index + 1}',
                style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white38 : AppTheme.textSub)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.productName,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? Colors.white
                            : const Color(0xFF1A1A1A)),
                    overflow: TextOverflow.ellipsis),
                Text(item.productCode,
                    style: TextStyle(
                        fontSize: 10,
                        color: isDark
                            ? Colors.white54
                            : AppTheme.textSub)),
              ],
            ),
          ),
          // สั่ง / รับ
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'สั่ง ${item.orderedQuantity.toStringAsFixed(0)}',
                style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.white38 : AppTheme.textSub),
              ),
              Text(
                'รับ ${item.receivedQuantity.toStringAsFixed(0)} ${item.unit}',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.success),
              ),
            ],
          ),
          if (!_isViewMode) ...[
            const SizedBox(width: 8),
            InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: () => _editItem(item, index),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.edit_outlined,
                    size: 15, color: AppTheme.info),
              ),
            ),
            InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: () =>
                  setState(() => _items.removeAt(index)),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.close,
                    size: 15,
                    color: isDark ? Colors.white38 : AppTheme.textSub),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Summary Section
  // ─────────────────────────────────────────────────────────────
  Widget _buildSummarySection(bool isDark) {
    final totalOrdered =
        _items.fold<double>(0, (s, i) => s + i.orderedQuantity);
    final totalReceived =
        _items.fold<double>(0, (s, i) => s + i.receivedQuantity);

    return Column(
      children: [
        _GRSummaryRow(
          label: 'จำนวนรายการ',
          value: '${_items.length} รายการ',
          isDark: isDark,
        ),
        const SizedBox(height: 8),
        _GRSummaryRow(
          label: 'จำนวนที่สั่ง',
          value: totalOrdered.toStringAsFixed(0),
          valueColor: AppTheme.info,
          isDark: isDark,
        ),
        Divider(
            height: 20,
            color: isDark ? Colors.white12 : AppTheme.border),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('จำนวนที่รับจริง',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? Colors.white
                        : const Color(0xFF1A1A1A))),
            Text(
              totalReceived.toStringAsFixed(0),
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.success),
            ),
          ],
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Actions
  // ─────────────────────────────────────────────────────────────
  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _grDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) setState(() => _grDate = date);
  }

  Future<void> _selectFromPO() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          const Center(child: CircularProgressIndicator()),
    );

    final pendingPOs = await ref
        .read(goodsReceiptListProvider.notifier)
        .getPendingPurchaseOrders();

    if (!mounted) return;
    Navigator.pop(context);

    if (pendingPOs.isEmpty) {
      _showInfoDialog(
        title: 'ไม่มี Purchase Order',
        message:
            'ไม่พบ PO ที่อนุมัติแล้วและรอรับสินค้า\n\nกรุณาสร้างและอนุมัติ PO ก่อน หรือเลือก "สร้างเอง"',
      );
      return;
    }

    final selectedPO = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _POSelectionDialog(pos: pendingPOs),
    );

    if (selectedPO != null) await _loadFromPO(selectedPO);
  }

  void _createManually() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor:
            isDark ? AppTheme.darkCard : Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppTheme.primaryDark.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.edit_outlined,
                  size: 18, color: AppTheme.primaryDark),
            ),
            const SizedBox(width: 10),
            Text('สร้างใบรับสินค้าเอง',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color:
                        isDark ? Colors.white : const Color(0xFF1A1A1A))),
          ],
        ),
        content: Text(
          'คุณต้องการสร้างใบรับสินค้าโดยไม่อ้างอิง PO ใช่หรือไม่?\n\n'
          'คุณจะต้องเลือกซัพพลายเออร์และเพิ่มรายการสินค้าเอง',
          style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('ยกเลิก',
                style: TextStyle(
                    color: isDark ? Colors.white60 : AppTheme.textSub)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showSupplierSelection();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryDark,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: const Text('ดำเนินการต่อ'),
          ),
        ],
      ),
    );
  }

  Future<void> _addItem() async {
    final products = ref.read(productListProvider).value;
    if (products == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('กำลังโหลดข้อมูลสินค้า...'),
        duration: Duration(seconds: 1),
      ));
      return;
    }
    final result = await showDialog<GoodsReceiptItemModel>(
      context: context,
      builder: (ctx) =>
          _ItemDialog(products: products, lineNo: _items.length + 1),
    );
    if (result != null) setState(() => _items.add(result));
  }

  Future<void> _editItem(GoodsReceiptItemModel item, int index) async {
    final result = await showDialog<GoodsReceiptItemModel>(
      context: context,
      builder: (ctx) => _ItemEditDialog(item: item),
    );
    if (result != null) setState(() => _items[index] = result);
  }

  Future<void> _saveReceipt() async {
    if (!_formKey.currentState!.validate()) return;

    if (_supplierId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('กรุณาเลือกซัพพลายเออร์'),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('กรุณาเพิ่มรายการสินค้าอย่างน้อย 1 รายการ'),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    setState(() => _isLoading = true);

    final receipt = GoodsReceiptModel(
      grId: widget.receipt?.grId ?? '',
      grNo: widget.receipt?.grNo ?? '',
      grDate: _grDate,
      poId: _poId,
      poNo: _poNo,
      supplierId: _supplierId!,
      supplierName: _supplierName!,
      warehouseId: _warehouseId,
      warehouseName: _warehouseName,
      userId: 'USR001',
      status: 'DRAFT',
      remark: _remarkController.text.isEmpty
          ? null
          : _remarkController.text,
      createdAt: widget.receipt?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      items: _items,
    );

    final success = widget.receipt == null
        ? await ref
            .read(goodsReceiptListProvider.notifier)
            .createGoodsReceipt(receipt)
        : await ref
            .read(goodsReceiptListProvider.notifier)
            .updateGoodsReceipt(receipt);

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.receipt == null
              ? 'สร้างใบรับสินค้าสำเร็จ'
              : 'แก้ไขใบรับสินค้าสำเร็จ'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('บันทึกไม่สำเร็จ กรุณาลองใหม่'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Future<void> _loadFromPO(Map<String, dynamic> poData) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          const Center(child: CircularProgressIndicator()),
    );

    final po = await ref
        .read(purchaseListProvider.notifier)
        .getPurchaseOrderDetails(poData['po_id']);

    if (!mounted) return;
    Navigator.pop(context);

    if (po == null || po.items == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('ไม่สามารถโหลดข้อมูล PO ได้'),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    setState(() {
      _poId = po.poId;
      _poNo = po.poNo;
      _supplierId = po.supplierId;
      _supplierName = po.supplierName;
      _warehouseId = po.warehouseId;
      _warehouseName = po.warehouseName ?? 'คลังสาขาหลัก';
      _items.clear();
      for (var i = 0; i < po.items!.length; i++) {
        final poItem = po.items![i];
        final remaining = poItem.remainingQuantity;
        if (remaining > 0) {
          _items.add(GoodsReceiptItemModel(
            itemId: '',
            grId: '',
            lineNo: i + 1,
            poItemId: poItem.itemId,
            productId: poItem.productId,
            productCode: poItem.productCode ?? '',
            productName: poItem.productName ?? '',
            unit: poItem.unit ?? '',
            orderedQuantity: poItem.quantity,
            receivedQuantity: remaining,
            unitPrice: poItem.unitPrice,
            amount: remaining * poItem.unitPrice,
          ));
        }
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          'โหลดข้อมูลจาก PO: ${po.poNo} สำเร็จ (${_items.length} รายการ)'),
      backgroundColor: AppTheme.success,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _showSupplierSelection() async {
    final suppliersAsync = ref.read(supplierListProvider);
    await suppliersAsync.when(
      data: (suppliers) async {
        final selected = await showDialog<Map<String, String>>(
          context: context,
          builder: (ctx) =>
              _SupplierSelectionDialog(suppliers: suppliers),
        );
        if (selected != null && mounted) {
          setState(() {
            _supplierId = selected['id'];
            _supplierName = selected['name'];
          });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('เลือกซัพพลายเออร์: ${selected['name']}'),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
          ));
        }
      },
      loading: () {},
      error: (_, _) {},
    );
  }

  void _showHelp() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor:
            isDark ? AppTheme.darkCard : Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppTheme.info.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.help_outline,
                  size: 18, color: AppTheme.info),
            ),
            const SizedBox(width: 10),
            Text('คำแนะนำ',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color:
                        isDark ? Colors.white : const Color(0xFF1A1A1A))),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _HelpItem(
                title: 'จาก Purchase Order',
                detail:
                    'เลือก PO ที่อนุมัติแล้ว ระบบจะดึงข้อมูลสินค้ามาให้อัตโนมัติ',
                isDark: isDark,
              ),
              const SizedBox(height: 10),
              _HelpItem(
                title: 'สร้างเอง',
                detail:
                    'สร้างใบรับสินค้าโดยไม่อ้างอิง PO — เลือกซัพพลายเออร์และเพิ่มสินค้าเอง',
                isDark: isDark,
              ),
              const SizedBox(height: 10),
              _HelpItem(
                title: 'แก้ไขจำนวน',
                detail:
                    'กดปุ่มดินสอที่รายการเพื่อแก้ไขจำนวนที่รับจริง',
                isDark: isDark,
              ),
              const SizedBox(height: 10),
              _HelpItem(
                title: 'Lot Number & วันหมดอายุ',
                detail:
                    'สามารถเพิ่ม Lot Number และวันหมดอายุได้ในแต่ละรายการ',
                isDark: isDark,
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.info,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: const Text('เข้าใจแล้ว'),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog(
      {required String title, required String message}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor:
            isDark ? AppTheme.darkCard : Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        title: Text(title,
            style: TextStyle(
                color:
                    isDark ? Colors.white : const Color(0xFF1A1A1A))),
        content: Text(message,
            style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black87)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ปิด'),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// _GRFormTitleBar
// ════════════════════════════════════════════════════════════════
class _GRFormTitleBar extends StatelessWidget {
  final String title;
  final bool isViewMode;
  final VoidCallback? onHelp;

  const _GRFormTitleBar({
    required this.title,
    required this.isViewMode,
    this.onHelp,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canPop = Navigator.of(context).canPop();

    return Container(
      color: isDark ? AppTheme.darkTopBar : Colors.white,
      padding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          if (canPop) ...[
            InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.arrow_back,
                    size: 20,
                    color:
                        isDark ? Colors.white70 : AppTheme.textSub),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.successContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.local_shipping_outlined,
                color: AppTheme.success, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color:
                    isDark ? Colors.white : const Color(0xFF1A1A1A),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onHelp != null) ...[
            Tooltip(
              message: 'คำแนะนำ',
              child: InkWell(
                onTap: onHelp,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.help_outline,
                      size: 20,
                      color:
                          isDark ? Colors.white54 : AppTheme.textSub),
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
          if (canPop)
            InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.close,
                    size: 20,
                    color:
                        isDark ? Colors.white54 : AppTheme.textSub),
              ),
            ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// _GRSectionCard
// ════════════════════════════════════════════════════════════════
class _GRSectionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget child;
  final Widget? trailing;

  const _GRSectionCard({
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
        border: Border.all(
            color: isDark ? Colors.white12 : AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkElement : AppTheme.headerBg,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border(
                  bottom: BorderSide(
                      color:
                          isDark ? Colors.white12 : AppTheme.border)),
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
                Text(title,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: iconColor)),
                if (trailing != null) ...[
                  const Spacer(),
                  trailing!,
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// PO Selection Dialog
// ════════════════════════════════════════════════════════════════
class _POSelectionDialog extends StatefulWidget {
  final List<Map<String, dynamic>> pos;
  const _POSelectionDialog({required this.pos});

  @override
  State<_POSelectionDialog> createState() => _POSelectionDialogState();
}

class _POSelectionDialogState extends State<_POSelectionDialog> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _search.isEmpty
        ? widget.pos
        : widget.pos.where((po) {
            final q = _search.toLowerCase();
            return (po['po_no'] as String? ?? '')
                    .toLowerCase()
                    .contains(q) ||
                (po['supplier_name'] as String? ?? '')
                    .toLowerCase()
                    .contains(q);
          }).toList();

    return AlertDialog(
      backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppTheme.info.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.receipt_long_outlined,
                size: 18, color: AppTheme.info),
          ),
          const SizedBox(width: 10),
          Text('เลือก Purchase Order',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1A1A1A))),
        ],
      ),
      content: SizedBox(
        width: 500,
        height: 420,
        child: Column(
          children: [
            // Search
            SizedBox(
              height: 38,
              child: TextField(
                style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  hintText: 'ค้นหาเลขที่ PO, ซัพพลายเออร์...',
                  hintStyle: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? const Color(0xFF666666)
                          : AppTheme.textSub),
                  prefixIcon: Icon(Icons.search,
                      size: 17,
                      color: isDark
                          ? Colors.white38
                          : AppTheme.textSub),
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                          color: isDark
                              ? Colors.white24
                              : AppTheme.border)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                          color: isDark
                              ? Colors.white24
                              : AppTheme.border)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                          color: AppTheme.primary, width: 1.5)),
                  filled: true,
                  fillColor:
                      isDark ? AppTheme.darkElement : Colors.white,
                ),
                onChanged: (v) => setState(() => _search = v),
              ),
            ),
            const SizedBox(height: 10),
            // List
            Expanded(
              child: ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: 6),
                itemBuilder: (ctx, i) {
                  final po = filtered[i];
                  final isApproved = po['status'] == 'APPROVED';
                  final statusColor =
                      isApproved ? AppTheme.info : AppTheme.warning;
                  final statusLabel =
                      isApproved ? 'รอรับสินค้า' : 'รับบางส่วน';
                  final fmt = NumberFormat('#,##0.00', 'th_TH');

                  return InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => Navigator.pop(ctx, po),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppTheme.darkElement
                            : const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: isDark
                                ? Colors.white12
                                : AppTheme.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 44,
                            decoration: BoxDecoration(
                              color: statusColor,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(po['po_no'] ?? '',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF1A1A1A))),
                                Text(po['supplier_name'] ?? '',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: isDark
                                            ? const Color(0xFFAAAAAA)
                                            : AppTheme.textSub)),
                                Text(
                                  DateFormat('dd/MM/yyyy').format(
                                      DateTime.parse(po['po_date'])),
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: isDark
                                          ? const Color(0xFFAAAAAA)
                                          : AppTheme.textSub),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: statusColor
                                      .withValues(alpha: 0.12),
                                  borderRadius:
                                      BorderRadius.circular(10),
                                ),
                                child: Text(statusLabel,
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: statusColor)),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '฿${fmt.format(po['total_amount'] ?? 0)}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.info),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('ยกเลิก',
              style: TextStyle(
                  color: isDark ? Colors.white60 : AppTheme.textSub)),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// Supplier Selection Dialog
// ════════════════════════════════════════════════════════════════
class _SupplierSelectionDialog extends StatefulWidget {
  final List suppliers;
  const _SupplierSelectionDialog({required this.suppliers});

  @override
  State<_SupplierSelectionDialog> createState() =>
      _SupplierSelectionDialogState();
}

class _SupplierSelectionDialogState
    extends State<_SupplierSelectionDialog> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _search.isEmpty
        ? widget.suppliers
        : widget.suppliers.where((s) {
            final q = _search.toLowerCase();
            return s.supplierName.toLowerCase().contains(q) ||
                s.supplierCode.toLowerCase().contains(q);
          }).toList();

    return AlertDialog(
      backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppTheme.primaryDark.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.business_outlined,
                size: 18, color: AppTheme.primaryDark),
          ),
          const SizedBox(width: 10),
          Text('เลือกซัพพลายเออร์',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1A1A1A))),
        ],
      ),
      content: SizedBox(
        width: 420,
        height: 380,
        child: Column(
          children: [
            SizedBox(
              height: 38,
              child: TextField(
                style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  hintText: 'ค้นหาชื่อ / รหัสซัพพลายเออร์...',
                  hintStyle: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? const Color(0xFF666666)
                          : AppTheme.textSub),
                  prefixIcon: Icon(Icons.search,
                      size: 17,
                      color: isDark
                          ? Colors.white38
                          : AppTheme.textSub),
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                          color: isDark
                              ? Colors.white24
                              : AppTheme.border)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                          color: isDark
                              ? Colors.white24
                              : AppTheme.border)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                          color: AppTheme.primary, width: 1.5)),
                  filled: true,
                  fillColor:
                      isDark ? AppTheme.darkElement : Colors.white,
                ),
                onChanged: (v) => setState(() => _search = v),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: 4),
                itemBuilder: (ctx, i) {
                  final s = filtered[i];
                  return InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => Navigator.pop(ctx, <String, String>{
                      'id': s.supplierId,
                      'name': s.supplierName,
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppTheme.darkElement
                            : const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: isDark
                                ? Colors.white12
                                : AppTheme.border),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: AppTheme.primaryDark
                                .withValues(alpha: 0.15),
                            child: Text(
                              s.supplierName.isNotEmpty
                                  ? s.supplierName[0].toUpperCase()
                                  : 'S',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryDark),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(s.supplierName,
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF1A1A1A))),
                                Text(s.supplierCode,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: isDark
                                            ? const Color(0xFFAAAAAA)
                                            : AppTheme.textSub)),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right,
                              size: 16,
                              color: isDark
                                  ? Colors.white38
                                  : AppTheme.textSub),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('ยกเลิก',
              style: TextStyle(
                  color: isDark ? Colors.white60 : AppTheme.textSub)),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// Item Add Dialog
// ════════════════════════════════════════════════════════════════
class _ItemDialog extends ConsumerStatefulWidget {
  final List products;
  final int lineNo;
  const _ItemDialog({required this.products, required this.lineNo});

  @override
  ConsumerState<_ItemDialog> createState() => _ItemDialogState();
}

class _ItemDialogState extends ConsumerState<_ItemDialog> {
  String? _selectedProductId;
  final _quantityController = TextEditingController(text: '1');
  final _lotController = TextEditingController();
  final _remarkController = TextEditingController();
  DateTime? _expiryDate;
  String _productSearch = '';

  @override
  void dispose() {
    _quantityController.dispose();
    _lotController.dispose();
    _remarkController.dispose();
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

    return AlertDialog(
      backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.add_shopping_cart_outlined,
                size: 18, color: AppTheme.success),
          ),
          const SizedBox(width: 10),
          Text('เพิ่มรายการสินค้า',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1A1A1A))),
          const Spacer(),
          ScannerButton(
            tooltip: 'สแกนบาร์โค้ด',
            onScanned: (value) {
              setState(() {
                _productSearch = value;
                final matched = widget.products.where((p) =>
                    (p.barcode?.toLowerCase() == value.toLowerCase()) ||
                    (p.productCode?.toLowerCase() ==
                        value.toLowerCase()));
                if (matched.length == 1) {
                  _selectedProductId = matched.first.productId;
                }
              });
            },
          ),
        ],
      ),
      content: SizedBox(
        width: 450,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search
              _GRDialogField(
                controller: TextEditingController(text: _productSearch),
                hint: 'ค้นหาชื่อ / รหัส / บาร์โค้ด...',
                icon: Icons.search,
                isDark: isDark,
                onChanged: (v) => setState(() => _productSearch = v),
              ),
              const SizedBox(height: 10),

              // Product dropdown
              _GRDialogDropdown<String>(
                value: _selectedProductId,
                hint: 'เลือกสินค้า *',
                icon: Icons.inventory_2_outlined,
                isDark: isDark,
                items: filteredProducts
                    .map<DropdownMenuItem<String>>((p) =>
                        DropdownMenuItem(
                          value: p.productId,
                          child: Text(
                              '${p.productCode} — ${p.productName}',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.white
                                      : Colors.black87),
                              overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (v) =>
                    setState(() => _selectedProductId = v),
              ),
              const SizedBox(height: 10),

              // Quantity
              _GRDialogField(
                controller: _quantityController,
                hint: 'จำนวนที่รับ *',
                icon: Icons.numbers,
                isDark: isDark,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),

              // Lot Number
              _GRDialogField(
                controller: _lotController,
                hint: 'Lot Number (ถ้ามี) เช่น LOT2024001',
                icon: Icons.qr_code,
                isDark: isDark,
              ),
              const SizedBox(height: 10),

              // Expiry Date
              _GRFieldLabel(label: 'วันหมดอายุ (ถ้ามี)', isDark: isDark),
              const SizedBox(height: 6),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: _selectExpiryDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkElement : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color:
                            isDark ? Colors.white24 : AppTheme.border),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.event_outlined,
                          size: 17,
                          color: isDark
                              ? Colors.white54
                              : AppTheme.textSub),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _expiryDate != null
                              ? DateFormat('dd/MM/yyyy')
                                  .format(_expiryDate!)
                              : 'ไม่ระบุ',
                          style: TextStyle(
                              fontSize: 13,
                              color: _expiryDate != null
                                  ? (isDark
                                      ? Colors.white
                                      : Colors.black87)
                                  : (isDark
                                      ? const Color(0xFF666666)
                                      : AppTheme.textSub)),
                        ),
                      ),
                      if (_expiryDate != null)
                        InkWell(
                          onTap: () =>
                              setState(() => _expiryDate = null),
                          child: Icon(Icons.clear,
                              size: 15,
                              color: isDark
                                  ? Colors.white38
                                  : AppTheme.textSub),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Remark
              _GRDialogField(
                controller: _remarkController,
                hint: 'หมายเหตุ (ถ้ามี)',
                icon: Icons.note_outlined,
                isDark: isDark,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('ยกเลิก',
              style: TextStyle(
                  color: isDark ? Colors.white60 : AppTheme.textSub)),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.add, size: 16),
          label: const Text('เพิ่ม'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.success,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
          onPressed: _addItem,
        ),
      ],
    );
  }

  Future<void> _selectExpiryDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate:
          _expiryDate ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (date != null) setState(() => _expiryDate = date);
  }

  void _addItem() {
    if (_selectedProductId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('กรุณาเลือกสินค้า'),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    final qty = double.tryParse(_quantityController.text) ?? 0;
    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('กรุณาระบุจำนวนที่ถูกต้อง'),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    final product = widget.products
        .firstWhere((p) => p.productId == _selectedProductId);
    Navigator.pop(
      context,
      GoodsReceiptItemModel(
        itemId: '',
        grId: '',
        lineNo: widget.lineNo,
        productId: product.productId,
        productCode: product.productCode,
        productName: product.productName,
        unit: product.baseUnit,
        orderedQuantity: 0,
        receivedQuantity: qty,
        unitPrice: 0,
        amount: 0,
        lotNumber:
            _lotController.text.isEmpty ? null : _lotController.text,
        expiryDate: _expiryDate,
        remark: _remarkController.text.isEmpty
            ? null
            : _remarkController.text,
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// Item Edit Dialog
// ════════════════════════════════════════════════════════════════
class _ItemEditDialog extends StatefulWidget {
  final GoodsReceiptItemModel item;
  const _ItemEditDialog({required this.item});

  @override
  State<_ItemEditDialog> createState() => _ItemEditDialogState();
}

class _ItemEditDialogState extends State<_ItemEditDialog> {
  late TextEditingController _quantityController;
  late TextEditingController _lotController;
  late TextEditingController _remarkController;
  DateTime? _expiryDate;

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController(
        text: widget.item.receivedQuantity.toStringAsFixed(0));
    _lotController =
        TextEditingController(text: widget.item.lotNumber ?? '');
    _remarkController =
        TextEditingController(text: widget.item.remark ?? '');
    _expiryDate = widget.item.expiryDate;
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _lotController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppTheme.info.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.edit_outlined,
                size: 18, color: AppTheme.info),
          ),
          const SizedBox(width: 10),
          Text('แก้ไขรายการ',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1A1A1A))),
        ],
      ),
      content: SizedBox(
        width: 450,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product info (read-only)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.darkElement
                      : const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: isDark ? Colors.white12 : AppTheme.border),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppTheme.info.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.inventory_2_outlined,
                          size: 15, color: AppTheme.info),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.item.productName,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF1A1A1A))),
                          Text(widget.item.productCode,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? Colors.white54
                                      : AppTheme.textSub)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Ordered qty (info only)
              if (widget.item.orderedQuantity > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.info.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppTheme.info.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.shopping_cart_outlined,
                          size: 15, color: AppTheme.info),
                      const SizedBox(width: 6),
                      Text(
                        'จำนวนที่สั่ง: ${widget.item.orderedQuantity.toStringAsFixed(0)} ${widget.item.unit}',
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.info),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Received qty
              _GRDialogField(
                controller: _quantityController,
                hint:
                    'จำนวนที่รับจริง * (${widget.item.unit})',
                icon: Icons.numbers,
                isDark: isDark,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),

              // Lot
              _GRDialogField(
                controller: _lotController,
                hint: 'Lot Number (ถ้ามี)',
                icon: Icons.qr_code,
                isDark: isDark,
              ),
              const SizedBox(height: 10),

              // Expiry Date
              _GRFieldLabel(label: 'วันหมดอายุ (ถ้ามี)', isDark: isDark),
              const SizedBox(height: 6),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: _selectExpiryDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color:
                        isDark ? AppTheme.darkElement : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: isDark ? Colors.white24 : AppTheme.border),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.event_outlined,
                          size: 17,
                          color: isDark
                              ? Colors.white54
                              : AppTheme.textSub),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _expiryDate != null
                              ? DateFormat('dd/MM/yyyy')
                                  .format(_expiryDate!)
                              : 'ไม่ระบุ',
                          style: TextStyle(
                              fontSize: 13,
                              color: _expiryDate != null
                                  ? (isDark ? Colors.white : Colors.black87)
                                  : (isDark
                                      ? const Color(0xFF666666)
                                      : AppTheme.textSub)),
                        ),
                      ),
                      if (_expiryDate != null)
                        InkWell(
                          onTap: () =>
                              setState(() => _expiryDate = null),
                          child: Icon(Icons.clear,
                              size: 15,
                              color: isDark
                                  ? Colors.white38
                                  : AppTheme.textSub),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Remark
              _GRDialogField(
                controller: _remarkController,
                hint: 'หมายเหตุ (ถ้ามี)',
                icon: Icons.note_outlined,
                isDark: isDark,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('ยกเลิก',
              style: TextStyle(
                  color: isDark ? Colors.white60 : AppTheme.textSub)),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.save_outlined, size: 16),
          label: const Text('บันทึก'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.info,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
          onPressed: _saveItem,
        ),
      ],
    );
  }

  Future<void> _selectExpiryDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate:
          _expiryDate ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (date != null) setState(() => _expiryDate = date);
  }

  void _saveItem() {
    final qty = double.tryParse(_quantityController.text) ?? 0;
    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('กรุณาระบุจำนวนที่ถูกต้อง'),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    Navigator.pop(
      context,
      widget.item.copyWith(
        receivedQuantity: qty,
        amount: qty * widget.item.unitPrice,
        lotNumber:
            _lotController.text.isEmpty ? null : _lotController.text,
        expiryDate: _expiryDate,
        remark: _remarkController.text.isEmpty
            ? null
            : _remarkController.text,
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// Small shared widgets
// ════════════════════════════════════════════════════════════════

class _GRFieldLabel extends StatelessWidget {
  final String label;
  final bool isDark;
  const _GRFieldLabel({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) => Text(label,
      style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.white60 : AppTheme.textSub));
}

class _GRTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool isDark;
  final int maxLines;
  const _GRTextField({
    required this.controller,
    required this.hint,
    required this.icon,
    required this.isDark,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        maxLines: maxLines,
        style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white : Colors.black87),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
              fontSize: 13,
              color: isDark
                  ? const Color(0xFF666666)
                  : AppTheme.textSub),
          prefixIcon: Icon(icon,
              size: 17,
              color: isDark ? Colors.white38 : AppTheme.textSub),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 12),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                  color:
                      isDark ? Colors.white24 : AppTheme.border)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                  color:
                      isDark ? Colors.white24 : AppTheme.border)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                  color: AppTheme.primary, width: 1.5)),
          filled: true,
          fillColor: isDark ? AppTheme.darkElement : Colors.white,
        ),
      );
}

class _GRReadOnlyField extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isDark;
  const _GRReadOnlyField(
      {required this.label, required this.icon, required this.isDark});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: isDark ? Colors.white12 : AppTheme.border),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 17,
                color: isDark ? Colors.white38 : AppTheme.textSub),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white54 : AppTheme.textSub)),
            ),
          ],
        ),
      );
}

class _GRDialogField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool isDark;
  final int maxLines;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  const _GRDialogField({
    required this.controller,
    required this.hint,
    required this.icon,
    required this.isDark,
    this.maxLines = 1,
    this.keyboardType,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white : Colors.black87),
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
              fontSize: 12,
              color: isDark
                  ? const Color(0xFF666666)
                  : AppTheme.textSub),
          prefixIcon: Icon(icon,
              size: 16,
              color: isDark ? Colors.white38 : AppTheme.textSub),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                  color:
                      isDark ? Colors.white24 : AppTheme.border)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                  color:
                      isDark ? Colors.white24 : AppTheme.border)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                  color: AppTheme.primary, width: 1.5)),
          filled: true,
          fillColor: isDark ? AppTheme.darkElement : Colors.white,
        ),
      );
}

class _GRDialogDropdown<T> extends StatelessWidget {
  final T? value;
  final String hint;
  final IconData icon;
  final bool isDark;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;

  const _GRDialogDropdown({
    required this.value,
    required this.hint,
    required this.icon,
    required this.isDark,
    required this.items,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<T>(
        initialValue: value,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
              fontSize: 12,
              color: isDark
                  ? const Color(0xFF666666)
                  : AppTheme.textSub),
          prefixIcon: Icon(icon,
              size: 16,
              color: isDark ? Colors.white38 : AppTheme.textSub),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                  color:
                      isDark ? Colors.white24 : AppTheme.border)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                  color:
                      isDark ? Colors.white24 : AppTheme.border)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                  color: AppTheme.primary, width: 1.5)),
          filled: true,
          fillColor: isDark ? AppTheme.darkElement : Colors.white,
        ),
        dropdownColor: isDark ? AppTheme.darkCard : Colors.white,
        style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white : Colors.black87),
        items: items,
        onChanged: onChanged,
      );
}

class _GRSmallIconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isDark;
  final Color? color;
  final VoidCallback onTap;

  const _GRSmallIconBtn({
    required this.icon,
    required this.tooltip,
    required this.isDark,
    required this.onTap,
    this.color,
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
              color: color != null
                  ? color!.withValues(alpha: 0.1)
                  : (isDark
                      ? AppTheme.darkElement
                      : const Color(0xFFF5F5F5)),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                  color: color != null
                      ? color!.withValues(alpha: 0.3)
                      : (isDark
                          ? const Color(0xFF444444)
                          : AppTheme.border)),
            ),
            child: Icon(icon,
                size: 15,
                color: color ??
                    (isDark
                        ? Colors.white54
                        : AppTheme.textSub)),
          ),
        ),
      );
}

class _QtyStat extends StatelessWidget {
  final String label;
  final double qty;
  final String unit;
  final Color color;
  final bool isDark;

  const _QtyStat({
    required this.label,
    required this.qty,
    required this.unit,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: isDark ? Colors.white38 : AppTheme.textSub)),
          const SizedBox(height: 2),
          Text(
            '${qty.toStringAsFixed(0)} $unit',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color),
          ),
        ],
      );
}

class _GRBadge extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isDark;

  const _GRBadge(
      {required this.icon, required this.text, required this.isDark});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 12,
              color: isDark ? Colors.white38 : AppTheme.textSub),
          const SizedBox(width: 3),
          Text(text,
              style: TextStyle(
                  fontSize: 11,
                  color: isDark
                      ? const Color(0xFFAAAAAA)
                      : AppTheme.textSub)),
        ],
      );
}

class _GRSummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;
  final Color? valueColor;

  const _GRSummaryRow({
    required this.label,
    required this.value,
    required this.isDark,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white70 : AppTheme.textSub)),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: valueColor ??
                      (isDark ? Colors.white70 : Colors.black87))),
        ],
      );
}

class _GRMethodBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _GRMethodBtn({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 22, color: color),
              ),
              const SizedBox(height: 8),
              Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: color)),
              const SizedBox(height: 2),
              Text(sublabel,
                  style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? Colors.white54
                          : AppTheme.textSub),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );
}

class _HelpItem extends StatelessWidget {
  final String title;
  final String detail;
  final bool isDark;
  const _HelpItem(
      {required this.title, required this.detail, required this.isDark});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF1A1A1A))),
          const SizedBox(height: 2),
          Text(detail,
              style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white60 : AppTheme.textSub)),
        ],
      );
}
