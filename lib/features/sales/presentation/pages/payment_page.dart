// ignore_for_file: avoid_print

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:printing/printing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import '../../../../core/client/api_client.dart';
import '../../../../core/utils/promptpay_utils.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../customers/presentation/providers/customer_provider.dart'; // ✅
import '../../../ar/presentation/providers/ar_invoice_provider.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import '../../../promotions/presentation/providers/promotion_provider.dart';
import '../../../restaurant/data/models/restaurant_order_context.dart';
import '../providers/cart_provider.dart';
import '../providers/sales_provider.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../../inventory/presentation/providers/stock_provider.dart';
import '../../../products/presentation/providers/product_provider.dart';
import '../../../branches/presentation/providers/branch_provider.dart';
import '../../../../core/config/app_mode.dart';
import '../../../../core/services/license/license_models.dart';
import '../../../../core/services/license/license_service.dart';
import '../../../../core/services/pending_sales_queue_service.dart';
import '../../../restaurant/presentation/providers/table_provider.dart';
import '../../../../shared/services/thermal_print_service.dart';
import '../../../../shared/services/mobile_scanner_service.dart';
import '../../../../shared/pdf/receipt_pdf_builder.dart';
import '../../../../shared/widgets/mobile_home_button.dart';
import '../../../../shared/widgets/thermal_receipt.dart';

