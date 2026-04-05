// lib/features/suppliers/presentation/pages/supplier_pdf_report.dart
//
// SupplierPdfBuilder — สร้าง PDF รายการซัพพลายเออร์
//
// วิธีใช้งาน (ใน PdfReportButton):
//   buildPdf: () => SupplierPdfBuilder.build(List<SupplierModel>.from(filtered))

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../data/models/supplier_model.dart';

// ─────────────────────────────────────────────────────────────────
// Standard color palette (ตรงกับ product_pdf_report)
// ─────────────────────────────────────────────────────────────────
const _kBorder  = PdfColor.fromInt(0xFFBBBBBB);
const _kHdrBg   = PdfColor.fromInt(0xFFDDDDDD);
const _kAltRow  = PdfColor.fromInt(0xFFF5F5F5);
const _kText    = PdfColors.black;
const _kSub     = PdfColor.fromInt(0xFF555555);
const _kSuccess = PdfColor.fromInt(0xFF1B5E20);
const _kError   = PdfColor.fromInt(0xFFB71C1C);

// ─────────────────────────────────────────────────────────────────
// SupplierPdfBuilder
// ─────────────────────────────────────────────────────────────────
class SupplierPdfBuilder {
  static final _money = NumberFormat('#,##0.00');

  static Future<pw.Document> build(
    List<SupplierModel> suppliers, {
    String companyName = 'DEE POS',
  }) async {
    final doc = pw.Document(
      title: 'รายงานรายการซัพพลายเออร์',
      author: companyName,
    );

    final ttf        = await PdfGoogleFonts.notoSansThaiBold();
    final ttfRegular = await PdfGoogleFonts.notoSansThaiRegular();
    final printedAt  = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    final activeCount = suppliers.where((s) => s.isActive).length;
    final summaryLine =
        'ทั้งหมด ${suppliers.length} ราย   ใช้งาน $activeCount ราย   ระงับ ${suppliers.length - activeCount} ราย';

    // แบ่ง page (35 rows/page — portrait A4)
    const rowsPerPage = 35;
    final pages = <List<SupplierModel>>[];
    for (var i = 0; i < suppliers.length; i += rowsPerPage) {
      pages.add(suppliers.sublist(
        i,
        (i + rowsPerPage) > suppliers.length ? suppliers.length : i + rowsPerPage,
      ));
    }
    if (pages.isEmpty) pages.add([]);
    final totalPages = pages.length;

    for (var pageIdx = 0; pageIdx < pages.length; pageIdx++) {
      final pageSuppliers = pages[pageIdx];
      final startNo       = pageIdx * rowsPerPage + 1;

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _buildPageHeader(
                companyName: companyName,
                reportTitle: 'รายงานรายการซัพพลายเออร์',
                printedAt:   printedAt,
                page:        pageIdx + 1,
                totalPages:  totalPages,
                ttf:         ttf,
                ttfRegular:  ttfRegular,
                summaryLine: summaryLine,
              ),
              _buildTable(pageSuppliers,
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
    required String   companyName,
    required String   reportTitle,
    required String   printedAt,
    required int      page,
    required int      totalPages,
    required pw.Font  ttf,
    required pw.Font  ttfRegular,
    String?           summaryLine,
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
    List<SupplierModel> suppliers, {
    required int     startNo,
    required pw.Font ttf,
    required pw.Font ttfRegular,
  }) {
    // portrait A4 usable ≈ 547pt
    const colWidths = {
      0: pw.FixedColumnWidth(24),   // #
      1: pw.FixedColumnWidth(62),   // รหัส
      2: pw.FlexColumnWidth(1.6),   // ชื่อซัพพลายเออร์
      3: pw.FixedColumnWidth(72),   // โทรศัพท์
      4: pw.FlexColumnWidth(1.0),   // ผู้ติดต่อ
      5: pw.FixedColumnWidth(50),   // เครดิต(วัน)
      6: pw.FixedColumnWidth(65),   // วงเงิน
      7: pw.FixedColumnWidth(42),   // สถานะ
    };

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
      columnWidths: colWidths,
      border: pw.TableBorder.all(color: _kBorder, width: 0.5),
      children: [
        // Header row
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _kHdrBg),
          children: [
            '#', 'รหัส', 'ชื่อซัพพลายเออร์', 'โทรศัพท์',
            'ผู้ติดต่อ', 'เครดิต\n(วัน)', 'วงเงิน', 'สถานะ'
          ].map((h) => pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 6),
                child: pw.Text(h,
                    style: pw.TextStyle(font: ttf, fontSize: 8, color: _kText)),
              ))
              .toList(),
        ),
        // Data rows
        ...suppliers.asMap().entries.map((e) {
          final i     = e.key;
          final s     = e.value;
          final rowBg = i.isEven ? _kAltRow : null;
          final statusColor = s.isActive ? _kSuccess : _kError;
          return pw.TableRow(children: [
            cell('${startNo + i}', ttfRegular,
                align: pw.Alignment.center, bgColor: rowBg),
            cell(s.supplierCode, ttfRegular, bgColor: rowBg),
            cell(s.supplierName, ttf, bgColor: rowBg),
            cell(s.phone ?? '-', ttfRegular, bgColor: rowBg),
            cell(s.contactPerson ?? '-', ttfRegular, bgColor: rowBg),
            cell('${s.creditTerm}', ttfRegular,
                align: pw.Alignment.center, bgColor: rowBg),
            cell(_money.format(s.creditLimit), ttfRegular,
                align: pw.Alignment.centerRight, bgColor: rowBg),
            cell(s.isActive ? 'ใช้งาน' : 'ระงับ', ttf,
                align: pw.Alignment.center,
                color: statusColor, bgColor: rowBg),
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
      child: pw.Text('DEE POS — รายงานรายการซัพพลายเออร์',
          style: pw.TextStyle(font: ttfRegular, fontSize: 7, color: _kSub)),
    );
  }
}
