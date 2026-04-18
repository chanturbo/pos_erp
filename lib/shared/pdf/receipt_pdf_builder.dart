// lib/shared/pdf/receipt_pdf_builder.dart
//
// สร้าง PDF ใบเสร็จรับเงินขนาด 80mm (หรือ 58mm)
// ใช้สำหรับ native OS print dialog บน macOS / Windows
// ─────────────────────────────────────────────────────────────────

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../services/thermal_print_service.dart';

class ReceiptPdfBuilder {
  static final _numFmt = NumberFormat('#,##0.00');
  static final _ptsF   = NumberFormat('#,##0');

  static Future<pw.Document> build(
    ThermalReceiptDocument doc, {
    int paperWidthMm = 80,
  }) async {
    final bold    = await PdfGoogleFonts.notoSansThaiBold();
    final regular = await PdfGoogleFonts.notoSansThaiRegular();

    final pageWidth = paperWidthMm * PdfPageFormat.mm;
    final format = PdfPageFormat(
      pageWidth,
      PdfPageFormat.a4.height,
      marginAll: 5 * PdfPageFormat.mm,
    );

    final document = pw.Document(title: 'ใบเสร็จ ${doc.orderNo}');
    document.addPage(
      pw.Page(
        pageFormat: format,
        build: (ctx) => _buildBody(doc, bold, regular),
      ),
    );
    return document;
  }

