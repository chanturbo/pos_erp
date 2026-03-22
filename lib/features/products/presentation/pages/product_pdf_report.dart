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
// PDF Colors — ใช้ PdfColor (pdf package) ไม่ใช่ Flutter Color
// ไม่สามารถใช้ AppColors ได้โดยตรงเพราะ AppColors เป็น Flutter Color
// ค่าสีตรงกับ AppColors palette ของ app
// ─────────────────────────────────────────────────────────────────
const _kPrimary    = PdfColor.fromInt(0xFFE8622A);
const _kNavy       = PdfColor.fromInt(0xFF16213E);
const _kHeaderBg   = PdfColor.fromInt(0xFFF4F4F0);
const _kBorder     = PdfColor.fromInt(0xFFE0E0E0);
const _kTextSub    = PdfColor.fromInt(0xFF666666);
const _kSuccess    = PdfColor.fromInt(0xFF2E7D32);
const _kSuccessBg  = PdfColor.fromInt(0xFFE8F5E9);
const _kInactive   = PdfColor.fromInt(0xFFC62828);
const _kInactiveBg = PdfColor.fromInt(0xFFFFEBEE);
const _kWhite      = PdfColors.white;

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

    // แบ่ง page (30 rows/page — landscape A4)
    const rowsPerPage = 30;
    final pages = <List<ProductModel>>[];
    for (var i = 0; i < products.length; i += rowsPerPage) {
      pages.add(products.sublist(
        i,
        (i + rowsPerPage) > products.length ? products.length : i + rowsPerPage,
      ));
    }
    final totalPages = pages.isEmpty ? 1 : pages.length;

    for (var pageIdx = 0;
        pageIdx < (pages.isEmpty ? 1 : pages.length);
        pageIdx++) {
      final pageProducts = pages.isEmpty ? <ProductModel>[] : pages[pageIdx];
      final startNo = pageIdx * rowsPerPage + 1;

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(24),
          build: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildHeader(
                companyName: companyName,
                printedAt:   printedAt,
                total:       products.length,
                active:      products.where((p) => p.isActive).length,
                ttf:         ttf,
                ttfRegular:  ttfRegular,
              ),
              pw.SizedBox(height: 12),
              _buildTable(pageProducts,
                  startNo: startNo, ttf: ttf, ttfRegular: ttfRegular),
              pw.Spacer(),
              _buildFooter(
                  page: pageIdx + 1,
                  totalPages: totalPages,
                  ttfRegular: ttfRegular),
            ],
          ),
        ),
      );
    }

    return doc;
  }

  // ── Header ────────────────────────────────────────────────────
  static pw.Widget _buildHeader({
    required String companyName,
    required String printedAt,
    required int total,
    required int active,
    required pw.Font ttf,
    required pw.Font ttfRegular,
  }) {
    return pw.Container(
      decoration: pw.BoxDecoration(
          color: _kNavy, borderRadius: pw.BorderRadius.circular(8)),
      padding:
          const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('รายงานรายการสินค้า',
                    style: pw.TextStyle(
                        font: ttf, fontSize: 18, color: _kWhite)),
                pw.SizedBox(height: 4),
                pw.Text(companyName,
                    style: pw.TextStyle(
                        font: ttfRegular,
                        fontSize: 11,
                        color: const PdfColor.fromInt(0xFFAAAAAA))),
              ],
            ),
          ),
          pw.Row(children: [
            _statChip('ทั้งหมด', '$total รายการ', _kPrimary, ttf, ttfRegular),
            pw.SizedBox(width: 8),
            _statChip('ใช้งาน', '$active รายการ', _kSuccess, ttf, ttfRegular),
            pw.SizedBox(width: 8),
            _statChip('พิมพ์เมื่อ', printedAt,
                const PdfColor.fromInt(0xFF1565C0), ttf, ttfRegular),
          ]),
        ],
      ),
    );
  }

  static pw.Widget _statChip(String label, String value, PdfColor color,
      pw.Font ttf, pw.Font ttfRegular) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: pw.BoxDecoration(
          color: PdfColors.white,
          borderRadius: pw.BorderRadius.circular(6)),
      child: pw.Column(children: [
        pw.Text(label,
            style: pw.TextStyle(
                font: ttfRegular, fontSize: 8, color: _kTextSub)),
        pw.SizedBox(height: 2),
        pw.Text(value,
            style:
                pw.TextStyle(font: ttf, fontSize: 10, color: color)),
      ]),
    );
  }

  // ── Table ─────────────────────────────────────────────────────
  static pw.Widget _buildTable(
    List<ProductModel> products, {
    required int startNo,
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
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        alignment: align,
        child: pw.Text(text,
            style: pw.TextStyle(font: font, fontSize: 9, color: color)),
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
          decoration: pw.BoxDecoration(color: _kNavy),
          children: ['#', 'รหัสสินค้า', 'ชื่อสินค้า', 'หน่วย',
                  'ราคาขาย', 'ต้นทุน', 'ควบคุมสต๊อก', 'สถานะ']
              .map((h) => pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 6, vertical: 7),
                    child: pw.Text(h,
                        style: pw.TextStyle(
                            font: ttf, fontSize: 9, color: _kWhite)),
                  ))
              .toList(),
        ),
        // Data rows
        ...products.asMap().entries.map((e) {
          final i = e.key;
          final p = e.value;
          final rowBg = i.isEven ? _kHeaderBg : PdfColors.white;
          final statusColor = p.isActive ? _kSuccess : _kInactive;
          final statusBg    = p.isActive ? _kSuccessBg : _kInactiveBg;
          return pw.TableRow(children: [
            cell('${startNo + i}', ttfRegular,
                align: pw.Alignment.center,
                bgColor: rowBg),
            cell(p.productCode, ttfRegular, bgColor: rowBg),
            cell(p.productName, ttf, bgColor: rowBg),
            cell(p.baseUnit, ttfRegular,
                align: pw.Alignment.center, bgColor: rowBg),
            cell(_fmt(p.priceLevel1), ttfRegular,
                align: pw.Alignment.centerRight, bgColor: rowBg),
            cell(_fmt(p.standardCost), ttfRegular,
                align: pw.Alignment.centerRight, bgColor: rowBg),
            cell(p.isStockControl ? 'ควบคุม' : '-',
                ttfRegular,
                align: pw.Alignment.center, bgColor: rowBg),
            cell(p.isActive ? 'ใช้งาน' : 'ปิด', ttf,
                align: pw.Alignment.center,
                color: statusColor,
                bgColor: statusBg),
          ]);
        }),
      ],
    );
  }

  // ── Footer ────────────────────────────────────────────────────
  static pw.Widget _buildFooter({
    required int page,
    required int totalPages,
    required pw.Font ttfRegular,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
          border: pw.Border(
              top: pw.BorderSide(color: _kBorder, width: 0.5))),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('DEE POS — รายงานสินค้า',
              style: pw.TextStyle(
                  font: ttfRegular, fontSize: 8, color: _kTextSub)),
          pw.Text('หน้า $page / $totalPages',
              style: pw.TextStyle(
                  font: ttfRegular, fontSize: 8, color: _kTextSub)),
        ],
      ),
    );
  }

  static String _fmt(double v) => NumberFormat('#,##0.00', 'th').format(v);
}