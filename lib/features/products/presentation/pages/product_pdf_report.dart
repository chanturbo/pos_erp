// lib/features/products/presentation/pages/product_pdf_report.dart
//
// หลัง refactor — เหลือแค่ ProductPdfBuilder (build PDF เท่านั้น)
// Logic preview / share / save ย้ายไปอยู่ที่ PdfExportService แล้ว
//
// ใน product_list_page.dart เปลี่ยนจาก:
//   ProductReportButton(products: filtered)
// เป็น:
//   PdfReportButton(
//     emptyMessage: 'ไม่มีข้อมูลสินค้า',
//     title:        'รายงานสินค้า',
//     filename:     () => PdfFilename.generate('product_report'),
//     buildPdf:     () => ProductPdfBuilder.build(filtered),
//     hasData:      filtered.isNotEmpty,
//   )

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../data/models/product_model.dart';

// ─────────────────────────────────────────────────────────────────
// Standard color palette
// ─────────────────────────────────────────────────────────────────
const _kBorder  = PdfColor.fromInt(0xFFBBBBBB);
const _kHdrBg   = PdfColor.fromInt(0xFFDDDDDD);
const _kAltRow  = PdfColor.fromInt(0xFFF5F5F5);
const _kText    = PdfColors.black;
const _kSub     = PdfColor.fromInt(0xFF555555);
const _kSuccess = PdfColor.fromInt(0xFF1B5E20);
const _kError   = PdfColor.fromInt(0xFFB71C1C);

