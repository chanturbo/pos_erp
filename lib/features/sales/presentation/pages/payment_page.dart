// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import '../../../../core/client/api_client.dart';
import '../../../../core/utils/promptpay_utils.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../customers/presentation/providers/customer_provider.dart'; // ✅
import '../../../settings/presentation/pages/settings_page.dart';
import '../../../promotions/presentation/providers/promotion_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/sales_provider.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../../../shared/services/mobile_scanner_service.dart';

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

  // ── Coupon ──────────────────────────────────────────────────────
  final TextEditingController _couponController = TextEditingController();
  bool _isValidatingCoupon = false;
  String? _couponError;

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
    _couponController.dispose();
    super.dispose();
  }

  double get _change {
    final cartState = ref.read(cartProvider);
    return _receivedAmount - cartState.total;
  }

  // ── Validate & apply coupon ─────────────────────────────────────
  Future<void> _applyCoupon() async {
    final code = _couponController.text.trim().toUpperCase();
    if (code.isEmpty) return;

    setState(() {
      _isValidatingCoupon = true;
      _couponError = null;
    });

    try {
      final result =
          await ref.read(couponListProvider.notifier).validateCoupon(code);

      if (!mounted) return;

      if (result == null) {
        setState(() => _couponError = 'คูปองไม่ถูกต้อง หรือหมดอายุ/ถูกใช้แล้ว');
        return;
      }

      final cartState = ref.read(cartProvider);
      final existing = cartState.appliedCoupons;

      // ── ตรวจสอบคูปองซ้ำ ──────────────────────────────────────
      if (existing.any((c) => c.code == code)) {
        setState(() => _couponError = 'ใช้คูปองนี้แล้ว');
        return;
      }

      // ── ตรวจสอบโปรโมชั่นซ้ำ ──────────────────────────────────
      final promoId = result['promotion_id'] as String? ?? '';
      if (existing.any((c) => c.promotionId == promoId)) {
        setState(() => _couponError = 'โปรโมชั่นนี้ถูกใช้คูปองไปแล้ว');
        return;
      }

      // ── ตรวจสอบ Exclusive ─────────────────────────────────────
      final isExclusive = result['is_exclusive'] as bool? ?? false;
      if (existing.isNotEmpty && isExclusive) {
        setState(() => _couponError = 'คูปองนี้ไม่สามารถใช้ร่วมกับคูปองอื่นได้');
        return;
      }
      if (existing.any((c) => c.isExclusive)) {
        setState(() => _couponError = 'มีคูปอง Exclusive อยู่แล้ว ไม่สามารถเพิ่มคูปองอื่นได้');
        return;
      }

      // ── คำนวณส่วนลด ───────────────────────────────────────────
      final discountType = result['discount_type'] as String? ?? 'AMOUNT';
      final discountValue = (result['discount_value'] as num?)?.toDouble() ?? 0;
      final maxDiscount = (result['max_discount_amount'] as num?)?.toDouble();

      double couponDiscount = 0;
      if (discountType == 'PERCENT') {
        couponDiscount = cartState.subtotal * discountValue / 100;
        if (maxDiscount != null) {
          couponDiscount = couponDiscount.clamp(0, maxDiscount);
        }
      } else {
        couponDiscount = discountValue;
      }
      couponDiscount = couponDiscount.clamp(0, cartState.subtotal);

      ref.read(cartProvider.notifier).applyCoupon(AppliedCoupon(
            code: code,
            discount: couponDiscount,
            promotionId: promoId,
            promotionName: result['promotion_name'] as String?,
            isExclusive: isExclusive,
          ));

      _couponController.clear();
      setState(() => _couponError = null);

      // อัปเดตยอดรับ (CASH)
      final newTotal = ref.read(cartProvider).total;
      setState(() {
        _receivedAmount = newTotal;
        _receivedController.text = newTotal.toStringAsFixed(2);
      });
    } finally {
      if (mounted) setState(() => _isValidatingCoupon = false);
    }
  }

  void _removeCoupon(String code) {
    ref.read(cartProvider.notifier).removeCoupon(code);
    setState(() => _couponError = null);
    final newTotal = ref.read(cartProvider).total;
    setState(() {
      _receivedAmount = newTotal;
      _receivedController.text = newTotal.toStringAsFixed(2);
    });
  }

  Future<void> _scanCoupon() async {
    final result = await MobileScannerService.scan(context);
    if (result == null || !mounted) return;
    _couponController.text = result.value.toUpperCase();
    setState(() => _couponError = null);
    await _applyCoupon();
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
                  Builder(builder: (context) {
                    final isDark = Theme.of(context).brightness == Brightness.dark;
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? [const Color(0xFF0D2137), const Color(0xFF0D3354)]
                              : [const Color(0xFF1565C0), const Color(0xFF1976D2)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1565C0).withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.receipt_long,
                                  color: Colors.white70, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                'ยอดที่ต้องชำระ',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.white.withValues(alpha: 0.85),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '฿${cartState.total.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 52,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1,
                            ),
                          ),
                          if (cartState.totalDiscount > 0) ...[
                            const SizedBox(height: 4),
                            Text(
                              'ส่วนลด ฿${cartState.totalDiscount.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 16),

                  // ── คูปองส่วนลด ────────────────────────────────
                  _CouponSection(
                    controller: _couponController,
                    isValidating: _isValidatingCoupon,
                    errorText: _couponError,
                    appliedCoupons: cartState.appliedCoupons,
                    onApply: _applyCoupon,
                    onRemove: _removeCoupon,
                    onScan: _scanCoupon,
                  ),
                  const SizedBox(height: 16),

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

                    // ปุ่มจำนวนเงินด่วน — คำนวณอัตโนมัติจากยอดขาย
                    Builder(builder: (context) {
                      final isDark = Theme.of(context).brightness == Brightness.dark;
                      // สร้าง list จากยอดจริง: พอดียอด → กลมขึ้นไปเรื่อย ๆ
                      final total = cartState.total;
                      final amounts = _buildQuickAmounts(total);
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: amounts.map((amount) {
                          final isExact = amount == total;
                          final isSelected = _receivedAmount == amount;
                          return InkWell(
                            onTap: () => setState(() {
                              _receivedAmount = amount;
                              _receivedController.text =
                                  amount.toStringAsFixed(2);
                            }),
                            borderRadius: BorderRadius.circular(8),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF1565C0)
                                    : isExact
                                        ? (isDark
                                            ? const Color(0xFF0D3354)
                                            : const Color(0xFFE3F2FD))
                                        : (isDark
                                            ? const Color(0xFF2A2A2A)
                                            : const Color(0xFFF5F5F5)),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF1565C0)
                                      : isExact
                                          ? const Color(0xFF90CAF9)
                                          : (isDark
                                              ? const Color(0xFF444444)
                                              : const Color(0xFFE0E0E0)),
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '฿${amount.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: isSelected
                                          ? Colors.white
                                          : isExact
                                              ? const Color(0xFF1565C0)
                                              : (isDark
                                                  ? Colors.white
                                                  : const Color(0xFF1A1A1A)),
                                    ),
                                  ),
                                  if (isExact)
                                    Text(
                                      'พอดี',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isSelected
                                            ? Colors.white70
                                            : const Color(0xFF1565C0),
                                      ),
                                    ),
                                  if (!isExact && amount > total)
                                    Text(
                                      'ทอน ฿${(amount - total).toStringAsFixed(0)}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isSelected
                                            ? Colors.white70
                                            : (isDark
                                                ? Colors.white54
                                                : Colors.grey[600]),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    }),
                    const SizedBox(height: 24),

                    // เงินทอน
                    Builder(builder: (context) {
                      final isDark = Theme.of(context).brightness == Brightness.dark;
                      final isOk = _change >= 0;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 16, horizontal: 24),
                        decoration: BoxDecoration(
                          // dark: bg มืดตาม isOk, border บาง
                          // light: เขียวอ่อน/แดงอ่อน ตาม isOk
                          color: isDark
                              ? (isOk
                                  ? const Color(0xFF1A2E1A)  // เขียวมืด
                                  : const Color(0xFF2A1A1A)) // แดงมืด (อ่อนกว่าเดิม)
                              : (isOk
                                  ? const Color(0xFFE8F5E9)
                                  : const Color(0xFFFFEBEE)),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? (isOk
                                    ? const Color(0xFF4CAF50).withValues(alpha: 0.25)
                                    : const Color(0xFFF44336).withValues(alpha: 0.25))
                                : (isOk
                                    ? const Color(0xFF4CAF50).withValues(alpha: 0.3)
                                    : const Color(0xFFF44336).withValues(alpha: 0.3)),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  isOk
                                      ? Icons.check_circle_outline
                                      : Icons.remove_circle_outline,
                                  color: isOk
                                      ? const Color(0xFF4CAF50)
                                      : const Color(0xFFEF5350),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isOk ? 'เงินทอน' : 'ยอดขาด',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white70
                                        : (isOk
                                            ? const Color(0xFF2E7D32)
                                            : const Color(0xFFC62828)),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '฿${_change.abs().toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: isOk
                                    ? const Color(0xFF4CAF50)
                                    : const Color(0xFFEF5350),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
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

                  // ── ปุ่มชำระเงิน ──────────────────────────────────
                  Builder(builder: (context) {
                    final isDisabled =
                        (_paymentType == 'CASH' && _change < 0) ||
                            _isProcessing;
                    final cartState = ref.watch(cartProvider);

                    final isDark =
                        Theme.of(context).brightness == Brightness.dark;

                    return SizedBox(
                      height: 64,
                      child: ElevatedButton(
                        onPressed: isDisabled ? null : _handlePayment,
                        style: ElevatedButton.styleFrom(
                          // dark: ส้มเข้ม #E57200 ชัดบน dark bg
                          // light: ใช้สีจาก AppTheme (default)
                          backgroundColor: isDisabled
                              ? null
                              : (isDark
                                  ? const Color(0xFFE57200)
                                  : null),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: isDark
                              ? const Color(0xFF2A2A2A)
                              : Colors.grey[300],
                          disabledForegroundColor: isDark
                              ? Colors.white30
                              : Colors.grey[500],
                          elevation: isDisabled ? 0 : 3,
                          shadowColor: isDark
                              ? const Color(0xFFE57200).withValues(alpha: 0.5)
                              : null,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isProcessing
                            ? const SizedBox(
                                height: 26,
                                width: 26,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _paymentType == 'TRANSFER'
                                        ? Icons.check_circle_outline
                                        : Icons.payments_outlined,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _paymentType == 'TRANSFER'
                                            ? 'ยืนยันรับเงินโอนแล้ว'
                                            : 'ชำระเงิน',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      if (_paymentType == 'CASH' &&
                                          !isDisabled)
                                        Text(
                                          '฿${cartState.total.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.white70,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// สร้างปุ่มจำนวนเงินด่วนอัตโนมัติจากยอดขาย
  /// เริ่มจากพอดียอด → กลมขึ้นไปเรื่อย ๆ ตามลำดับ
  List<double> _buildQuickAmounts(double total) {
    final result = <double>[total]; // พอดียอดเสมอ

    // ระดับการปัด: 10, 20, 50, 100, 200, 500, 1000
    const steps = [10, 20, 50, 100, 200, 500, 1000];

    for (final step in steps) {
      // หาค่าที่มากกว่า total และหารด้วย step ลงตัว
      final rounded = ((total / step).ceil()) * step.toDouble();
      if (rounded > total && !result.contains(rounded)) {
        result.add(rounded);
      }
      if (result.length >= 6) break;
    }

    // ถ้ายังไม่ครบ 6 ให้เพิ่ม +500, +1000 จากค่าสุดท้าย
    while (result.length < 6) {
      final last = result.last;
      final next = last + (last >= 1000 ? 1000 : 500);
      result.add(next);
    }

    return result;
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
        'discount_amount': cartState.totalDiscount + cartState.totalCouponDiscount,
        'coupon_discount': cartState.totalCouponDiscount,
        'amount_before_vat': cartState.total,
        'vat_amount': 0.0,
        'total_amount': cartState.total,
        'payment_type': _paymentType,
        'paid_amount':
            _paymentType == 'CASH' ? _receivedAmount : cartState.total,
        'change_amount': _paymentType == 'CASH' ? _change : 0.0,
        if (cartState.appliedCoupons.isNotEmpty)
          'coupon_codes':
              cartState.appliedCoupons.map((c) => c.code).toList(),
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
        // ── Mark all coupons as used ──────────────────────────────
        for (final coupon in cartState.appliedCoupons) {
          try {
            await apiClient.put(
              '/api/promotions/coupons/${coupon.code.toUpperCase()}/use',
              data: {'customer_id': cartState.customerId},
            );
          } catch (e) {
            print('⚠️ Could not mark coupon ${coupon.code} as used: $e');
          }
        }
        if (cartState.appliedCoupons.isNotEmpty) {
          ref.read(couponListProvider.notifier).refresh();
        }

        ref.read(cartProvider.notifier).clear();

        // ✅ refresh sales list & dashboard หลังบันทึกออเดอร์สำเร็จ
        ref.invalidate(salesHistoryProvider);
        ref.invalidate(dashboardProvider);

        // ✅ อ่านค่าแบบ null-safe ป้องกัน crash ถ้า API response ผิดรูปแบบ
        final responseData =
            response.data is Map ? response.data as Map : {};
        final dataMap =
            responseData['data'] is Map ? responseData['data'] as Map : {};
        final orderNo      = dataMap['order_no'] as String? ?? '-';
        final earnedPoints = dataMap['earned_points'] as int? ?? 0;

        // ✅ refresh customer list เพื่อให้ points อัพเดททันที
        ref.read(customerListProvider.notifier).refresh();

        // ✅ คำนวณค่าทั้งหมดก่อน navigate — ป้องกัน ref ถูกเรียกหลัง unmount
        final paidAmount   = _paymentType == 'CASH' ? _receivedAmount : cartState.total;
        final changeAmount = _paymentType == 'CASH' ? _receivedAmount - cartState.total : 0.0;

        if (mounted) {
          // ✅ ไปหน้าใบเสร็จแทน dialog
          await Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ReceiptPage(
                orderNo:        orderNo,
                orderDate:      DateTime.now(),
                customerName:   cartState.customerName,
                items:          cartState.items,
                subtotal:       cartState.subtotal,
                discount:       cartState.totalDiscount,
                appliedCoupons: cartState.appliedCoupons,
                total:          cartState.total,
                paymentType:    _paymentType,
                paidAmount:     paidAmount,
                changeAmount:   changeAmount,
                earnedPoints:   earnedPoints,
              ),
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
// _CouponSection — กรอกคูปองได้หลายใบ
// ─────────────────────────────────────────────────────────────────
class _CouponSection extends StatelessWidget {
  final TextEditingController controller;
  final bool isValidating;
  final String? errorText;
  final List<AppliedCoupon> appliedCoupons;
  final VoidCallback onApply;
  final ValueChanged<String> onRemove;
  final VoidCallback onScan;

  const _CouponSection({
    required this.controller,
    required this.isValidating,
    required this.errorText,
    required this.appliedCoupons,
    required this.onApply,
    required this.onRemove,
    required this.onScan,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00', 'th_TH');
    final hasApplied = appliedCoupons.isNotEmpty;
    final totalDiscount =
        appliedCoupons.fold(0.0, (s, c) => s + c.discount);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hasApplied
            ? (isDark ? const Color(0xFF1A2E1A) : const Color(0xFFE8F5E9))
            : (isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF9F9F9)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasApplied
              ? const Color(0xFF4CAF50)
              : errorText != null
                  ? const Color(0xFFEF5350)
                  : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────
          Row(
            children: [
              const Icon(Icons.confirmation_number_outlined,
                  size: 18, color: Color(0xFF1565C0)),
              const SizedBox(width: 8),
              const Text(
                'คูปองส่วนลด',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1565C0)),
              ),
              if (hasApplied) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${appliedCoupons.length} ใบ',
                    style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                const Spacer(),
                Text(
                  'ส่วนลดรวม ฿${fmt.format(totalDiscount)}',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2E7D32)),
                ),
              ],
            ],
          ),

          // ── Applied coupon chips ─────────────────────────────
          if (hasApplied) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: appliedCoupons.map((c) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: const Color(0xFF4CAF50).withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle,
                          size: 13, color: Color(0xFF2E7D32)),
                      const SizedBox(width: 5),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            c.code,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                              color: Color(0xFF1B5E20),
                            ),
                          ),
                          if (c.promotionName != null)
                            Text(
                              c.promotionName!,
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF388E3C)),
                            ),
                          Text(
                            'ลด ฿${fmt.format(c.discount)}',
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2E7D32)),
                          ),
                        ],
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () => onRemove(c.code),
                        borderRadius: BorderRadius.circular(4),
                        child: const Padding(
                          padding: EdgeInsets.all(2),
                          child: Icon(Icons.close,
                              size: 14, color: Color(0xFFEF5350)),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],

          // ── Input row (always visible) ────────────────────────
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5),
                  decoration: InputDecoration(
                    hintText: hasApplied
                        ? 'เพิ่มคูปองอีกใบ...'
                        : 'กรอกรหัสคูปอง',
                    hintStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.normal,
                        letterSpacing: 0,
                        color: Colors.grey.shade500),
                    errorText: errorText,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: errorText != null
                            ? const Color(0xFFEF5350)
                            : Colors.grey.shade300,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                          color: Color(0xFF1565C0), width: 1.5),
                    ),
                    isDense: true,
                  ),
                  onSubmitted: (_) => onApply(),
                ),
              ),
              const SizedBox(width: 8),
              // ── ปุ่มสแกน QR ──────────────────────────────
              SizedBox(
                height: 42,
                width: 42,
                child: Tooltip(
                  message: 'สแกน QR คูปอง',
                  child: OutlinedButton(
                    onPressed: isValidating ? null : onScan,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1565C0),
                      side: const BorderSide(color: Color(0xFF1565C0)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: EdgeInsets.zero,
                    ),
                    child: const Icon(Icons.qr_code_scanner, size: 20),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 42,
                child: ElevatedButton(
                  onPressed: isValidating ? null : onApply,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: isValidating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('ใช้งาน',
                          style: TextStyle(fontSize: 13)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
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

// ─────────────────────────────────────────────────────────────────
// ReceiptPage — หน้าใบเสร็จ thermal style
// แสดงหลังชำระเงินสำเร็จ กดกลับไปหน้าขาย
// ─────────────────────────────────────────────────────────────────
class ReceiptPage extends ConsumerWidget {
  final String   orderNo;
  final DateTime orderDate;
  final String?  customerName;
  final List<CartItem> items;
  final double   subtotal;
  final double   discount;
  final List<AppliedCoupon> appliedCoupons;
  final double   total;
  final String   paymentType;
  final double   paidAmount;
  final double   changeAmount;
  final int      earnedPoints;

  const ReceiptPage({
    super.key,
    required this.orderNo,
    required this.orderDate,
    required this.items,
    required this.subtotal,
    required this.discount,
    required this.total,
    required this.paymentType,
    required this.paidAmount,
    required this.changeAmount,
    this.customerName,
    this.appliedCoupons = const [],
    this.earnedPoints = 0,
  });

  static String _paymentLabel(String type) => switch (type) {
        'CASH'     => 'เงินสด',
        'CARD'     => 'บัตรเครดิต/เดบิต',
        'TRANSFER' => 'โอนเงิน',
        _          => type,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final dateFmt  = DateFormat('dd/MM/yyyy HH:mm');
    final numFmt   = NumberFormat('#,##0.00');

    return Scaffold(
      backgroundColor: const Color(0xFFEEEEEE),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('ใบเสร็จรับเงิน'),
        actions: [
          TextButton.icon(
            onPressed: () =>
                Navigator.of(context).pop(),
            icon: const Icon(Icons.storefront, color: Colors.white),
            label: const Text('กลับหน้าขาย',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            children: [
              // ── ใบเสร็จ ─────────────────────────────────────────
              _ThermalReceipt(
                companyName:    settings.companyName,
                address:        settings.address,
                phone:          settings.phone,
                taxId:          settings.taxId,
                orderNo:        orderNo,
                orderDate:      dateFmt.format(orderDate),
                customerName:   customerName,
                items:          items,
                subtotal:       subtotal,
                discount:       discount,
                appliedCoupons: appliedCoupons,
                total:          total,
                paymentLabel:   _paymentLabel(paymentType),
                paymentType:    paymentType,
                paidAmount:     paidAmount,
                changeAmount:   changeAmount,
                earnedPoints:   earnedPoints,
                numFmt:         numFmt,
              ),

              const SizedBox(height: 32),

              // ── ปุ่มกลับ ─────────────────────────────────────────
              SizedBox(
                width: 340,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () =>
                      Navigator.of(context).pop(),
                  icon: const Icon(Icons.storefront, size: 20),
                  label: const Text(
                    'กลับหน้าขาย',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// _ThermalReceipt — ใบเสร็จ thermal printer style
// ─────────────────────────────────────────────────────────────────
class _ThermalReceipt extends StatelessWidget {
  final String   companyName;
  final String   address;
  final String   phone;
  final String   taxId;
  final String   orderNo;
  final String   orderDate;
  final String?  customerName;
  final List<CartItem> items;
  final double   subtotal;
  final double   discount;
  final List<AppliedCoupon> appliedCoupons;
  final double   total;
  final String   paymentLabel;
  final String   paymentType;
  final double   paidAmount;
  final double   changeAmount;
  final int      earnedPoints;
  final NumberFormat numFmt;

  const _ThermalReceipt({
    required this.companyName,
    required this.address,
    required this.phone,
    required this.taxId,
    required this.orderNo,
    required this.orderDate,
    required this.items,
    required this.subtotal,
    required this.discount,
    required this.total,
    required this.paymentLabel,
    required this.paymentType,
    required this.paidAmount,
    required this.changeAmount,
    required this.numFmt,
    this.customerName,
    this.appliedCoupons = const [],
    this.earnedPoints = 0,
  });

  // ── shared text style ────────────────────────────────────────
  static const _mono    = TextStyle(fontFamily: 'monospace', fontSize: 13, color: Colors.black87);
  static const _monoSm  = TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.black54);
  static const _monoBd  = TextStyle(fontFamily: 'monospace', fontSize: 13,
      fontWeight: FontWeight.bold, color: Colors.black87);
  static const _monoLg  = TextStyle(fontFamily: 'monospace', fontSize: 18,
      fontWeight: FontWeight.bold, color: Colors.black);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 340,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── รอยปรุ ด้านบน ──────────────────────────────────────
          _PerforatedEdge(top: true),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ── ข้อมูลร้าน ─────────────────────────────────
                Text(companyName,
                    style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black),
                    textAlign: TextAlign.center),
                if (address.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(address,
                      style: _monoSm, textAlign: TextAlign.center),
                ],
                if (phone.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text('โทร: $phone', style: _monoSm),
                ],
                if (taxId.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text('เลขภาษี: $taxId', style: _monoSm),
                ],

                _dashed(),

                // ── หัวใบเสร็จ ─────────────────────────────────
                const Text('ใบเสร็จรับเงิน',
                    style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
                const SizedBox(height: 6),
                _row('เลขที่', orderNo),
                _row('วันที่', orderDate),
                if (customerName != null && customerName != 'ลูกค้าทั่วไป')
                  _row('ลูกค้า', customerName!),

                _dashed(),

                // ── รายการสินค้า ────────────────────────────────
                ...items.map((item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.productName, style: _monoBd,
                              overflow: TextOverflow.ellipsis),
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '  ${item.quantity.toStringAsFixed(0)} x '
                                '${numFmt.format(item.unitPrice)}',
                                style: _monoSm,
                              ),
                              Text(numFmt.format(item.amount),
                                  style: _mono),
                            ],
                          ),
                        ],
                      ),
                    )),

                _dashed(),

                // ── สรุปยอด ────────────────────────────────────
                _row('รวม', '฿${numFmt.format(subtotal)}'),
                if (discount > 0)
                  _row('ส่วนลด', '-฿${numFmt.format(discount)}',
                      valueColor: Colors.red[700]),
                ...appliedCoupons.map((c) => _row(
                      'คูปอง ${c.code}',
                      '-฿${numFmt.format(c.discount)}',
                      valueColor: Colors.red[700],
                      subLabel: c.promotionName,
                    )),

                const SizedBox(height: 4),
                _solidLine(),
                const SizedBox(height: 4),

                // ยอดชำระ — ใหญ่
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('ยอดชำระ', style: _monoBd),
                    Text('฿${numFmt.format(total)}', style: _monoLg),
                  ],
                ),

                const SizedBox(height: 4),
                _solidLine(),
                const SizedBox(height: 6),

                // วิธีชำระ / รับเงิน / ทอน
                _row('ชำระด้วย', paymentLabel),
                if (paymentType == 'CASH') ...[
                  _row('รับเงิน', '฿${numFmt.format(paidAmount)}'),
                  _row('เงินทอน', '฿${numFmt.format(changeAmount)}',
                      valueColor: Colors.green[700]),
                ],

                // แต้มสะสม
                if (earnedPoints > 0) ...[
                  _dashed(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.stars,
                          size: 14, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text('ได้รับ $earnedPoints แต้มสะสม',
                          style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              color: Colors.amber,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],

                _dashed(),

                // ── ขอบคุณ ─────────────────────────────────────
                const SizedBox(height: 4),
                const Text('ขอบคุณที่ใช้บริการ',
                    style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
                const Text('(THANK YOU)',
                    style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: Colors.black45)),
                const Text('โปรดเก็บใบเสร็จไว้เป็นหลักฐาน',
                    style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        color: Colors.black38)),
                const SizedBox(height: 4),
              ],
            ),
          ),

          // ── รอยปรุ ด้านล่าง ────────────────────────────────────
          _PerforatedEdge(top: false),
        ],
      ),
    );
  }

  // helpers
  Widget _row(String label, String value, {Color? valueColor, String? subLabel}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: _mono),
                  if (subLabel != null && subLabel.isNotEmpty)
                    Text(subLabel, style: _monoSm, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Text(value,
                style: valueColor != null
                    ? _mono.copyWith(color: valueColor)
                    : _mono),
          ],
        ),
      );

  Widget _dashed() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: List.generate(
            38,
            (_) => Expanded(
              child: Container(
                height: 1,
                color: Colors.grey[300],
                margin: const EdgeInsets.symmetric(horizontal: 1),
              ),
            ),
          ),
        ),
      );

  Widget _solidLine() => Container(height: 1.5, color: Colors.black87);
}

// ─────────────────────────────────────────────────────────────────
// _PerforatedEdge — รอยปรุกระดาษ thermal
// ─────────────────────────────────────────────────────────────────
class _PerforatedEdge extends StatelessWidget {
  final bool top;
  const _PerforatedEdge({required this.top});

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: SizedBox(
        height: 12,
        child: Row(
          children: List.generate(28, (i) {
            return Expanded(
              child: Container(
                height: 12,
                margin: EdgeInsets.only(
                  left: i == 0 ? 0 : 2,
                  right: i == 27 ? 0 : 0,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEEEEE),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}