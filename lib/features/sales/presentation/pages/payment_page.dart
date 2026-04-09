// ignore_for_file: avoid_print

import 'package:dio/dio.dart';
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
import '../../../inventory/presentation/providers/stock_provider.dart';
import '../../../products/presentation/providers/product_provider.dart';
import '../../../branches/presentation/providers/branch_provider.dart';
import '../../../../core/config/app_mode.dart';
import '../../../../core/services/pending_sales_queue_service.dart';
import '../../../../shared/services/mobile_scanner_service.dart';
import '../../../../shared/widgets/mobile_home_button.dart';
import '../../../../shared/widgets/thermal_receipt.dart';

class PaymentPage extends ConsumerStatefulWidget {
  const PaymentPage({super.key});

  @override
  ConsumerState<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends ConsumerState<PaymentPage> {
  String _paymentType = 'CASH';
  final TextEditingController _receivedController = TextEditingController();
  final FocusNode _receivedFocusNode = FocusNode();
  double _receivedAmount = 0;
  bool _isProcessing = false;

  // ── Coupon ──────────────────────────────────────────────────────
  final TextEditingController _couponController = TextEditingController();
  bool _isValidatingCoupon = false;
  String? _couponError;

  // ── Points redemption ────────────────────────────────────────────
  int _customerPoints = 0; // แต้มคงเหลือของลูกค้า (โหลดจาก API)
  int _pointsUsed = 0; // แต้มที่เลือกจะใช้ในบิลนี้
  bool _isLoadingPoints = false;

  @override
  void initState() {
    super.initState();
    final cartState = ref.read(cartProvider);
    _receivedAmount = cartState.total;
    _receivedController.text = cartState.total.toStringAsFixed(2);

    // โฟกัสและเลือกทั้งหมดหลัง frame แรก
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _receivedFocusNode.requestFocus();
      _receivedController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _receivedController.text.length,
      );
      _loadCustomerPoints();
    });
  }

  Future<void> _loadCustomerPoints() async {
    final cartState = ref.read(cartProvider);
    final customerId = cartState.customerId;
    if (customerId == null || customerId == 'WALK_IN' || customerId.isEmpty) {
      return;
    }

    setState(() => _isLoadingPoints = true);
    final pts = await ref
        .read(salesHistoryProvider.notifier)
        .getCustomerPoints(customerId);
    if (mounted) {
      setState(() {
        _customerPoints = pts;
        _isLoadingPoints = false;
      });
    }
  }

  /// คำนวณยอดหลังหักแต้ม
  double get _netTotal {
    final cartState = ref.read(cartProvider);
    return (cartState.total - _pointsUsed).clamp(0.0, double.infinity);
  }

  void _applyPoints(int points) {
    final cartState = ref.read(cartProvider);
    final maxPoints = cartState.total.floor().clamp(0, _customerPoints);
    final used = points.clamp(0, maxPoints);
    setState(() {
      _pointsUsed = used;
      _receivedAmount = _netTotal;
      _receivedController.text = _netTotal.toStringAsFixed(2);
    });
  }

  @override
  void dispose() {
    _receivedController.dispose();
    _receivedFocusNode.dispose();
    _couponController.dispose();
    super.dispose();
  }

  double get _change => _receivedAmount - _netTotal;

  // ── Validate & apply coupon ─────────────────────────────────────
  Future<void> _applyCoupon() async {
    final code = _couponController.text.trim().toUpperCase();
    if (code.isEmpty) return;

    setState(() {
      _isValidatingCoupon = true;
      _couponError = null;
    });

    try {
      final result = await ref
          .read(couponListProvider.notifier)
          .validateCoupon(code);

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
        setState(
          () => _couponError = 'คูปองนี้ไม่สามารถใช้ร่วมกับคูปองอื่นได้',
        );
        return;
      }
      if (existing.any((c) => c.isExclusive)) {
        setState(
          () => _couponError =
              'มีคูปอง Exclusive อยู่แล้ว ไม่สามารถเพิ่มคูปองอื่นได้',
        );
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

      ref
          .read(cartProvider.notifier)
          .applyCoupon(
            AppliedCoupon(
              code: code,
              discount: couponDiscount,
              promotionId: promoId,
              promotionName: result['promotion_name'] as String?,
              isExclusive: isExclusive,
            ),
          );

      _couponController.clear();
      setState(() => _couponError = null);

      // อัปเดตยอดรับ (CASH) คำนึงถึงแต้มที่ใช้ด้วย
      final newTotal = ref.read(cartProvider).total;
      final maxPts = newTotal.floor().clamp(0, _customerPoints);
      _pointsUsed = _pointsUsed.clamp(0, maxPts);
      final net = (newTotal - _pointsUsed).clamp(0.0, double.infinity);
      setState(() {
        _receivedAmount = net;
        _receivedController.text = net.toStringAsFixed(2);
      });
    } finally {
      if (mounted) setState(() => _isValidatingCoupon = false);
    }
  }

  void _removeCoupon(String code) {
    ref.read(cartProvider.notifier).removeCoupon(code);
    setState(() => _couponError = null);
    // re-clamp pointsUsed in case total changed
    final newTotal = ref.read(cartProvider).total;
    final maxPts = newTotal.floor().clamp(0, _customerPoints);
    _pointsUsed = _pointsUsed.clamp(0, maxPts);
    final net = (newTotal - _pointsUsed).clamp(0.0, double.infinity);
    setState(() {
      _receivedAmount = net;
      _receivedController.text = net.toStringAsFixed(2);
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
    ref.watch(posContextBootstrapProvider);
    final cartState = ref.watch(cartProvider);
    final settings = ref.watch(settingsProvider);
    final promptPayId = settings.promptPayId.trim();
    final hasPromptPay = PromptPayUtils.isValidPromptPayId(promptPayId);

    return Scaffold(
      appBar: AppBar(
        leading: buildMobileHomeLeading(context),
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
                  Builder(
                    builder: (context) {
                      final isDark =
                          Theme.of(context).brightness == Brightness.dark;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 20,
                          horizontal: 24,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isDark
                                ? [
                                    const Color(0xFF0D2137),
                                    const Color(0xFF0D3354),
                                  ]
                                : [
                                    const Color(0xFF1565C0),
                                    const Color(0xFF1976D2),
                                  ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF1565C0,
                              ).withValues(alpha: 0.3),
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
                                const Icon(
                                  Icons.receipt_long,
                                  color: Colors.white70,
                                  size: 16,
                                ),
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
                              '฿${_netTotal.toStringAsFixed(2)}',
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
                            if (_pointsUsed > 0) ...[
                              const SizedBox(height: 2),
                              Text(
                                'แลกแต้ม $_pointsUsed pt = -฿${_pointsUsed.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange[200],
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
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
                  const SizedBox(height: 12),

                  // ── แลกแต้ม (เฉพาะสมาชิก) ──────────────────────
                  if (cartState.customerId != null &&
                      cartState.customerId != 'WALK_IN' &&
                      cartState.customerId!.isNotEmpty)
                    _PointsSection(
                      customerPoints: _customerPoints,
                      pointsUsed: _pointsUsed,
                      cartTotal: cartState.total,
                      isLoading: _isLoadingPoints,
                      onApply: _applyPoints,
                      onClear: () => _applyPoints(0),
                    ),
                  if (cartState.customerId != null &&
                      cartState.customerId != 'WALK_IN' &&
                      cartState.customerId!.isNotEmpty)
                    const SizedBox(height: 12),

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
                      focusNode: _receivedFocusNode,
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
                    Builder(
                      builder: (context) {
                        final isDark =
                            Theme.of(context).brightness == Brightness.dark;
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
                                _receivedController.text = amount
                                    .toStringAsFixed(2);
                              }),
                              borderRadius: BorderRadius.circular(8),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
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
                      },
                    ),
                    const SizedBox(height: 24),

                    // เงินทอน
                    Builder(
                      builder: (context) {
                        final isDark =
                            Theme.of(context).brightness == Brightness.dark;
                        final isOk = _change >= 0;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 24,
                          ),
                          decoration: BoxDecoration(
                            // dark: bg มืดตาม isOk, border บาง
                            // light: เขียวอ่อน/แดงอ่อน ตาม isOk
                            color: isDark
                                ? (isOk
                                      ? const Color(0xFF1A2E1A) // เขียวมืด
                                      : const Color(
                                          0xFF2A1A1A,
                                        )) // แดงมืด (อ่อนกว่าเดิม)
                                : (isOk
                                      ? const Color(0xFFE8F5E9)
                                      : const Color(0xFFFFEBEE)),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? (isOk
                                        ? const Color(
                                            0xFF4CAF50,
                                          ).withValues(alpha: 0.25)
                                        : const Color(
                                            0xFFF44336,
                                          ).withValues(alpha: 0.25))
                                  : (isOk
                                        ? const Color(
                                            0xFF4CAF50,
                                          ).withValues(alpha: 0.3)
                                        : const Color(
                                            0xFFF44336,
                                          ).withValues(alpha: 0.3)),
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
                      },
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
                      Builder(
                        builder: (context) {
                          final isDark =
                              Theme.of(context).brightness == Brightness.dark;
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF2A1F00)
                                  : Colors.orange[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark
                                    ? Colors.orange.withValues(alpha: 0.4)
                                    : Colors.orange.shade200,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  color: isDark
                                      ? Colors.orange[300]
                                      : Colors.orange[700],
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'ยังไม่ได้ตั้งค่าเลข PromptPay',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'ไปที่ ตั้งค่า → ข้อมูลบริษัท → เลข PromptPay',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark
                                              ? Colors.white54
                                              : Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 16),
                  ],

                  // ── บัตร ───────────────────────────────────────────
                  if (_paymentType == 'CARD') ...[
                    const SizedBox(height: 8),
                    Builder(
                      builder: (context) {
                        final isDark =
                            Theme.of(context).brightness == Brightness.dark;
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF0D2137)
                                : Colors.blue[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF1565C0).withValues(alpha: 0.5)
                                  : Colors.blue.shade200,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.credit_card,
                                color: isDark
                                    ? const Color(0xFF90CAF9)
                                    : Colors.blue,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'รูดบัตรที่เครื่อง EDC แล้วกดยืนยัน',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  const SizedBox(height: 32),

                  // ── ปุ่มชำระเงิน ──────────────────────────────────
                  Builder(
                    builder: (context) {
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
                                : (isDark ? const Color(0xFFE57200) : null),
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
                                  mainAxisAlignment: MainAxisAlignment.center,
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
                    },
                  ),
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
      final selectedBranch = ref.read(selectedBranchProvider);
      final selectedWarehouse = ref.read(selectedWarehouseProvider);
      // ✅ เก็บ netTotal ก่อน clear cart — getter _netTotal อ่านจาก cart
      final netTotal = _netTotal;

      if (selectedBranch == null || selectedWarehouse == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('กรุณาเลือกสาขาและคลังของเครื่องนี้ก่อนชำระเงิน'),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => _isProcessing = false);
        return;
      }

      final orderData = {
        'customer_id': cartState.customerId,
        'customer_name': cartState.customerName,
        'user_id': authState.user?.userId ?? 'USR001',
        'branch_id': selectedBranch.branchId,
        'warehouse_id': selectedWarehouse.warehouseId,
        'subtotal': cartState.subtotal,
        'discount_amount':
            cartState.totalDiscount + cartState.totalCouponDiscount,
        'coupon_discount': cartState.totalCouponDiscount,
        'points_used': _pointsUsed,
        'amount_before_vat': _netTotal,
        'vat_amount': 0.0,
        'total_amount': _netTotal,
        'payment_type': _paymentType,
        'paid_amount': _paymentType == 'CASH' ? _receivedAmount : _netTotal,
        'change_amount': _paymentType == 'CASH' ? _change : 0.0,
        if (cartState.appliedCoupons.isNotEmpty)
          'coupon_codes': cartState.appliedCoupons.map((c) => c.code).toList(),
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
        if (cartState.freeItems.isNotEmpty) ...{
          'free_items': cartState.freeItems
              .map(
                (item) => {
                  'product_id': item.productId,
                  'product_code': item.productCode,
                  'product_name': item.productName,
                  'unit': item.unit,
                  'quantity': item.quantity,
                  'promotion_id': item.promotionId,
                },
              )
              .toList(),
          'promotion_ids': cartState.freeItems
              .map((i) => i.promotionId)
              .whereType<String>()
              .toSet()
              .toList(),
        },
      };

      print('📦 Sending order: total=${orderData['total_amount']}');

      final response = await apiClient.post('/api/sales', data: orderData);

      print('✅ Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        // ✅ อ่านค่าจาก response ก่อน — ต้องใช้ orderNo ใน coupon use call
        final responseData = response.data is Map ? response.data as Map : {};
        final dataMap = responseData['data'] is Map
            ? responseData['data'] as Map
            : {};
        final orderNo = dataMap['order_no'] as String? ?? '-';
        final earnedPoints = dataMap['earned_points'] as int? ?? 0;

        // ── Mark all coupons as used ──────────────────────────────
        for (final coupon in cartState.appliedCoupons) {
          try {
            await apiClient.put(
              '/api/promotions/coupons/${coupon.code.toUpperCase()}/use',
              data: {'customer_id': cartState.customerId, 'order_no': orderNo},
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
        // ✅ refresh stock — ตัดสต๊อกแล้วต้องให้ UI อัปเดตทันที
        ref.invalidate(stockBalanceProvider);
        ref.invalidate(productListProvider);

        // ✅ refresh customer list เพื่อให้ points อัพเดททันที
        ref.read(customerListProvider.notifier).refresh();

        // ✅ คำนวณค่าทั้งหมดก่อน navigate — ป้องกัน ref ถูกเรียกหลัง unmount
        final paidAmount = _paymentType == 'CASH' ? _receivedAmount : netTotal;
        final changeAmount = _paymentType == 'CASH'
            ? _receivedAmount - netTotal
            : 0.0;

        if (mounted) {
          // ✅ ไปหน้าใบเสร็จแทน dialog
          await Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ReceiptPage(
                orderNo: orderNo,
                orderDate: DateTime.now(),
                customerName: cartState.customerName,
                items: cartState.items,
                freeItems: cartState.freeItems,
                subtotal: cartState.subtotal,
                discount: cartState.totalDiscount,
                appliedCoupons: cartState.appliedCoupons,
                total: netTotal,
                paymentType: _paymentType,
                paidAmount: paidAmount,
                changeAmount: changeAmount,
                earnedPoints: earnedPoints,
                pointsUsed: _pointsUsed,
                pointsBalance:
                    (cartState.customerId != null &&
                        cartState.customerId != 'WALK_IN' &&
                        cartState.customerId!.isNotEmpty)
                    ? _customerPoints - _pointsUsed + earnedPoints
                    : null,
              ),
            ),
          );
        }
      } else {
        // ✅ อ่าน error message จาก API แต่ไม่ expose raw exception
        final responseData = response.data is Map ? response.data as Map : {};
        final serverMsg =
            responseData['message'] as String? ?? 'ไม่สามารถบันทึกออเดอร์ได้';
        throw Exception(serverMsg);
      }
    } on DioException catch (e) {
      print('❌ Payment error: $e');

      final shouldQueue =
          AppModeConfig.isClient &&
          (e.response == null ||
              e.type == DioExceptionType.connectionError ||
              e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.receiveTimeout ||
              e.type == DioExceptionType.unknown);

      if (shouldQueue) {
        final cartState = ref.read(cartProvider);
        final authState = ref.read(authProvider);
        final selectedBranch = ref.read(selectedBranchProvider);
        final selectedWarehouse = ref.read(selectedWarehouseProvider);

        if (selectedBranch != null && selectedWarehouse != null) {
          final fallbackOrderData = {
            'customer_id': cartState.customerId,
            'customer_name': cartState.customerName,
            'user_id': authState.user?.userId ?? 'USR001',
            'branch_id': selectedBranch.branchId,
            'warehouse_id': selectedWarehouse.warehouseId,
            'subtotal': cartState.subtotal,
            'discount_amount':
                cartState.totalDiscount + cartState.totalCouponDiscount,
            'coupon_discount': cartState.totalCouponDiscount,
            'points_used': _pointsUsed,
            'amount_before_vat': _netTotal,
            'vat_amount': 0.0,
            'total_amount': _netTotal,
            'payment_type': _paymentType,
            'paid_amount': _paymentType == 'CASH' ? _receivedAmount : _netTotal,
            'change_amount': _paymentType == 'CASH' ? _change : 0.0,
            if (cartState.appliedCoupons.isNotEmpty)
              'coupon_codes': cartState.appliedCoupons
                  .map((c) => c.code)
                  .toList(),
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
            if (cartState.freeItems.isNotEmpty) ...{
              'free_items': cartState.freeItems
                  .map(
                    (item) => {
                      'product_id': item.productId,
                      'product_code': item.productCode,
                      'product_name': item.productName,
                      'unit': item.unit,
                      'quantity': item.quantity,
                      'promotion_id': item.promotionId,
                    },
                  )
                  .toList(),
              'promotion_ids': cartState.freeItems
                  .map((i) => i.promotionId)
                  .whereType<String>()
                  .toSet()
                  .toList(),
            },
          };

          await ref
              .read(pendingSalesQueueServiceProvider)
              .enqueueOrder(fallbackOrderData);
          ref.read(cartProvider.notifier).clear();
          ref.invalidate(syncStatusProvider);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'เชื่อมต่อ Master ไม่ได้ บิลถูกเก็บเข้าคิวในเครื่องนี้แล้ว และจะส่งอัตโนมัติเมื่อ Wi‑Fi กลับมา',
                ),
                backgroundColor: Colors.orange,
              ),
            );
            Navigator.of(context).pop();
          }
          return;
        }
      }

      if (mounted) {
        // ✅ แสดงข้อความที่เป็นมิตรกับผู้ใช้ ไม่หลุด stack trace หรือ schema
        final userMessage = _toUserMessage(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userMessage), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      print('❌ Payment error: $e');

      if (mounted) {
        final userMessage = _toUserMessage(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userMessage), backgroundColor: Colors.red),
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
    final totalDiscount = appliedCoupons.fold(0.0, (s, c) => s + c.discount);
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
              const Icon(
                Icons.confirmation_number_outlined,
                size: 18,
                color: Color(0xFF1565C0),
              ),
              const SizedBox(width: 8),
              const Text(
                'คูปองส่วนลด',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1565C0),
                ),
              ),
              if (hasApplied) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${appliedCoupons.length} ใบ',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  'ส่วนลดรวม ฿${fmt.format(totalDiscount)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2E7D32),
                  ),
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
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF4CAF50).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle,
                        size: 13,
                        color: Color(0xFF2E7D32),
                      ),
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
                                color: Color(0xFF388E3C),
                              ),
                            ),
                          Text(
                            'ลด ฿${fmt.format(c.discount)}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2E7D32),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () => onRemove(c.code),
                        borderRadius: BorderRadius.circular(4),
                        child: const Padding(
                          padding: EdgeInsets.all(2),
                          child: Icon(
                            Icons.close,
                            size: 14,
                            color: Color(0xFFEF5350),
                          ),
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
                    letterSpacing: 1.5,
                  ),
                  decoration: InputDecoration(
                    hintText: hasApplied
                        ? 'เพิ่มคูปองอีกใบ...'
                        : 'กรอกรหัสคูปอง',
                    hintStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.normal,
                      letterSpacing: 0,
                      color: Colors.grey.shade500,
                    ),
                    errorText: errorText,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
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
                        color: Color(0xFF1565C0),
                        width: 1.5,
                      ),
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
                        borderRadius: BorderRadius.circular(8),
                      ),
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
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: isValidating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('ใช้งาน', style: TextStyle(fontSize: 13)),
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

  const _PromptPayQrSection({required this.promptPayId, required this.amount});

  @override
  Widget build(BuildContext context) {
    final qrData = PromptPayUtils.generatePayload(promptPayId, amount);
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
                Text(
                  'PromptPay QR Code',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
                const Text(
                  'ยอดที่ต้องชำระ',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 4),
                Text(
                  '฿${amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1565C0),
                  ),
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
                Text(
                  'PromptPay: $displayId',
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
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
  final String orderNo;
  final DateTime orderDate;
  final String? customerName;
  final List<CartItem> items;
  final List<CartItem> freeItems;
  final double subtotal;
  final double discount;
  final List<AppliedCoupon> appliedCoupons;
  final double total;
  final String paymentType;
  final double paidAmount;
  final double changeAmount;
  final int earnedPoints;
  final int pointsUsed;
  final int? pointsBalance;

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
    this.freeItems = const [],
    this.appliedCoupons = const [],
    this.earnedPoints = 0,
    this.pointsUsed = 0,
    this.pointsBalance,
  });

  static String _paymentLabel(String type) => switch (type) {
    'CASH' => 'เงินสด',
    'CARD' => 'บัตรเครดิต/เดบิต',
    'TRANSFER' => 'โอนเงิน',
    _ => type,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final dateFmt = DateFormat('dd/MM/yyyy HH:mm');
    final numFmt = NumberFormat('#,##0.00');

    return Scaffold(
      backgroundColor: const Color(0xFFEEEEEE),
      appBar: AppBar(
        leading: buildMobileHomeLeading(context),
        automaticallyImplyLeading: false,
        title: const Text('ใบเสร็จรับเงิน'),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.storefront, color: Colors.white),
            label: const Text(
              'กลับหน้าขาย',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            children: [
              // ── ใบเสร็จ ─────────────────────────────────────────
              ThermalReceiptWidget(
                companyName: settings.companyName,
                address: settings.address,
                phone: settings.phone,
                taxId: settings.taxId,
                orderNo: orderNo,
                orderDate: dateFmt.format(orderDate),
                customerName: customerName,
                items: items
                    .map(
                      (i) => ReceiptItem(
                        name: i.productName,
                        quantity: i.quantity,
                        unitPrice: i.unitPrice,
                        amount: i.amount,
                      ),
                    )
                    .toList(),
                freeItems: freeItems
                    .map(
                      (i) => ReceiptFreeItem(
                        name: i.productName,
                        quantity: i.quantity,
                        promotionName: i.promotionName,
                      ),
                    )
                    .toList(),
                subtotal: subtotal,
                discount: discount,
                coupons: appliedCoupons
                    .map(
                      (c) => ReceiptCoupon(
                        code: c.code,
                        discount: c.discount,
                        promotionName: c.promotionName,
                      ),
                    )
                    .toList(),
                total: total,
                paymentLabel: _paymentLabel(paymentType),
                paymentType: paymentType,
                paidAmount: paidAmount,
                changeAmount: changeAmount,
                earnedPoints: earnedPoints,
                pointsUsed: pointsUsed,
                pointsBalance: pointsBalance,
                numFmt: numFmt,
              ),

              const SizedBox(height: 32),

              // ── ปุ่มกลับ ─────────────────────────────────────────
              SizedBox(
                width: 340,
                height: 52,
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.add_shopping_cart, size: 20),
                  label: const Text(
                    'เปิดบิลใหม่',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: 340,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.storefront, size: 20),
                  label: const Text(
                    'กลับหน้าขาย',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
// _PointsSection — แสดงแต้มและให้เลือกใช้แต้มแลกส่วนลด
// ─────────────────────────────────────────────────────────────────
class _PointsSection extends StatefulWidget {
  final int customerPoints;
  final int pointsUsed;
  final double cartTotal;
  final bool isLoading;
  final ValueChanged<int> onApply;
  final VoidCallback onClear;

  const _PointsSection({
    required this.customerPoints,
    required this.pointsUsed,
    required this.cartTotal,
    required this.isLoading,
    required this.onApply,
    required this.onClear,
  });

  @override
  State<_PointsSection> createState() => _PointsSectionState();
}

class _PointsSectionState extends State<_PointsSection> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text: widget.pointsUsed > 0 ? widget.pointsUsed.toString() : '',
    );
  }

  @override
  void didUpdateWidget(_PointsSection old) {
    super.didUpdateWidget(old);
    if (old.pointsUsed != widget.pointsUsed && widget.pointsUsed == 0) {
      _ctrl.clear();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  int get _maxPoints =>
      widget.cartTotal.floor().clamp(0, widget.customerPoints);

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'th_TH');
    final hasPoints = widget.pointsUsed > 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hasPoints
            ? (isDark ? const Color(0xFF2A1F00) : const Color(0xFFFFF8E1))
            : (isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF9F9F9)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasPoints ? Colors.amber : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────
          Row(
            children: [
              Icon(
                Icons.stars,
                size: 18,
                color: hasPoints ? Colors.amber : Colors.amber[300],
              ),
              const SizedBox(width: 8),
              Text(
                'ใช้แต้มสะสม',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: hasPoints ? Colors.amber[800] : Colors.amber[700],
                ),
              ),
              const Spacer(),
              if (widget.isLoading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Text(
                  'มี ${fmt.format(widget.customerPoints)} แต้ม'
                  ' (สูงสุด ${fmt.format(_maxPoints)} pt)',
                  style: TextStyle(fontSize: 11, color: Colors.amber[700]),
                ),
            ],
          ),

          if (hasPoints) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.check_circle, size: 14, color: Colors.amber),
                const SizedBox(width: 4),
                Text(
                  'ใช้ ${fmt.format(widget.pointsUsed)} แต้ม'
                  ' = ลด ฿${widget.pointsUsed.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.amber,
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: widget.onClear,
                  borderRadius: BorderRadius.circular(4),
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(Icons.close, size: 16, color: Colors.red),
                  ),
                ),
              ],
            ),
          ],

          // ── Input row ────────────────────────────────────────
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'จำนวนแต้มที่ต้องการใช้',
                    hintStyle: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // ใช้ทั้งหมด
              OutlinedButton(
                onPressed: widget.isLoading || _maxPoints == 0
                    ? null
                    : () {
                        _ctrl.text = _maxPoints.toString();
                        widget.onApply(_maxPoints);
                      },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.amber[800],
                  side: BorderSide(color: Colors.amber[400]!),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 12,
                  ),
                ),
                child: const Text('ใช้ทั้งหมด', style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 6),
              ElevatedButton(
                onPressed: widget.isLoading
                    ? null
                    : () {
                        final v = int.tryParse(_ctrl.text.trim()) ?? 0;
                        widget.onApply(v);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
                child: const Text('ใช้แต้ม', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '1 แต้ม = ส่วนลด ฿1.00',
            style: TextStyle(fontSize: 11, color: Colors.amber[600]),
          ),
        ],
      ),
    );
  }
}
