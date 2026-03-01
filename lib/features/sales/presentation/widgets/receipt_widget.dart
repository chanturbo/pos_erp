import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/sales_order_model.dart';

class ReceiptWidget extends StatelessWidget {
  final SalesOrderModel order;
  
  const ReceiptWidget({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Company Info
          const Text(
            'บริษัท ทดสอบ POS จำกัด',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Text(
            '123 ถนนทดสอบ กรุงเทพฯ 10100',
            style: TextStyle(fontSize: 12),
          ),
          const Text(
            'โทร: 02-123-4567',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 8),
          const Divider(),
          
          // Receipt Info
          Text(
            'ใบเสร็จรับเงิน',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          _buildReceiptRow('เลขที่', order.orderNo, isBold: true),
          _buildReceiptRow('วันที่', DateFormat('dd/MM/yyyy HH:mm').format(order.orderDate)),
          if (order.customerName != null)
            _buildReceiptRow('ลูกค้า', order.customerName!),
          const Divider(),
          
          // Items
          ...?order.items?.map((item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(fontSize: 12),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '  ${item.quantity.toStringAsFixed(0)} x ${item.unitPrice.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                    Text(
                      '${item.amount.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          )),
          const Divider(),
          
          // Summary
          _buildReceiptRow('รวม', order.subtotal.toStringAsFixed(2)),
          if (order.discountAmount > 0)
            _buildReceiptRow('ส่วนลด', '-${order.discountAmount.toStringAsFixed(2)}'),
          const Divider(),
          _buildReceiptRow(
            'ยอดชำระ',
            order.totalAmount.toStringAsFixed(2),
            isBold: true,
            isLarge: true,
          ),
          
          if (order.paymentType == 'CASH') ...[
            const SizedBox(height: 8),
            _buildReceiptRow('รับเงิน', order.paidAmount.toStringAsFixed(2)),
            _buildReceiptRow('เงินทอน', order.changeAmount.toStringAsFixed(2)),
          ],
          
          const SizedBox(height: 8),
          _buildReceiptRow('ชำระด้วย', _getPaymentTypeText(order.paymentType)),
          
          const Divider(),
          const SizedBox(height: 8),
          const Text(
            'ขอบคุณที่ใช้บริการ',
            style: TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildReceiptRow(String label, String value, {
    bool isBold = false,
    bool isLarge = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isLarge ? 14 : 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isLarge ? 16 : 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
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
}