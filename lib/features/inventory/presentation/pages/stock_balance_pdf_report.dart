import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../data/models/stock_balance_model.dart';

const _kNavy      = PdfColor.fromInt(0xFF16213E);
const _kPrimary   = PdfColor.fromInt(0xFFE8622A);
const _kHeaderBg  = PdfColor.fromInt(0xFFF4F4F0);
const _kBorder    = PdfColor.fromInt(0xFFE0E0E0);
const _kTextSub   = PdfColor.fromInt(0xFF666666);
const _kSuccess   = PdfColor.fromInt(0xFF2E7D32);
const _kWarning   = PdfColor.fromInt(0xFFF57F17);
const _kWarningBg = PdfColor.fromInt(0xFFFFFDE7);
const _kWhite     = PdfColors.white;

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

    const rowsPerPage = 30;
    final pages = <List<StockBalanceModel>>[];
    for (var i = 0; i < stocks.length; i += rowsPerPage) {
      pages.add(stocks.sublist(
        i,
        (i + rowsPerPage) > stocks.length ? stocks.length : i + rowsPerPage,
      ));
    }
    final totalPages = pages.isEmpty ? 1 : pages.length;

    for (var pageIdx = 0; pageIdx < (pages.isEmpty ? 1 : pages.length); pageIdx++) {
      final pageStocks = pages.isEmpty ? <StockBalanceModel>[] : pages[pageIdx];
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
                printedAt: printedAt,
                total: stocks.length,
                lowCount: lowCount,
                ttf: ttf,
                ttfRegular: ttfRegular,
              ),
              pw.SizedBox(height: 12),
              _buildTable(
                pageStocks,
                startNo: startNo,
                lowStockThreshold: lowStockThreshold,
                highlightLowStock: highlightLowStock,
                ttf: ttf,
                ttfRegular: ttfRegular,
              ),
              pw.Spacer(),
              _buildFooter(page: pageIdx + 1, totalPages: totalPages, ttfRegular: ttfRegular),
            ],
          ),
        ),
      );
    }

    return doc;
  }

  static pw.Widget _buildHeader({
    required String companyName,
    required String printedAt,
    required int total,
    required int lowCount,
    required pw.Font ttf,
    required pw.Font ttfRegular,
  }) {
    return pw.Container(
      decoration: pw.BoxDecoration(
          color: _kNavy, borderRadius: pw.BorderRadius.circular(8)),
      padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('รายงานสต๊อกสินค้า',
                    style: pw.TextStyle(font: ttf, fontSize: 18, color: _kWhite)),
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
            if (lowCount > 0) ...[
              _statChip('สต๊อกต่ำ', '$lowCount รายการ', _kWarning, ttf, ttfRegular),
              pw.SizedBox(width: 8),
            ],
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
          color: PdfColors.white, borderRadius: pw.BorderRadius.circular(6)),
      child: pw.Column(children: [
        pw.Text(label,
            style: pw.TextStyle(font: ttfRegular, fontSize: 8, color: _kTextSub)),
        pw.SizedBox(height: 2),
        pw.Text(value,
            style: pw.TextStyle(font: ttf, fontSize: 10, color: color)),
      ]),
    );
  }

  static pw.Widget _buildTable(
    List<StockBalanceModel> stocks, {
    required int startNo,
    required int lowStockThreshold,
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
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        alignment: align,
        child: pw.Text(text,
            style: pw.TextStyle(font: font, fontSize: 9, color: color)),
      );
    }

    return pw.Table(
      columnWidths: colWidths,
      border: pw.TableBorder.all(color: _kBorder, width: 0.5),
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _kNavy),
          children: ['#', 'รหัสสินค้า', 'ชื่อสินค้า', 'คลัง', 'คงเหลือ', 'หน่วย']
              .map((h) => pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 7),
                    child: pw.Text(h,
                        style: pw.TextStyle(font: ttf, fontSize: 9, color: _kWhite)),
                  ))
              .toList(),
        ),
        ...stocks.asMap().entries.map((e) {
          final i = e.key;
          final s = e.value;
          final isLow = highlightLowStock && s.balance < lowStockThreshold;
          final rowBg = isLow ? _kWarningBg : (i.isEven ? _kHeaderBg : PdfColors.white);
          final balanceColor = isLow ? _kWarning : _kSuccess;

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

  static pw.Widget _buildFooter({
    required int page,
    required int totalPages,
    required pw.Font ttfRegular,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
          border: pw.Border(top: pw.BorderSide(color: _kBorder, width: 0.5))),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('DEE POS — รายงานสต๊อกสินค้า',
              style: pw.TextStyle(font: ttfRegular, fontSize: 8, color: _kTextSub)),
          pw.Text('หน้า $page / $totalPages',
              style: pw.TextStyle(font: ttfRegular, fontSize: 8, color: _kTextSub)),
        ],
      ),
    );
  }

  static String _fmt(double v) => NumberFormat('#,##0.00', 'th').format(v);
}
