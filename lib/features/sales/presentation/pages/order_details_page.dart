import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../providers/sales_provider.dart';
import '../../data/models/sales_order_model.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import '../../../../shared/pdf/receipt_pdf_builder.dart';
import '../../../../shared/services/thermal_print_service.dart';
import '../../../../shared/widgets/mobile_home_button.dart';
import '../../../../shared/widgets/thermal_receipt.dart';

class OrderDetailsPage extends ConsumerStatefulWidget {
  final String orderId;

  const OrderDetailsPage({super.key, required this.orderId});

  @override
  ConsumerState<OrderDetailsPage> createState() => _OrderDetailsPageState();
}

class _OrderDetailsPageState extends ConsumerState<OrderDetailsPage> {
  SalesOrderModel? _order;
  bool _isLoading = true;
  bool _isPrintingReceipt = false;

  @override
  void initState() {
    super.initState();
    _loadOrderDetails();
  }

  Future<void> _loadOrderDetails() async {
    setState(() => _isLoading = true);
    final order = await ref
        .read(salesHistoryProvider.notifier)
        .getOrderDetails(widget.orderId);
    setState(() {
      _order = order;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    return Scaffold(
      appBar: AppBar(
        leading: buildMobileHomeLeading(context),
        title: const Text('รายละเอียดใบขาย'),
        actions: [
          if (_order != null)
            IconButton(
              icon: const Icon(Icons.print),
              tooltip: settings.enableDirectThermalPrint
                  ? 'พิมพ์ตรงไปยังเครื่องสลิป'
                  : 'ดูใบเสร็จ',
              onPressed: _isPrintingReceipt
                  ? null
                  : () => _handleReceiptAction(settings),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _order == null
              ? const Center(child: Text('ไม่พบข้อมูล'))
              : _buildOrderDetails(),
    );
  }

  Widget _buildOrderDetails() {
    final order = _order!;
    // ✅ Week 5: คำนวณ points ที่ได้รับจากใบขายนี้
    final earnedPoints = calculateEarnedPoints(order.totalAmount);
    final isWalkIn = order.customerId == null ||
        order.customerId == 'WALK_IN' ||
        order.customerId!.isEmpty;
    final hasMember = !isWalkIn;

    final allItems     = order.items ?? [];
    final regularItems = allItems.where((i) => !i.isFreeItem).toList();
    final freeItems    = allItems.where((i) => i.isFreeItem).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Order Info Card ──────────────────────────────
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            order.orderNo,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Chip(
                            label: Text(order.status),
                            backgroundColor:
                                _getStatusColor(order.status),
                            labelStyle:
                                const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                      const Divider(),
                      _buildInfoRow('วันที่',
                          DateFormat('dd/MM/yyyy HH:mm')
                              .format(order.orderDate)),
                      if (order.customerName != null)
                        _buildInfoRow('ลูกค้า', order.customerName!),
                      _buildInfoRow(
                          'ชำระด้วย', _getPaymentTypeText(order.paymentType)),
                      // ✅ Week 5: แสดง Points ที่ได้รับ
                      if (hasMember)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.amber[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.amber[200]!),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  earnedPoints > 0
                                      ? Icons.stars
                                      : Icons.stars_outlined,
                                  color: earnedPoints > 0
                                      ? Colors.amber
                                      : Colors.amber[300],
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  earnedPoints > 0
                                      ? 'สะสมคะแนน: +$earnedPoints pt'
                                      : 'ยอดไม่ถึงเกณฑ์ (ต้องการ ฿$kPointsPerBaht)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: earnedPoints > 0
                                        ? Colors.amber[800]
                                        : Colors.amber[600],
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  'ทุก ฿$kPointsPerBaht = 1 pt',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.amber[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Items Card ───────────────────────────────────
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'รายการสินค้า',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue[100],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${regularItems.length} รายการ',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue[800],
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      const Divider(),
                      ...regularItems.map((item) => _buildItemRow(item)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Promotion Card ───────────────────────────────
              if ((order.couponCodes != null && order.couponCodes!.isNotEmpty) ||
                  freeItems.isNotEmpty)
                _buildPromotionCard(order, freeItems),

              if ((order.couponCodes != null && order.couponCodes!.isNotEmpty) ||
                  freeItems.isNotEmpty)
                const SizedBox(height: 16),

              // ── Summary Card ─────────────────────────────────
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildSummaryRow('ยอดรวม', order.subtotal),
                      if (order.discountAmount - order.couponDiscount > 0)
                        _buildSummaryRow(
                            'ส่วนลด',
                            -(order.discountAmount - order.couponDiscount),
                            isDiscount: true),
                      if (order.couponDiscount > 0) ...[
                        if (order.couponCodes != null &&
                            order.couponCodes!.isNotEmpty)
                          ...order.couponCodes!.asMap().entries.map((e) {
                            final perCoupon = order.couponDiscount / order.couponCodes!.length;
                            final isLast = e.key == order.couponCodes!.length - 1;
                            final amt = isLast
                                ? order.couponDiscount - perCoupon * e.key
                                : perCoupon;
                            return _buildSummaryRow(
                                'คูปอง ${e.value}', -amt,
                                isDiscount: true, isCoupon: true);
                          })
                        else
                          _buildSummaryRow('ส่วนลดคูปอง', -order.couponDiscount,
                              isDiscount: true, isCoupon: true),
                      ],
                      if (order.pointsUsed > 0)
                        _buildSummaryRow(
                            'แลกแต้ม ${order.pointsUsed} pt',
                            -order.pointsUsed.toDouble(),
                            isDiscount: true, isPoints: true),
                      const Divider(),
                      _buildSummaryRow('ยอดชำระ', order.totalAmount,
                          isTotal: true),
                      if (order.paymentType == 'CASH') ...[
                        const SizedBox(height: 8),
                        _buildSummaryRow('รับเงิน', order.paidAmount),
                        _buildSummaryRow('เงินทอน', order.changeAmount,
                            isChange: true),
                      ],
                      // สรุป points ด้านล่าง summary
                      if (hasMember) ...[
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  earnedPoints > 0
                                      ? Icons.stars
                                      : Icons.stars_outlined,
                                  size: 16,
                                  color: earnedPoints > 0
                                      ? Colors.amber
                                      : Colors.amber[300],
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'คะแนนที่ได้รับ',
                                  style: TextStyle(
                                    color: Colors.amber[700],
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              earnedPoints > 0
                                  ? '+$earnedPoints pt'
                                  : '0 pt',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: earnedPoints > 0
                                    ? Colors.amber[700]
                                    : Colors.amber[400],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPromotionCard(SalesOrderModel order, List<SalesOrderItemModel> freeItems) {
    final fmt = NumberFormat('#,##0.00', 'th_TH');
    final codes = order.couponCodes ?? [];
    final totalDiscount = order.couponDiscount;
    final hasCoupons = codes.isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.local_offer, size: 18, color: Colors.deepPurple),
                const SizedBox(width: 8),
                const Text(
                  'โปรโมชั่นที่ใช้',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(),

            // ── คูปองส่วนลด ──────────────────────────────────
            if (hasCoupons) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF4CAF50)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4CAF50),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${codes.length} ใบ',
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
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: codes.asMap().entries.map((e) {
                        final perCoupon = totalDiscount / codes.length;
                        final isLast = e.key == codes.length - 1;
                        final amt = isLast
                            ? totalDiscount - perCoupon * e.key
                            : perCoupon;
                        final promoName = order.couponPromotionNames?[e.value];
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4CAF50).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: const Color(0xFF4CAF50)
                                    .withValues(alpha: 0.4)),
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
                                    e.value,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1,
                                      color: Color(0xFF1B5E20),
                                    ),
                                  ),
                                  if (promoName != null && promoName.isNotEmpty)
                                    Text(
                                      promoName,
                                      style: const TextStyle(
                                          fontSize: 10,
                                          color: Color(0xFF388E3C)),
                                    ),
                                  Text(
                                    'ลด ฿${fmt.format(amt)}',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF2E7D32)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],

            // ── สินค้าแถมฟรี (BUY_X_GET_Y) ──────────────────
            if (freeItems.isNotEmpty) ...[
              if (hasCoupons) const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.card_giftcard,
                            size: 18, color: Colors.green),
                        const SizedBox(width: 8),
                        const Text(
                          'ของแถมฟรี',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.green),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${freeItems.length} รายการ',
                            style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...freeItems.map((item) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            const Text('🎁 ', style: TextStyle(fontSize: 14)),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.productName,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF1B5E20)),
                                  ),
                                  if (item.promotionName != null &&
                                      item.promotionName!.isNotEmpty)
                                    Text(
                                      item.promotionName!,
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.green[700]),
                                    ),
                                ],
                              ),
                            ),
                            Text(
                              'x${item.quantity.toStringAsFixed(0)}  ฿0.00',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.green,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: TextStyle(color: Colors.grey[600])),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(SalesOrderItemModel item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.productName,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                Text(item.productCode,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
          Expanded(
            child: Text('${item.quantity.toStringAsFixed(0)}x',
                textAlign: TextAlign.center),
          ),
          Expanded(
            child: Text('฿${item.unitPrice.toStringAsFixed(2)}',
                textAlign: TextAlign.right),
          ),
          Expanded(
            child: Text(
              '฿${item.amount.toStringAsFixed(2)}',
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    double amount, {
    bool isDiscount = false,
    bool isTotal = false,
    bool isChange = false,
    bool isCoupon = false,
    bool isPoints = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (isCoupon) ...[
                const Icon(Icons.local_offer_outlined,
                    size: 14, color: Colors.deepOrange),
                const SizedBox(width: 4),
              ],
              if (isPoints) ...[
                const Icon(Icons.stars, size: 14, color: Colors.orange),
                const SizedBox(width: 4),
              ],
              Text(label,
                  style: TextStyle(
                    fontSize: isTotal ? 18 : 14,
                    fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                    color: isCoupon
                        ? Colors.deepOrange
                        : isPoints
                            ? Colors.orange[700]
                            : isChange
                                ? Colors.green[700]
                                : null,
                  )),
            ],
          ),
          Text(
            amount != 0 ? '฿${amount.toStringAsFixed(2)}' : '฿0.00',
            style: TextStyle(
              fontSize: isTotal ? 22 : 14,
              fontWeight:
                  isTotal ? FontWeight.bold : FontWeight.normal,
              color: isDiscount
                  ? Colors.red
                  : isChange
                      ? Colors.green[700]
                      : isTotal
                          ? Colors.blue
                          : null,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'COMPLETED':
        return Colors.green;
      case 'PENDING':
        return Colors.orange;
      case 'CANCELLED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getPaymentTypeText(String type) {
    switch (type) {
      case 'CASH':
        return 'เงินสด';
      case 'CARD':
        return 'บัตร';
      case 'TRANSFER':
        return 'โอน';
      default:
        return type;
    }
  }

  void _showReceiptPreview() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _OrderReceiptPage(order: _order!),
      ),
    );
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
    final order = _order!;
    final isWalkIn = order.customerId == null ||
        order.customerId == 'WALK_IN' ||
        order.customerId!.isEmpty;
    final allItems = order.items ?? [];
    final regularItems = allItems.where((i) => !i.isFreeItem).toList();
    final freeItems = allItems.where((i) => i.isFreeItem).toList();

    return ThermalReceiptDocument(
      companyName: settings.companyName,
      address: settings.address,
      phone: settings.phone,
      taxId: settings.taxId,
      orderNo: order.orderNo,
      orderDate: DateFormat('dd/MM/yyyy HH:mm').format(order.orderDate),
      customerName: order.customerName,
      items: regularItems
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
      subtotal: order.subtotal,
      discount: order.discountAmount - order.couponDiscount,
      coupons: _OrderReceiptPage._buildCoupons(
        order.couponCodes ?? [],
        order.couponDiscount,
        order.couponPromotionNames,
      ),
      total: order.totalAmount,
      paymentLabel: _OrderReceiptPage._paymentLabel(order.paymentType),
      paymentType: order.paymentType,
      paidAmount: order.paidAmount,
      changeAmount: order.changeAmount,
      earnedPoints: isWalkIn ? 0 : calculateEarnedPoints(order.totalAmount),
      pointsUsed: order.pointsUsed,
    );
  }

  Future<void> _handleReceiptAction(SettingsState settings) async {
    if (!settings.enableDirectThermalPrint) {
      _showReceiptPreview();
      return;
    }

    await _printReceiptDirect(settings);
  }

  Future<void> _printReceiptDirect(SettingsState settings) async {
    if (_order == null || _isPrintingReceipt) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isPrintingReceipt = true);
    try {
      await ThermalPrintService.instance.printReceipt(
        settings: _buildPrintSettings(settings),
        document: _buildReceiptDocument(settings),
      );
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('ส่งใบเสร็จไปยังเครื่องพิมพ์แล้ว'),
          behavior: SnackBarBehavior.floating,
        ),
      );
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
      if (mounted) setState(() => _isPrintingReceipt = false);
    }
  }
}

