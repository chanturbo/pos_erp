// lib/shared/pdf/barcode_pdf_builder.dart
//
// สร้าง PDF บาร์โค้ด A4 แนวตั้ง
// แต่ละ label: ชื่อสินค้า + barcode + ตัวเลข
// รองรับ Code128 / EAN-13 / QR Code

import 'dart:math' show min;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// ─────────────────────────────────────────────────────────────────
// Data model
// ─────────────────────────────────────────────────────────────────
class BarcodeLabel {
  final String name;
  final String barcodeValue;
  const BarcodeLabel({required this.name, required this.barcodeValue});
}

enum BarcodePdfType { code128, ean13, qrCode }

// ─────────────────────────────────────────────────────────────────
// BarcodePdfBuilder
// ─────────────────────────────────────────────────────────────────
class BarcodePdfBuilder {
  static const _margin = 10.0; // mm
  static const _gap    = 3.0;  // mm between cells

  static Future<pw.Document> build(
    List<BarcodeLabel> labels, {
    int columnsPerRow = 3,
    BarcodePdfType type = BarcodePdfType.code128,
  }) async {
    assert(columnsPerRow >= 1 && columnsPerRow <= 4);

    final bold    = await PdfGoogleFonts.notoSansThaiBold();
    final regular = await PdfGoogleFonts.notoSansThaiRegular();

    // Available width inside margins
    final availW = (210 - _margin * 2) * PdfPageFormat.mm;
    final gapPt  = _gap * PdfPageFormat.mm;
    final labelW = (availW - gapPt * (columnsPerRow - 1)) / columnsPerRow;
    final labelH = type == BarcodePdfType.qrCode
        ? labelW                           // QR = square
        : (type == BarcodePdfType.ean13
            ? 28 * PdfPageFormat.mm
            : 26 * PdfPageFormat.mm);

    final doc = pw.Document(title: 'บาร์โค้ดสินค้า');
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.copyWith(
          marginLeft:   _margin * PdfPageFormat.mm,
          marginRight:  _margin * PdfPageFormat.mm,
          marginTop:    _margin * PdfPageFormat.mm,
          marginBottom: _margin * PdfPageFormat.mm,
        ),
        build: (ctx) => [
          pw.Wrap(
            spacing: gapPt,
            runSpacing: gapPt,
            children: labels
                .map((l) => _cell(l, labelW, labelH, type, bold, regular))
                .toList(),
          ),
        ],
      ),
    );
    return doc;
  }

  // ── label cell ─────────────────────────────────────────────────
  static pw.Widget _cell(
    BarcodeLabel label,
    double w,
    double h,
    BarcodePdfType type,
    pw.Font bold,
    pw.Font regular,
  ) {
    final barcodeH = type == BarcodePdfType.qrCode
        ? w - 8 * PdfPageFormat.mm           // QR square inside padding
        : h - 12 * PdfPageFormat.mm;         // subtract name + padding

    return pw.Container(
      width: w,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
        borderRadius: pw.BorderRadius.circular(2),
      ),
      padding: const pw.EdgeInsets.all(3),
      child: pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          // ── ชื่อสินค้า ─────────────────────────────────────────
          pw.Text(
            label.name,
            style: pw.TextStyle(font: bold, fontSize: 7),
            textAlign: pw.TextAlign.center,
            maxLines: 2,
            overflow: pw.TextOverflow.clip,
          ),
          pw.SizedBox(height: 2),
          // ── barcode ────────────────────────────────────────────
          _safeBarcode(label.barcodeValue, w - 6, barcodeH, type, regular),
        ],
      ),
    );
  }

  // ── guard invalid barcodes ─────────────────────────────────────
  static pw.Widget _safeBarcode(
    String data,
    double w,
    double h,
    BarcodePdfType type,
    pw.Font regular,
  ) {
    try {
      return pw.BarcodeWidget(
        barcode: _barcodeOf(type),
        data: data,
        width: w,
        height: h,
        drawText: type != BarcodePdfType.qrCode,
        textStyle: pw.TextStyle(font: regular, fontSize: 6),
        color: PdfColors.black,
      );
    } catch (_) {
      return pw.Container(
        width: w,
        height: h,
        alignment: pw.Alignment.center,
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.red, width: 0.5),
        ),
        child: pw.Text(
          'บาร์โค้ดไม่ถูกต้อง\n$data',
          style: pw.TextStyle(font: regular, fontSize: 6, color: PdfColors.red),
          textAlign: pw.TextAlign.center,
        ),
      );
    }
  }

  static pw.Barcode _barcodeOf(BarcodePdfType type) => switch (type) {
        BarcodePdfType.code128 => pw.Barcode.code128(),
        BarcodePdfType.ean13   => pw.Barcode.ean13(),
        BarcodePdfType.qrCode  => pw.Barcode.qrCode(),
      };

  // ── expand by quantity (repeat each label n times) ─────────────
  static List<BarcodeLabel> expand(BarcodeLabel label, int qty) =>
      List.generate(min(qty, 200), (_) => label);
}
