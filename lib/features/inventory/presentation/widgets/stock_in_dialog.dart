import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/stock_balance_model.dart';
import '../providers/stock_provider.dart';

class StockInDialog extends ConsumerStatefulWidget {
  final StockBalanceModel stock;
  
  const StockInDialog({super.key, required this.stock});

  @override
  ConsumerState<StockInDialog> createState() => _StockInDialogState();
}

class _StockInDialogState extends ConsumerState<StockInDialog> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _costController     = TextEditingController();
  final _referenceController = TextEditingController();
  final _remarkController = TextEditingController();
  bool _isLoading = false;

  /// WAC ที่จะได้หลังรับของ (แสดง preview แบบ real-time)
  double get _previewWac {
    final qty     = double.tryParse(_quantityController.text) ?? 0;
    final newCost = double.tryParse(_costController.text) ?? 0;
    final oldQty  = widget.stock.balance;
    final oldCost = widget.stock.avgCost;
    if (qty <= 0) return oldCost;
    final totalQty = oldQty + qty;
    if (totalQty == 0) return 0;
    return (oldQty * oldCost + qty * newCost) / totalQty;
  }

  @override
  void initState() {
    super.initState();
    // pre-fill ด้วย avgCost ปัจจุบัน (ถ้ามี)
    if (widget.stock.avgCost > 0) {
      _costController.text = widget.stock.avgCost.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _costController.dispose();
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
                  const Icon(Icons.add_box, color: Colors.green, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'รับสินค้าเข้า',
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
              
              // Current Stock + WAC summary
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('สต๊อกปัจจุบัน:', style: TextStyle(color: Colors.black87)),
                        Text(
                          '${widget.stock.balance.toStringAsFixed(0)} ${widget.stock.baseUnit}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    if (widget.stock.avgCost > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('ต้นทุนเฉลี่ย (WAC) ปัจจุบัน:', style: TextStyle(fontSize: 12, color: Colors.black54)),
                          Text(
                            '฿${widget.stock.avgCost.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Quantity + Cost (side by side)
              StatefulBuilder(
                builder: (_, setInner) => Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // จำนวน
                        Expanded(
                          child: TextFormField(
                            controller: _quantityController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'จำนวนที่รับเข้า *',
                              border: const OutlineInputBorder(),
                              suffixText: widget.stock.baseUnit,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) return 'กรุณากรอกจำนวน';
                              final qty = double.tryParse(value);
                              if (qty == null || qty <= 0) return 'ต้องมากกว่า 0';
                              return null;
                            },
                            autofocus: true,
                            onChanged: (_) => setInner(() {}),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // ราคาต้นทุน/หน่วย
                        Expanded(
                          child: TextFormField(
                            controller: _costController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'ราคาต้นทุน/หน่วย *',
                              border: OutlineInputBorder(),
                              prefixText: '฿',
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) return 'กรุณากรอกราคา';
                              final cost = double.tryParse(value);
                              if (cost == null || cost < 0) return 'ราคาต้องไม่ติดลบ';
                              return null;
                            },
                            onChanged: (_) => setInner(() {}),
                          ),
                        ),
                      ],
                    ),
                    // Preview WAC ใหม่
                    if ((double.tryParse(_quantityController.text) ?? 0) > 0 &&
                        (double.tryParse(_costController.text) ?? 0) >= 0) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('WAC ใหม่ (หลังรับ):', style: TextStyle(fontSize: 12, color: Colors.black54)),
                            Text(
                              '฿${_previewWac.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
                  hintText: 'เช่น PO-001',
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
    
    final quantity  = double.parse(_quantityController.text);
    final unitCost  = double.tryParse(_costController.text) ?? 0;
    final reference = _referenceController.text.trim();
    final remark    = _remarkController.text.trim();

    final success = await ref.read(stockBalanceProvider.notifier).stockIn(
      productId: widget.stock.productId,
      warehouseId: widget.stock.warehouseId,
      quantity: quantity,
      unitCost: unitCost,
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
          content: Text(success ? 'รับสินค้าเข้าสำเร็จ' : 'เกิดข้อผิดพลาด'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }
}