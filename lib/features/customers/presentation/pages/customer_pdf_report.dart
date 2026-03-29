// lib/features/customers/presentation/pages/customer_pdf_report.dart
//
// หลัง refactor — เหลือแค่ CustomerPdfBuilder (build PDF เท่านั้น)
// Logic preview / share / save ย้ายไปอยู่ที่ PdfExportService แล้ว
//
// ใน customer_list_page.dart เปลี่ยนจาก:
//   CustomerReportButton(customers: filtered)
// เป็น:
//   PdfReportButton(
//     emptyMessage: 'ไม่มีข้อมูลลูกค้า',
//     title:        'รายงานลูกค้า',
//     filename:     () => PdfFilename.generate('customer_report'),
//     buildPdf:     () => CustomerPdfBuilder.build(filtered),
//     hasData:      filtered.isNotEmpty,
//   )

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../data/models/customer_model.dart';

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
const _kAmber   = PdfColor.fromInt(0xFFE65100);

// ─────────────────────────────────────────────────────────────────
// CustomerPdfBuilder — สร้าง pw.Document เท่านั้น
// ─────────────────────────────────────────────────────────────────
class CustomerPdfBuilder {
  static Future<pw.Document> build(
    List<CustomerModel> customers, {
    String companyName = 'DEE POS',
  }) async {
    final doc = pw.Document(
      title: 'รายงานรายการลูกค้า',
      author: companyName,
    );

    final ttf        = await PdfGoogleFonts.notoSansThaiBold();
    final ttfRegular = await PdfGoogleFonts.notoSansThaiRegular();
    final printedAt  = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    // สถิติ
    final total       = customers.length;
    final active      = customers.where((c) => c.isActive).length;
    final members     = customers
        .where((c) => c.memberNo != null && c.memberNo!.isNotEmpty)
        .length;
    final creditCount = customers.where((c) => c.creditLimit > 0).length;

    final summaryLine =
        'ทั้งหมด $total ราย   ใช้งาน $active ราย   สมาชิก $members ราย   เครดิต $creditCount ราย';

    // แบ่ง page (38 rows/page — portrait A4)
    const rowsPerPage = 38;
    final pages = <List<CustomerModel>>[];
    for (var i = 0; i < customers.length; i += rowsPerPage) {
      pages.add(customers.sublist(
        i,
        (i + rowsPerPage) > customers.length
            ? customers.length
            : i + rowsPerPage,
      ));
    }
    if (pages.isEmpty) pages.add([]);
    final totalPages = pages.length;

    for (var pageIdx = 0; pageIdx < pages.length; pageIdx++) {
      final pageCustomers = pages[pageIdx];
      final startNo       = pageIdx * rowsPerPage + 1;

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _buildPageHeader(
                companyName:  companyName,
                reportTitle:  'รายงานรายการลูกค้า',
                printedAt:    printedAt,
                page:         pageIdx + 1,
                totalPages:   totalPages,
                ttf:          ttf,
                ttfRegular:   ttfRegular,
                summaryLine:  summaryLine,
              ),
              _buildTable(pageCustomers,
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
    List<CustomerModel> customers, {
    required int     startNo,
    required pw.Font ttf,
    required pw.Font ttfRegular,
  }) {
    // portrait A4 usable ≈ 547pt — fixed total 368pt → flex ≈ 179pt
    const colWidths = [
      pw.FixedColumnWidth(26),   // #
      pw.FixedColumnWidth(60),   // รหัส
      pw.FlexColumnWidth(1),     // ชื่อ
      pw.FixedColumnWidth(75),   // โทร
      pw.FixedColumnWidth(55),   // เลขสมาชิก
      pw.FixedColumnWidth(45),   // คะแนน
      pw.FixedColumnWidth(62),   // วงเงิน
      pw.FixedColumnWidth(45),   // สถานะ
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
          children: ['#', 'รหัส', 'ชื่อลูกค้า', 'โทรศัพท์',
                  'เลขสมาชิก', 'คะแนน', 'วงเงินเครดิต', 'สถานะ']
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
        ...customers.asMap().entries.map((e) {
          final i    = e.key;
          final c    = e.value;
          final rowBg       = i.isEven ? _kAltRow : null;
          final statusColor = c.isActive ? _kSuccess : _kError;
          final isMember    = c.memberNo != null && c.memberNo!.isNotEmpty;

          return pw.TableRow(children: [
            cell('${startNo + i}', ttfRegular,
                align: pw.Alignment.center, bgColor: rowBg),
            cell(c.customerCode, ttfRegular, bgColor: rowBg),
            cell(c.customerName, ttf, bgColor: rowBg),
            cell(c.phone ?? '-', ttfRegular, bgColor: rowBg),
            cell(isMember ? (c.memberNo ?? '-') : '-', ttfRegular,
                align: pw.Alignment.center,
                color: isMember ? _kAmber : _kSub,
                bgColor: rowBg),
            cell(isMember ? '${c.points}' : '-', ttfRegular,
                align: pw.Alignment.center, bgColor: rowBg),
            cell(c.creditLimit > 0 ? _fmt(c.creditLimit) : '-', ttfRegular,
                align: pw.Alignment.centerRight, bgColor: rowBg),
            cell(c.isActive ? 'ใช้งาน' : 'ปิด', ttf,
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
      child: pw.Text('DEE POS — รายงานรายการลูกค้า',
          style: pw.TextStyle(font: ttfRegular, fontSize: 7, color: _kSub)),
    );
  }

  static String _fmt(double v) => NumberFormat('#,##0.00', 'th').format(v);
}
