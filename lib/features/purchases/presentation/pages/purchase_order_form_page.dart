import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/models/purchase_order_model.dart';
import '../../data/models/purchase_order_item_model.dart';
import '../providers/purchase_provider.dart';
import '../../../suppliers/presentation/providers/supplier_provider.dart';
import '../../../products/presentation/providers/product_provider.dart';
import '../../../../../shared/services/mobile_scanner_service.dart'; // ✅ Phase 5

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

  final List<PurchaseOrderItemModel> _items = [];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.order != null) {
      _loadOrderData();
    }
  }

  void _loadOrderData() {
    final order = widget.order!;
    _poDate = order.poDate;
    _supplierId = order.supplierId;
    _supplierName = order.supplierName;
    _warehouseId = order.warehouseId;
    _warehouseName = order.warehouseName ?? 'คลังสาขาหลัก';
    _remark = order.remark;

    if (order.items != null) {
      _items.addAll(order.items!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final suppliersAsync = ref.watch(supplierListProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.order == null ? 'สร้างใบสั่งซื้อ' : 'แก้ไขใบสั่งซื้อ',
        ),
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
                    // Header Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'ข้อมูลทั่วไป',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // วันที่
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.calendar_today),
                              title: const Text('วันที่'),
                              subtitle: Text(
                                DateFormat('dd/MM/yyyy').format(_poDate),
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: _poDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2030),
                                );
                                if (date != null) {
                                  setState(() {
                                    _poDate = date;
                                  });
                                }
                              },
                            ),

                            const Divider(),

                            // ซัพพลายเออร์
                            suppliersAsync.when(
                              data: (suppliers) {
                                return DropdownButtonFormField<String>(
                                  decoration: const InputDecoration(
                                    labelText: 'ซัพพลายเออร์',
                                    prefixIcon: Icon(Icons.business),
                                  ),
                                  initialValue: _supplierId,
                                  items: suppliers.map((supplier) {
                                    return DropdownMenuItem<String>(
                                      value: supplier.supplierId,
                                      child: Text(supplier.supplierName),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    final supplier = suppliers.firstWhere(
                                      (s) => s.supplierId == value,
                                    );
                                    setState(() {
                                      _supplierId = value;
                                      _supplierName = supplier.supplierName;
                                    });
                                  },
                                  validator: (value) {
                                    if (value == null) {
                                      return 'กรุณาเลือกซัพพลายเออร์';
                                    }
                                    return null;
                                  },
                                );
                              },
                              loading: () => const LinearProgressIndicator(),
                              error: (error, stack) =>
                                  const Text('โหลดซัพพลายเออร์ไม่สำเร็จ'),
                            ),

                            const SizedBox(height: 16),

                            // หมายเหตุ
                            TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'หมายเหตุ',
                                prefixIcon: Icon(Icons.note),
                              ),
                              initialValue: _remark,
                              maxLines: 2,
                              onChanged: (value) {
                                _remark = value;
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Items Card
                    Card(
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
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
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
                                      Icon(
                                        Icons.inventory_2_outlined,
                                        size: 64,
                                        color: Colors.grey[400],
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'ยังไม่มีรายการสินค้า',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey[600],
                                        ),
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
                    ),

                    const SizedBox(height: 16),

                    // Summary Card
                    if (_items.isNotEmpty) _buildSummaryCard(),
                  ],
                ),
              ),
            ),

            // Bottom Actions
            Container(
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
                      onPressed: _isLoading ? null : _savePurchaseOrder,
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemRow(PurchaseOrderItemModel item, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
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
                        item.productName ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        item.productCode ?? '',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
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
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'จำนวน: ${item.quantity.toStringAsFixed(0)} ${item.unit ?? ''}',
                  ),
                ),
                Expanded(
                  child: Text('ราคา: ฿${item.unitPrice.toStringAsFixed(2)}'),
                ),
                Expanded(
                  child: Text(
                    'รวม: ฿${item.amount.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.right,
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
    final subtotal = _items.fold<double>(0, (sum, item) => sum + item.amount);
    final vat = subtotal * 0.07;
    final total = subtotal + vat;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSummaryRow('ยอดรวม', subtotal),
            const SizedBox(height: 8),
            _buildSummaryRow('VAT 7%', vat),
            const Divider(),
            _buildSummaryRow('ยอดรวมทั้งสิ้น', total, isTotal: true),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 18 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          '฿${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: isTotal ? 20 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: isTotal ? Colors.blue : Colors.black,
          ),
        ),
      ],
    );
  }

  Future<void> _addItem() async {
    final productsAsync = ref.read(productListProvider);

    await productsAsync.when(
      data: (products) async {
        final result = await showDialog<Map<String, dynamic>>(
          context: context,
          builder: (context) => _ProductSelectionDialog(products: products),
        );

        if (result != null) {
          setState(() {
            _items.add(result['item'] as PurchaseOrderItemModel);
          });
        }
      },
      loading: () {},
      error: (error, stack) {},
    );
  }

  Future<void> _savePurchaseOrder() async {
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

    setState(() {
      _isLoading = true;
    });

    final subtotal = _items.fold<double>(0, (sum, item) => sum + item.amount);
    final vat = subtotal * 0.07;
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

    setState(() {
      _isLoading = false;
    });

    if (mounted) {
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.order == null
                  ? 'สร้างใบสั่งซื้อสำเร็จ'
                  : 'แก้ไขใบสั่งซื้อสำเร็จ',
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
}

// Product Selection Dialog
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
  // ✅ Phase 5 — สำหรับกรอง dropdown จาก barcode scan
  String _productSearch = '';

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // กรองสินค้าตาม barcode หรือ code ที่สแกนได้
    final filteredProducts = _productSearch.isEmpty
        ? widget.products
        : widget.products.where((p) {
            final q = _productSearch.toLowerCase();
            return (p.productCode?.toLowerCase().contains(q) ?? false) ||
                (p.productName?.toLowerCase().contains(q) ?? false) ||
                (p.barcode?.toLowerCase().contains(q) ?? false);
          }).toList();

    return AlertDialog(
      title: Row(
        children: [
          const Text('เลือกสินค้า'),
          const Spacer(),
          // ✅ ScannerButton ใน title bar ของ dialog
          ScannerButton(
            tooltip: 'สแกนบาร์โค้ดสินค้า',
            onScanned: (value) {
              setState(() {
                _productSearch = value;
                // ถ้าค้นพบสินค้าเดียว เลือกให้เลย
                final matched = widget.products.where((p) =>
                    (p.barcode?.toLowerCase() == value.toLowerCase()) ||
                    (p.productCode?.toLowerCase() == value.toLowerCase()));
                if (matched.length == 1) {
                  _selectedProductId = matched.first.productId;
                  _priceController.text =
                      matched.first.priceLevel1.toString();
                }
              });
            },
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'สินค้า'),
              value: _selectedProductId,
              items: filteredProducts.map<DropdownMenuItem<String>>((product) {
                return DropdownMenuItem<String>(
                  value: product.productId,
                  child: Text(
                    '${product.productCode} - ${product.productName}',
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedProductId = value;
                  _priceController.text = '0';
                });
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _quantityController,
              decoration: const InputDecoration(labelText: 'จำนวน'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _priceController,
              decoration: const InputDecoration(labelText: 'ราคาต่อหน่วย'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ยกเลิก'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_selectedProductId == null) {
              return;
            }

            final product = widget.products.firstWhere(
              (p) => p.productId == _selectedProductId,
            );

            final quantity = double.tryParse(_quantityController.text) ?? 0;
            final price = double.tryParse(_priceController.text) ?? 0;
            final amount = quantity * price;

            final item = PurchaseOrderItemModel(
              itemId: '',
              poId: '',
              lineNo: 0,
              productId: product.productId,
              productCode: product.productCode,
              productName: product.productName,
              unit: product.baseUnit,
              quantity: quantity,
              unitPrice: price,
              amount: amount,
              remainingQuantity: quantity,
            );

            Navigator.pop(context, {'item': item});
          },
          child: const Text('เพิ่ม'),
        ),
      ],
    );
  }
}