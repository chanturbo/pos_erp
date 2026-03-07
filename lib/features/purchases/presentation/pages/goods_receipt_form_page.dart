import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../products/presentation/providers/product_provider.dart';
import '../../../suppliers/presentation/providers/supplier_provider.dart';
import '../../data/models/goods_receipt_model.dart';
import '../../data/models/goods_receipt_item_model.dart';
import '../providers/goods_receipt_provider.dart';
import '../providers/purchase_provider.dart';

class GoodsReceiptFormPage extends ConsumerStatefulWidget {
  final GoodsReceiptModel? receipt;

  const GoodsReceiptFormPage({super.key, this.receipt});

  @override
  ConsumerState<GoodsReceiptFormPage> createState() =>
      _GoodsReceiptFormPageState();
}

class _GoodsReceiptFormPageState extends ConsumerState<GoodsReceiptFormPage> {
  final _formKey = GlobalKey<FormState>();

  DateTime _grDate = DateTime.now();
  String? _poId;
  String? _poNo;
  String? _supplierId;
  String? _supplierName;
  String _warehouseId = 'WH001';
  String _warehouseName = 'คลังสาขาหลัก';
  String? _remark;

  final List<GoodsReceiptItemModel> _items = [];

  bool _isLoading = false;
  bool _isViewMode = false;

  @override
  void initState() {
    super.initState();
    if (widget.receipt != null) {
      _loadReceiptData();
      _isViewMode = widget.receipt!.status == 'CONFIRMED';
    }
  }

