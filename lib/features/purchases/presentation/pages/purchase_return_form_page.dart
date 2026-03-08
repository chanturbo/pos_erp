import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/models/purchase_return_model.dart';
import '../../data/models/purchase_return_item_model.dart';
import '../providers/purchase_return_provider.dart';
import '../../../suppliers/presentation/providers/supplier_provider.dart';
import '../../../products/presentation/providers/product_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class PurchaseReturnFormPage extends ConsumerStatefulWidget {
  final PurchaseReturnModel? returnDoc;

  const PurchaseReturnFormPage({super.key, this.returnDoc});

  @override
  ConsumerState<PurchaseReturnFormPage> createState() => _PurchaseReturnFormPageState();
}

class _PurchaseReturnFormPageState extends ConsumerState<PurchaseReturnFormPage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _returnNoController;
  late TextEditingController _reasonController;
  late TextEditingController _remarkController;

  DateTime _returnDate = DateTime.now();
  String? _supplierId;
  String? _supplierName;

  final List<PurchaseReturnItemModel> _items = [];
  bool _isLoading = false;
  bool _isViewMode = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    if (widget.returnDoc != null) {
      final returnDoc = widget.returnDoc!;
      _returnNoController = TextEditingController(text: returnDoc.returnNo);
      _reasonController = TextEditingController(text: returnDoc.reason ?? '');
      _remarkController = TextEditingController(text: returnDoc.remark ?? '');
      _returnDate = returnDoc.returnDate;
      _supplierId = returnDoc.supplierId;
      _supplierName = returnDoc.supplierName;
      _isViewMode = returnDoc.isConfirmed;

      if (returnDoc.items != null) {
        _items.addAll(returnDoc.items!);
      }
    } else {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _returnNoController = TextEditingController(text: 'PRET${timestamp.toString().substring(8)}');
      _reasonController = TextEditingController();
      _remarkController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _returnNoController.dispose();
    _reasonController.dispose();
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
    if (_isViewMode) return 'รายละเอียดใบคืนสินค้า';
    if (widget.returnDoc == null) return 'สร้างใบคืนสินค้า';
    return 'แก้ไขใบคืนสินค้า';
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

            // เลขที่ใบคืนสินค้า
            TextFormField(
              controller: _returnNoController,
              decoration: const InputDecoration(
                labelText: 'เลขที่ใบคืนสินค้า',
                prefixIcon: Icon(Icons.receipt),
              ),
              readOnly: true,
              style: TextStyle(color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),

            // วันที่คืน
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: const Text('วันที่คืนสินค้า'),
              subtitle: Text(DateFormat('dd/MM/yyyy').format(_returnDate)),
              trailing: _isViewMode ? null : const Icon(Icons.chevron_right),
              onTap: _isViewMode ? null : _selectReturnDate,
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

            // เหตุผล
            if (_isViewMode)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.warning),
                title: const Text('เหตุผลการคืน'),
                subtitle: Text(_reasonController.text.isEmpty ? '-' : _reasonController.text),
              )
            else
              TextFormField(
                controller: _reasonController,
                decoration: const InputDecoration(
                  labelText: 'เหตุผลการคืน',
                  prefixIcon: Icon(Icons.warning),
                  hintText: 'สินค้าชำรุด, ส่งผิด, ฯลฯ',
                ),
                maxLines: 2,
              ),

            const SizedBox(height: 16),

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
                  'รายการสินค้าที่คืน',
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

  Widget _buildItemRow(PurchaseReturnItemModel item, int index) {
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
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.red),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (item.reason != null && item.reason!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'เหตุผล: ${item.reason}',
                  style: TextStyle(fontSize: 11, color: Colors.orange.shade700),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final totalAmount = _items.fold<double>(0, (sum, item) => sum + item.amount);

    return Card(
      color: Colors.red.withValues(alpha: 0.1),
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
                const Text('ยอดรวมที่คืน', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text(
                  '฿${totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
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
              onPressed: _isLoading ? null : _saveReturn,
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

  Future<void> _selectReturnDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _returnDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() {
        _returnDate = date;
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
        final result = await showDialog<PurchaseReturnItemModel>(
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

  Future<void> _saveReturn() async {
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

    final authState = ref.read(authProvider);
    final totalAmount = _items.fold<double>(0, (sum, item) => sum + item.amount);

    final returnDoc = PurchaseReturnModel(
      returnId: widget.returnDoc?.returnId ?? '',
      returnNo: _returnNoController.text.trim(),
      returnDate: _returnDate,
      supplierId: _supplierId!,
      supplierName: _supplierName!,
      totalAmount: totalAmount,
      status: 'DRAFT',
      reason: _reasonController.text.trim().isEmpty ? null : _reasonController.text.trim(),
      remark: _remarkController.text.trim().isEmpty ? null : _remarkController.text.trim(),
      userId: authState.user!.userId,
      createdAt: widget.returnDoc?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      items: _items,
    );

    final success = await ref.read(purchaseReturnListProvider.notifier).createReturn(returnDoc);

    setState(() {
      _isLoading = false;
    });

    if (mounted) {
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('สร้างใบคืนสินค้าสำเร็จ'),
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
                'ใบคืนสินค้า',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 8),
              Text('บันทึกการคืนสินค้าให้ซัพพลายเออร์'),
              SizedBox(height: 16),
              Text(
                'การยืนยัน',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 8),
              Text('เมื่อยืนยันใบคืนสินค้า ระบบจะลดสต๊อกสินค้าทันที'),
              SizedBox(height: 16),
              Text(
                'สถานะ',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 8),
              Text('• DRAFT: แบบร่าง (ยังแก้ไขได้)\n• CONFIRMED: ยืนยันแล้ว (ไม่สามารถแก้ไขได้)'),
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
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _quantityController.dispose();
    _unitPriceController.dispose();
    _reasonController.dispose();
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
              const SizedBox(height: 16),
              TextField(
                controller: _reasonController,
                decoration: const InputDecoration(
                  labelText: 'เหตุผล',
                  hintText: 'สินค้าชำรุด, ส่งผิด, ฯลฯ',
                ),
                maxLines: 2,
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

    final item = PurchaseReturnItemModel(
      itemId: '',
      returnId: '',
      lineNo: widget.lineNo,
      productId: product.productId,
      productCode: product.productCode,
      productName: product.productName,
      unit: product.baseUnit,
      warehouseId: 'WH001',
      warehouseName: 'คลังหลัก',
      quantity: quantity,
      unitPrice: unitPrice,
      amount: quantity * unitPrice,
      reason: _reasonController.text.trim().isEmpty ? null : _reasonController.text.trim(),
    );

    Navigator.pop(context, item);
  }
}