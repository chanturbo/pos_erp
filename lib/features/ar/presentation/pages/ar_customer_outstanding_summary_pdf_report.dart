import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../settings/shared/settings_defaults.dart';

const _kBorder = PdfColor.fromInt(0xFFBBBBBB);
const _kHdrBg = PdfColor.fromInt(0xFFDDDDDD);
const _kText = PdfColors.black;
const _kSub = PdfColor.fromInt(0xFF555555);
const _kNavy = PdfColor.fromInt(0xFF16213E);
const _kError = PdfColor.fromInt(0xFFC62828);

class ArCustomerOutstandingSummaryPdfRow {
  final String customerName;
  final int invoiceCount;
  final double outstandingAmount;
  final double overdueAmount;

  const ArCustomerOutstandingSummaryPdfRow({
    required this.customerName,
    required this.invoiceCount,
    required this.outstandingAmount,
    required this.overdueAmount,
  });
}

class ArCustomerOutstandingSummaryPdfBuilder {
  static final _money = NumberFormat('#,##0.00');

  static Future<pw.Document> build(
    List<ArCustomerOutstandingSummaryPdfRow> rows, {
    String? companyName,
  }) async {
    final effectiveCompanyName =
        companyName ?? await SettingsStorage.getCompanyName();
    final doc = pw.Document(
      title: 'รายงานสรุปลูกค้าค้างชำระ',
      author: effectiveCompanyName,
    );
    final ttf = await PdfGoogleFonts.notoSansThaiBold();
    final ttfR = await PdfGoogleFonts.notoSansThaiRegular();
    final printedAt = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final totalOutstanding = rows.fold<double>(
      0,
      (s, r) => s + r.outstandingAmount,
    );
    final totalOverdue = rows.fold<double>(0, (s, r) => s + r.overdueAmount);
    final rowsPerPage = await SettingsStorage.getPdfReportRowsPerPage(
      PdfReportType.arInvoice,
    );
    final pages = <List<ArCustomerOutstandingSummaryPdfRow>>[];
    for (var i = 0; i < rows.length; i += rowsPerPage) {
      pages.add(
        rows.sublist(i, (i + rowsPerPage) > rows.length ? rows.length : i + rowsPerPage),
      );
    }
    if (pages.isEmpty) pages.add([]);
    final totalPages = pages.length;

    for (var pi = 0; pi < pages.length; pi++) {
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (_) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _buildHeader(
                companyName: effectiveCompanyName,
                printedAt: printedAt,
                page: pi + 1,
                totalPages: totalPages,
                customerCount: rows.length,
                totalOutstanding: totalOutstanding,
                totalOverdue: totalOverdue,
                ttf: ttf,
                ttfR: ttfR,
              ),
              _buildTable(pages[pi], startNo: pi * rowsPerPage + 1, ttf: ttf, ttfR: ttfR),
              pw.Spacer(),
              _buildFooter(companyName: effectiveCompanyName, ttfR: ttfR),
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
    required int page,
    required int totalPages,
    required int customerCount,
    required double totalOutstanding,
    required double totalOverdue,
    required pw.Font ttf,
    required pw.Font ttfR,
  }) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'พิมพ์เมื่อ $printedAt',
            style: pw.TextStyle(font: ttfR, fontSize: 8, color: _kSub),
          ),
          pw.Text(
            'หน้าที่ $page / $totalPages',
            style: pw.TextStyle(font: ttfR, fontSize: 8, color: _kSub),
          ),
        ],
      ),
      pw.SizedBox(height: 3),
      pw.Center(
        child: pw.Text(
          companyName,
          style: pw.TextStyle(font: ttfR, fontSize: 9, color: _kSub),
        ),
      ),
      pw.SizedBox(height: 2),
      pw.Center(
        child: pw.Text(
          'รายงานสรุปลูกค้าค้างชำระ',
          style: pw.TextStyle(font: ttf, fontSize: 14, color: _kText),
        ),
      ),
      pw.SizedBox(height: 2),
      pw.Center(
        child: pw.Text(
          'ลูกค้า $customerCount ราย   ยอดค้างรวม ฿${_money.format(totalOutstanding)}   เกินกำหนด ฿${_money.format(totalOverdue)}',
          style: pw.TextStyle(font: ttfR, fontSize: 8, color: _kSub),
        ),
      ),
      pw.SizedBox(height: 6),
      pw.Container(height: 0.5, color: _kBorder),
      pw.SizedBox(height: 6),
    ],
  );

  static pw.Widget _buildTable(
    List<ArCustomerOutstandingSummaryPdfRow> rows, {
    required int startNo,
    required pw.Font ttf,
    required pw.Font ttfR,
  }) {
    return pw.Table(
      columnWidths: const {
        0: pw.FixedColumnWidth(28),
        1: pw.FlexColumnWidth(3),
        2: pw.FixedColumnWidth(74),
        3: pw.FixedColumnWidth(110),
        4: pw.FixedColumnWidth(110),
      },
      border: pw.TableBorder.all(color: _kBorder, width: 0.5),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _kHdrBg),
          children: ['#', 'ลูกค้า', 'จำนวนใบค้าง', 'ยอดค้างรวม', 'เกินกำหนด']
              .map(
                (h) => pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: pw.Text(
                    h,
                    style: pw.TextStyle(font: ttf, fontSize: 8, color: _kText),
                    textAlign: h == 'ลูกค้า' ? pw.TextAlign.left : pw.TextAlign.center,
                  ),
                ),
              )
              .toList(),
        ),
        ...rows.asMap().entries.map((entry) {
          final idx = entry.key;
          final row = entry.value;
          return pw.TableRow(
            decoration: pw.BoxDecoration(
              color: idx.isEven ? PdfColors.white : const PdfColor.fromInt(0xFFF8F8F8),
            ),
            children: [
              _cell('${startNo + idx}', ttfR, align: pw.TextAlign.center),
              _cell(row.customerName, ttfR),
              _cell('${row.invoiceCount} ใบ', ttfR, align: pw.TextAlign.center),
              _cell('฿${_money.format(row.outstandingAmount)}', ttfR, align: pw.TextAlign.right, bold: true, color: _kNavy),
              _cell('฿${_money.format(row.overdueAmount)}', ttfR, align: pw.TextAlign.right, bold: true, color: row.overdueAmount > 0 ? _kError : _kSub),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _cell(
    String text,
    pw.Font font, {
    pw.TextAlign align = pw.TextAlign.left,
    bool bold = false,
    PdfColor color = _kText,
  }) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6),
    child: pw.Text(
      text,
      textAlign: align,
      style: pw.TextStyle(
        font: font,
        fontSize: 8,
        color: color,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
    ),
  );

  static pw.Widget _buildFooter({
    required String companyName,
    required pw.Font ttfR,
  }) => pw.Container(
    padding: const pw.EdgeInsets.only(top: 6),
    decoration: const pw.BoxDecoration(
      border: pw.Border(top: pw.BorderSide(color: _kBorder, width: 0.5)),
    ),
    child: pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Text(
        companyName,
        style: pw.TextStyle(font: ttfR, fontSize: 7, color: _kSub),
      ),
    ),
  );
}