// ─────────────────────────────────────────────────────────────────
// _OrderReceiptPage — หน้าแสดงใบเสร็จ thermal style (จากประวัติ)
// ─────────────────────────────────────────────────────────────────
class _OrderReceiptPage extends ConsumerStatefulWidget {
  final SalesOrderModel order;
  const _OrderReceiptPage({required this.order});

  static String _paymentLabel(String type) => switch (type) {
        'CASH'     => 'เงินสด',
        'CARD'     => 'บัตรเครดิต/เดบิต',
        'TRANSFER' => 'โอนเงิน',
        _          => type,
      };

  static List<ReceiptCoupon> _buildCoupons(
      List<String> codes, double total, Map<String, String>? promoNames) {
    if (codes.isEmpty || total <= 0) return [];
    final perCoupon = total / codes.length;
    return codes.asMap().entries.map((e) {
      final isLast = e.key == codes.length - 1;
      final already = perCoupon * e.key;
      return ReceiptCoupon(
        code:          e.value,
        discount:      isLast ? total - already : perCoupon,
        promotionName: promoNames?[e.value],
      );
    }).toList();
  }

  @override
  ConsumerState<_OrderReceiptPage> createState() => _OrderReceiptPageState();
}

class _OrderReceiptPageState extends ConsumerState<_OrderReceiptPage> {
  bool _isPrinting = false;

