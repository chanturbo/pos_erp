import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/stock_balance_model.dart';
import '../providers/stock_provider.dart';

class StockTransferDialog extends ConsumerStatefulWidget {
  final StockBalanceModel stock;
  
  const StockTransferDialog({super.key, required this.stock});

  @override
  ConsumerState<StockTransferDialog> createState() => _StockTransferDialogState();
}

class _StockTransferDialogState extends ConsumerState<StockTransferDialog> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _remarkController = TextEditingController();
  String? _toWarehouseId;
  bool _isLoading = false;
  
  // TODO: ควรดึงจาก API
  final List<Map<String, String>> warehouses = [
    {'id': 'WH001', 'name': 'คลังสาขาหลัก'},
    {'id': 'WH002', 'name': 'คลังสาขาสยาม'},
  ];
  
  @override
  void dispose() {
    _quantityController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final availableWarehouses = warehouses
        .where((w) => w['id'] != widget.stock.warehouseId)
        .toList();
    
    return Dialog(
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.swap_horiz, color: Colors.purple, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'โอนย้ายสินค้า',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.stock.productName,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 32),
              
              // From Warehouse
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('จากคลัง:', style: TextStyle(fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(
                      widget.stock.warehouseName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'สต๊อกคงเหลือ: ${widget.stock.balance.toStringAsFixed(0)} ${widget.stock.baseUnit}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // To Warehouse
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'ไปยังคลัง *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.warehouse),
                ),
                value: _toWarehouseId,
                items: availableWarehouses.map((w) {
                  return DropdownMenuItem(
                    value: w['id'],
                    child: Text(w['name']!),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _toWarehouseId = value;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return 'กรุณาเลือกคลังปลายทาง';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Quantity
              TextFormField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'จำนวนที่โอน *',
                  border: const OutlineInputBorder(),
                  suffixText: widget.stock.baseUnit,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'กรุณากรอกจำนวน';
                  }
                  final qty = double.tryParse(value);
                  if (qty == null || qty <= 0) {
                    return 'จำนวนต้องมากกว่า 0';
                  }
                  if (qty > widget.stock.balance) {
                    return 'จำนวนต้องไม่เกินสต๊อกคงเหลือ';
                  }
                  return null;
                },
                autofocus: true,
              ),
              const SizedBox(height: 16),
              
              // Remark
              TextFormField(
                controller: _remarkController,
                decoration: const InputDecoration(
                  labelText: 'หมายเหตุ',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              
              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : () => Navigator.pop(context),
                      child: const Text('ยกเลิก'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('โอนย้าย'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    final quantity = double.parse(_quantityController.text);
    final remark = _remarkController.text.trim();
    
    final success = await ref.read(stockBalanceProvider.notifier).transferStock(
      productId: widget.stock.productId,
      fromWarehouseId: widget.stock.warehouseId,
      toWarehouseId: _toWarehouseId!,
      quantity: quantity,
      remark: remark.isEmpty ? null : remark,
    );
    
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      
      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'โอนย้ายสินค้าสำเร็จ' : 'เกิดข้อผิดพลาด'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }
}