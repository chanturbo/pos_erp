import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/sales_provider.dart';
import '../../data/models/sales_order_model.dart';
import '../../../settings/presentation/pages/settings_page.dart';
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('รายละเอียดใบขาย'),
        actions: [
          if (_order != null)
            IconButton(
              icon: const Icon(Icons.print),
              tooltip: 'พิมพ์ใบเสร็จ',
              onPressed: _showReceiptPreview,
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
                      const Text(
                        'รายการสินค้า',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const Divider(),
                      ...?order.items?.map((item) => _buildItemRow(item)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Coupon Card ───────────────────────────────────
              if (order.couponCodes != null &&
                  order.couponCodes!.isNotEmpty)
                _buildCouponCard(order),

              if (order.couponCodes != null &&
                  order.couponCodes!.isNotEmpty)
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

  Widget _buildCouponCard(SalesOrderModel order) {
    final fmt = NumberFormat('#,##0.00', 'th_TH');
    final codes = order.couponCodes!;
    final totalDiscount = order.couponDiscount;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF4CAF50)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────
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
              // ── Coupon chips ─────────────────────────────────
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: codes.asMap().entries.map((e) {
                  final perCoupon = totalDiscount / codes.length;
                  final isLast = e.key == codes.length - 1;
                  final amt = isLast
                      ? totalDiscount - perCoupon * e.key
                      : perCoupon;
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
}

// ─────────────────────────────────────────────────────────────────
// _OrderReceiptPage — หน้าแสดงใบเสร็จ thermal style (จากประวัติ)
// ─────────────────────────────────────────────────────────────────
class _OrderReceiptPage extends ConsumerWidget {
  final SalesOrderModel order;
  const _OrderReceiptPage({required this.order});

  static String _paymentLabel(String type) => switch (type) {
        'CASH'     => 'เงินสด',
        'CARD'     => 'บัตรเครดิต/เดบิต',
        'TRANSFER' => 'โอนเงิน',
        _          => type,
      };

  static List<ReceiptCoupon> _buildCoupons(
      List<String> codes, double total) {
    if (codes.isEmpty || total <= 0) return [];
    final perCoupon = total / codes.length;
    return codes.asMap().entries.map((e) {
      final isLast = e.key == codes.length - 1;
      final already = perCoupon * e.key;
      return ReceiptCoupon(
        code:     e.value,
        discount: isLast ? total - already : perCoupon,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final dateFmt  = DateFormat('dd/MM/yyyy HH:mm');
    final numFmt   = NumberFormat('#,##0.00');

    final isWalkIn = order.customerId == null ||
        order.customerId == 'WALK_IN' ||
        order.customerId!.isEmpty;
    final earnedPoints = isWalkIn ? 0 : calculateEarnedPoints(order.totalAmount);

    return Scaffold(
      backgroundColor: const Color(0xFFEEEEEE),
      appBar: AppBar(
        title: const Text('ใบเสร็จรับเงิน'),
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
            orderDate:    dateFmt.format(order.orderDate),
            customerName: order.customerName,
            items: (order.items ?? []).map((i) => ReceiptItem(
                  name:      i.productName,
                  quantity:  i.quantity,
                  unitPrice: i.unitPrice,
                  amount:    i.amount,
                )).toList(),
            subtotal:     order.subtotal,
            discount:     order.discountAmount - order.couponDiscount,
            coupons: _buildCoupons(
                order.couponCodes ?? [], order.couponDiscount),
            total:        order.totalAmount,
            paymentLabel: _paymentLabel(order.paymentType),
            paymentType:  order.paymentType,
            paidAmount:   order.paidAmount,
            changeAmount: order.changeAmount,
            numFmt:       numFmt,
            earnedPoints: earnedPoints,
            pointsUsed:   order.pointsUsed,
          ),
        ),
      ),
    );
  }
}

