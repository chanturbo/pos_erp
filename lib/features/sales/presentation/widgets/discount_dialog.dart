import 'package:flutter/material.dart';

class DiscountDialog extends StatefulWidget {
  final double currentPercent;
  final double currentAmount;
  
  const DiscountDialog({
    super.key,
    this.currentPercent = 0,
    this.currentAmount = 0,
  });

  @override
  State<DiscountDialog> createState() => _DiscountDialogState();
}

class _DiscountDialogState extends State<DiscountDialog> {
  late TextEditingController _percentController;
  late TextEditingController _amountController;
  int _selectedTab = 0; // 0 = percent, 1 = amount
  
  @override
  void initState() {
    super.initState();
    _percentController = TextEditingController(
      text: widget.currentPercent > 0 ? widget.currentPercent.toString() : '',
    );
    _amountController = TextEditingController(
      text: widget.currentAmount > 0 ? widget.currentAmount.toString() : '',
    );
    _selectedTab = widget.currentPercent > 0 ? 0 : 1;
  }
  
  @override
  void dispose() {
    _percentController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'ส่วนลด',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 16),
            
            // Tab Selection
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                  value: 0,
                  label: Text('เปอร์เซ็นต์ (%)'),
                  icon: Icon(Icons.percent),
                ),
                ButtonSegment(
                  value: 1,
                  label: Text('จำนวนเงิน (฿)'),
                  icon: Icon(Icons.money),
                ),
              ],
              selected: {_selectedTab},
              onSelectionChanged: (Set<int> newSelection) {
                setState(() {
                  _selectedTab = newSelection.first;
                });
              },
            ),
            const SizedBox(height: 24),
            
            // Input
            if (_selectedTab == 0) ...[
              TextField(
                controller: _percentController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'ส่วนลด (%)',
                  border: OutlineInputBorder(),
                  suffixText: '%',
                ),
                autofocus: true,
              ),
              const SizedBox(height: 8),
              // Quick buttons
              Wrap(
                spacing: 8,
                children: [5, 10, 15, 20, 25, 30].map((percent) {
                  return ActionChip(
                    label: Text('$percent%'),
                    onPressed: () {
                      _percentController.text = percent.toString();
                    },
                  );
                }).toList(),
              ),
            ] else ...[
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'ส่วนลด (฿)',
                  border: OutlineInputBorder(),
                  prefixText: '฿',
                ),
                autofocus: true,
              ),
              const SizedBox(height: 8),
              // Quick buttons
              Wrap(
                spacing: 8,
                children: [10, 20, 50, 100, 200, 500].map((amount) {
                  return ActionChip(
                    label: Text('฿$amount'),
                    onPressed: () {
                      _amountController.text = amount.toString();
                    },
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 24),
            
            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context, {
                        'percent': 0.0,
                        'amount': 0.0,
                      });
                    },
                    child: const Text('ล้าง'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final percent = _selectedTab == 0
                          ? double.tryParse(_percentController.text) ?? 0
                          : 0.0;
                      final amount = _selectedTab == 1
                          ? double.tryParse(_amountController.text) ?? 0
                          : 0.0;
                      
                      Navigator.pop(context, {
                        'percent': percent,
                        'amount': amount,
                      });
                    },
                    child: const Text('ตกลง'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}