// ─────────────────────────────────────────────────────────────────
// ProductPdfBuilder — สร้าง pw.Document เท่านั้น
// ─────────────────────────────────────────────────────────────────
class ProductPdfBuilder {
  static Future<pw.Document> build(
    List<ProductModel> products, {
    String companyName = 'DEE POS',
  }) async {
    final doc = pw.Document(
      title: 'รายงานรายการสินค้า',
      author: companyName,
    );

    final ttf        = await PdfGoogleFonts.notoSansThaiBold();
    final ttfRegular = await PdfGoogleFonts.notoSansThaiRegular();
    final printedAt  = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    final activeCount = products.where((p) => p.isActive).length;
    final summaryLine =
        'ทั้งหมด ${products.length} รายการ   ใช้งาน $activeCount รายการ   ไม่ใช้งาน ${products.length - activeCount} รายการ';

    // แบ่ง page (30 rows/page — landscape A4)
    const rowsPerPage = 30;
    final pages = <List<ProductModel>>[];
    for (var i = 0; i < products.length; i += rowsPerPage) {
      pages.add(products.sublist(
        i,
        (i + rowsPerPage) > products.length ? products.length : i + rowsPerPage,
      ));
    }
    if (pages.isEmpty) pages.add([]);
    final totalPages = pages.length;

    for (var pageIdx = 0; pageIdx < pages.length; pageIdx++) {
      final pageProducts = pages[pageIdx];
      final startNo      = pageIdx * rowsPerPage + 1;

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(24),
          build: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _buildPageHeader(
                companyName:  companyName,
                reportTitle:  'รายงานรายการสินค้า',
                printedAt:    printedAt,
                page:         pageIdx + 1,
                totalPages:   totalPages,
                ttf:          ttf,
                ttfRegular:   ttfRegular,
                summaryLine:  summaryLine,
              ),
              _buildTable(pageProducts,
                  startNo: startNo, ttf: ttf, ttfRegular: ttfRegular),
              pw.Spacer(),
              _buildFooter(ttfRegular: ttfRegular),
            ],
          ),
        ),
      );
    }

    return doc;
  }

  // ── Page Header ───────────────────────────────────────────────
  static pw.Widget _buildPageHeader({
    required String  companyName,
    required String  reportTitle,
    required String  printedAt,
    required int     page,
    required int     totalPages,
    required pw.Font ttf,
    required pw.Font ttfRegular,
    String?          subtitle,
    String?          summaryLine,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('พิมพ์เมื่อ $printedAt',
                style: pw.TextStyle(font: ttfRegular, fontSize: 8, color: _kSub)),
            pw.Text('หน้าที่ $page / $totalPages',
                style: pw.TextStyle(font: ttfRegular, fontSize: 8, color: _kSub)),
          ],
        ),
        pw.SizedBox(height: 3),
        pw.Center(
          child: pw.Text(companyName,
              style: pw.TextStyle(font: ttfRegular, fontSize: 9, color: _kSub)),
        ),
        pw.SizedBox(height: 2),
        pw.Center(
          child: pw.Text(reportTitle,
              style: pw.TextStyle(font: ttf, fontSize: 14, color: _kText)),
        ),
        if (subtitle != null) ...[
          pw.SizedBox(height: 3),
          pw.Center(
            child: pw.Text(subtitle,
                style: pw.TextStyle(font: ttfRegular, fontSize: 8, color: _kSub)),
          ),
        ],
        if (summaryLine != null) ...[
          pw.SizedBox(height: 2),
          pw.Center(
            child: pw.Text(summaryLine,
                style: pw.TextStyle(font: ttfRegular, fontSize: 8, color: _kSub)),
          ),
        ],
        pw.SizedBox(height: 6),
        pw.Container(height: 0.5, color: _kBorder),
        pw.SizedBox(height: 6),
      ],
    );
  }

  // ── Table ─────────────────────────────────────────────────────
  static pw.Widget _buildTable(
    List<ProductModel> products, {
    required int     startNo,
    required pw.Font ttf,
    required pw.Font ttfRegular,
  }) {
    const colWidths = [
      pw.FixedColumnWidth(36),   // #
      pw.FixedColumnWidth(80),   // รหัส
      pw.FlexColumnWidth(2.5),   // ชื่อ
      pw.FixedColumnWidth(55),   // หน่วย
      pw.FixedColumnWidth(75),   // ราคา
      pw.FixedColumnWidth(75),   // ต้นทุน
      pw.FixedColumnWidth(55),   // สต๊อก
      pw.FixedColumnWidth(55),   // สถานะ
    ];

    pw.Widget cell(String text, pw.Font font,
        {pw.Alignment align = pw.Alignment.centerLeft,
        PdfColor? color,
        PdfColor? bgColor}) {
      return pw.Container(
        color: bgColor,
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
        alignment: align,
        child: pw.Text(text,
            style: pw.TextStyle(font: font, fontSize: 8.5, color: color ?? _kText)),
      );
    }

    return pw.Table(
      columnWidths: {
        for (var i = 0; i < colWidths.length; i++) i: colWidths[i]
      },
      border: pw.TableBorder.all(color: _kBorder, width: 0.5),
      children: [
        // Header row
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _kHdrBg),
          children: ['#', 'รหัสสินค้า', 'ชื่อสินค้า', 'หน่วย',
                  'ราคาขาย', 'ต้นทุน', 'ควบคุมสต๊อก', 'สถานะ']
              .map((h) => pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 5, vertical: 6),
                    child: pw.Text(h,
                        style: pw.TextStyle(
                            font: ttf, fontSize: 8, color: _kText)),
                  ))
              .toList(),
        ),
        // Data rows
        ...products.asMap().entries.map((e) {
          final i    = e.key;
          final p    = e.value;
          final rowBg = i.isEven ? _kAltRow : null;
          final statusColor = p.isActive ? _kSuccess : _kError;
          return pw.TableRow(children: [
            cell('${startNo + i}', ttfRegular,
                align: pw.Alignment.center, bgColor: rowBg),
            cell(p.productCode, ttfRegular, bgColor: rowBg),
            cell(p.productName, ttf, bgColor: rowBg),
            cell(p.baseUnit, ttfRegular,
                align: pw.Alignment.center, bgColor: rowBg),
            cell(_fmt(p.priceLevel1), ttfRegular,
                align: pw.Alignment.centerRight, bgColor: rowBg),
            cell(_fmt(p.standardCost), ttfRegular,
                align: pw.Alignment.centerRight, bgColor: rowBg),
            cell(p.isStockControl ? 'ควบคุม' : '-', ttfRegular,
                align: pw.Alignment.center, bgColor: rowBg),
            cell(p.isActive ? 'ใช้งาน' : 'ปิด', ttf,
                align: pw.Alignment.center,
                color: statusColor,
                bgColor: rowBg),
          ]);
        }),
      ],
    );
  }

  // ── Footer ────────────────────────────────────────────────────
  static pw.Widget _buildFooter({required pw.Font ttfRegular}) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
          border: pw.Border(
              top: pw.BorderSide(color: _kBorder, width: 0.5))),
      child: pw.Text('DEE POS — รายงานรายการสินค้า',
          style: pw.TextStyle(font: ttfRegular, fontSize: 7, color: _kSub)),
    );
  }

  static String _fmt(double v) => NumberFormat('#,##0.00', 'th').format(v);
}
