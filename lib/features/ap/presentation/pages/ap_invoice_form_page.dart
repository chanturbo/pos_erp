import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
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

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    if (widget.invoice != null) {
      final invoice = widget.invoice!;
      _invoiceNoController = TextEditingController(text: invoice.invoiceNo);
      _remarkController = TextEditingController(text: invoice.remark ?? '');
      _invoiceDate = invoice.invoiceDate;
      _dueDate = invoice.dueDate;
      _supplierId = invoice.supplierId;
      _supplierName = invoice.supplierName;
      _referenceType = invoice.referenceType;
      _referenceId = invoice.referenceId;
      _isViewMode = invoice.status == 'PAID';

      if (invoice.items != null) {
        _items.addAll(invoice.items!);
      }
    } else {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _invoiceNoController = TextEditingController(text: 'APINV${timestamp.toString().substring(8)}');
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
        actions: _isViewMode
            ? []
            : [
                IconButton(
                  icon: const Icon(Icons.help_outline),
                  onPressed: _showHelp,
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
    if (_isViewMode) return 'รายละเอียดใบแจ้งหนี้';
    if (widget.invoice == null) return 'สร้างใบแจ้งหนี้';
    return 'แก้ไขใบแจ้งหนี้';
  }

  Widget _buildHeaderCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ข้อมูลทั่วไป',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // เลขที่ใบแจ้งหนี้
            TextFormField(
              controller: _invoiceNoController,
              decoration: const InputDecoration(
                labelText: 'เลขที่ใบแจ้งหนี้',
                prefixIcon: Icon(Icons.receipt),
              ),
              readOnly: true,
              style: TextStyle(color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),

            // วันที่ใบแจ้งหนี้
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: const Text('วันที่ใบแจ้งหนี้'),
              subtitle: Text(DateFormat('dd/MM/yyyy').format(_invoiceDate)),
              trailing: _isViewMode ? null : const Icon(Icons.chevron_right),
              onTap: _isViewMode ? null : _selectInvoiceDate,
            ),

            // วันครบกำหนด
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_available),
              title: const Text('วันครบกำหนดชำระ'),
              subtitle: Text(_dueDate != null ? DateFormat('dd/MM/yyyy').format(_dueDate!) : 'ไม่ระบุ'),
              trailing: _isViewMode ? null : const Icon(Icons.chevron_right),
              onTap: _isViewMode ? null : _selectDueDate,
            ),

            const Divider(),

            // ซัพพลายเออร์
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.business),
              title: const Text('ซัพพลายเออร์'),
              subtitle: Text(_supplierName ?? 'เลือกซัพพลายเออร์'),
              trailing: _isViewMode ? null : const Icon(Icons.chevron_right),
              onTap: _isViewMode ? null : _selectSupplier,
            ),

            const Divider(),

            // หมายเหตุ
            if (_isViewMode)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.note),
                title: const Text('หมายเหตุ'),
                subtitle: Text(_remarkController.text.isEmpty ? '-' : _remarkController.text),
              )
            else
              TextFormField(
                controller: _remarkController,
                decoration: const InputDecoration(
                  labelText: 'หมายเหตุ',
                  prefixIcon: Icon(Icons.note),
                ),
                maxLines: 2,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'รายการสินค้า',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (!_isViewMode && _supplierId != null)
                  ElevatedButton.icon(
                    onPressed: _addItem,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('เพิ่มสินค้า'),
                    style: ElevatedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
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
                      Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        _supplierId == null ? 'กรุณาเลือกซัพพลายเออร์ก่อน' : 'ยังไม่มีรายการสินค้า',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              ..._items.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return _buildItemRow(item, index);
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildItemRow(ApInvoiceItemModel item, int index) {
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
                      Text(
                        item.productName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        item.productCode,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                if (!_isViewMode)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        _items.removeAt(index);
                      });
                    },
                  ),
              ],
            ),
            const Divider(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('จำนวน', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                      const SizedBox(height: 2),
                      Text(
                        '${item.quantity.toStringAsFixed(0)} ${item.unit}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ราคา/หน่วย', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                      const SizedBox(height: 2),
                      Text(
                        '฿${item.unitPrice.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('รวม', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                      const SizedBox(height: 2),
                      Text(
                        '฿${item.amount.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final totalAmount = _items.fold<double>(0, (sum, item) => sum + item.amount);

    return Card(
      color: Colors.blue.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('จำนวนรายการ', style: TextStyle(fontSize: 14)),
                Text(
                  '${_items.length} รายการ',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('ยอดรวมทั้งสิ้น', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text(
                  '฿${totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

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
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('บันทึก'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectInvoiceDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _invoiceDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() {
        _invoiceDate = date;
      });
    }
  }

  Future<void> _selectDueDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() {
        _dueDate = date;
      });
    }
  }

  Future<void> _selectSupplier() async {
    final suppliersAsync = ref.read(supplierListProvider);

    await suppliersAsync.when(
      data: (suppliers) async {
        final selected = await showDialog<Map<String, String>>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('เลือกซัพพลายเออร์'),
            content: SizedBox(
              width: 400,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: suppliers.length,
                itemBuilder: (context, index) {
                  final supplier = suppliers[index];
                  return ListTile(
                    title: Text(supplier.supplierName),
                    subtitle: Text(supplier.supplierCode),
                    onTap: () {
                      Navigator.pop(context, {
                        'id': supplier.supplierId,
                        'name': supplier.supplierName,
                      });
                    },
                  );
                },
              ),
            ),
          ),
        );

        if (selected != null) {
          setState(() {
            _supplierId = selected['id'];
            _supplierName = selected['name'];
          });
        }
      },
      loading: () {},
      error: (error, stack) {},
    );
  }

  Future<void> _addItem() async {
    final productsAsync = ref.read(productListProvider);

    await productsAsync.when(
      data: (products) async {
        final result = await showDialog<ApInvoiceItemModel>(
          context: context,
          builder: (context) => _ItemDialog(
            products: products,
            lineNo: _items.length + 1,
          ),
        );

        if (result != null) {
          setState(() {
            _items.add(result);
          });
        }
      },
      loading: () {},
      error: (error, stack) {},
    );
  }

  Future<void> _saveInvoice() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณาเพิ่มรายการสินค้า'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_supplierId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณาเลือกซัพพลายเออร์'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final totalAmount = _items.fold<double>(0, (sum, item) => sum + item.amount);

    final invoice = ApInvoiceModel(
      invoiceId: widget.invoice?.invoiceId ?? '',
      invoiceNo: _invoiceNoController.text.trim(),
      invoiceDate: _invoiceDate,
      dueDate: _dueDate,
      supplierId: _supplierId!,
      supplierName: _supplierName!,
      totalAmount: totalAmount,
      paidAmount: widget.invoice?.paidAmount ?? 0,
      referenceType: _referenceType,
      referenceId: _referenceId,
      status: widget.invoice?.status ?? 'UNPAID',
      remark: _remarkController.text.trim().isEmpty ? null : _remarkController.text.trim(),
      createdAt: widget.invoice?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      items: _items,
    );

    final success = widget.invoice == null
        ? await ref.read(apInvoiceListProvider.notifier).createInvoice(invoice)
        : await ref.read(apInvoiceListProvider.notifier).updateInvoice(invoice);

    setState(() {
      _isLoading = false;
    });

    if (mounted) {
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.invoice == null ? 'สร้างใบแจ้งหนี้สำเร็จ' : 'แก้ไขใบแจ้งหนี้สำเร็จ',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('บันทึกไม่สำเร็จ'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('คำแนะนำ'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'ใบแจ้งหนี้ (AP Invoice)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 8),
              Text('บันทึกหนี้ที่เราต้องจ่ายให้ซัพพลายเออร์'),
              SizedBox(height: 16),
              Text(
                'วันครบกำหนด',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 8),
              Text('วันที่ต้องชำระเงินให้ซัพพลายเออร์'),
              SizedBox(height: 16),
              Text(
                'การจ่ายเงิน',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 8),
              Text('ใช้เมนู "จ่ายเงินซัพพลายเออร์" เพื่อบันทึกการจ่ายเงิน'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ปิด'),
          ),
        ],
      ),
    );
  }
}

