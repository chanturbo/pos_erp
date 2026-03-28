import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/sales_provider.dart';
import '../../data/models/sales_order_model.dart';
import '../../../settings/presentation/pages/settings_page.dart';

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
              Text(label,
                  style: TextStyle(
                    fontSize: isTotal ? 18 : 14,
                    fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                    color: isCoupon ? Colors.deepOrange : null,
                  )),
            ],
          ),
          Text(
            amount != 0 ? '฿${amount.toStringAsFixed(2)}' : '',
            style: TextStyle(
              fontSize: isTotal ? 22 : 14,
              fontWeight:
                  isTotal ? FontWeight.bold : FontWeight.normal,
              color: isDiscount
                  ? Colors.red
                  : isChange
                      ? Colors.green
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final dateFmt  = DateFormat('dd/MM/yyyy HH:mm');
    final numFmt   = NumberFormat('#,##0.00');

    return Scaffold(
      backgroundColor: const Color(0xFFEEEEEE),
      appBar: AppBar(
        title: const Text('ใบเสร็จรับเงิน'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: _ThermalReceiptFromOrder(
            companyName:  settings.companyName,
            address:      settings.address,
            phone:        settings.phone,
            taxId:        settings.taxId,
            orderNo:      order.orderNo,
            orderDate:    dateFmt.format(order.orderDate),
            customerName: order.customerName,
            items:        order.items ?? [],
            subtotal:     order.subtotal,
            discount:     order.discountAmount - order.couponDiscount,
            couponCodes:  order.couponCodes ?? [],
            couponDiscount: order.couponDiscount,
            total:        order.totalAmount,
            paymentLabel: _paymentLabel(order.paymentType),
            paymentType:  order.paymentType,
            paidAmount:   order.paidAmount,
            changeAmount: order.changeAmount,
            numFmt:       numFmt,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// _ThermalReceiptFromOrder — thermal receipt จาก SalesOrderModel
// ─────────────────────────────────────────────────────────────────
class _ThermalReceiptFromOrder extends StatelessWidget {
  final String   companyName;
  final String   address;
  final String   phone;
  final String   taxId;
  final String   orderNo;
  final String   orderDate;
  final String?  customerName;
  final List<SalesOrderItemModel> items;
  final double   subtotal;
  final double   discount;
  final List<String> couponCodes;
  final double   couponDiscount;
  final double   total;
  final String   paymentLabel;
  final String   paymentType;
  final double   paidAmount;
  final double   changeAmount;
  final NumberFormat numFmt;

  const _ThermalReceiptFromOrder({
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
    this.couponCodes = const [],
    this.couponDiscount = 0.0,
  });

  static const _mono   = TextStyle(fontFamily: 'monospace', fontSize: 13, color: Colors.black87);
  static const _monoSm = TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.black54);
  static const _monoBd = TextStyle(fontFamily: 'monospace', fontSize: 13,
      fontWeight: FontWeight.bold, color: Colors.black87);
  static const _monoLg = TextStyle(fontFamily: 'monospace', fontSize: 18,
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
          _PerforatedEdge(top: true),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ── ข้อมูลร้าน ──────────────────────────────────
                Text(companyName,
                    style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black),
                    textAlign: TextAlign.center),
                if (address.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(address, style: _monoSm, textAlign: TextAlign.center),
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

                // ── หัวใบเสร็จ ──────────────────────────────────
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
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '  ${item.quantity.toStringAsFixed(0)} x '
                                '${numFmt.format(item.unitPrice)}',
                                style: _monoSm,
                              ),
                              Text(numFmt.format(item.amount), style: _mono),
                            ],
                          ),
                        ],
                      ),
                    )),

                _dashed(),

                // ── สรุปยอด ──────────────────────────────────────
                _row('รวม', '฿${numFmt.format(subtotal)}'),
                if (discount > 0)
                  _row('ส่วนลด', '-฿${numFmt.format(discount)}',
                      valueColor: Colors.red[700]),
                if (couponDiscount > 0) ...[
                  if (couponCodes.isNotEmpty)
                    ...couponCodes.asMap().entries.map((e) {
                      final perCoupon = couponDiscount / couponCodes.length;
                      final isLast = e.key == couponCodes.length - 1;
                      // ปัดเศษให้รวมได้พอดี
                      final alreadyShown = perCoupon * e.key;
                      final amt = isLast
                          ? couponDiscount - alreadyShown
                          : perCoupon;
                      return _row(
                        'คูปอง ${e.value}',
                        '-฿${numFmt.format(amt)}',
                        valueColor: Colors.red[700],
                      );
                    })
                  else
                    _row('ส่วนลดคูปอง', '-฿${numFmt.format(couponDiscount)}',
                        valueColor: Colors.red[700]),
                ],

                const SizedBox(height: 4),
                _solidLine(),
                const SizedBox(height: 4),

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

                _row('ชำระด้วย', paymentLabel),
                if (paymentType == 'CASH') ...[
                  _row('รับเงิน', '฿${numFmt.format(paidAmount)}'),
                  _row('เงินทอน', '฿${numFmt.format(changeAmount)}',
                      valueColor: Colors.green[700]),
                ],

                _dashed(),

                // ── ขอบคุณ ──────────────────────────────────────
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
          _PerforatedEdge(top: false),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {Color? valueColor, String? subLabel}) => Padding(
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
                margin: EdgeInsets.only(left: i == 0 ? 0 : 2),
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