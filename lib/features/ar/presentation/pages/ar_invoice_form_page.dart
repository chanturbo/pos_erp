import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pos_erp/shared/theme/app_theme.dart';
import 'package:pos_erp/shared/utils/responsive_utils.dart';
import 'package:pos_erp/shared/widgets/escape_pop_scope.dart';
import 'package:pos_erp/shared/widgets/mobile_home_button.dart';
import '../../../customers/presentation/providers/customer_provider.dart';
import '../../../products/presentation/providers/product_provider.dart';
import '../../../../core/client/api_client.dart';
import '../../data/models/ar_invoice_model.dart';
import '../providers/ar_invoice_provider.dart';
import '../providers/ar_receipt_provider.dart';
import 'ar_receipt_form_page.dart';

class ArInvoiceFormPage extends ConsumerStatefulWidget {
  final ArInvoiceModel? invoice;

  const ArInvoiceFormPage({super.key, this.invoice});

  @override
  ConsumerState<ArInvoiceFormPage> createState() => _ArInvoiceFormPageState();
}

class _ArInvoiceFormPageState extends ConsumerState<ArInvoiceFormPage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _invoiceNoController;
  late TextEditingController _remarkController;

  DateTime _invoiceDate = DateTime.now();
  DateTime? _dueDate;
  String? _customerId;
  String? _customerName;
  String? _referenceType;
  String? _referenceId;

  final List<ArInvoiceItemModel> _items = [];
  bool _isLoading = false;
  bool _isLoadingItems = false;
  bool _isViewMode = false;
  bool _isCardView = false;

  @override
  void initState() {
    super.initState();
    _initControllers();
    // list API ไม่ return items — โหลดจาก detail endpoint เมื่อเปิดแก้ไข
    if (widget.invoice != null && (widget.invoice!.items == null || widget.invoice!.items!.isEmpty)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadItemsFromDetail());
    }
  }

  Future<void> _loadItemsFromDetail() async {
    if (!mounted) return;
    setState(() => _isLoadingItems = true);
    try {
      // เรียก API โดยตรง — ไม่ใช้ cached provider เพื่อให้ได้ข้อมูลล่าสุดเสมอ
      final apiClient = ref.read(apiClientProvider);
      final res = await apiClient.get(
        '/api/ar-invoices/${widget.invoice!.invoiceId}',
      );
      if (mounted && res.statusCode == 200 && res.data['data'] != null) {
        final detail = ArInvoiceModel.fromJson(
          res.data['data'] as Map<String, dynamic>,
        );
        if (detail.items != null && detail.items!.isNotEmpty) {
          setState(() {
            _items.clear();
            _items.addAll(detail.items!);
          });
        }
      }
    } catch (e) {
      // ไม่ขึ้น error ใน UI — items จะเป็น [] และผู้ใช้สามารถเพิ่มเองได้
      debugPrint('⚠️ _loadItemsFromDetail: $e');
    } finally {
      if (mounted) setState(() => _isLoadingItems = false);
    }
  }

  void _initControllers() {
    if (widget.invoice != null) {
      final inv = widget.invoice!;
      _invoiceNoController = TextEditingController(text: inv.invoiceNo);
      _remarkController = TextEditingController(text: inv.remark ?? '');
      _invoiceDate = inv.invoiceDate;
      _dueDate = inv.dueDate;
      _customerId = inv.customerId;
      _customerName = inv.customerName;
      _referenceType = inv.referenceType;
      _referenceId = inv.referenceId;
      _isViewMode = inv.status == 'PAID';
      if (inv.items != null) _items.addAll(inv.items!);
    } else {
      final ts = DateTime.now().millisecondsSinceEpoch;
      _invoiceNoController = TextEditingController(
        text: 'ARINV${ts.toString().substring(8)}',
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
            _ArFormTitleBar(
              isEdit: isEdit,
              isView: _isViewMode,
              status: widget.invoice?.status,
              invoice: widget.invoice,
              onReceive: widget.invoice == null || widget.invoice!.isFullyPaid
                  ? null
                  : () => _createReceipt(widget.invoice!),
            ),
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _SectionCard(
                        icon: Icons.receipt_long_outlined,
                        iconColor: AppTheme.primary,
                        title: 'ข้อมูลทั่วไป',
                        child: _buildGeneralSection(isDark),
                      ),
                      const SizedBox(height: 14),
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
                      if (_items.isNotEmpty) ...[
                        _SectionCard(
                          icon: Icons.calculate_outlined,
                          iconColor: AppTheme.success,
                          title: 'สรุปยอด',
                          child: _buildSummarySection(isDark),
                        ),
                        const SizedBox(height: 14),
                      ],
                      if (_isViewMode && widget.invoice != null) ...[
                        _SectionCard(
                          icon: Icons.account_balance_wallet_outlined,
                          iconColor: AppTheme.info,
                          title: 'สถานะการรับเงิน',
                          child: _buildPaymentStatusSection(
                            isDark,
                            widget.invoice!,
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
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
                            : _ArTextField(
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
            if (!_isViewMode)
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
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.pop(context),
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

  Widget _buildGeneralSection(bool isDark) {
    final customersAsync = ref.watch(customerListProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label: 'เลขที่ใบแจ้งหนี้', isDark: isDark),
        const SizedBox(height: 6),
        _ArTextField(
          controller: _invoiceNoController,
          hint: 'เลขที่ใบแจ้งหนี้',
          icon: Icons.receipt_outlined,
          isDark: isDark,
          readOnly: true,
        ),
        const SizedBox(height: 14),
        _FieldLabel(label: 'วันที่ใบแจ้งหนี้', isDark: isDark),
        const SizedBox(height: 6),
        _DatePickerField(
          date: _invoiceDate,
          isDark: isDark,
          readOnly: _isViewMode,
          onTap: _isViewMode ? null : _selectInvoiceDate,
        ),
        const SizedBox(height: 14),
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
        _FieldLabel(label: 'ลูกค้า *', isDark: isDark),
        const SizedBox(height: 6),
        if (_isViewMode)
          _ViewText(text: _customerName ?? '-', isDark: isDark)
        else
          customersAsync.when(
            data: (customers) => _ArDropdown<String>(
              value: _customerId,
              hint: 'เลือกลูกค้า',
              icon: Icons.person_outline,
              isDark: isDark,
              items: customers
                  .map(
                    (c) => DropdownMenuItem(
                      value: c.customerId,
                      child: Text(
                        c.customerName,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                final selected = customers.firstWhere((c) => c.customerId == v);
                setState(() {
                  _customerId = v;
                  _customerName = selected.customerName;
                });
              },
              validator: (v) => v == null ? 'กรุณาเลือกลูกค้า' : null,
            ),
            loading: () => LinearProgressIndicator(
              color: AppTheme.primary,
              backgroundColor: isDark ? AppTheme.darkElement : AppTheme.border,
            ),
            error: (_, _) => Text(
              'โหลดข้อมูลลูกค้าไม่สำเร็จ',
              style: TextStyle(color: AppTheme.error, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildItemsSection(bool isDark) {
    if (_isLoadingItems) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('กำลังโหลดรายการสินค้า...', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
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

  Widget _buildItemCard(ArInvoiceItemModel item, int index, bool isDark) {
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
                if (item.discountAmount > 0)
                  Expanded(
                    child: _ItemStat(
                      label: 'ส่วนลด',
                      value: '฿${fmt.format(item.discountAmount)}',
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

  Widget _buildItemRow(ArInvoiceItemModel item, int index, bool isDark) {
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
          if (item.discountAmount > 0)
            SizedBox(
              width: 70,
              child: Text(
                '-฿${fmt.format(item.discountAmount)}',
                style: const TextStyle(fontSize: 11, color: AppTheme.warning),
                textAlign: TextAlign.right,
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

  Widget _buildSummarySection(bool isDark) {
    final subtotal = _items.fold<double>(0, (s, item) => s + item.amount);
    final discount = _items.fold<double>(
      0,
      (s, item) => s + item.discountAmount,
    );
    final fmt = NumberFormat('#,##0.00', 'th_TH');

    return Column(
      children: [
        _SummaryRow(
          label: 'ยอดรวมก่อนหักส่วนลด',
          value: '฿${fmt.format(subtotal + discount)}',
          isDark: isDark,
        ),
        const SizedBox(height: 8),
        _SummaryRow(
          label: 'ส่วนลดรวม',
          value: '฿${fmt.format(discount)}',
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
              '฿${fmt.format(subtotal)}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
              ),
            ),
          ],
        ),
        if (_isViewMode && widget.invoice != null) ...[
          Divider(height: 20, color: isDark ? Colors.white12 : AppTheme.border),
          _SummaryRow(
            label: 'รับแล้ว',
            value: '฿${fmt.format(widget.invoice!.paidAmount)}',
            isDark: isDark,
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'คงค้าง',
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

  Widget _buildPaymentStatusSection(bool isDark, ArInvoiceModel invoice) {
    final fmt = NumberFormat('#,##0.00', 'th_TH');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: invoice.totalAmount > 0
                ? (invoice.paidAmount / invoice.totalAmount).clamp(0.0, 1.0)
                : 0,
            backgroundColor: isDark ? AppTheme.darkElement : Colors.grey[200],
            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.info),
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _AmountTile(
                label: 'ยอดรวม',
                value: '฿${fmt.format(invoice.totalAmount)}',
                labelColor: isDark ? const Color(0xFFAAAAAA) : AppTheme.textSub,
                valueColor: isDark ? Colors.white : const Color(0xFF1A1A1A),
              ),
            ),
            Expanded(
              child: _AmountTile(
                label: 'รับแล้ว',
                value: '฿${fmt.format(invoice.paidAmount)}',
                labelColor: isDark ? const Color(0xFFAAAAAA) : AppTheme.textSub,
                valueColor: AppTheme.success,
              ),
            ),
            Expanded(
              child: _AmountTile(
                label: 'คงค้าง',
                value: '฿${fmt.format(invoice.remainingAmount)}',
                labelColor: isDark ? const Color(0xFFAAAAAA) : AppTheme.textSub,
                valueColor: invoice.remainingAmount > 0
                    ? AppTheme.error
                    : AppTheme.success,
              ),
            ),
          ],
        ),
        if (!invoice.isFullyPaid) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _createReceipt(invoice),
              icon: const Icon(Icons.payments_outlined),
              label: const Text('บันทึกรับเงิน'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.info,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
            ),
          ),
        ],
      ],
    );
  }

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

  Future<void> _addItem() async {
    final products = ref.read(productListProvider).value;
    if (products == null) {
      _showSnack('กำลังโหลดข้อมูลสินค้า...', backgroundColor: AppTheme.warning);
      return;
    }

    final result = await showDialog<ArInvoiceItemModel>(
      context: context,
      builder: (context) =>
          _ArItemDialog(products: products, lineNo: _items.length + 1),
    );

    if (result != null) setState(() => _items.add(result));
  }

  Future<void> _saveInvoice() async {
    if (!_formKey.currentState!.validate()) return;

    if (_customerId == null) {
      _showSnack('กรุณาเลือกลูกค้า');
      return;
    }

    if (_items.isEmpty) {
      _showSnack('กรุณาเพิ่มรายการสินค้าอย่างน้อย 1 รายการ');
      return;
    }

    setState(() => _isLoading = true);

    final totalAmount = _items.fold<double>(0, (s, item) => s + item.amount);

    final invoice = ArInvoiceModel(
      invoiceId: widget.invoice?.invoiceId ?? '',
      invoiceNo: _invoiceNoController.text.trim(),
      invoiceDate: _invoiceDate,
      dueDate: _dueDate,
      customerId: _customerId!,
      customerName: _customerName!,
      totalAmount: totalAmount,
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
        ? await ref.read(arInvoiceListProvider.notifier).createInvoice(invoice)
        : await ref.read(arInvoiceListProvider.notifier).updateInvoice(invoice);

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (success) {
      Navigator.pop(context);
      _showSnack(
        widget.invoice == null
            ? 'สร้างใบแจ้งหนี้สำเร็จ'
            : 'แก้ไขใบแจ้งหนี้สำเร็จ',
        backgroundColor: AppTheme.success,
      );
    } else {
      _showSnack('บันทึกไม่สำเร็จ กรุณาลองใหม่');
    }
  }

  void _showSnack(String message, {Color backgroundColor = AppTheme.error}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _createReceipt(ArInvoiceModel invoice) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => ArReceiptFormPage(preselectedInvoice: invoice),
      ),
    );
    ref.read(arInvoiceListProvider.notifier).refresh();
    ref.read(arReceiptListProvider.notifier).refresh();
  }
}

class _ArFormTitleBar extends StatelessWidget {
  final bool isEdit;
  final bool isView;
  final String? status;
  final ArInvoiceModel? invoice;
  final VoidCallback? onReceive;

  const _ArFormTitleBar({
    required this.isEdit,
    required this.isView,
    this.status,
    this.invoice,
    this.onReceive,
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
        return 'ยังไม่รับ';
      case 'PARTIAL':
        return 'รับบางส่วน';
      case 'PAID':
        return 'รับครบแล้ว';
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
              color: AppTheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              color: AppTheme.primary,
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
          if (onReceive != null) ...[
            ElevatedButton.icon(
              onPressed: onReceive,
              icon: const Icon(Icons.payments_outlined, size: 16),
              label: const Text(
                'รับเงิน',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.info,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
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

class _ArItemDialog extends ConsumerStatefulWidget {
  final List products;
  final int lineNo;

  const _ArItemDialog({required this.products, required this.lineNo});

  @override
  ConsumerState<_ArItemDialog> createState() => _ArItemDialogState();
}

class _ArItemDialogState extends ConsumerState<_ArItemDialog> {
  String? _selectedProductId;
  String _search = '';
  final _qtyCtrl = TextEditingController(text: '1');
  final _priceCtrl = TextEditingController(text: '0');
  final _discountCtrl = TextEditingController(text: '0');

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    _discountCtrl.dispose();
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
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 620),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: isDark ? 0.10 : 0.06),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.add_shopping_cart,
                    size: 18,
                    color: AppTheme.primary,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'เพิ่มรายการสินค้า',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
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
                            onTap: () => setState(() {
                              _selectedProductId = p.productId;
                              _priceCtrl.text =
                                  p.sellPrice?.toStringAsFixed(2) ?? '0';
                            }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              color: isSelected
                                  ? AppTheme.primary.withValues(alpha: 0.10)
                                  : null,
                              child: Row(
                                children: [
                                  if (isSelected)
                                    const Icon(
                                      Icons.check_circle,
                                      size: 14,
                                      color: AppTheme.primary,
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
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _FieldLabel(label: 'จำนวน', isDark: isDark),
                              const SizedBox(height: 4),
                              _ArDialogTextField(
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
                              _ArDialogTextField(
                                controller: _priceCtrl,
                                keyboardType: TextInputType.number,
                                isDark: isDark,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FieldLabel(label: 'ส่วนลด', isDark: isDark),
                        const SizedBox(height: 4),
                        _ArDialogTextField(
                          controller: _discountCtrl,
                          keyboardType: TextInputType.number,
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
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
                        backgroundColor: AppTheme.primary,
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
    final discount = double.tryParse(_discountCtrl.text) ?? 0;

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
      ArInvoiceItemModel(
        itemId: '',
        invoiceId: '',
        lineNo: widget.lineNo,
        productId: product.productId,
        productCode: product.productCode,
        productName: product.productName,
        unit: product.baseUnit,
        quantity: qty,
        unitPrice: price,
        discountAmount: discount,
        amount: (qty * price) - discount,
      ),
    );
  }
}

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

class _ArTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final int maxLines;
  final bool isDark;
  final bool readOnly;

  const _ArTextField({
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
        borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
      ),
      filled: true,
      fillColor: readOnly
          ? (isDark ? AppTheme.darkElement : const Color(0xFFF5F5F5))
          : (isDark ? AppTheme.darkElement : Colors.white),
    ),
  );
}

class _ArDropdown<T> extends StatelessWidget {
  final T? value;
  final String hint;
  final IconData icon;
  final bool isDark;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String? Function(T?)? validator;

  const _ArDropdown({
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
              ? AppTheme.primary
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

class _ArDialogTextField extends StatelessWidget {
  final TextEditingController controller;
  final TextInputType keyboardType;
  final bool isDark;

  const _ArDialogTextField({
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
        borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    ),
  );
}

class _AmountTile extends StatelessWidget {
  final String label;
  final String value;
  final Color labelColor;
  final Color valueColor;

  const _AmountTile({
    required this.label,
    required this.value,
    required this.labelColor,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyle(fontSize: 10, color: labelColor)),
      Text(
        value,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: valueColor,
        ),
      ),
    ],
  );
}
