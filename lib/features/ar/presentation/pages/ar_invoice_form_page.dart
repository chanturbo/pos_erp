// ar_invoice_form_page.dart
// Day 36-38: AR Invoice Form Page — สร้าง/แก้ไขใบแจ้งหนี้ลูกค้า

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/models/ar_invoice_model.dart';
import '../providers/ar_invoice_provider.dart';
import '../providers/ar_receipt_provider.dart';
import '../../../customers/presentation/providers/customer_provider.dart';
import '../../../products/presentation/providers/product_provider.dart';
import 'ar_receipt_form_page.dart';

class ArInvoiceFormPage extends ConsumerStatefulWidget {
  final ArInvoiceModel? invoice;

  const ArInvoiceFormPage({super.key, this.invoice});

  @override
  ConsumerState<ArInvoiceFormPage> createState() =>
      _ArInvoiceFormPageState();
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
  bool _isViewMode = false;

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    if (widget.invoice != null) {
      final inv = widget.invoice!;
      _invoiceNoController = TextEditingController(text: inv.invoiceNo);
      _remarkController =
          TextEditingController(text: inv.remark ?? '');
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
          text: 'ARINV${ts.toString().substring(8)}');
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
    return Scaffold(
      appBar: AppBar(
        title: Text(_getTitle()),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          if (_isViewMode && widget.invoice != null)
            TextButton.icon(
              onPressed: widget.invoice!.isFullyPaid
                  ? null
                  : () => _createReceipt(widget.invoice!),
              icon: const Icon(Icons.payments, color: Colors.white),
              label: const Text('รับเงิน',
                  style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeaderCard(),
                    const SizedBox(height: 16),
                    _buildItemsCard(),
                    const SizedBox(height: 16),
                    if (_items.isNotEmpty) _buildSummaryCard(),
                    if (_isViewMode && widget.invoice != null)
                      _buildPaymentStatusCard(widget.invoice!),
                  ],
                ),
              ),
            ),
            if (!_isViewMode) _buildBottomActions(),
          ],
        ),
      ),
    );
  }

  String _getTitle() {
    if (_isViewMode) return 'รายละเอียดใบแจ้งหนี้ AR';
    if (widget.invoice == null) return 'สร้างใบแจ้งหนี้ AR';
    return 'แก้ไขใบแจ้งหนี้ AR';
  }

  // ─── Header Card ──────────────────────────────────────────────────────────
  Widget _buildHeaderCard() {
    return Card(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ข้อมูลทั่วไป',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // เลขที่ใบแจ้งหนี้
            TextFormField(
              controller: _invoiceNoController,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'เลขที่ใบแจ้งหนี้',
                prefixIcon: Icon(Icons.receipt),
              ),
              style: TextStyle(color: Colors.grey[700]),
            ),
            const SizedBox(height: 8),

            // วันที่
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today, color: Colors.teal),
              title: const Text('วันที่ใบแจ้งหนี้'),
              subtitle:
                  Text(DateFormat('dd/MM/yyyy').format(_invoiceDate)),
              trailing:
                  _isViewMode ? null : const Icon(Icons.chevron_right),
              onTap: _isViewMode ? null : _selectInvoiceDate,
            ),

            // วันครบกำหนด
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading:
                  const Icon(Icons.event_available, color: Colors.teal),
              title: const Text('วันครบกำหนดชำระ'),
              subtitle: Text(_dueDate != null
                  ? DateFormat('dd/MM/yyyy').format(_dueDate!)
                  : 'ไม่ระบุ'),
              trailing:
                  _isViewMode ? null : const Icon(Icons.chevron_right),
              onTap: _isViewMode ? null : _selectDueDate,
            ),

            const Divider(),

            // ลูกค้า
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person, color: Colors.teal),
              title: const Text('ลูกค้า'),
              subtitle: Text(_customerName ?? 'เลือกลูกค้า'),
              trailing:
                  _isViewMode ? null : const Icon(Icons.chevron_right),
              onTap: _isViewMode ? null : _selectCustomer,
            ),

            const Divider(),

            // หมายเหตุ
            if (_isViewMode)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.note_outlined),
                title: const Text('หมายเหตุ'),
                subtitle: Text(_remarkController.text.isEmpty
                    ? '-'
                    : _remarkController.text),
              )
            else
              TextFormField(
                controller: _remarkController,
                decoration: const InputDecoration(
                  labelText: 'หมายเหตุ',
                  prefixIcon: Icon(Icons.note_outlined),
                ),
                maxLines: 2,
              ),
          ],
        ),
      ),
    );
  }

  // ─── Items Card ───────────────────────────────────────────────────────────
  Widget _buildItemsCard() {
    return Card(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('รายการสินค้า',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                if (!_isViewMode && _customerId != null)
                  ElevatedButton.icon(
                    onPressed: _addItem,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('เพิ่มสินค้า'),
                    style: ElevatedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_items.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(Icons.inventory_2_outlined,
                          size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        _customerId == null
                            ? 'กรุณาเลือกลูกค้าก่อน'
                            : 'ยังไม่มีรายการสินค้า',
                        style: TextStyle(
                            fontSize: 16, color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              ..._items.asMap().entries.map((e) {
                return _buildItemRow(e.value, e.key);
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildItemRow(ArInvoiceItemModel item, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.grey[50],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.productName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold)),
                      Text(item.productCode,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                ),
                if (!_isViewMode)
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.red),
                    onPressed: () =>
                        setState(() => _items.removeAt(index)),
                  ),
              ],
            ),
            const Divider(height: 16),
            Row(
              children: [
                _buildItemDetail('จำนวน',
                    '${item.quantity.toStringAsFixed(0)} ${item.unit}'),
                _buildItemDetail('ราคา/หน่วย',
                    '฿${item.unitPrice.toStringAsFixed(2)}'),
                if (item.discountAmount > 0)
                  _buildItemDetail('ส่วนลด',
                      '฿${item.discountAmount.toStringAsFixed(2)}'),
                _buildItemDetail(
                    'รวม',
                    '฿${item.amount.toStringAsFixed(2)}',
                    color: Colors.teal),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemDetail(String label, String value,
      {Color? color}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color ?? Colors.black87)),
        ],
      ),
    );
  }

  // ─── Summary Card ─────────────────────────────────────────────────────────
  Widget _buildSummaryCard() {
    final total = _items.fold<double>(0, (s, i) => s + i.amount);
    final discount =
        _items.fold<double>(0, (s, i) => s + i.discountAmount);

    return Card(
      color: Colors.teal.withValues(alpha: 0.08),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSummaryRow('จำนวนรายการ', '${_items.length} รายการ'),
            if (discount > 0)
              _buildSummaryRow(
                  'ส่วนลดรวม', '฿${discount.toStringAsFixed(2)}',
                  color: Colors.orange),
            const Divider(),
            _buildSummaryRow(
                'ยอดรวมทั้งสิ้น', '฿${total.toStringAsFixed(2)}',
                color: Colors.teal, bold: true, fontSize: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value,
      {Color? color, bool bold = false, double fontSize = 14}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: fontSize)),
          Text(value,
              style: TextStyle(
                  fontSize: fontSize,
                  fontWeight:
                      bold ? FontWeight.bold : FontWeight.normal,
                  color: color)),
        ],
      ),
    );
  }

  // ─── Payment Status Card (view mode) ──────────────────────────────────────
  Widget _buildPaymentStatusCard(ArInvoiceModel invoice) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Card(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('สถานะการรับเงิน',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: invoice.totalAmount > 0
                    ? (invoice.paidAmount / invoice.totalAmount)
                        .clamp(0.0, 1.0)
                    : 0,
                backgroundColor: Colors.grey[200],
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Colors.teal),
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildAmountStat('ยอดรวม',
                      invoice.totalAmount, Colors.teal.shade700),
                  _buildAmountStat(
                      'รับแล้ว', invoice.paidAmount, Colors.green),
                  _buildAmountStat(
                    'คงค้าง',
                    invoice.remainingAmount,
                    invoice.remainingAmount > 0
                        ? Colors.orange
                        : Colors.grey,
                  ),
                ],
              ),
              if (!invoice.isFullyPaid) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _createReceipt(invoice),
                    icon: const Icon(Icons.payments),
                    label: const Text('บันทึกรับเงิน'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAmountStat(String label, double amount, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          Text('฿${amount.toStringAsFixed(2)}',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: color)),
        ],
      ),
    );
  }

  // ─── Bottom Actions ───────────────────────────────────────────────────────
  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ยกเลิก'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: _isLoading ? null : _saveInvoice,
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child:
                          CircularProgressIndicator(strokeWidth: 2))
                  : const Text('บันทึก'),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Actions ──────────────────────────────────────────────────────────────
  Future<void> _selectInvoiceDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _invoiceDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) setState(() => _invoiceDate = d);
  }

  Future<void> _selectDueDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate:
          _dueDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (d != null) setState(() => _dueDate = d);
  }

  Future<void> _selectCustomer() async {
    final customersAsync = ref.read(customerListProvider);
    await customersAsync.when(
      data: (customers) async {
        final selected = await showDialog<Map<String, String>>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('เลือกลูกค้า'),
            content: SizedBox(
              width: 400,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: customers.length,
                itemBuilder: (ctx, i) {
                  final c = customers[i];
                  return ListTile(
                    leading:
                        const Icon(Icons.person, color: Colors.teal),
                    title: Text(c.customerName),
                    subtitle: Text(c.customerCode),
                    onTap: () => Navigator.pop(ctx, {
                      'id': c.customerId,
                      'name': c.customerName,
                    }),
                  );
                },
              ),
            ),
          ),
        );
        if (selected != null) {
          setState(() {
            _customerId = selected['id'];
            _customerName = selected['name'];
          });
        }
      },
      loading: () {},
      error: (err, stack) {},
    );
  }

  Future<void> _addItem() async {
    final productsAsync = ref.read(productListProvider);
    await productsAsync.when(
      data: (products) async {
        final result = await showDialog<ArInvoiceItemModel>(
          context: context,
          builder: (ctx) => _ArItemDialog(
            products: products,
            lineNo: _items.length + 1,
          ),
        );
        if (result != null) setState(() => _items.add(result));
      },
      loading: () {},
      error: (err, stack) {},
    );
  }

  Future<void> _saveInvoice() async {
    if (!_formKey.currentState!.validate()) return;

    if (_customerId == null) {
      _showError('กรุณาเลือกลูกค้า');
      return;
    }

    if (_items.isEmpty) {
      _showError('กรุณาเพิ่มรายการสินค้า');
      return;
    }

    setState(() => _isLoading = true);

    final totalAmount =
        _items.fold<double>(0, (s, i) => s + i.amount);

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
        ? await ref
            .read(arInvoiceListProvider.notifier)
            .createInvoice(invoice)
        : await ref
            .read(arInvoiceListProvider.notifier)
            .updateInvoice(invoice);

    setState(() => _isLoading = false);

    if (mounted) {
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.invoice == null
              ? '✅ สร้างใบแจ้งหนี้สำเร็จ'
              : '✅ แก้ไขใบแจ้งหนี้สำเร็จ'),
          backgroundColor: Colors.green,
        ));
      } else {
        _showError('บันทึกไม่สำเร็จ กรุณาลองใหม่');
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red));
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