  static pw.Widget _buildBody(
    ThermalReceiptDocument doc,
    pw.Font bold,
    pw.Font regular,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        // ── ข้อมูลร้าน ─────────────────────────────────────────
        pw.Text(
          doc.companyName,
          style: pw.TextStyle(font: bold, fontSize: 11),
          textAlign: pw.TextAlign.center,
        ),
        if (doc.address.trim().isNotEmpty)
          pw.Text(
            doc.address,
            style: pw.TextStyle(font: regular, fontSize: 8),
            textAlign: pw.TextAlign.center,
          ),
        if (doc.phone.trim().isNotEmpty)
          pw.Text(
            'โทร: ${doc.phone}',
            style: pw.TextStyle(font: regular, fontSize: 8),
          ),
        if (doc.taxId.trim().isNotEmpty)
          pw.Text(
            'เลขภาษี: ${doc.taxId}',
            style: pw.TextStyle(font: regular, fontSize: 8),
          ),

        _divider(),

        // ── หัวใบเสร็จ ─────────────────────────────────────────
        pw.Text(
          'ใบเสร็จรับเงิน',
          style: pw.TextStyle(font: bold, fontSize: 10),
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 4),
        _row('เลขที่', doc.orderNo, regular),
        _row('วันที่', doc.orderDate, regular),
        if (doc.customerName != null &&
            doc.customerName!.trim().isNotEmpty &&
            doc.customerName != 'ลูกค้าทั่วไป')
          _row('ลูกค้า', doc.customerName!, regular),

        _divider(),

        // ── รายการสินค้า ───────────────────────────────────────
        ...doc.items.map((item) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(item.name,
                    style: pw.TextStyle(font: bold, fontSize: 9)),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      '  ${_qty(item.quantity)} x ${_numFmt.format(item.unitPrice)}',
                      style: pw.TextStyle(font: regular, fontSize: 8),
                    ),
                    pw.Text(
                      _numFmt.format(item.amount),
                      style: pw.TextStyle(font: regular, fontSize: 8),
                    ),
                  ],
                ),
                pw.SizedBox(height: 2),
              ],
            )),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'รวม ${doc.items.length} รายการ',
            style: pw.TextStyle(font: regular, fontSize: 8,
                color: PdfColors.grey600),
          ),
        ),

        // ── ของแถมฟรี ──────────────────────────────────────────
        if (doc.freeItems.isNotEmpty) ...[
          _divider(),
          pw.Align(
            alignment: pw.Alignment.centerLeft,
            child: pw.Text(
              'ของแถมฟรี',
              style: pw.TextStyle(
                  font: bold,
                  fontSize: 9,
                  color: const PdfColor.fromInt(0xFF1B5E20)),
            ),
          ),
          ...doc.freeItems.map((item) => pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('* ${item.name}',
                      style: pw.TextStyle(font: regular, fontSize: 8)),
                  pw.Text('x${_qty(item.quantity)} ฿0.00',
                      style: pw.TextStyle(font: regular, fontSize: 8)),
                ],
              )),
        ],

        _divider(),

        // ── สรุปยอด ────────────────────────────────────────────
        _row('รวม', '฿${_numFmt.format(doc.subtotal)}', regular),
        if (doc.discount > 0)
          _row('ส่วนลด', '-฿${_numFmt.format(doc.discount)}', regular,
              valueColor: PdfColors.red700),
        ...doc.coupons.map((c) => _row(
              'คูปอง ${c.code}',
              '-฿${_numFmt.format(c.discount)}',
              regular,
              valueColor: PdfColors.red700,
            )),
        if (doc.pointsUsed > 0)
          _row(
            'แลกแต้ม ${doc.pointsUsed} pt',
            '-฿${_numFmt.format(doc.pointsUsed.toDouble())}',
            regular,
            valueColor: PdfColors.orange700,
          ),

        pw.SizedBox(height: 3),
        pw.Divider(thickness: 1.5, color: PdfColors.black),
        pw.SizedBox(height: 3),

        // ยอดชำระ
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('ยอดชำระ',
                style: pw.TextStyle(font: bold, fontSize: 10)),
            pw.Text(
              '฿${_numFmt.format(doc.total)}',
              style: pw.TextStyle(font: bold, fontSize: 14),
            ),
          ],
        ),

        pw.Divider(thickness: 1.5, color: PdfColors.black),
        pw.SizedBox(height: 2),

        _row('ชำระด้วย', doc.paymentLabel, regular),
        if (doc.paymentType == 'CASH') ...[
          _row('รับเงิน', '฿${_numFmt.format(doc.paidAmount)}', regular),
          _row('เงินทอน', '฿${_numFmt.format(doc.changeAmount)}', regular,
              valueColor: PdfColors.green700),
        ],

        // ── แต้มสะสม ───────────────────────────────────────────
        if (doc.earnedPoints > 0 || doc.pointsBalance != null) ...[
          _divider(),
          if (doc.earnedPoints > 0)
            pw.Center(
              child: pw.Text(
                'ได้รับ ${doc.earnedPoints} แต้มสะสม',
                style: pw.TextStyle(
                    font: bold,
                    fontSize: 9,
                    color: const PdfColor.fromInt(0xFFF57F17)),
              ),
            ),
          if (doc.pointsBalance != null)
            pw.Center(
              child: pw.Text(
                'แต้มคงเหลือ ${_ptsF.format(doc.pointsBalance!)} แต้ม',
                style: pw.TextStyle(
                    font: regular,
                    fontSize: 8,
                    color: const PdfColor.fromInt(0xFFF57F17)),
              ),
            ),
        ],

        _divider(),

        // ── ขอบคุณ ─────────────────────────────────────────────
        pw.Center(
          child: pw.Text(
            'ขอบคุณที่ใช้บริการ',
            style: pw.TextStyle(font: bold, fontSize: 10),
          ),
        ),
        pw.Center(
          child: pw.Text(
            '(THANK YOU)',
            style: pw.TextStyle(
                font: regular, fontSize: 8, color: PdfColors.grey600),
          ),
        ),
        pw.Center(
          child: pw.Text(
            'โปรดเก็บใบเสร็จไว้เป็นหลักฐาน',
            style: pw.TextStyle(
                font: regular, fontSize: 7, color: PdfColors.grey500),
          ),
        ),
      ],
    );
  }

  static pw.Widget _divider() => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        child: pw.Divider(color: PdfColors.grey400, thickness: 0.5),
      );

  static pw.Widget _row(
    String label,
    String value,
    pw.Font font, {
    PdfColor? valueColor,
  }) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 1),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label,
                style: pw.TextStyle(font: font, fontSize: 8)),
            pw.Text(value,
                style: pw.TextStyle(
                    font: font, fontSize: 8, color: valueColor)),
          ],
        ),
      );

  static String _qty(double qty) => qty == qty.roundToDouble()
      ? qty.toStringAsFixed(0)
      : qty.toStringAsFixed(2);
}
