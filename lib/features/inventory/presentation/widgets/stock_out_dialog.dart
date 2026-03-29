import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/stock_balance_model.dart';
import '../providers/stock_provider.dart';

class StockOutDialog extends ConsumerStatefulWidget {
  final StockBalanceModel stock;

  const StockOutDialog({super.key, required this.stock});

  @override
  ConsumerState<StockOutDialog> createState() => _StockOutDialogState();
}

class _StockOutDialogState extends ConsumerState<StockOutDialog> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _referenceController = TextEditingController();
  final _remarkController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _quantityController.dispose();
    _referenceController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                  const Icon(
                    Icons.remove_circle,
                    color: Colors.orange,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'เบิกสินค้าออก',
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
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('สต๊อกปัจจุบัน:', style: TextStyle(color: Colors.black87)),
                    Text(
                      '${widget.stock.balance.toStringAsFixed(0)} ${widget.stock.baseUnit}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Quantity
              TextFormField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'จำนวนที่เบิกออก *',
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

              // Reference No
              TextFormField(
                controller: _referenceController,
                decoration: const InputDecoration(
                  labelText: 'เลขที่เอกสารอ้างอิง',
                  border: OutlineInputBorder(),
                  hintText: 'เช่น REQ-001',
                ),
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
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.pop(context),
                      child: const Text('ยกเลิก'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
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
                          : const Text('เบิกออก'),
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
    final reference = _referenceController.text.trim();
    final remark = _remarkController.text.trim();

    // ✅ stockOut return bool แล้ว
    final success = await ref
        .read(stockBalanceProvider.notifier)
        .stockOut(
          productId: widget.stock.productId,
          warehouseId: widget.stock.warehouseId,
          quantity: quantity,
          referenceNo: reference.isEmpty ? null : reference,
          remark: remark.isEmpty ? null : remark,
        );

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'เบิกสินค้าสำเร็จ' : 'เกิดข้อผิดพลาด'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }
}
