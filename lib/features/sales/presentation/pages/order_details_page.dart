import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/sales_provider.dart';
import '../../data/models/sales_order_model.dart';
import '../widgets/receipt_widget.dart';

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
    final hasMember = !isWalkIn && earnedPoints > 0;

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
                                const Icon(Icons.stars,
                                    color: Colors.amber, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'สะสมคะแนน: +$earnedPoints pt',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.amber[800],
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

              // ── Summary Card ─────────────────────────────────
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildSummaryRow('ยอดรวม', order.subtotal),
                      if (order.discountAmount > 0)
                        _buildSummaryRow('ส่วนลด', -order.discountAmount,
                            isDiscount: true),
                      const Divider(),
                      _buildSummaryRow('ยอดชำระ', order.totalAmount,
                          isTotal: true),
                      if (order.paymentType == 'CASH') ...[
                        const SizedBox(height: 8),
                        _buildSummaryRow('รับเงิน', order.paidAmount),
                        _buildSummaryRow('เงินทอน', order.changeAmount,
                            isChange: true),
                      ],
                      // ✅ Week 5: สรุป points ด้านล่าง summary
                      if (hasMember) ...[
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.stars,
                                    size: 16, color: Colors.amber),
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
                              '+$earnedPoints pt',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.amber[700],
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
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                fontSize: isTotal ? 18 : 14,
                fontWeight:
                    isTotal ? FontWeight.bold : FontWeight.normal,
              )),
          Text(
            '฿${amount.toStringAsFixed(2)}',
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
                          : Colors.black,
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
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: Container(
          width: 400,
          constraints: const BoxConstraints(maxHeight: 700),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('ใบเสร็จ',
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: SingleChildScrollView(
                  child: ReceiptWidget(order: _order!),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('พิมพ์ใบเสร็จ (เร็วๆ นี้...)')),
                    );
                  },
                  icon: const Icon(Icons.print),
                  label: const Text('พิมพ์'),
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}