  ThermalReceiptDocument _buildDocument(SettingsState settings) {
    final order = widget.order;
    final dateFmt = DateFormat('dd/MM/yyyy HH:mm');
    final isWalkIn = order.customerId == null ||
        order.customerId == 'WALK_IN' ||
        order.customerId!.isEmpty;
    final allItems = order.items ?? [];
    final regularItems = allItems.where((i) => !i.isFreeItem).toList();
    final freeItems = allItems.where((i) => i.isFreeItem).toList();
    return ThermalReceiptDocument(
      companyName:  settings.companyName,
      address:      settings.address,
      phone:        settings.phone,
      taxId:        settings.taxId,
      orderNo:      order.orderNo,
      orderDate:    dateFmt.format(order.orderDate),
      customerName: order.customerName,
      items: regularItems
          .map((i) => ReceiptItem(
                name:      i.productName,
                quantity:  i.quantity,
                unitPrice: i.unitPrice,
                amount:    i.amount,
              ))
          .toList(),
      freeItems: freeItems
          .map((i) => ReceiptFreeItem(
                name:          i.productName,
                quantity:      i.quantity,
                promotionName: i.promotionName,
              ))
          .toList(),
      subtotal:     order.subtotal,
      discount:     order.discountAmount - order.couponDiscount,
      coupons: _OrderReceiptPage._buildCoupons(
          order.couponCodes ?? [], order.couponDiscount, order.couponPromotionNames),
      total:        order.totalAmount,
      paymentLabel: _OrderReceiptPage._paymentLabel(order.paymentType),
      paymentType:  order.paymentType,
      paidAmount:   order.paidAmount,
      changeAmount: order.changeAmount,
      earnedPoints: isWalkIn ? 0 : calculateEarnedPoints(order.totalAmount),
      pointsUsed:   order.pointsUsed,
    );
  }