  void _loadReceiptData() {
    final receipt = widget.receipt!;
    _grDate = receipt.grDate;
    _poId = receipt.poId;
    _poNo = receipt.poNo;
    _supplierId = receipt.supplierId;
    _supplierName = receipt.supplierName;
    _warehouseId = receipt.warehouseId;
    _warehouseName = receipt.warehouseName;
    _remark = receipt.remark;

    if (receipt.items != null) {
      _items.addAll(receipt.items!);
    }
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
                    // Method Selection (ถ้าเป็นการสร้างใหม่)
                    if (widget.receipt == null && _poId == null)
                      _buildMethodSelection(),

                    // Header Card
                    _buildHeaderCard(),

                    const SizedBox(height: 16),

                    // Items Card
                    _buildItemsCard(),

                    const SizedBox(height: 16),

                    // Summary (ถ้ามีรายการ)
                    if (_items.isNotEmpty) _buildSummaryCard(),
                  ],
                ),
              ),
            ),

            // Bottom Actions
            if (!_isViewMode) _buildBottomActions(),
          ],
        ),
      ),
    );
  }

  String _getTitle() {
    if (_isViewMode) return 'รายละเอียดใบรับสินค้า';
    if (widget.receipt == null) return 'สร้างใบรับสินค้า';
    return 'แก้ไขใบรับสินค้า';
  }

  // Method Selection
  Widget _buildMethodSelection() {
    return Card(
      color: Colors.blue.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'เลือกวิธีการสร้างใบรับสินค้า',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _selectFromPO,
                    icon: const Icon(Icons.shopping_cart),
                    label: const Text('จาก Purchase Order'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _createManually,
                    icon: const Icon(Icons.edit),
                    label: const Text('สร้างเอง'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Header Card
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

            // วันที่
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: const Text('วันที่รับสินค้า'),
              subtitle: Text(DateFormat('dd/MM/yyyy').format(_grDate)),
              trailing: _isViewMode ? null : const Icon(Icons.chevron_right),
              onTap: _isViewMode ? null : _selectDate,
            ),

            const Divider(),

            // PO Reference (ถ้ามี)
            if (_poNo != null) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.receipt_long),
                title: const Text('อ้างอิง Purchase Order'),
                subtitle: Text(_poNo!),
              ),
              const Divider(),
            ],

            // Supplier
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.business),
              title: const Text('ซัพพลายเออร์'),
              subtitle: Text(_supplierName ?? '-'),
            ),

            const Divider(),

            // Warehouse
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.warehouse),
              title: const Text('คลังสินค้า'),
              subtitle: Text(_warehouseName),
            ),

            const Divider(),

            // Remark
            if (_isViewMode)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.note),
                title: const Text('หมายเหตุ'),
                subtitle: Text(_remark ?? '-'),
              )
            else
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
    );
  }

  // Items Card
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
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _supplierId == null
                            ? 'กรุณาเลือกวิธีการสร้างใบรับสินค้าก่อน'
                            : 'ยังไม่มีรายการสินค้า',
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

  // Item Row
  Widget _buildItemRow(GoodsReceiptItemModel item, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.grey[50],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
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

            // Quantities
            Row(
              children: [
                Expanded(
                  child: _buildQuantityInfo(
                    'สั่งซื้อ',
                    item.orderedQuantity,
                    item.unit,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildQuantityInfo(
                    'รับจริง',
                    item.receivedQuantity,
                    item.unit,
                    Colors.green,
                  ),
                ),
                if (item.orderedQuantity > 0)
                  Expanded(
                    child: _buildQuantityInfo(
                      'คงเหลือ',
                      item.orderedQuantity - item.receivedQuantity,
                      item.unit,
                      Colors.orange,
                    ),
                  ),
              ],
            ),

            // Additional Info
            if (item.lotNumber != null || item.expiryDate != null) ...[
              const Divider(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  if (item.lotNumber != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.qr_code, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          'Lot: ${item.lotNumber}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  if (item.expiryDate != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.event, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          'EXP: ${DateFormat('dd/MM/yyyy').format(item.expiryDate!)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],

            // Edit Button (ถ้าไม่ใช่ View Mode)
            if (!_isViewMode) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _editItem(item, index),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('แก้ไขจำนวน/ข้อมูลเพิ่มเติม'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Quantity Info Widget
  Widget _buildQuantityInfo(
    String label,
    double quantity,
    String unit,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        const SizedBox(height: 2),
        Text(
          '${quantity.toStringAsFixed(0)} $unit',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  // Summary Card
  Widget _buildSummaryCard() {
    final totalItems = _items.length;
    final totalOrdered = _items.fold<double>(
      0,
      (sum, item) => sum + item.orderedQuantity,
    );
    final totalReceived = _items.fold<double>(
      0,
      (sum, item) => sum + item.receivedQuantity,
    );

    return Card(
      color: Colors.green.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('จำนวนรายการ', style: TextStyle(fontSize: 14)),
                Text(
                  '$totalItems รายการ',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('จำนวนที่สั่ง', style: TextStyle(fontSize: 14)),
                Text(
                  totalOrdered.toStringAsFixed(0),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('จำนวนที่รับจริง', style: TextStyle(fontSize: 14)),
                Text(
                  totalReceived.toStringAsFixed(0),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Bottom Actions
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
              onPressed: _isLoading ? null : _saveReceipt,
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

  // Select Date
  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _grDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() {
        _grDate = date;
      });
    }
  }

  // Select from PO
  Future<void> _selectFromPO() async {
    // โหลดรายการ PO ที่รอรับสินค้า
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final pendingPOs = await ref
        .read(goodsReceiptListProvider.notifier)
        .getPendingPurchaseOrders();

    if (!mounted) return;
    Navigator.pop(context); // ปิด loading dialog

    if (pendingPOs.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('ไม่มี Purchase Order'),
          content: const Text(
            'ไม่พบ Purchase Order ที่อนุมัติแล้วและรอรับสินค้า\n\n'
            'กรุณาสร้างและอนุมัติ Purchase Order ก่อน หรือเลือก "สร้างเอง"',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ปิด'),
            ),
          ],
        ),
      );
      return;
    }

    // แสดง Dialog เลือก PO
    final selectedPO = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _POSelectionDialog(pos: pendingPOs),
    );

    if (selectedPO != null) {
      await _loadFromPO(selectedPO);
    }
  }

  // Create Manually
  void _createManually() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('สร้างใบรับสินค้าเอง'),
        content: const Text(
          'คุณต้องการสร้างใบรับสินค้าโดยไม่อ้างอิง Purchase Order ใช่หรือไม่?\n\n'
          'คุณจะต้องเลือกซัพพลายเออร์และเพิ่มรายการสินค้าเอง',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showSupplierSelection();
            },
            child: const Text('ดำเนินการต่อ'),
          ),
        ],
      ),
    );
  }

  // Add Item
  Future<void> _addItem() async {
    final productsAsync = ref.read(productListProvider);

    await productsAsync.when(
      data: (products) async {
        final result = await showDialog<GoodsReceiptItemModel>(
          context: context,
          builder: (context) =>
              _ItemDialog(products: products, lineNo: _items.length + 1),
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

  // Edit Item
  Future<void> _editItem(GoodsReceiptItemModel item, int index) async {
    final result = await showDialog<GoodsReceiptItemModel>(
      context: context,
      builder: (context) => _ItemEditDialog(item: item),
    );

    if (result != null) {
      setState(() {
        _items[index] = result;
      });
    }
  }

  // Save Receipt
  Future<void> _saveReceipt() async {
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
      remark: _remark,
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

    setState(() {
      _isLoading = false;
    });

    if (mounted) {
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.receipt == null
                  ? 'สร้างใบรับสินค้าสำเร็จ'
                  : 'แก้ไขใบรับสินค้าสำเร็จ',
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

  // Show Help
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
                'วิธีการสร้างใบรับสินค้า',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                '1. จาก Purchase Order - เลือก PO ที่อนุมัติแล้ว ข้อมูลจะถูกดึงมาอัตโนมัติ',
              ),
              SizedBox(height: 8),
              Text('2. สร้างเอง - สร้างใบรับสินค้าโดยไม่อ้างอิง PO'),
              SizedBox(height: 16),
              Text(
                'การแก้ไขจำนวน',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('คุณสามารถแก้ไขจำนวนที่รับจริง ถ้ารับไม่ตรงกับที่สั่ง'),
              SizedBox(height: 16),
              Text(
                'Lot Number & Expiry Date',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'สามารถเพิ่มข้อมูล Lot Number และวันหมดอายุได้ในแต่ละรายการ',
              ),
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

  // Load data from PO
  Future<void> _loadFromPO(Map<String, dynamic> poData) async {
    // แสดง loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    // ดึงรายละเอียด PO พร้อม items
    final purchaseProvider = ref.read(purchaseListProvider.notifier);
    final po = await purchaseProvider.getPurchaseOrderDetails(poData['po_id']);

    if (!mounted) return;
    Navigator.pop(context); // ปิด loading

    if (po == null || po.items == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ไม่สามารถโหลดข้อมูล PO ได้'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _poId = po.poId;
      _poNo = po.poNo;
      _supplierId = po.supplierId;
      _supplierName = po.supplierName;
      _warehouseId = po.warehouseId;
      _warehouseName = po.warehouseName ?? 'คลังสาขาหลัก';

      // แปลง PO Items เป็น GR Items
      _items.clear();
      for (var i = 0; i < po.items!.length; i++) {
        final poItem = po.items![i];

        // คำนวณจำนวนที่ยังรับไม่ครบ
        final remainingQty = poItem.remainingQuantity;

        if (remainingQty > 0) {
          _items.add(
            GoodsReceiptItemModel(
              itemId: '',
              grId: '',
              lineNo: i + 1,
              poItemId: poItem.itemId,
              productId: poItem.productId,
              productCode: poItem.productCode ?? '',
              productName: poItem.productName ?? '',
              unit: poItem.unit ?? '',
              orderedQuantity: poItem.quantity,
              receivedQuantity: remainingQty, // Default รับเท่าที่เหลือ
              unitPrice: poItem.unitPrice,
              amount: remainingQty * poItem.unitPrice,
            ),
          );
        }
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'โหลดข้อมูลจาก PO: ${po.poNo} สำเร็จ (${_items.length} รายการ)',
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  // Show Supplier Selection
  Future<void> _showSupplierSelection() async {
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

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('เลือกซัพพลายเออร์: ${selected['name']}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      },
      loading: () {},
      error: (error, stack) {},
    );
  }
}

// ========================================
// PO SELECTION DIALOG
// ========================================

class _POSelectionDialog extends StatelessWidget {
  final List<Map<String, dynamic>> pos;

  const _POSelectionDialog({required this.pos});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('เลือก Purchase Order'),
      content: SizedBox(
        width: 500,
        height: 400,
        child: ListView.builder(
          itemCount: pos.length,
          itemBuilder: (context, index) {
            final po = pos[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(
                  po['po_no'] ?? '',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ซัพพลายเออร์: ${po['supplier_name'] ?? ''}'),
                    Text(
                      'วันที่: ${DateFormat('dd/MM/yyyy').format(DateTime.parse(po['po_date']))}',
                    ),
                    Text(
                      'ยอดรวม: ฿${(po['total_amount'] ?? 0).toStringAsFixed(2)}',
                    ),
                  ],
                ),
                trailing: Chip(
                  label: Text(
                    po['status'] == 'APPROVED' ? 'รอรับสินค้า' : 'รับบางส่วน',
                    style: const TextStyle(fontSize: 11),
                  ),
                  backgroundColor: po['status'] == 'APPROVED'
                      ? Colors.blue.withValues(alpha: 0.2)
                      : Colors.orange.withValues(alpha: 0.2),
                ),
                onTap: () => Navigator.pop(context, po),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ยกเลิก'),
        ),
      ],
    );
  }
}

// ========================================
// ITEM DIALOG (สำหรับเพิ่มรายการใหม่)
// ========================================

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
  DateTime? _expiryDate;
  final _remarkController = TextEditingController();

  @override
  void dispose() {
    _quantityController.dispose();
    _lotController.dispose();
    _remarkController.dispose();
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
              // Product Selection
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'สินค้า *'),
                items: widget.products.map<DropdownMenuItem<String>>((product) {
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
                  });
                },
              ),
              const SizedBox(height: 16),

              // Quantity
              TextField(
                controller: _quantityController,
                decoration: const InputDecoration(labelText: 'จำนวนที่รับ *'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),

              // Lot Number
              TextField(
                controller: _lotController,
                decoration: const InputDecoration(
                  labelText: 'Lot Number (ถ้ามี)',
                  hintText: 'เช่น LOT2024001',
                ),
              ),
              const SizedBox(height: 16),

              // Expiry Date
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('วันหมดอายุ (ถ้ามี)'),
                subtitle: Text(
                  _expiryDate != null
                      ? DateFormat('dd/MM/yyyy').format(_expiryDate!)
                      : 'ไม่ระบุ',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_expiryDate != null)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _expiryDate = null;
                          });
                        },
                      ),
                    IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: _selectExpiryDate,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Remark
              TextField(
                controller: _remarkController,
                decoration: const InputDecoration(labelText: 'หมายเหตุ'),
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
        ElevatedButton(onPressed: _addItem, child: const Text('เพิ่ม')),
      ],
    );
  }

  Future<void> _selectExpiryDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (date != null) {
      setState(() {
        _expiryDate = date;
      });
    }
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
    if (quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณาระบุจำนวนที่ถูกต้อง'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final product = widget.products.firstWhere(
      (p) => p.productId == _selectedProductId,
    );

    final item = GoodsReceiptItemModel(
      itemId: '',
      grId: '',
      lineNo: widget.lineNo,
      productId: product.productId,
      productCode: product.productCode,
      productName: product.productName,
      unit: product.baseUnit,
      orderedQuantity: 0,
      receivedQuantity: quantity,
      unitPrice: 0,
      amount: 0,
      lotNumber: _lotController.text.isEmpty ? null : _lotController.text,
      expiryDate: _expiryDate,
      remark: _remarkController.text.isEmpty ? null : _remarkController.text,
    );

    Navigator.pop(context, item);
  }
}

