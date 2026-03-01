import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/client/api_client.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/cart_provider.dart';

class PaymentPage extends ConsumerStatefulWidget {
  const PaymentPage({super.key});

  @override
  ConsumerState<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends ConsumerState<PaymentPage> {
  String _paymentType = 'CASH';
  final TextEditingController _receivedController = TextEditingController();
  double _receivedAmount = 0;
  bool _isProcessing = false;
  
  @override
  void initState() {
    super.initState();
    // ตั้งค่าเริ่มต้นเป็นยอดที่ต้องชำระ
    final cartState = ref.read(cartProvider);
    _receivedAmount = cartState.total;
    _receivedController.text = cartState.total.toStringAsFixed(2);
  }
  
  @override
  void dispose() {
    _receivedController.dispose();
    super.dispose();
  }
  
  double get _change {
    final cartState = ref.read(cartProvider);
    return _receivedAmount - cartState.total;
  }
  
  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('ชำระเงิน'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ยอดที่ต้องชำระ
                  Card(
                    color: Colors.blue[50],
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const Text(
                            'ยอดที่ต้องชำระ',
                            style: TextStyle(fontSize: 18),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '฿${cartState.total.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // วิธีชำระเงิน
                  const Text(
                    'วิธีชำระเงิน',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'CASH',
                        label: Text('เงินสด'),
                        icon: Icon(Icons.money),
                      ),
                      ButtonSegment(
                        value: 'CARD',
                        label: Text('บัตร'),
                        icon: Icon(Icons.credit_card),
                      ),
                      ButtonSegment(
                        value: 'TRANSFER',
                        label: Text('โอน'),
                        icon: Icon(Icons.account_balance),
                      ),
                    ],
                    selected: {_paymentType},
                    onSelectionChanged: (Set<String> newSelection) {
                      setState(() {
                        _paymentType = newSelection.first;
                      });
                    },
                  ),
                  const SizedBox(height: 24),
                  
                  // จำนวนเงินที่รับ (สำหรับเงินสด)
                  if (_paymentType == 'CASH') ...[
                    const Text(
                      'จำนวนเงินที่รับ',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    TextField(
                      controller: _receivedController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 24),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        prefixText: '฿ ',
                        prefixStyle: TextStyle(fontSize: 24),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _receivedAmount = double.tryParse(value) ?? 0;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // ปุ่มจำนวนเงินด่วน
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        cartState.total,
                        100, 200, 500, 1000,
                      ].map((amount) {
                        return ActionChip(
                          label: Text('฿${amount.toStringAsFixed(0)}'),
                          onPressed: () {
                            setState(() {
                              _receivedAmount = amount.toDouble();
                              _receivedController.text = amount.toStringAsFixed(2);
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    
                    // เงินทอน
                    Card(
                      color: _change >= 0 ? Colors.green[50] : Colors.red[50],
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Text(
                              _change >= 0 ? 'เงินทอน' : 'ยอดขาด',
                              style: const TextStyle(fontSize: 18),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '฿${_change.abs().toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: _change >= 0 ? Colors.green : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 32),
                  
                  // ปุ่มชำระเงิน
                  SizedBox(
                    height: 60,
                    child: ElevatedButton(
                      onPressed: (_paymentType == 'CASH' && _change < 0) || _isProcessing
                          ? null
                          : _handlePayment,
                      child: _isProcessing
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'ชำระเงิน',
                              style: TextStyle(fontSize: 20),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Future<void> _handlePayment() async {
    setState(() {
      _isProcessing = true;
    });
    
    try {
      final cartState = ref.read(cartProvider);
      final authState = ref.read(authProvider);
      final apiClient = ref.read(apiClientProvider);
      
      // เตรียมข้อมูล Order
      final orderData = {
        'customer_id': cartState.customerId,
        'customer_name': cartState.customerName,
        'user_id': authState.user?.userId ?? 'USR001',
        'branch_id': 'BR001',
        'warehouse_id': 'WH001',
        'subtotal': cartState.subtotal,
        'discount_amount': cartState.totalDiscount,
        'amount_before_vat': cartState.total,
        'vat_amount': 0.0,
        'total_amount': cartState.total,
        'payment_type': _paymentType,
        'paid_amount': _paymentType == 'CASH' ? _receivedAmount : cartState.total,
        'change_amount': _paymentType == 'CASH' ? _change : 0.0,
        'items': cartState.items.map((item) => {
          'product_id': item.productId,
          'product_code': item.productCode,
          'product_name': item.productName,
          'unit': item.unit,
          'quantity': item.quantity,
          'unit_price': item.price,
          'discount_percent': 0.0,
          'discount_amount': item.discount,
          'amount': item.amount,
        }).toList(),
      };
      
      // บันทึก Order
      final response = await apiClient.post('/api/sales', data: orderData);
      
      if (response.statusCode == 200) {
        // ล้างตะกร้า
        ref.read(cartProvider.notifier).clear();
        
        if (mounted) {
          // แสดง Success Dialog
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 32),
                  SizedBox(width: 8),
                  Text('ชำระเงินสำเร็จ'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('เลขที่: ${response.data['data']['order_no']}'),
                  Text('ยอดชำระ: ฿${cartState.total.toStringAsFixed(2)}'),
                  if (_paymentType == 'CASH')
                    Text('เงินทอน: ฿${_change.toStringAsFixed(2)}'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context); // Back to POS
                  },
                  child: const Text('ปิด'),
                ),
                ElevatedButton(
                  onPressed: () {
                    // TODO: พิมพ์ใบเสร็จ
                    Navigator.pop(context);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('พิมพ์ใบเสร็จ (เร็วๆ นี้...)')),
                    );
                  },
                  child: const Text('พิมพ์ใบเสร็จ'),
                ),
              ],
            ),
          );
        }
      } else {
        throw Exception('Save order failed');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }
}