  Future<void> _printNative() async {
    if (_isPrinting) return;
    setState(() => _isPrinting = true);
    try {
      final settings = ref.read(settingsProvider);
      final doc = _buildDocument(settings);
      await Printing.layoutPdf(
        onLayout: (_) async {
          final pdf = await ReceiptPdfBuilder.build(
            doc,
            paperWidthMm: settings.thermalPaperWidthMm,
          );
          return pdf.save();
        },
        name: 'ใบเสร็จ-${widget.order.orderNo}',
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

    await _doPrint(host: host, port: port);
  }

  Future<void> _doPrint({required String host, required int port}) async {
    if (_isPrinting) return;
    final settings = ref.read(settingsProvider);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isPrinting = true);
    try {
      await ThermalPrintService.instance.printReceipt(
        settings: ThermalPrintSettings(
          enabled: true,
          autoPrintOnSale: false,
          host: host,
          port: port,
          paperWidthMm: settings.thermalPaperWidthMm,
        ),
        document: _buildDocument(settings),
      );
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(
        content: Text('ส่งใบเสร็จไปยังเครื่องพิมพ์แล้ว'),
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text('พิมพ์ใบเสร็จไม่สำเร็จ: $e'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red[700],
      ));
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final numFmt = NumberFormat('#,##0.00');
    final order = widget.order;

    final isWalkIn = order.customerId == null ||
        order.customerId == 'WALK_IN' ||
        order.customerId!.isEmpty;
    final earnedPoints = isWalkIn ? 0 : calculateEarnedPoints(order.totalAmount);

    final allItems     = order.items ?? [];
    final regularItems = allItems.where((i) => !i.isFreeItem).toList();
    final freeItems    = allItems.where((i) => i.isFreeItem).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFEEEEEE),
      appBar: AppBar(
        leading: buildMobileHomeLeading(context),
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
          child: ThermalReceiptWidget(
            companyName:  settings.companyName,
            address:      settings.address,
            phone:        settings.phone,
            taxId:        settings.taxId,
            orderNo:      order.orderNo,
            orderDate:    DateFormat('dd/MM/yyyy HH:mm').format(order.orderDate),
            customerName: order.customerName,
            items: regularItems.map((i) => ReceiptItem(
                  name:      i.productName,
                  quantity:  i.quantity,
                  unitPrice: i.unitPrice,
                  amount:    i.amount,
                )).toList(),
            freeItems: freeItems.map((i) => ReceiptFreeItem(
                  name:          i.productName,
                  quantity:      i.quantity,
                  promotionName: i.promotionName,
                )).toList(),
            subtotal:     order.subtotal,
            discount:     order.discountAmount - order.couponDiscount,
            coupons: _OrderReceiptPage._buildCoupons(
                order.couponCodes ?? [],
                order.couponDiscount,
                order.couponPromotionNames),
            total:        order.totalAmount,
            paymentLabel: _OrderReceiptPage._paymentLabel(order.paymentType),
            paymentType:  order.paymentType,
            paidAmount:   order.paidAmount,
            changeAmount: order.changeAmount,
            numFmt:       numFmt,
            earnedPoints: earnedPoints,
            pointsUsed:   order.pointsUsed,
            paperWidthMm: settings.thermalPaperWidthMm,
          ),
        ),
      ),
    );
  }
}