// ========================================
// ITEM EDIT DIALOG (สำหรับแก้ไขรายการ)
// ========================================

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
      text: widget.item.receivedQuantity.toStringAsFixed(0),
    );
    _lotController = TextEditingController(text: widget.item.lotNumber ?? '');
    _remarkController = TextEditingController(text: widget.item.remark ?? '');
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
    return AlertDialog(
      title: const Text('แก้ไขรายการ'),
      content: SizedBox(
        width: 450,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Info (แสดงอย่างเดียว)
              Text(
                widget.item.productName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                widget.item.productCode,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const Divider(height: 24),

              // Ordered Quantity (ถ้ามี)
              if (widget.item.orderedQuantity > 0) ...[
                Text(
                  'จำนวนที่สั่ง: ${widget.item.orderedQuantity.toStringAsFixed(0)} ${widget.item.unit}',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),
              ],

              // Received Quantity
              TextField(
                controller: _quantityController,
                decoration: InputDecoration(
                  labelText: 'จำนวนที่รับจริง *',
                  suffixText: widget.item.unit,
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),

              // Lot Number
              TextField(
                controller: _lotController,
                decoration: const InputDecoration(
                  labelText: 'Lot Number (ถ้ามี)',
                  hintText: 'เช่น LOT2024001',
                ),
              ),
              const SizedBox(height: 16),

              // Expiry Date
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('วันหมดอายุ (ถ้ามี)'),
                subtitle: Text(
                  _expiryDate != null
                      ? DateFormat('dd/MM/yyyy').format(_expiryDate!)
                      : 'ไม่ระบุ',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_expiryDate != null)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _expiryDate = null;
                          });
                        },
                      ),
                    IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: _selectExpiryDate,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Remark
              TextField(
                controller: _remarkController,
                decoration: const InputDecoration(labelText: 'หมายเหตุ'),
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
        ElevatedButton(onPressed: _saveItem, child: const Text('บันทึก')),
      ],
    );
  }

  Future<void> _selectExpiryDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (date != null) {
      setState(() {
        _expiryDate = date;
      });
    }
  }

  void _saveItem() {
    final quantity = double.tryParse(_quantityController.text) ?? 0;
    if (quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณาระบุจำนวนที่ถูกต้อง'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final updatedItem = widget.item.copyWith(
      receivedQuantity: quantity,
      amount: quantity * widget.item.unitPrice,
      lotNumber: _lotController.text.isEmpty ? null : _lotController.text,
      expiryDate: _expiryDate,
      remark: _remarkController.text.isEmpty ? null : _remarkController.text,
    );

    Navigator.pop(context, updatedItem);
  }
}
