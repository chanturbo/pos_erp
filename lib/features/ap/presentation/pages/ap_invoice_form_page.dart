import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pos_erp/shared/theme/app_theme.dart';
import 'package:pos_erp/shared/utils/responsive_utils.dart';
import 'package:pos_erp/shared/widgets/escape_pop_scope.dart';
import 'package:pos_erp/shared/widgets/mobile_home_button.dart';
import '../../data/models/ap_invoice_model.dart';
import '../../data/models/ap_invoice_item_model.dart';
import '../providers/ap_invoice_provider.dart';
import '../../../suppliers/presentation/providers/supplier_provider.dart';
import '../../../products/presentation/providers/product_provider.dart';

class ApInvoiceFormPage extends ConsumerStatefulWidget {
  final ApInvoiceModel? invoice;
  const ApInvoiceFormPage({super.key, this.invoice});

  @override
  ConsumerState<ApInvoiceFormPage> createState() => _ApInvoiceFormPageState();
}

class _ApInvoiceFormPageState extends ConsumerState<ApInvoiceFormPage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _invoiceNoController;
  late TextEditingController _remarkController;

  DateTime _invoiceDate = DateTime.now();
  DateTime? _dueDate;
  String? _supplierId;
  String? _supplierName;
  String? _referenceType;
  String? _referenceId;

  final List<ApInvoiceItemModel> _items = [];
  bool _isLoading = false;
  bool _isViewMode = false;
  bool _isCardView = false;
  bool _includeVat = false;

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    if (widget.invoice != null) {
      final inv = widget.invoice!;
      _invoiceNoController = TextEditingController(text: inv.invoiceNo);
      _remarkController = TextEditingController(text: inv.remark ?? '');
      _invoiceDate = inv.invoiceDate;
      _dueDate = inv.dueDate;
      _supplierId = inv.supplierId;
      _supplierName = inv.supplierName;
      _referenceType = inv.referenceType;
      _referenceId = inv.referenceId;
      _isViewMode = inv.status == 'PAID' || inv.status == 'PARTIAL';
      if (inv.items != null) _items.addAll(inv.items!);
    } else {
      final ts = DateTime.now().millisecondsSinceEpoch;
      _invoiceNoController = TextEditingController(
        text: 'APINV${ts.toString().substring(8)}',
      );
      _remarkController = TextEditingController();
      _dueDate = DateTime.now().add(const Duration(days: 30));
    }
  }

  @override
  void dispose() {
    _invoiceNoController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isEdit = widget.invoice != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    ref.watch(productListProvider);

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : const Color(0xFFF5F5F5),
      body: EscapePopScope(
        child: Column(
          children: [
            // ── Title Bar ─────────────────────────────────────────
            _APFormTitleBar(
              isEdit: isEdit,
              isView: _isViewMode,
              status: widget.invoice?.status,
            ),

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
                        iconColor: AppTheme.error,
                        title: 'ข้อมูลทั่วไป',
                        child: _buildGeneralSection(isDark),
                      ),
                      const SizedBox(height: 14),

                      // Section 2 — รายการสินค้า
                      _SectionCard(
                        icon: Icons.shopping_cart_outlined,
                        iconColor: AppTheme.info,
                        title: 'รายการสินค้า',
                        trailing: _isViewMode
                            ? null
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _SmallIconBtn(
                                    icon: _isCardView
                                        ? Icons.view_list_outlined
                                        : Icons.grid_view_outlined,
                                    tooltip: _isCardView
                                        ? 'List View'
                                        : 'Card View',
                                    isDark: isDark,
                                    onTap: () => setState(
                                      () => _isCardView = !_isCardView,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
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
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      elevation: 0,
                                    ),
                                  ),
                                ],
                              ),
                        child: _buildItemsSection(isDark),
                      ),
                      const SizedBox(height: 14),

                      // Section 3 — สรุปยอด
                      if (_items.isNotEmpty) ...[
                        _SectionCard(
                          icon: Icons.calculate_outlined,
                          iconColor: AppTheme.success,
                          title: 'สรุปยอด',
                          child: _buildSummarySection(isDark),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Section 4 — หมายเหตุ
                      _SectionCard(
                        icon: Icons.note_outlined,
                        iconColor: AppTheme.textSub,
                        title: 'หมายเหตุ',
                        child: _isViewMode
                            ? _ViewText(
                                text: _remarkController.text.isEmpty
                                    ? '-'
                                    : _remarkController.text,
                                isDark: isDark,
                              )
                            : _APTextField(
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
            Container(
              color: isDark ? AppTheme.darkTopBar : Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 14,
              ),
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
                      _isViewMode ? 'ปิด' : 'ยกเลิก',
                      style: TextStyle(
                        color: isDark ? Colors.white60 : AppTheme.textSub,
                      ),
                    ),
                  ),
                  if (!_isViewMode) ...[
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _saveInvoice,
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
                        isEdit ? 'บันทึก' : 'สร้างใบแจ้งหนี้',
                        style: const TextStyle(fontSize: 14),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.error,
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
  Widget _buildGeneralSection(bool isDark) {
    final suppliersAsync = ref.watch(supplierListProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // เลขที่ใบแจ้งหนี้ (read-only)
        _FieldLabel(label: 'เลขที่ใบแจ้งหนี้', isDark: isDark),
        const SizedBox(height: 6),
        _APTextField(
          controller: _invoiceNoController,
          hint: 'เลขที่ใบแจ้งหนี้',
          icon: Icons.receipt_outlined,
          isDark: isDark,
          readOnly: true,
        ),
        const SizedBox(height: 14),

        // วันที่ใบแจ้งหนี้
        _FieldLabel(label: 'วันที่ใบแจ้งหนี้', isDark: isDark),
        const SizedBox(height: 6),
        _DatePickerField(
          date: _invoiceDate,
          isDark: isDark,
          readOnly: _isViewMode,
          onTap: _isViewMode ? null : _selectInvoiceDate,
        ),
        const SizedBox(height: 14),

        // วันครบกำหนดชำระ
        _FieldLabel(label: 'วันครบกำหนดชำระ', isDark: isDark),
        const SizedBox(height: 6),
        _DatePickerField(
          date: _dueDate,
          placeholder: 'ไม่ระบุ',
          isDark: isDark,
          readOnly: _isViewMode,
          icon: Icons.event_outlined,
          highlightOverdue:
              _dueDate != null &&
              DateTime.now().isAfter(_dueDate!) &&
              !_isViewMode,
          onTap: _isViewMode ? null : _selectDueDate,
        ),
        const SizedBox(height: 14),

        // ซัพพลายเออร์
        _FieldLabel(label: 'ซัพพลายเออร์ *', isDark: isDark),
        const SizedBox(height: 6),
        if (_isViewMode)
          _ViewText(text: _supplierName ?? '-', isDark: isDark)
        else
          suppliersAsync.when(
            data: (suppliers) => _APDropdown<String>(
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
              color: AppTheme.error,
              backgroundColor: isDark ? AppTheme.darkElement : AppTheme.border,
            ),
            error: (_, _) => Text(
              'โหลดซัพพลายเออร์ไม่สำเร็จ',
              style: TextStyle(color: AppTheme.error, fontSize: 12),
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
                Icons.add_shopping_cart_outlined,
                size: 48,
                color: isDark ? const Color(0xFF444444) : Colors.grey[300],
              ),
              const SizedBox(height: 8),
              Text(
                _isViewMode
                    ? 'ไม่มีรายการสินค้า'
                    : 'ยังไม่มีรายการสินค้า\nกดปุ่ม "เพิ่ม" เพื่อเพิ่มสินค้า',
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

  Widget _buildItemCard(ApInvoiceItemModel item, int index, bool isDark) {
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
                        item.productName,
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
                        item.productCode,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white54 : AppTheme.textSub,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_isViewMode)
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
            Row(
              children: [
                Expanded(
                  child: _ItemStat(
                    label: 'จำนวน',
                    value: '${item.quantity.toStringAsFixed(0)} ${item.unit}',
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

  Widget _buildItemRow(ApInvoiceItemModel item, int index, bool isDark) {
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  item.productCode,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.white54 : AppTheme.textSub,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 56,
            child: Text(
              '${item.quantity.toStringAsFixed(0)} ${item.unit}',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
          ),
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
          if (!_isViewMode)
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
            )
          else
            const SizedBox(width: 23),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Summary Section
  // ─────────────────────────────────────────────────────────────
  Widget _buildSummarySection(bool isDark) {
    final subtotal = _items.fold<double>(0, (s, item) => s + item.amount);
    final vat = _includeVat ? subtotal * 0.07 : 0.0;
    final total = subtotal + vat;
    final fmt = NumberFormat('#,##0.00', 'th_TH');

    return Column(
      children: [
        if (!_isViewMode)
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
                activeThumbColor: AppTheme.error,
                activeTrackColor: AppTheme.error.withValues(alpha: 0.4),
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
                color: AppTheme.error,
              ),
            ),
          ],
        ),

        // แสดงสถานะการชำระ (view mode)
        if (_isViewMode && widget.invoice != null) ...[
          Divider(height: 20, color: isDark ? Colors.white12 : AppTheme.border),
          _SummaryRow(
            label: 'จ่ายแล้ว',
            value: '฿${fmt.format(widget.invoice!.paidAmount)}',
            isDark: isDark,
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ค้างชำระ',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : AppTheme.textSub,
                ),
              ),
              Text(
                '฿${fmt.format(widget.invoice!.remainingAmount)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: widget.invoice!.remainingAmount > 0
                      ? AppTheme.error
                      : AppTheme.success,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Date pickers
  // ─────────────────────────────────────────────────────────────
  Future<void> _selectInvoiceDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _invoiceDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date != null) setState(() => _invoiceDate = date);
  }

  Future<void> _selectDueDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (date != null) setState(() => _dueDate = date);
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
    final result = await showDialog<ApInvoiceItemModel>(
      context: context,
      builder: (context) =>
          _APItemDialog(products: products, lineNo: _items.length + 1),
    );
    if (result != null) setState(() => _items.add(result));
  }

  // ─────────────────────────────────────────────────────────────
  // Save
  // ─────────────────────────────────────────────────────────────
  Future<void> _saveInvoice() async {
    if (!_formKey.currentState!.validate()) return;

    if (_supplierId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณาเลือกซัพพลายเออร์'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

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
    final total = subtotal + (_includeVat ? subtotal * 0.07 : 0.0);

    final invoice = ApInvoiceModel(
      invoiceId: widget.invoice?.invoiceId ?? '',
      invoiceNo: _invoiceNoController.text.trim(),
      invoiceDate: _invoiceDate,
      dueDate: _dueDate,
      supplierId: _supplierId!,
      supplierName: _supplierName!,
      totalAmount: total,
      paidAmount: widget.invoice?.paidAmount ?? 0,
      referenceType: _referenceType,
      referenceId: _referenceId,
      status: widget.invoice?.status ?? 'UNPAID',
      remark: _remarkController.text.trim().isEmpty
          ? null
          : _remarkController.text.trim(),
      createdAt: widget.invoice?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      items: _items,
    );

    final success = widget.invoice == null
        ? await ref.read(apInvoiceListProvider.notifier).createInvoice(invoice)
        : await ref.read(apInvoiceListProvider.notifier).updateInvoice(invoice);

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.invoice == null
                  ? 'สร้างใบแจ้งหนี้สำเร็จ'
                  : 'แก้ไขใบแจ้งหนี้สำเร็จ',
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
class _APFormTitleBar extends StatelessWidget {
  final bool isEdit;
  final bool isView;
  final String? status;
  const _APFormTitleBar({
    required this.isEdit,
    required this.isView,
    this.status,
  });

  String get _title {
    if (isView) return 'รายละเอียดใบแจ้งหนี้';
    if (isEdit) return 'แก้ไขใบแจ้งหนี้';
    return 'สร้างใบแจ้งหนี้';
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'UNPAID':
        return AppTheme.error;
      case 'PARTIAL':
        return AppTheme.warning;
      case 'PAID':
        return AppTheme.success;
      default:
        return AppTheme.textSub;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'UNPAID':
        return 'ยังไม่จ่าย';
      case 'PARTIAL':
        return 'จ่ายบางส่วน';
      case 'PAID':
        return 'จ่ายครบแล้ว';
      default:
        return s;
    }
  }

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
              color: AppTheme.error.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              color: AppTheme.error,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1A1A1A),
              ),
            ),
          ),
          if (status != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _statusColor(status!).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _statusColor(status!),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _statusLabel(status!),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _statusColor(status!),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
          ],
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
// Item Dialog
// ════════════════════════════════════════════════════════════════
class _APItemDialog extends ConsumerStatefulWidget {
  final List products;
  final int lineNo;
  const _APItemDialog({required this.products, required this.lineNo});

  @override
  ConsumerState<_APItemDialog> createState() => _APItemDialogState();
}

class _APItemDialogState extends ConsumerState<_APItemDialog> {
  String? _selectedProductId;
  String _search = '';
  final _qtyCtrl = TextEditingController(text: '1');
  final _priceCtrl = TextEditingController(text: '0');

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = widget.products
        .where(
          (p) =>
              p.productName.toLowerCase().contains(_search) ||
              p.productCode.toLowerCase().contains(_search),
        )
        .toList();

    return Dialog(
      backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 580),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: isDark ? 0.10 : 0.06),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.add_shopping_cart,
                    size: 18,
                    color: AppTheme.error,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'เพิ่มรายการสินค้า',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.error,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      size: 18,
                      color: isDark ? Colors.white54 : AppTheme.textSub,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search
                    _FieldLabel(label: 'สินค้า', isDark: isDark),
                    const SizedBox(height: 4),
                    TextField(
                      onChanged: (v) =>
                          setState(() => _search = v.toLowerCase()),
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        hintText: 'ค้นหาสินค้า...',
                        hintStyle: const TextStyle(fontSize: 12),
                        prefixIcon: const Icon(Icons.search, size: 18),
                        filled: true,
                        fillColor: isDark
                            ? AppTheme.darkElement
                            : const Color(0xFFF5F5F5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Product list
                    Container(
                      height: 160,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF3A3A3A)
                              : AppTheme.border,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (ctx, i) {
                          final p = filtered[i];
                          final isSelected = _selectedProductId == p.productId;
                          return InkWell(
                            onTap: () => setState(
                              () => _selectedProductId = p.productId,
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              color: isSelected
                                  ? AppTheme.error.withValues(alpha: 0.10)
                                  : null,
                              child: Row(
                                children: [
                                  if (isSelected)
                                    const Icon(
                                      Icons.check_circle,
                                      size: 14,
                                      color: AppTheme.error,
                                    )
                                  else
                                    const SizedBox(width: 14),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${p.productCode} - ${p.productName}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black87,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Qty + Price
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _FieldLabel(label: 'จำนวน', isDark: isDark),
                              const SizedBox(height: 4),
                              _APDialogTextField(
                                controller: _qtyCtrl,
                                keyboardType: TextInputType.number,
                                isDark: isDark,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _FieldLabel(label: 'ราคา/หน่วย', isDark: isDark),
                              const SizedBox(height: 4),
                              _APDialogTextField(
                                controller: _priceCtrl,
                                keyboardType: TextInputType.number,
                                isDark: isDark,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Actions
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: const Text('ยกเลิก'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.error,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: const Text('เพิ่ม'),
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

  void _submit() {
    if (_selectedProductId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณาเลือกสินค้า'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final qty = double.tryParse(_qtyCtrl.text) ?? 0;
    final price = double.tryParse(_priceCtrl.text) ?? 0;
    if (qty <= 0 || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณาระบุจำนวนและราคาที่ถูกต้อง'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final product = widget.products.firstWhere(
      (p) => p.productId == _selectedProductId,
    );
    Navigator.pop(
      context,
      ApInvoiceItemModel(
        itemId: '',
        invoiceId: '',
        lineNo: widget.lineNo,
        productId: product.productId,
        productCode: product.productCode,
        productName: product.productName,
        unit: product.baseUnit,
        quantity: qty,
        unitPrice: price,
        amount: qty * price,
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// Shared helper widgets (file-private)
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
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  final bool isDark;
  const _FieldLabel({required this.label, required this.isDark});
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

class _APTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final int maxLines;
  final bool isDark;
  final bool readOnly;

  const _APTextField({
    required this.controller,
    required this.hint,
    required this.icon,
    required this.isDark,
    this.maxLines = 1,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    maxLines: maxLines,
    readOnly: readOnly,
    style: TextStyle(
      fontSize: 13,
      color: isDark
          ? (readOnly ? Colors.white38 : Colors.white)
          : (readOnly ? Colors.black38 : Colors.black87),
    ),
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
        borderSide: const BorderSide(color: AppTheme.error, width: 1.5),
      ),
      filled: true,
      fillColor: readOnly
          ? (isDark ? AppTheme.darkElement : const Color(0xFFF5F5F5))
          : (isDark ? AppTheme.darkElement : Colors.white),
    ),
  );
}

class _APDropdown<T> extends StatelessWidget {
  final T? value;
  final String hint;
  final IconData icon;
  final bool isDark;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String? Function(T?)? validator;

  const _APDropdown({
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
        borderSide: const BorderSide(color: AppTheme.error, width: 1.5),
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

class _DatePickerField extends StatelessWidget {
  final DateTime? date;
  final String? placeholder;
  final bool isDark;
  final bool readOnly;
  final bool highlightOverdue;
  final IconData icon;
  final VoidCallback? onTap;

  const _DatePickerField({
    required this.date,
    required this.isDark,
    this.placeholder,
    this.readOnly = false,
    this.highlightOverdue = false,
    this.icon = Icons.calendar_today_outlined,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = highlightOverdue
        ? AppTheme.error
        : (isDark ? Colors.white : Colors.black87);

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: readOnly ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkElement : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: highlightOverdue
                ? AppTheme.error.withValues(alpha: 0.5)
                : (isDark ? Colors.white24 : AppTheme.border),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 17,
              color: highlightOverdue
                  ? AppTheme.error
                  : (isDark ? Colors.white54 : AppTheme.textSub),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                date != null
                    ? DateFormat('dd/MM/yyyy').format(date!)
                    : (placeholder ?? '-'),
                style: TextStyle(fontSize: 13, color: textColor),
              ),
            ),
            if (!readOnly)
              Icon(
                Icons.chevron_right,
                size: 18,
                color: isDark ? Colors.white38 : AppTheme.textSub,
              ),
          ],
        ),
      ),
    );
  }
}

class _ViewText extends StatelessWidget {
  final String text;
  final bool isDark;
  const _ViewText({required this.text, required this.isDark});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    decoration: BoxDecoration(
      color: isDark ? AppTheme.darkElement : const Color(0xFFF5F5F5),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: isDark ? Colors.white12 : AppTheme.border),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 13,
        color: isDark ? Colors.white70 : Colors.black87,
      ),
    ),
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
              ? AppTheme.error
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

class _APDialogTextField extends StatelessWidget {
  final TextEditingController controller;
  final TextInputType keyboardType;
  final bool isDark;

  const _APDialogTextField({
    required this.controller,
    required this.isDark,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: keyboardType,
    style: TextStyle(
      fontSize: 13,
      color: isDark ? Colors.white : Colors.black87,
    ),
    decoration: InputDecoration(
      filled: true,
      fillColor: isDark ? AppTheme.darkElement : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF3A3A3A) : AppTheme.border,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF3A3A3A) : AppTheme.border,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppTheme.error, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    ),
  );
}
