import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../data/models/stock_balance_model.dart';

// ─────────────────────────────────────────────────────────────────
// Standard color palette
// ─────────────────────────────────────────────────────────────────
const _kBorder  = PdfColor.fromInt(0xFFBBBBBB);
const _kHdrBg   = PdfColor.fromInt(0xFFDDDDDD);
const _kAltRow  = PdfColor.fromInt(0xFFF5F5F5);
const _kText    = PdfColors.black;
const _kSub     = PdfColor.fromInt(0xFF555555);
const _kWarning = PdfColor.fromInt(0xFFBF360C);
const _kWarnBg  = PdfColor.fromInt(0xFFFFF8E1);

class StockBalancePdfBuilder {
  static Future<pw.Document> build(
    List<StockBalanceModel> stocks, {
    String companyName = 'DEE POS',
    int lowStockThreshold = 10,
    bool highlightLowStock = true,
  }) async {
    final doc = pw.Document(
      title: 'รายงานสต๊อกสินค้า',
      author: companyName,
    );

    final ttf        = await PdfGoogleFonts.notoSansThaiBold();
    final ttfRegular = await PdfGoogleFonts.notoSansThaiRegular();
    final printedAt  = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    final lowCount = highlightLowStock
        ? stocks.where((s) => s.balance < lowStockThreshold).length
        : 0;

    var summaryLine = 'ทั้งหมด ${stocks.length} รายการ';
    if (lowCount > 0) {
      summaryLine += '   สต๊อกต่ำกว่า $lowStockThreshold : $lowCount รายการ';
    }

    const rowsPerPage = 30;
    final pages = <List<StockBalanceModel>>[];
    for (var i = 0; i < stocks.length; i += rowsPerPage) {
      pages.add(stocks.sublist(
        i,
        (i + rowsPerPage) > stocks.length ? stocks.length : i + rowsPerPage,
      ));
    }
    if (pages.isEmpty) pages.add([]);
    final totalPages = pages.length;

    for (var pageIdx = 0; pageIdx < pages.length; pageIdx++) {
      final pageStocks = pages[pageIdx];
      final startNo    = pageIdx * rowsPerPage + 1;

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(24),
          build: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _buildPageHeader(
                companyName:  companyName,
                reportTitle:  'รายงานสต๊อกสินค้า',
                printedAt:    printedAt,
                page:         pageIdx + 1,
                totalPages:   totalPages,
                ttf:          ttf,
                ttfRegular:   ttfRegular,
                summaryLine:  summaryLine,
              ),
              _buildTable(
                pageStocks,
                startNo:           startNo,
                lowStockThreshold: lowStockThreshold,
                highlightLowStock: highlightLowStock,
                ttf:               ttf,
                ttfRegular:        ttfRegular,
              ),
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

  static pw.Widget _buildTable(
    List<StockBalanceModel> stocks, {
    required int  startNo,
    required int  lowStockThreshold,
    required bool highlightLowStock,
    required pw.Font ttf,
    required pw.Font ttfRegular,
  }) {
    const colWidths = {
      0: pw.FixedColumnWidth(36),   // #
      1: pw.FixedColumnWidth(80),   // รหัส
      2: pw.FlexColumnWidth(2.5),   // ชื่อ
      3: pw.FlexColumnWidth(1.5),   // คลัง
      4: pw.FixedColumnWidth(80),   // คงเหลือ
      5: pw.FixedColumnWidth(55),   // หน่วย
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
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _kHdrBg),
          children: ['#', 'รหัสสินค้า', 'ชื่อสินค้า', 'คลัง', 'คงเหลือ', 'หน่วย']
              .map((h) => pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 5, vertical: 6),
                    child: pw.Text(h,
                        style: pw.TextStyle(
                            font: ttf, fontSize: 8, color: _kText)),
                  ))
              .toList(),
        ),
        ...stocks.asMap().entries.map((e) {
          final i     = e.key;
          final s     = e.value;
          final isLow = highlightLowStock && s.balance < lowStockThreshold;
          // Low stock rows keep _kWarnBg background (functionally important)
          final rowBg = isLow ? _kWarnBg : (i.isEven ? _kAltRow : null);
          final balanceColor = isLow ? _kWarning : _kText;

          return pw.TableRow(children: [
            cell('${startNo + i}', ttfRegular,
                align: pw.Alignment.center, bgColor: rowBg),
            cell(s.productCode, ttfRegular, bgColor: rowBg),
            cell(s.productName, ttf, bgColor: rowBg),
            cell(s.warehouseName, ttfRegular, bgColor: rowBg),
            cell(_fmt(s.balance), ttfRegular,
                align: pw.Alignment.centerRight,
                color: balanceColor,
                bgColor: rowBg),
            cell(s.baseUnit, ttfRegular,
                align: pw.Alignment.center, bgColor: rowBg),
          ]);
        }),
      ],
    );
  }

  static pw.Widget _buildFooter({required pw.Font ttfRegular}) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
          border: pw.Border(top: pw.BorderSide(color: _kBorder, width: 0.5))),
      child: pw.Text('DEE POS — รายงานสต๊อกสินค้า',
          style: pw.TextStyle(font: ttfRegular, fontSize: 7, color: _kSub)),
    );
  }

  static String _fmt(double v) => NumberFormat('#,##0.00', 'th').format(v);
}
