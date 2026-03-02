import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/stock_balance_model.dart';
import '../providers/stock_provider.dart';

class StockAdjustDialog extends ConsumerStatefulWidget {
  final StockBalanceModel stock;
  
  const StockAdjustDialog({super.key, required this.stock});

  @override
  ConsumerState<StockAdjustDialog> createState() => _StockAdjustDialogState();
}

class _StockAdjustDialogState extends ConsumerState<StockAdjustDialog> {
  final _formKey = GlobalKey<FormState>();
  final _newBalanceController = TextEditingController();
  final _referenceController = TextEditingController();
  final _remarkController = TextEditingController();
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _newBalanceController.text = widget.stock.balance.toStringAsFixed(0);
  }
  
  @override
  void dispose() {
    _newBalanceController.dispose();
    _referenceController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final newBalance = double.tryParse(_newBalanceController.text) ?? widget.stock.balance;
    final difference = newBalance - widget.stock.balance;
    
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
                  const Icon(Icons.edit, color: Colors.blue, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ปรับสต๊อก',
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
              
              // Current Stock
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('สต๊อกปัจจุบัน:'),
                    Text(
                      '${widget.stock.balance.toStringAsFixed(0)} ${widget.stock.baseUnit}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // New Balance
              TextFormField(
                controller: _newBalanceController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'สต๊อกใหม่ *',
                  border: const OutlineInputBorder(),
                  suffixText: widget.stock.baseUnit,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'กรุณากรอกจำนวน';
                  }
                  final qty = double.tryParse(value);
                  if (qty == null || qty < 0) {
                    return 'จำนวนต้องไม่ติดลบ';
                  }
                  return null;
                },
                onChanged: (value) {
                  setState(() {}); // Rebuild to show difference
                },
                autofocus: true,
              ),
              const SizedBox(height: 16),
              
              // Difference
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: difference >= 0 ? Colors.green[50] : Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: difference >= 0 ? Colors.green : Colors.red,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('ผลต่าง:'),
                    Row(
                      children: [
                        Icon(
                          difference >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                          color: difference >= 0 ? Colors.green : Colors.red,
                          size: 20,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${difference.abs().toStringAsFixed(0)} ${widget.stock.baseUnit}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: difference >= 0 ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Reference No
              TextFormField(
                controller: _referenceController,
                decoration: const InputDecoration(
                  labelText: 'เลขที่เอกสารอ้างอิง',
                  border: OutlineInputBorder(),
                  hintText: 'เช่น ADJ-001',
                ),
              ),
              const SizedBox(height: 16),
              
              // Remark
              TextFormField(
                controller: _remarkController,
                decoration: const InputDecoration(
                  labelText: 'หมายเหตุ *',
                  border: OutlineInputBorder(),
                  hintText: 'เหตุผลในการปรับสต๊อก',
                ),
                maxLines: 2,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'กรุณากรอกเหตุผลในการปรับสต๊อก';
                  }
                  return null;
                },
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
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('บันทึก'),
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
    
    final newBalance = double.parse(_newBalanceController.text);
    final reference = _referenceController.text.trim();
    final remark = _remarkController.text.trim();
    
    final success = await ref.read(stockBalanceProvider.notifier).adjustStock(
      productId: widget.stock.productId,
      warehouseId: widget.stock.warehouseId,
      newBalance: newBalance,
      referenceNo: reference.isEmpty ? null : reference,
      remark: remark,
    );
    
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      
      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'ปรับสต๊อกสำเร็จ' : 'เกิดข้อผิดพลาด'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }
}