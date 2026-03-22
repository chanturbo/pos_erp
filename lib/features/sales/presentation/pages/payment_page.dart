// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/client/api_client.dart';
import '../../../../core/utils/promptpay_utils.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../customers/presentation/providers/customer_provider.dart'; // ✅
import '../../../settings/presentation/pages/settings_page.dart';
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
    final cartState   = ref.watch(cartProvider);
    final settings    = ref.watch(settingsProvider);
    final promptPayId = settings.promptPayId.trim();
    final hasPromptPay = PromptPayUtils.isValidPromptPayId(promptPayId);

    return Scaffold(
      appBar: AppBar(title: const Text('ชำระเงิน')),
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
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                        icon: Icon(Icons.qr_code),
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
                      children: [cartState.total, 100, 200, 500, 1000]
                          .map((amount) {
                        return ActionChip(
                          label: Text('฿${amount.toStringAsFixed(0)}'),
                          onPressed: () {
                            setState(() {
                              _receivedAmount = amount.toDouble();
                              _receivedController.text =
                                  amount.toStringAsFixed(2);
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // เงินทอน
                    Card(
                      color: _change >= 0
                          ? Colors.green[50]
                          : Colors.red[50],
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
                                color: _change >= 0
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // ── โอน: QR PromptPay ──────────────────────────
                  if (_paymentType == 'TRANSFER') ...[
                    const SizedBox(height: 8),
                    if (hasPromptPay)
                      _PromptPayQrSection(
                        promptPayId: promptPayId,
                        amount: cartState.total,
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber_rounded,
                                color: Colors.orange[700], size: 24),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('ยังไม่ได้ตั้งค่าเลข PromptPay',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13)),
                                  SizedBox(height: 4),
                                  Text(
                                    'ไปที่ ตั้งค่า → ข้อมูลบริษัท → เลข PromptPay',
                                    style: TextStyle(
                                        fontSize: 11, color: Colors.black54),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                  ],

                  // ── บัตร ───────────────────────────────────────────
                  if (_paymentType == 'CARD') ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.credit_card, color: Colors.blue, size: 24),
                          SizedBox(width: 12),
                          Text('รูดบัตรที่เครื่อง EDC แล้วกดยืนยัน',
                              style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  const SizedBox(height: 32),

                  // ปุ่มชำระเงิน
                  SizedBox(
                    height: 60,
                    child: ElevatedButton(
                      onPressed:
                          (_paymentType == 'CASH' && _change < 0) ||
                              _isProcessing
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
                          : Text(
                              _paymentType == 'TRANSFER'
                                  ? 'ยืนยันรับเงินโอนแล้ว'
                                  : 'ชำระเงิน',
                              style: const TextStyle(fontSize: 20),
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
    setState(() => _isProcessing = true);

    try {
      final cartState = ref.read(cartProvider);
      final authState = ref.read(authProvider);
      final apiClient = ref.read(apiClientProvider);

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
        'paid_amount':
            _paymentType == 'CASH' ? _receivedAmount : cartState.total,
        'change_amount': _paymentType == 'CASH' ? _change : 0.0,
        'items': cartState.items
            .map(
              (item) => {
                'product_id': item.productId,
                'product_code': item.productCode,
                'product_name': item.productName,
                'unit': item.unit,
                'quantity': item.quantity,
                'unit_price': item.unitPrice,
                'discount_percent': 0.0,
                'discount_amount': 0.0,
                'amount': item.amount,
              },
            )
            .toList(),
      };

      print('📦 Sending order: total=${orderData['total_amount']}');

      final response = await apiClient.post('/api/sales', data: orderData);

      print('✅ Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        ref.read(cartProvider.notifier).clear();

        // ✅ อ่านค่าแบบ null-safe ป้องกัน crash ถ้า API response ผิดรูปแบบ
        final responseData =
            response.data is Map ? response.data as Map : {};
        final dataMap =
            responseData['data'] is Map ? responseData['data'] as Map : {};
        final orderNo      = dataMap['order_no'] as String? ?? '-';
        final earnedPoints = dataMap['earned_points'] as int? ?? 0;

        // ✅ refresh customer list เพื่อให้ points อัพเดททันที
        ref.read(customerListProvider.notifier).refresh();

        if (mounted) {
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
                  Text('เลขที่: $orderNo'),
                  Text('ยอดชำระ: ฿${cartState.total.toStringAsFixed(2)}'),
                  if (_paymentType == 'CASH')
                    Text('เงินทอน: ฿${_change.toStringAsFixed(2)}'),
                  // ✅ แสดงแต้มที่ได้รับ
                  if (earnedPoints > 0) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.star,
                            color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'ได้รับ $earnedPoints แต้ม',
                          style: const TextStyle(
                            color: Colors.amber,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                  child: const Text('ปิด'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('ฟีเจอร์พิมพ์ใบเสร็จกำลังพัฒนา'),
                      ),
                    );
                  },
                  child: const Text('พิมพ์ใบเสร็จ'),
                ),
              ],
            ),
          );
        }
      } else {
        // ✅ อ่าน error message จาก API แต่ไม่ expose raw exception
        final responseData =
            response.data is Map ? response.data as Map : {};
        final serverMsg =
            responseData['message'] as String? ?? 'ไม่สามารถบันทึกออเดอร์ได้';
        throw Exception(serverMsg);
      }
    } catch (e) {
      print('❌ Payment error: $e');

      if (mounted) {
        // ✅ แสดงข้อความที่เป็นมิตรกับผู้ใช้ ไม่หลุด stack trace หรือ schema
        final userMessage = _toUserMessage(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  /// ✅ แปลง exception เป็น user-friendly message
  /// — ไม่หลุด schema, path, stack trace ไปยัง UI
  String _toUserMessage(Object e) {
    final msg = e.toString();

    // ถ้าเป็น server message ที่เราโยนเอง (Exception: xxx) → แสดงตรงๆ
    if (msg.startsWith('Exception: ') &&
        !msg.contains('DioException') &&
        !msg.contains('SocketException')) {
      return msg.replaceFirst('Exception: ', '');
    }

    // Network error
    if (msg.contains('SocketException') ||
        msg.contains('Connection refused') ||
        msg.contains('NetworkException')) {
      return 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้ กรุณาตรวจสอบการเชื่อมต่อ';
    }

    // Timeout
    if (msg.contains('TimeoutException') || msg.contains('timeout')) {
      return 'การเชื่อมต่อหมดเวลา กรุณาลองใหม่';
    }

    // Fallback — generic message ไม่หลุด internal details
    return 'เกิดข้อผิดพลาด กรุณาลองใหม่หรือติดต่อผู้ดูแลระบบ';
  }
}

// ─────────────────────────────────────────────────────────────────
// _PromptPayQrSection — แสดง QR Code PromptPay แบบ Inline
// ─────────────────────────────────────────────────────────────────
class _PromptPayQrSection extends StatelessWidget {
  final String promptPayId;
  final double amount;

  const _PromptPayQrSection({
    required this.promptPayId,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    final qrData    = PromptPayUtils.generatePayload(promptPayId, amount);
    final displayId = PromptPayUtils.formatDisplayId(promptPayId);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF1565C0),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.qr_code_2, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('PromptPay QR Code',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),

          // QR Image
          Padding(
            padding: const EdgeInsets.all(20),
            child: QrImageView(
              data: qrData,
              version: QrVersions.auto,
              size: 220,
              backgroundColor: Colors.white,
              errorCorrectionLevel: QrErrorCorrectLevel.M,
            ),
          ),

          // Amount
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                const Text('ยอดที่ต้องชำระ',
                    style: TextStyle(fontSize: 12, color: Colors.black54)),
                const SizedBox(height: 4),
                Text(
                  '฿${amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1565C0)),
                ),
              ],
            ),
          ),

          // PromptPay ID
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.phone, size: 14, color: Colors.black45),
                const SizedBox(width: 6),
                Text('PromptPay: $displayId',
                    style: const TextStyle(fontSize: 13, color: Colors.black54)),
              ],
            ),
          ),

          // คำแนะนำ
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: Colors.black38),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'สแกน QR ด้วยแอปธนาคาร แล้วกด "ยืนยันรับเงินโอนแล้ว"',
                    style: TextStyle(fontSize: 11, color: Colors.black45),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}