enum ReceiptExitAction { openNewBill }

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

  // ── Credit ───────────────────────────────────────────────────────
  double _creditLimit = 0;
  double _creditDays = 0;
  double _currentBalance = 0; // ยอดค้างชำระปัจจุบัน

  @override
  void initState() {
    super.initState();
    _receivedAmount = _grossTotal;
    _receivedController.text = _grossTotal.toStringAsFixed(2);

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
    if (!_supportsAdjustments) return;
    final cartState = ref.read(cartProvider);
    final customerId = cartState.customerId;
    if (customerId == null || customerId == 'WALK_IN' || customerId.isEmpty) {
      return;
    }

    setState(() => _isLoadingPoints = true);
    final pts = await ref
        .read(salesHistoryProvider.notifier)
        .getCustomerPoints(customerId);

    // โหลดข้อมูลเครดิตของลูกค้า
    try {
      final customers = ref.read(customerListProvider).asData?.value ?? [];
      for (final c in customers) {
        if (c.customerId == customerId) {
          if (mounted) {
            setState(() {
              _creditLimit = c.creditLimit;
              _creditDays = c.creditDays.toDouble();
              _currentBalance = c.currentBalance;
            });
          }
          break;
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _customerPoints = pts;
        _isLoadingPoints = false;
      });
    }
  }

  /// คำนวณยอดหลังหักแต้ม
  RestaurantOrderContext? get _restaurantContext =>
      ref.read(restaurantOrderContextProvider);

  bool get _supportsAdjustments => _restaurantContext?.totalOverride == null;

  double get _grossTotal =>
      _restaurantContext?.totalOverride ?? ref.read(cartProvider).total;

  double get _subtotalBeforeAdjustments =>
      _restaurantContext?.subtotalOverride ?? ref.read(cartProvider).subtotal;

  double get _discountAmount =>
      _restaurantContext?.discountOverride ??
      ref.read(cartProvider).totalDiscount;

  double get _serviceChargeAmount =>
      _restaurantContext?.serviceChargeOverride ?? 0;

  double get _netTotal {
    if (!_supportsAdjustments) return _grossTotal;
    return (_grossTotal - _pointsUsed).clamp(0.0, double.infinity);
  }

  void _applyPoints(int points) {
    final maxPoints = _grossTotal.floor().clamp(0, _customerPoints);
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

    if (!_supportsAdjustments) {
      setState(() {
        _couponError = 'บิลร้านอาหารที่ส่งเข้าระบบแล้วไม่สามารถแก้คูปองในหน้านี้ได้';
        _isValidatingCoupon = false;
      });
      return;
    }

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
    if (!_supportsAdjustments) return;
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
    final restaurantContext = ref.watch(restaurantOrderContextProvider);
    final supportsAdjustments = restaurantContext?.totalOverride == null;
    final settings = ref.watch(settingsProvider);
    final promptPayId = settings.promptPayId.trim();
    final hasPromptPay = PromptPayUtils.isValidPromptPayId(promptPayId);

    return Scaffold(
      appBar: AppBar(
        leading: buildMobileHomeLeading(context),
        title: Text(restaurantContext?.paymentTitle ?? 'ชำระเงิน'),
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
                            if (_discountAmount > 0) ...[
                              const SizedBox(height: 4),
                              Text(
                                'ส่วนลด ฿${_discountAmount.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                            if (_serviceChargeAmount > 0) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Service charge ฿${_serviceChargeAmount.toStringAsFixed(2)}',
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
                  if (supportsAdjustments) ...[
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
                  ],

                  // ── แลกแต้ม (เฉพาะสมาชิก) ──────────────────────
                  if (supportsAdjustments &&
                      cartState.customerId != null &&
                      cartState.customerId != 'WALK_IN' &&
                      cartState.customerId!.isNotEmpty)
                    _PointsSection(
                      customerPoints: _customerPoints,
                      pointsUsed: _pointsUsed,
                      cartTotal: _grossTotal,
                      isLoading: _isLoadingPoints,
                      onApply: _applyPoints,
                      onClear: () => _applyPoints(0),
                    ),
                  if (supportsAdjustments &&
                      cartState.customerId != null &&
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
                    segments: [
                      const ButtonSegment(
                        value: 'CASH',
                        label: Text('เงินสด'),
                        icon: Icon(Icons.money),
                      ),
                      const ButtonSegment(
                        value: 'CARD',
                        label: Text('บัตร'),
                        icon: Icon(Icons.credit_card),
                      ),
                      const ButtonSegment(
                        value: 'TRANSFER',
                        label: Text('โอน'),
                        icon: Icon(Icons.qr_code),
                      ),
                      if (cartState.customerId != null &&
                          cartState.customerId != 'WALK_IN' &&
                          cartState.customerId!.isNotEmpty &&
                          _creditLimit > 0)
                        const ButtonSegment(
                          value: 'CREDIT',
                          label: Text('เครดิต'),
                          icon: Icon(Icons.account_balance_wallet_outlined),
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

                  // ── เครดิต: แสดงข้อมูลวงเงินและวันครบกำหนด ──────
                  if (_paymentType == 'CREDIT') ...[
                    _CreditInfoPanel(
                      creditLimit: _creditLimit,
                      creditDays: _creditDays.toInt(),
                      currentBalance: _currentBalance,
                      orderAmount: _netTotal,
                    ),
                    const SizedBox(height: 16),
                  ],

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
                        final total = _grossTotal;
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
                        amount: _grossTotal,
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
                      final availableCredit = _creditLimit - _currentBalance;
                      final isDisabled =
                          (_paymentType == 'CASH' && _change < 0) ||
                          (_paymentType == 'CREDIT' && _netTotal > availableCredit) ||
                          _isProcessing;

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
                                            '฿${_grossTotal.toStringAsFixed(2)}',
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

  bool _ensureLicenseFeature(LicenseFeature feature, String message) {
    final status = ref.read(licenseServiceProvider).asData?.value;
    if (status != null && !status.canUseFeature(feature)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
        Navigator.of(context).pushNamed('/license');
      }
      return false;
    }
    return true;
  }

  Future<void> _handlePayment() async {
    if (!_ensureLicenseFeature(
      LicenseFeature.openSale,
      'หมดช่วงทดลองแล้ว ต้องมี License ก่อนเปิดบิลหรือขายสินค้า',
    )) {
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final cartState = ref.read(cartProvider);
      final authState = ref.read(authProvider);
      final apiClient = ref.read(apiClientProvider);
      final selectedBranch = ref.read(selectedBranchProvider);
      final selectedWarehouse = ref.read(selectedWarehouseProvider);
      final restaurantContext = ref.read(restaurantOrderContextProvider);
      final currentOrderId = restaurantContext?.currentOrderId;
      final targetOrderIds = restaurantContext != null
          ? (restaurantContext.currentOrderIds.isNotEmpty
              ? restaurantContext.currentOrderIds
              : [
                  if (currentOrderId != null && currentOrderId.isNotEmpty)
                    currentOrderId,
                ])
          : const <String>[];
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

      if (restaurantContext != null &&
          (currentOrderId == null || currentOrderId.isEmpty)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('กรุณาส่งออเดอร์เข้าครัวก่อนปิดบิล'),
              backgroundColor: Colors.orange,
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
        if (restaurantContext != null) ...{
          'table_id': restaurantContext.tableId,
          'session_id': restaurantContext.sessionId,
          'service_type': restaurantContext.serviceType,
          'party_size': restaurantContext.guestCount,
        },
        'subtotal': _subtotalBeforeAdjustments,
        'discount_amount':
            _discountAmount +
                (_supportsAdjustments ? cartState.totalCouponDiscount : 0),
        'coupon_discount':
            _supportsAdjustments ? cartState.totalCouponDiscount : 0.0,
        'points_used': _pointsUsed,
        'amount_before_vat': _netTotal,
        'vat_amount': 0.0,
        'total_amount': _netTotal,
        'payment_type': _paymentType,
        'paid_amount': _paymentType == 'CASH' ? _receivedAmount : (_paymentType == 'CREDIT' ? 0.0 : _netTotal),
        'change_amount': _paymentType == 'CASH' ? _change : 0.0,
        if (_paymentType == 'CREDIT')
          'due_date': DateTime.now().add(Duration(days: _creditDays.toInt())).toIso8601String(),
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
                'special_instructions': item.note,
                'course_no': item.courseNo,
                'modifiers': item.modifiers
                    .map(
                      (modifier) => {
                        'modifier_id': modifier.modifierId,
                        'modifier_name': modifier.modifierName,
                        'price_adjustment': modifier.priceAdjustment,
                      },
                    )
                    .toList(),
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

      final response = targetOrderIds.isNotEmpty
          ? await apiClient.post(
              '/api/sales/${targetOrderIds.first}/complete',
              data: {
                'payment_type': _paymentType,
                'paid_amount': _paymentType == 'CASH'
                    ? _receivedAmount
                    : (_paymentType == 'CREDIT' ? 0.0 : _netTotal),
                'change_amount': _paymentType == 'CASH' ? _change : 0.0,
                'additional_order_ids': targetOrderIds.skip(1).toList(),
              },
            )
          : await apiClient.post('/api/sales', data: orderData);

      print('✅ Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        // ✅ อ่านค่าจาก response ก่อน — ต้องใช้ orderNo ใน coupon use call
        final responseData = response.data is Map ? response.data as Map : {};
        final dataMap = responseData['data'] is Map
            ? responseData['data'] as Map
            : {};
        final orderNo = dataMap['order_no'] as String? ?? '-';
        final orderId = dataMap['order_id'] as String? ?? '';
        final earnedPoints = dataMap['earned_points'] as int? ?? 0;

        // ── Mark all coupons as used ──────────────────────────────
        if (_supportsAdjustments) {
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
        }
        if (_supportsAdjustments && cartState.appliedCoupons.isNotEmpty) {
          ref.read(couponListProvider.notifier).refresh();
        }

        // ── สร้าง AR Invoice อัตโนมัติเมื่อชำระแบบเครดิต ────────
        if (_paymentType == 'CREDIT' &&
            cartState.customerId != null &&
            cartState.customerId != 'WALK_IN') {
          try {
            final dueDate = DateTime.now().add(
              Duration(days: _creditDays.toInt()),
            );
            final arData = {
              'invoice_no': 'AR-$orderNo',
              'customer_id': cartState.customerId,
              'customer_name': cartState.customerName ?? 'ลูกค้าทั่วไป',
              'invoice_date': DateTime.now().toIso8601String(),
              'due_date': dueDate.toIso8601String(),
              'total_amount': netTotal,
              'paid_amount': 0,
              'status': 'UNPAID',
              'reference_type': 'SALE',
                  'reference_id': orderId.isNotEmpty
                      ? orderId
                      : (targetOrderIds.isNotEmpty ? targetOrderIds.first : orderNo),
              'remark': 'ขายเชื่อ #$orderNo',
              'items': cartState.items
                  .map((item) => {
                        'product_id': item.productId,
                        'product_code': item.productCode,
                        'product_name': item.productName,
                        'unit': item.unit,
                        'quantity': item.quantity,
                        'unit_price': item.unitPrice,
                        'discount_amount': 0.0,
                        'amount': item.amount,
                      })
                  .toList(),
            };
            await apiClient.post('/api/ar-invoices', data: arData);
            print('✅ AR Invoice created for CREDIT sale $orderNo');
          } catch (e) {
            print('⚠️ Could not create AR invoice: $e');
          }
        }

        if (restaurantContext != null) {
          try {
            final billRes = await apiClient.get('/api/tables/${restaurantContext.tableId}/bill');
            final billData = billRes.data is Map ? billRes.data as Map : {};
            final billPayload =
                billData['data'] is Map ? billData['data'] as Map : {};
            final remainingItems = billPayload['items'] as List? ?? const [];
            if (remainingItems.isEmpty) {
              await apiClient.post(
                '/api/tables/${restaurantContext.tableId}/close',
                data: {},
              );
            }
            ref.invalidate(tableListProvider);
          } catch (e) {
            print('⚠️ Could not close restaurant table after payment: $e');
          }
        }

        ref.read(cartProvider.notifier).clear();
        ref.read(restaurantOrderContextProvider.notifier).state = null;

        // ✅ refresh sales list & dashboard หลังบันทึกออเดอร์สำเร็จ
        ref.invalidate(salesHistoryProvider);
        ref.invalidate(dashboardProvider);
        // ✅ refresh stock — ตัดสต๊อกแล้วต้องให้ UI อัปเดตทันที
        ref.invalidate(stockBalanceProvider);
        ref.invalidate(productListProvider);

        // ✅ refresh customer list เพื่อให้ points อัพเดททันที
        ref.read(customerListProvider.notifier).refresh();

        // ✅ refresh AR invoices หากขายเครดิต
        if (_paymentType == 'CREDIT') {
          ref.invalidate(arInvoiceListProvider);
        }

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
                subtotal: _subtotalBeforeAdjustments,
                discount: _discountAmount,
                serviceCharge: _serviceChargeAmount,
                appliedCoupons: cartState.appliedCoupons,
                total: netTotal,
                paymentType: _paymentType,
                paidAmount: paidAmount,
                changeAmount: changeAmount,
                earnedPoints: earnedPoints,
                pointsUsed: _pointsUsed,
                receiptTitle: restaurantContext?.splitLabel != null
                    ? 'ใบเสร็จรับเงิน (${restaurantContext!.splitLabel})'
                    : 'ใบเสร็จรับเงิน',
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

      final currentOrderId =
          ref.read(restaurantOrderContextProvider)?.currentOrderId;

      final shouldQueue =
          AppModeConfig.isClient &&
          (currentOrderId == null || currentOrderId.isEmpty) &&
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
        final restaurantContext = ref.read(restaurantOrderContextProvider);

        if (selectedBranch != null && selectedWarehouse != null) {
          final fallbackOrderData = {
            'customer_id': cartState.customerId,
            'customer_name': cartState.customerName,
            'user_id': authState.user?.userId ?? 'USR001',
            'branch_id': selectedBranch.branchId,
            'warehouse_id': selectedWarehouse.warehouseId,
            if (restaurantContext != null) ...{
              'table_id': restaurantContext.tableId,
              'session_id': restaurantContext.sessionId,
              'service_type': restaurantContext.serviceType,
              'party_size': restaurantContext.guestCount,
            },
            'subtotal': cartState.subtotal,
            'discount_amount':
                cartState.totalDiscount + cartState.totalCouponDiscount,
            'coupon_discount': cartState.totalCouponDiscount,
            'points_used': _pointsUsed,
            'amount_before_vat': _netTotal,
            'vat_amount': 0.0,
            'total_amount': _netTotal,
            'payment_type': _paymentType,
            'paid_amount': _paymentType == 'CASH' ? _receivedAmount : (_paymentType == 'CREDIT' ? 0.0 : _netTotal),
            'change_amount': _paymentType == 'CASH' ? _change : 0.0,
            if (_paymentType == 'CREDIT')
              'due_date': DateTime.now().add(Duration(days: _creditDays.toInt())).toIso8601String(),
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
                    'special_instructions': item.note,
                'course_no': item.courseNo,
                    'modifiers': item.modifiers
                        .map(
                          (modifier) => {
                            'modifier_id': modifier.modifierId,
                            'modifier_name': modifier.modifierName,
                            'price_adjustment': modifier.priceAdjustment,
                          },
                        )
                        .toList(),
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
          ref.read(restaurantOrderContextProvider.notifier).state = null;
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
// _CreditInfoPanel — แสดงวงเงินและวันครบกำหนด (เครดิต)
// ─────────────────────────────────────────────────────────────────
class _CreditInfoPanel extends StatelessWidget {
  final double creditLimit;
  final int creditDays;
  final double currentBalance;
  final double orderAmount;

  const _CreditInfoPanel({
    required this.creditLimit,
    required this.creditDays,
    required this.currentBalance,
    required this.orderAmount,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fmt = NumberFormat('#,##0.00', 'th_TH');
    final availableCredit = creditLimit - currentBalance;
    final isOverLimit = orderAmount > availableCredit;
    final dueDate = DateTime.now().add(Duration(days: creditDays));
    final dueDateStr = DateFormat('dd/MM/yyyy').format(dueDate);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isOverLimit
            ? (isDark ? const Color(0xFF2A1A1A) : const Color(0xFFFFEBEE))
            : (isDark ? const Color(0xFF0D2137) : const Color(0xFFE3F2FD)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOverLimit
              ? const Color(0xFFEF5350).withValues(alpha: 0.5)
              : const Color(0xFF1565C0).withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                size: 16,
                color: isOverLimit ? const Color(0xFFEF5350) : const Color(0xFF1565C0),
              ),
              const SizedBox(width: 8),
              Text(
                'ข้อมูลเครดิต',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isOverLimit ? const Color(0xFFEF5350) : const Color(0xFF1565C0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _row('วงเงินเครดิต', '฿${fmt.format(creditLimit)}', isDark),
          const SizedBox(height: 6),
          _row('ยอดค้างชำระ', '฿${fmt.format(currentBalance)}', isDark,
              valueColor: currentBalance > 0 ? const Color(0xFFEF5350) : null),
          const SizedBox(height: 6),
          _row('วงเงินคงเหลือ', '฿${fmt.format(availableCredit)}', isDark,
              valueColor: availableCredit <= 0 ? const Color(0xFFEF5350) : const Color(0xFF4CAF50)),
          const SizedBox(height: 6),
          _row('ยอดบิลนี้', '฿${fmt.format(orderAmount)}', isDark,
              valueColor: isOverLimit ? const Color(0xFFEF5350) : null),
          const SizedBox(height: 6),
          _row('วันครบกำหนด', '$dueDateStr ($creditDays วัน)', isDark),
          if (isOverLimit) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFEF5350).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFEF5350)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'วงเงินไม่เพียงพอ (ขาด ฿${fmt.format(orderAmount - availableCredit)})',
                      style: const TextStyle(fontSize: 12, color: Color(0xFFEF5350)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String value, bool isDark, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white54 : Colors.black54,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: valueColor ?? (isDark ? Colors.white : Colors.black87),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
class ReceiptPage extends ConsumerStatefulWidget {
  final String orderNo;
  final DateTime orderDate;
  final String? customerName;
  final List<CartItem> items;
  final List<CartItem> freeItems;
  final double subtotal;
  final double discount;
  final double serviceCharge;
  final List<AppliedCoupon> appliedCoupons;
  final double total;
  final String receiptTitle;
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
    this.serviceCharge = 0,
    required this.total,
    this.receiptTitle = 'ใบเสร็จรับเงิน',
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
    'CREDIT' => 'เครดิต',
    _ => type,
  };

  @override
  ConsumerState<ReceiptPage> createState() => _ReceiptPageState();
}

class _ReceiptPageState extends ConsumerState<ReceiptPage> {
  bool _isPrinting = false;
  bool _autoPrintTriggered = false;

  bool _ensureLicenseFeature(LicenseFeature feature, String message) {
    final status = ref.read(licenseServiceProvider).asData?.value;
    if (status != null && !status.canUseFeature(feature)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
        Navigator.of(context).pushNamed('/license');
      }
      return false;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _triggerAutoPrintIfNeeded();
    });
  }

  ThermalPrintSettings _buildPrintSettings(SettingsState settings) {
    return ThermalPrintSettings(
      enabled: settings.enableDirectThermalPrint,
      autoPrintOnSale: settings.autoPrintReceipt,
      host: settings.thermalPrinterHost,
      port: settings.thermalPrinterPort,
      paperWidthMm: settings.thermalPaperWidthMm,
    );
  }

  ThermalReceiptDocument _buildReceiptDocument(SettingsState settings) {
    final dateFmt = DateFormat('dd/MM/yyyy HH:mm');
    return ThermalReceiptDocument(
      companyName: settings.companyName,
      address: settings.address,
      phone: settings.phone,
      taxId: settings.taxId,
      title: widget.receiptTitle,
      orderNo: widget.orderNo,
      orderDate: dateFmt.format(widget.orderDate),
      customerName: widget.customerName,
      items: widget.items
          .map(
            (i) => ReceiptItem(
              name: i.productName,
              quantity: i.quantity,
              unitPrice: i.unitPrice,
              amount: i.amount,
            ),
          )
          .toList(),
      freeItems: widget.freeItems
          .map(
            (i) => ReceiptFreeItem(
              name: i.productName,
              quantity: i.quantity,
              promotionName: i.promotionName,
            ),
          )
          .toList(),
      subtotal: widget.subtotal,
      discount: widget.discount,
      serviceCharge: widget.serviceCharge,
      coupons: widget.appliedCoupons
          .map(
            (c) => ReceiptCoupon(
              code: c.code,
              discount: c.discount,
              promotionName: c.promotionName,
            ),
          )
          .toList(),
      total: widget.total,
      paymentLabel: ReceiptPage._paymentLabel(widget.paymentType),
      paymentType: widget.paymentType,
      paidAmount: widget.paidAmount,
      changeAmount: widget.changeAmount,
      earnedPoints: widget.earnedPoints,
      pointsUsed: widget.pointsUsed,
      pointsBalance: widget.pointsBalance,
    );
  }

  Future<void> _triggerAutoPrintIfNeeded() async {
    if (_autoPrintTriggered) return;
    _autoPrintTriggered = true;

    final settings = ref.read(settingsProvider);
    final thermalSettings = _buildPrintSettings(settings);
    if (!thermalSettings.canPrintDirect || !thermalSettings.autoPrintOnSale) {
      return;
    }

    await _printDirectReceipt(showSuccessMessage: false);
  }

  Future<void> _printNative() async {
    if (!_ensureLicenseFeature(
      LicenseFeature.printReceipt,
      'หมดช่วงทดลองแล้ว ต้องมี License ก่อนพิมพ์ใบเสร็จ',
    )) {
      return;
    }
    if (_isPrinting) return;
    setState(() => _isPrinting = true);
    try {
      final settings = ref.read(settingsProvider);
      final doc = _buildReceiptDocument(settings);
      await Printing.layoutPdf(
        onLayout: (_) async {
          final pdf = await ReceiptPdfBuilder.build(
            doc,
            paperWidthMm: settings.thermalPaperWidthMm,
          );
          return pdf.save();
        },
        name: 'ใบเสร็จ-${doc.orderNo}',
      );
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  Future<void> _showPrinterDialog() async {
    final settings = ref.read(settingsProvider);
    final useNative = (Platform.isMacOS || Platform.isWindows)
        ? !settings.desktopUseTcpPrint
        : settings.mobileUseNativePrint;
    if (useNative) {
      await _printNative();
      return;
    }

    final hostCtrl = TextEditingController(text: settings.thermalPrinterHost);
    final portCtrl = TextEditingController(
        text: settings.thermalPrinterPort.toString());

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.print_outlined),
            SizedBox(width: 8),
            Text('เลือกเครื่องพิมพ์'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: hostCtrl,
              decoration: const InputDecoration(
                labelText: 'Printer IP / Host',
                hintText: 'เช่น 192.168.1.120',
                prefixIcon: Icon(Icons.router_outlined),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: portCtrl,
              decoration: const InputDecoration(
                labelText: 'Port',
                hintText: '9100',
                prefixIcon: Icon(Icons.settings_ethernet_outlined),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.print_outlined, size: 18),
            label: const Text('พิมพ์'),
          ),
        ],
      ),
    );

    final host = hostCtrl.text.trim();
    final portStr = portCtrl.text.trim();
    hostCtrl.dispose();
    portCtrl.dispose();

    if (confirmed != true || !mounted) return;

    if (host.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('กรุณาระบุ IP เครื่องพิมพ์'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    final port = int.tryParse(portStr);
    if (port == null || port <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('พอร์ตไม่ถูกต้อง'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    await _printDirectReceipt(hostOverride: host, portOverride: port);
  }

  Future<void> _printDirectReceipt({
    bool showSuccessMessage = true,
    String? hostOverride,
    int? portOverride,
  }) async {
    if (_isPrinting) return;

    final settings = ref.read(settingsProvider);
    final thermalSettings = hostOverride != null
        ? ThermalPrintSettings(
            enabled: true,
            autoPrintOnSale: settings.autoPrintReceipt,
            host: hostOverride,
            port: portOverride ?? settings.thermalPrinterPort,
            paperWidthMm: settings.thermalPaperWidthMm,
          )
        : _buildPrintSettings(settings);
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _isPrinting = true);
    try {
      await ThermalPrintService.instance.printReceipt(
        settings: thermalSettings,
        document: _buildReceiptDocument(settings),
      );
      if (!mounted) return;
      if (showSuccessMessage) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('ส่งใบเสร็จไปยังเครื่องพิมพ์แล้ว'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('พิมพ์ใบเสร็จไม่สำเร็จ: $error'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red[700],
        ),
      );
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final dateFmt = DateFormat('dd/MM/yyyy HH:mm');
    final numFmt = NumberFormat('#,##0.00');
    final directPrintEnabled = settings.enableDirectThermalPrint;

    return Scaffold(
      backgroundColor: const Color(0xFFEEEEEE),
      appBar: AppBar(
        leading: buildMobileHomeLeading(context),
        automaticallyImplyLeading: false,
        title: const Text('ใบเสร็จรับเงิน'),
        actions: [
          IconButton(
            onPressed: _isPrinting ? null : _showPrinterDialog,
            tooltip: 'เลือกเครื่องพิมพ์',
            icon: _isPrinting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.print_outlined),
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
                title: widget.receiptTitle,
                orderNo: widget.orderNo,
                orderDate: dateFmt.format(widget.orderDate),
                customerName: widget.customerName,
                items: widget.items
                    .map(
                      (i) => ReceiptItem(
                        name: i.productName,
                        quantity: i.quantity,
                        unitPrice: i.unitPrice,
                        amount: i.amount,
                      ),
                    )
                    .toList(),
                freeItems: widget.freeItems
                    .map(
                      (i) => ReceiptFreeItem(
                        name: i.productName,
                        quantity: i.quantity,
                        promotionName: i.promotionName,
                      ),
                    )
                    .toList(),
                subtotal: widget.subtotal,
                discount: widget.discount,
                serviceCharge: widget.serviceCharge,
                coupons: widget.appliedCoupons
                    .map(
                      (c) => ReceiptCoupon(
                        code: c.code,
                        discount: c.discount,
                        promotionName: c.promotionName,
                      ),
                    )
                    .toList(),
                total: widget.total,
                paymentLabel: ReceiptPage._paymentLabel(widget.paymentType),
                paymentType: widget.paymentType,
                paidAmount: widget.paidAmount,
                changeAmount: widget.changeAmount,
                earnedPoints: widget.earnedPoints,
                pointsUsed: widget.pointsUsed,
                pointsBalance: widget.pointsBalance,
                numFmt: numFmt,
                paperWidthMm: settings.thermalPaperWidthMm,
              ),

              if (directPrintEnabled) ...[
                const SizedBox(height: 16),
                Container(
                  width: 340,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFDADADA)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.print_outlined, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          settings.autoPrintReceipt
                              ? 'เปิด auto print แล้ว ระบบจะพยายามส่งใบเสร็จไปที่ ${settings.thermalPrinterHost}:${settings.thermalPrinterPort}'
                              : 'เปิด direct thermal print แล้ว สามารถกดไอคอนพิมพ์ด้านบนเพื่อส่งไปที่ ${settings.thermalPrinterHost}:${settings.thermalPrinterPort}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // ── ปุ่มเปิดบิลใหม่ ──────────────────────────────────
              SizedBox(
                width: 340,
                height: 52,
                child: FilledButton.icon(
                  onPressed: () =>
                      Navigator.of(context).pop(ReceiptExitAction.openNewBill),
                  icon: const Icon(Icons.add_shopping_cart, size: 20),
                  label: const Text(
                    'เปิดบิลใหม่',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
