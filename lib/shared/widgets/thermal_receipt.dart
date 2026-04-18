// lib/shared/widgets/thermal_receipt.dart
//
// Shared thermal-style receipt widget — ใช้ได้ทั้ง payment page และ order details page
// ─────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────────────
// Data models
// ─────────────────────────────────────────────────────────────────

class ReceiptItem {
  final String name;
  final double quantity;
  final double unitPrice;
  final double amount;

  const ReceiptItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.amount,
  });
}

class ReceiptCoupon {
  final String  code;
  final double  discount;
  final String? promotionName;

  const ReceiptCoupon({
    required this.code,
    required this.discount,
    this.promotionName,
  });
}

class ReceiptFreeItem {
  final String name;
  final double quantity;
  final String? promotionName;

  const ReceiptFreeItem({
    required this.name,
    required this.quantity,
    this.promotionName,
  });
}

// ─────────────────────────────────────────────────────────────────
// ThermalReceiptWidget
// ─────────────────────────────────────────────────────────────────

class ThermalReceiptWidget extends StatelessWidget {
  final String         companyName;
  final String         address;
  final String         phone;
  final String         taxId;
  final String         orderNo;
  final String         orderDate;
  final String?        customerName;
  final List<ReceiptItem>     items;
  final List<ReceiptFreeItem> freeItems;
  final double         subtotal;
  final double         discount;
  final List<ReceiptCoupon> coupons;
  final double         total;
  final String         paymentLabel;
  final String         paymentType;
  final double         paidAmount;
  final double         changeAmount;
  final int            earnedPoints;
  final int            pointsUsed;
  final int?           pointsBalance;
  final NumberFormat   numFmt;
  final int            paperWidthMm;

  const ThermalReceiptWidget({
    super.key,
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
    this.freeItems     = const [],
    this.coupons       = const [],
    this.earnedPoints  = 0,
    this.pointsUsed    = 0,
    this.pointsBalance,
    this.paperWidthMm  = 80,
  });

  // ── text styles ──────────────────────────────────────────────────
  static const _mono   = TextStyle(fontFamily: 'monospace', fontSize: 13, color: Colors.black87);
  static const _monoSm = TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.black54);
  static const _monoBd = TextStyle(fontFamily: 'monospace', fontSize: 13,
      fontWeight: FontWeight.bold, color: Colors.black87);
  static const _monoLg = TextStyle(fontFamily: 'monospace', fontSize: 18,
      fontWeight: FontWeight.bold, color: Colors.black);

  bool get _isNarrowPaper => paperWidthMm <= 58;
  double get _receiptWidth => _isNarrowPaper ? 280 : 340;
  double get _horizontalPadding => _isNarrowPaper ? 14 : 20;
  int get _dashSegments => _isNarrowPaper ? 30 : 38;
  int get _perforatedSegments => _isNarrowPaper ? 22 : 28;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _receiptWidth,
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
          // รอยปรุ ด้านบน
          PerforatedEdge(top: true, segments: _perforatedSegments),

          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: _horizontalPadding,
              vertical: 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ── ข้อมูลร้าน ───────────────────────────────────
                Text(
                  companyName,
                  style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black),
                  textAlign: TextAlign.center,
                ),
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
                const Text(
                  'ใบเสร็จรับเงิน',
                  style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87),
                ),
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
                          Text(item.name, style: _monoBd,
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
                // ── จำนวนรายการ ──────────────────────────────
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'รวม ${items.length} รายการ',
                    style: _monoSm,
                  ),
                ),

                // ── สินค้าแถมฟรี (BUY_X_GET_Y) ─────────────────
                if (freeItems.isNotEmpty) ...[
                  _dashed(),
                  Row(
                    children: const [
                      Icon(Icons.card_giftcard, size: 13, color: Colors.green),
                      SizedBox(width: 4),
                      Text('ของแถมฟรี',
                          style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.green)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ...freeItems.map((item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            const Text('  🎁 ',
                                style: TextStyle(fontSize: 12)),
                            Expanded(
                              child: Text(item.name,
                                  style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 12,
                                      color: Colors.green)),
                            ),
                            Text(
                              'x${item.quantity.toStringAsFixed(0)}  ฿0.00',
                              style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  color: Colors.green),
                            ),
                          ],
                        ),
                      )),
                ],

                _dashed(),

                // ── สรุปยอด ──────────────────────────────────────
                _row('รวม', '฿${numFmt.format(subtotal)}'),
                if (discount > 0)
                  _row('ส่วนลด', '-฿${numFmt.format(discount)}',
                      valueColor: Colors.red[700]),
                ...coupons.map((c) => _row(
                      'คูปอง ${c.code}',
                      '-฿${numFmt.format(c.discount)}',
                      valueColor: Colors.red[700],
                      subLabel: c.promotionName,
                    )),

                // แลกแต้ม (อยู่ก่อนยอดชำระ)
                if (pointsUsed > 0)
                  _row('แลกแต้ม $pointsUsed pt',
                      '-฿${numFmt.format(pointsUsed.toDouble())}',
                      valueColor: Colors.orange[700]),

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
                if (earnedPoints > 0 || pointsBalance != null) ...[
                  _dashed(),
                  if (earnedPoints > 0)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.stars, size: 14, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text(
                          'ได้รับ $earnedPoints แต้มสะสม',
                          style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              color: Colors.amber,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  if (pointsBalance != null)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.account_balance_wallet_outlined,
                            size: 13, color: Colors.amber[700]),
                        const SizedBox(width: 4),
                        Text(
                          'แต้มคงเหลือ ${NumberFormat('#,##0').format(pointsBalance!)} แต้ม',
                          style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              color: Colors.amber[700],
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                ],

                _dashed(),

                // ── ขอบคุณ ──────────────────────────────────────
                const SizedBox(height: 4),
                const Text(
                  'ขอบคุณที่ใช้บริการ',
                  style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87),
                ),
                const Text(
                  '(THANK YOU)',
                  style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: Colors.black45),
                ),
                const Text(
                  'โปรดเก็บใบเสร็จไว้เป็นหลักฐาน',
                  style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      color: Colors.black38),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),

          // รอยปรุ ด้านล่าง
          PerforatedEdge(top: false, segments: _perforatedSegments),
        ],
      ),
    );
  }

  Widget _row(String label, String value,
          {Color? valueColor, String? subLabel}) =>
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
                    Text(subLabel,
                        style: _monoSm, overflow: TextOverflow.ellipsis),
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
            _dashSegments,
            (i) => Expanded(
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
// PerforatedEdge — รอยปรุกระดาษ thermal (shared / exported)
// ─────────────────────────────────────────────────────────────────
class PerforatedEdge extends StatelessWidget {
  final bool top;
  final int segments;

  const PerforatedEdge({
    super.key,
    required this.top,
    this.segments = 28,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: SizedBox(
        height: 12,
        child: Row(
          children: List.generate(segments, (i) {
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
