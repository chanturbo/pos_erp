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
import '../../../settings/shared/settings_defaults.dart';
import '../../data/models/product_model.dart';

// ─────────────────────────────────────────────────────────────────
// Standard color palette
// ─────────────────────────────────────────────────────────────────
const _kBorder = PdfColor.fromInt(0xFFBBBBBB);
const _kHdrBg = PdfColor.fromInt(0xFFDDDDDD);
const _kAltRow = PdfColor.fromInt(0xFFF5F5F5);
const _kText = PdfColors.black;
const _kSub = PdfColor.fromInt(0xFF555555);
const _kSuccess = PdfColor.fromInt(0xFF1B5E20);
const _kError = PdfColor.fromInt(0xFFB71C1C);

// ─────────────────────────────────────────────────────────────────
// ProductPdfBuilder — สร้าง pw.Document เท่านั้น
// ─────────────────────────────────────────────────────────────────
class ProductPdfBuilder {
  static final _money = NumberFormat('#,##0.00');

  static Future<pw.Document> build(
    List<ProductModel> products, {
    String? companyName,
    Map<String, double> stockQtyMap = const {},
    double? totalCost,
    double? totalSelling,
    double? totalProfit,
  }) async {
    final effectiveCompanyName =
        companyName ?? await SettingsStorage.getCompanyName();
    final doc = pw.Document(
      title: 'รายงานรายการสินค้า',
      author: effectiveCompanyName,
    );

    final ttf = await PdfGoogleFonts.notoSansThaiBold();
    final ttfRegular = await PdfGoogleFonts.notoSansThaiRegular();
    final printedAt = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    final activeCount = products.where((p) => p.isActive).length;
    final summaryLine =
        'ทั้งหมด ${products.length} รายการ   ใช้งาน $activeCount รายการ   ไม่ใช้งาน ${products.length - activeCount} รายการ';

    // Financial summary widget (แสดงทุกหน้า)
    final financialRow =
        (totalCost != null && totalSelling != null && totalProfit != null)
        ? _buildFinancialRow(
            totalCost: totalCost,
            totalSelling: totalSelling,
            totalProfit: totalProfit,
            ttf: ttf,
            ttfRegular: ttfRegular,
          )
        : null;

    // แบ่ง page (38 rows/page — portrait A4)
    final rowsPerPage = await SettingsStorage.getPdfReportRowsPerPage(
      PdfReportType.productList,
    );
    final pages = <List<ProductModel>>[];
    for (var i = 0; i < products.length; i += rowsPerPage) {
      pages.add(
        products.sublist(
          i,
          (i + rowsPerPage) > products.length
              ? products.length
              : i + rowsPerPage,
        ),
      );
    }
    if (pages.isEmpty) pages.add([]);
    final totalPages = pages.length;

    for (var pageIdx = 0; pageIdx < pages.length; pageIdx++) {
      final pageProducts = pages[pageIdx];
      final startNo = pageIdx * rowsPerPage + 1;

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _buildPageHeader(
                companyName: effectiveCompanyName,
                reportTitle: 'รายงานรายการสินค้า',
                printedAt: printedAt,
                page: pageIdx + 1,
                totalPages: totalPages,
                ttf: ttf,
                ttfRegular: ttfRegular,
                summaryLine: summaryLine,
                financialRow: financialRow,
              ),
              _buildTable(
                pageProducts,
                startNo: startNo,
                stockQtyMap: stockQtyMap,
                ttf: ttf,
                ttfRegular: ttfRegular,
              ),
              pw.Spacer(),
              _buildFooter(
                companyName: effectiveCompanyName,
                ttfRegular: ttfRegular,
              ),
            ],
          ),
        ),
      );
    }

    return doc;
  }

  // ── Page Header ───────────────────────────────────────────────
  static pw.Widget _buildPageHeader({
    required String companyName,
    required String reportTitle,
    required String printedAt,
    required int page,
    required int totalPages,
    required pw.Font ttf,
    required pw.Font ttfRegular,
    String? subtitle,
    String? summaryLine,
    pw.Widget? financialRow,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'พิมพ์เมื่อ $printedAt',
              style: pw.TextStyle(font: ttfRegular, fontSize: 8, color: _kSub),
            ),
            pw.Text(
              'หน้าที่ $page / $totalPages',
              style: pw.TextStyle(font: ttfRegular, fontSize: 8, color: _kSub),
            ),
          ],
        ),
        pw.SizedBox(height: 3),
        pw.Center(
          child: pw.Text(
            companyName,
            style: pw.TextStyle(font: ttfRegular, fontSize: 9, color: _kSub),
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Center(
          child: pw.Text(
            reportTitle,
            style: pw.TextStyle(font: ttf, fontSize: 14, color: _kText),
          ),
        ),
        if (subtitle != null) ...[
          pw.SizedBox(height: 3),
          pw.Center(
            child: pw.Text(
              subtitle,
              style: pw.TextStyle(font: ttfRegular, fontSize: 8, color: _kSub),
            ),
          ),
        ],
        if (summaryLine != null) ...[
          pw.SizedBox(height: 2),
          pw.Center(
            child: pw.Text(
              summaryLine,
              style: pw.TextStyle(font: ttfRegular, fontSize: 8, color: _kSub),
            ),
          ),
        ],
        if (financialRow != null) ...[pw.SizedBox(height: 5), financialRow],
        pw.SizedBox(height: 6),
        pw.Container(height: 0.5, color: _kBorder),
        pw.SizedBox(height: 6),
      ],
    );
  }

  // ── Financial Summary Row ─────────────────────────────────────
  static pw.Widget _buildFinancialRow({
    required double totalCost,
    required double totalSelling,
    required double totalProfit,
    required pw.Font ttf,
    required pw.Font ttfRegular,
  }) {
    final profitColor = totalProfit >= 0 ? _kSuccess : _kError;
    final profitSign = totalProfit >= 0 ? '+' : '-';

    pw.Widget cell(String label, String value, PdfColor valueColor) =>
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                label,
                style: pw.TextStyle(
                  font: ttfRegular,
                  fontSize: 8,
                  color: _kSub,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                value,
                style: pw.TextStyle(font: ttf, fontSize: 10, color: valueColor),
              ),
            ],
          ),
        );

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFF5F5F5),
        border: pw.Border.all(color: _kBorder, width: 0.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
      ),
      child: pw.Row(
        children: [
          cell('ต้นทุนรวม', '฿${_money.format(totalCost)}', _kSub),
          pw.Container(width: 0.5, height: 28, color: _kBorder),
          cell(
            'มูลค่าขาย',
            '฿${_money.format(totalSelling)}',
            const PdfColor.fromInt(0xFF1565C0),
          ),
          pw.Container(width: 0.5, height: 28, color: _kBorder),
          cell(
            'กำไรคาดการณ์',
            '$profitSign฿${_money.format(totalProfit.abs())}',
            profitColor,
          ),
        ],
      ),
    );
  }

  // ── Table ─────────────────────────────────────────────────────
  static pw.Widget _buildTable(
    List<ProductModel> products, {
    required int startNo,
    required Map<String, double> stockQtyMap,
    required pw.Font ttf,
    required pw.Font ttfRegular,
  }) {
    // portrait A4 usable ≈ 547pt — fixed = 26+68+52+38+56+56+62+40 = 398pt → flex ≈ 149pt
    const colWidths = [
      pw.FixedColumnWidth(26), // #
      pw.FixedColumnWidth(68), // รหัส
      pw.FlexColumnWidth(1), // ชื่อ
      pw.FixedColumnWidth(52), // คงเหลือ
      pw.FixedColumnWidth(38), // หน่วย
      pw.FixedColumnWidth(56), // ราคา
      pw.FixedColumnWidth(56), // ต้นทุน
      pw.FixedColumnWidth(62), // มูลค่า
      pw.FixedColumnWidth(40), // สถานะ
    ];

    pw.Widget cell(
      String text,
      pw.Font font, {
      pw.Alignment align = pw.Alignment.centerLeft,
      PdfColor? color,
      PdfColor? bgColor,
    }) {
      return pw.Container(
        color: bgColor,
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
        alignment: align,
        child: pw.Text(
          text,
          style: pw.TextStyle(
            font: font,
            fontSize: 8.5,
            color: color ?? _kText,
          ),
        ),
      );
    }

    return pw.Table(
      columnWidths: {
        for (var i = 0; i < colWidths.length; i++) i: colWidths[i],
      },
      border: pw.TableBorder.all(color: _kBorder, width: 0.5),
      children: [
        // Header row
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _kHdrBg),
          children:
              [
                    '#',
                    'รหัสสินค้า',
                    'ชื่อสินค้า',
                    'คงเหลือ',
                    'หน่วย',
                    'ราคาขาย',
                    'ต้นทุน',
                    'มูลค่า',
                    'สถานะ',
                  ]
                  .map(
                    (h) => pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 6,
                      ),
                      child: pw.Text(
                        h,
                        style: pw.TextStyle(
                          font: ttf,
                          fontSize: 8,
                          color: _kText,
                        ),
                      ),
                    ),
                  )
                  .toList(),
        ),
        // Data rows
        ...products.asMap().entries.map((e) {
          final i = e.key;
          final p = e.value;
          final rowBg = i.isEven ? _kAltRow : null;
          final statusColor = p.isActive ? _kSuccess : _kError;
          final qty = stockQtyMap[p.productId] ?? 0;
          final stockValue = p.standardCost * qty;
          final qtyFmt = NumberFormat('#,##0', 'th').format(qty);
          return pw.TableRow(
            children: [
              cell(
                '${startNo + i}',
                ttfRegular,
                align: pw.Alignment.center,
                bgColor: rowBg,
              ),
              cell(p.productCode, ttfRegular, bgColor: rowBg),
              cell(p.productName, ttf, bgColor: rowBg),
              cell(
                qtyFmt,
                ttfRegular,
                align: pw.Alignment.centerRight,
                bgColor: rowBg,
              ),
              cell(
                p.baseUnit,
                ttfRegular,
                align: pw.Alignment.center,
                bgColor: rowBg,
              ),
              cell(
                _fmt(p.priceLevel1),
                ttfRegular,
                align: pw.Alignment.centerRight,
                bgColor: rowBg,
              ),
              cell(
                _fmt(p.standardCost),
                ttfRegular,
                align: pw.Alignment.centerRight,
                bgColor: rowBg,
              ),
              cell(
                _fmt(stockValue),
                ttfRegular,
                align: pw.Alignment.centerRight,
                bgColor: rowBg,
              ),
              cell(
                p.isActive ? 'ใช้งาน' : 'ปิด',
                ttf,
                align: pw.Alignment.center,
                color: statusColor,
                bgColor: rowBg,
              ),
            ],
          );
        }),
      ],
    );
  }

  // ── Footer ────────────────────────────────────────────────────
  static pw.Widget _buildFooter({
    required String companyName,
    required pw.Font ttfRegular,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _kBorder, width: 0.5)),
      ),
      child: pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          companyName,
          style: pw.TextStyle(font: ttfRegular, fontSize: 7, color: _kSub),
        ),
      ),
    );
  }

  static String _fmt(double v) => NumberFormat('#,##0.00', 'th').format(v);
}