// ─── Item Dialog ─────────────────────────────────────────────────────────────
class _ArItemDialog extends ConsumerStatefulWidget {
  final List products;
  final int lineNo;

  const _ArItemDialog({required this.products, required this.lineNo});

  @override
  ConsumerState<_ArItemDialog> createState() => _ArItemDialogState();
}

class _ArItemDialogState extends ConsumerState<_ArItemDialog> {
  String? _selectedProductId;
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
    final qty = double.tryParse(_qtyCtrl.text) ?? 0;
    final price = double.tryParse(_priceCtrl.text) ?? 0;
    final discount = double.tryParse(_discountCtrl.text) ?? 0;
    final total = (qty * price) - discount;

    return AlertDialog(
      title: const Text('เพิ่มรายการสินค้า'),
      content: SizedBox(
        width: 450,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                decoration:
                    const InputDecoration(labelText: 'สินค้า *'),
                items: widget.products
                    .map<DropdownMenuItem<String>>((p) {
                  return DropdownMenuItem<String>(
                    value: p.productId,
                    child: Text(
                      '${p.productCode} - ${p.productName}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedProductId = val;
                    final p = widget.products
                        .firstWhere((x) => x.productId == val);
                    _priceCtrl.text =
                        p.sellPrice?.toStringAsFixed(2) ?? '0';
                  });
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _qtyCtrl,
                decoration: const InputDecoration(labelText: 'จำนวน *'),
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _priceCtrl,
                decoration:
                    const InputDecoration(labelText: 'ราคา/หน่วย *'),
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _discountCtrl,
                decoration:
                    const InputDecoration(labelText: 'ส่วนลด'),
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('ยอดรวม',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      '฿${total.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก')),
        ElevatedButton(
          onPressed: _confirm,
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white),
          child: const Text('เพิ่ม'),
        ),
      ],
    );
  }

  void _confirm() {
    if (_selectedProductId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('กรุณาเลือกสินค้า'),
          backgroundColor: Colors.red));
      return;
    }

    final qty = double.tryParse(_qtyCtrl.text) ?? 0;
    final price = double.tryParse(_priceCtrl.text) ?? 0;
    final discount = double.tryParse(_discountCtrl.text) ?? 0;

    if (qty <= 0 || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('กรุณาระบุจำนวนและราคา'),
          backgroundColor: Colors.red));
      return;
    }

    final p = widget.products
        .firstWhere((x) => x.productId == _selectedProductId);

    final item = ArInvoiceItemModel(
      itemId: '',
      invoiceId: '',
      lineNo: widget.lineNo,
      productId: p.productId,
      productCode: p.productCode,
      productName: p.productName,
      unit: p.baseUnit,
      quantity: qty,
      unitPrice: price,
      discountAmount: discount,
      amount: (qty * price) - discount,
    );

    Navigator.pop(context, item);
  }
}