// Item Dialog
class _ItemDialog extends ConsumerStatefulWidget {
  final List products;
  final int lineNo;

  const _ItemDialog({
    required this.products,
    required this.lineNo,
  });

  @override
  ConsumerState<_ItemDialog> createState() => _ItemDialogState();
}

class _ItemDialogState extends ConsumerState<_ItemDialog> {
  String? _selectedProductId;
  final _quantityController = TextEditingController(text: '1');
  final _unitPriceController = TextEditingController(text: '0');

  @override
  void dispose() {
    _quantityController.dispose();
    _unitPriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('เพิ่มรายการสินค้า'),
      content: SizedBox(
        width: 450,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'สินค้า *'),
                items: widget.products.map<DropdownMenuItem<String>>((product) {
                  return DropdownMenuItem<String>(
                    value: product.productId,
                    child: Text('${product.productCode} - ${product.productName}'),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedProductId = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _quantityController,
                decoration: const InputDecoration(labelText: 'จำนวน *'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _unitPriceController,
                decoration: const InputDecoration(labelText: 'ราคา/หน่วย *'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ยกเลิก'),
        ),
        ElevatedButton(
          onPressed: _addItem,
          child: const Text('เพิ่ม'),
        ),
      ],
    );
  }

  void _addItem() {
    if (_selectedProductId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณาเลือกสินค้า'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final quantity = double.tryParse(_quantityController.text) ?? 0;
    final unitPrice = double.tryParse(_unitPriceController.text) ?? 0;

    if (quantity <= 0 || unitPrice <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณาระบุจำนวนและราคาที่ถูกต้อง'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final product = widget.products.firstWhere((p) => p.productId == _selectedProductId);

    final item = ApInvoiceItemModel(
      itemId: '',
      invoiceId: '',
      lineNo: widget.lineNo,
      productId: product.productId,
      productCode: product.productCode,
      productName: product.productName,
      unit: product.baseUnit,
      quantity: quantity,
      unitPrice: unitPrice,
      amount: quantity * unitPrice,
    );

    Navigator.pop(context, item);
  }
}