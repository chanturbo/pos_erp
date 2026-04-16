// lib/features/purchases/presentation/pages/purchase_return_pdf_report.dart
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../settings/shared/settings_defaults.dart';
import '../../data/models/purchase_return_model.dart';

const _kBorder = PdfColor.fromInt(0xFFBBBBBB);
const _kHdrBg = PdfColor.fromInt(0xFFDDDDDD);
const _kAltRow = PdfColor.fromInt(0xFFF5F5F5);
const _kText = PdfColors.black;
const _kSub = PdfColor.fromInt(0xFF555555);
const _kDraft = PdfColor.fromInt(0xFFE65100);
const _kConfirmed = PdfColor.fromInt(0xFF1B5E20);
const _kRed = PdfColor.fromInt(0xFFB71C1C);
const _kNavy = PdfColor.fromInt(0xFF16213E);

class PurchaseReturnPdfBuilder {
  static final _money = NumberFormat('#,##0.00');
  static final _date = DateFormat('dd/MM/yy');

  static Future<pw.Document> build(
    List<PurchaseReturnModel> returns, {
    String? companyName,
  }) async {
    final effectiveCompanyName =
        companyName ?? await SettingsStorage.getCompanyName();
    final doc = pw.Document(
      title: 'รายงานการคืนสินค้า',
      author: effectiveCompanyName,
    );
    final ttf = await PdfGoogleFonts.notoSansThaiBold();
    final ttfR = await PdfGoogleFonts.notoSansThaiRegular();
    final printedAt = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    final totalAmt = returns.fold<double>(0, (s, r) => s + r.totalAmount);
    final confirmed = returns.where((r) => r.isConfirmed).length;
    final summaryLine =
        'ทั้งหมด ${returns.length} ใบ   '
        'ร่าง ${returns.length - confirmed} ใบ   '
        'ยืนยันแล้ว $confirmed ใบ';

    final summaryRow = _buildSummaryRow(
      count: returns.length,
      confirmed: confirmed,
      total: totalAmt,
      ttf: ttf,
      ttfR: ttfR,
    );

    final rowsPerPage = await SettingsStorage.getPdfReportRowsPerPage(
      PdfReportType.purchaseReturn,
    );
    final pages = <List<PurchaseReturnModel>>[];
    for (var i = 0; i < returns.length; i += rowsPerPage) {
      pages.add(
        returns.sublist(
          i,
          (i + rowsPerPage) > returns.length ? returns.length : i + rowsPerPage,
        ),
      );
    }
    if (pages.isEmpty) pages.add([]);
    final totalPages = pages.length;

    for (var pi = 0; pi < pages.length; pi++) {
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _buildHeader(
                companyName: effectiveCompanyName,
                printedAt: printedAt,
                page: pi + 1,
                totalPages: totalPages,
                summaryLine: summaryLine,
                summaryRow: summaryRow,
                ttf: ttf,
                ttfR: ttfR,
              ),
              _buildTable(
                pages[pi],
                startNo: pi * rowsPerPage + 1,
                ttf: ttf,
                ttfR: ttfR,
              ),
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
    required String summaryLine,
    required pw.Widget summaryRow,
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
          'รายงานการคืนสินค้า',
          style: pw.TextStyle(font: ttf, fontSize: 14, color: _kText),
        ),
      ),
      pw.SizedBox(height: 2),
      pw.Center(
        child: pw.Text(
          summaryLine,
          style: pw.TextStyle(font: ttfR, fontSize: 8, color: _kSub),
        ),
      ),
      pw.SizedBox(height: 5),
      summaryRow,
      pw.SizedBox(height: 6),
      pw.Container(height: 0.5, color: _kBorder),
      pw.SizedBox(height: 6),
    ],
  );

  static pw.Widget _buildSummaryRow({
    required int count,
    required int confirmed,
    required double total,
    required pw.Font ttf,
    required pw.Font ttfR,
  }) {
    pw.Widget cell(String label, String value, PdfColor vc) => pw.Expanded(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(font: ttfR, fontSize: 8, color: _kSub),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            value,
            style: pw.TextStyle(font: ttf, fontSize: 10, color: vc),
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
          cell('จำนวนใบคืน', '$count ใบ', _kNavy),
          pw.Container(width: 0.5, height: 28, color: _kBorder),
          cell('ยืนยันแล้ว', '$confirmed ใบ', _kConfirmed),
          pw.Container(width: 0.5, height: 28, color: _kBorder),
          cell('ยอดรวมที่คืน', '฿${_money.format(total)}', _kRed),
        ],
      ),
    );
  }

  static pw.Widget _buildTable(
    List<PurchaseReturnModel> returns, {
    required int startNo,
    required pw.Font ttf,
    required pw.Font ttfR,
  }) {
    const colWidths = {
      0: pw.FixedColumnWidth(24),
      1: pw.FixedColumnWidth(76),
      2: pw.FlexColumnWidth(1),
      3: pw.FixedColumnWidth(54),
      4: pw.FixedColumnWidth(54),
      5: pw.FixedColumnWidth(70),
    };

    pw.Widget cell(
      String text,
      pw.Font font, {
      pw.Alignment align = pw.Alignment.centerLeft,
      PdfColor? color,
      PdfColor? bgColor,
    }) => pw.Container(
      color: bgColor,
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      alignment: align,
      child: pw.Text(
        text,
        style: pw.TextStyle(font: font, fontSize: 8, color: color ?? _kText),
      ),
    );

    return pw.Table(
      columnWidths: colWidths,
      border: pw.TableBorder.all(color: _kBorder, width: 0.5),
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _kHdrBg),
          children:
              [
                    '#',
                    'เลขที่คืน',
                    'ซัพพลายเออร์',
                    'วันที่คืน',
                    'สถานะ',
                    'ยอดรวม (฿)',
                  ]
                  .map(
                    (h) => pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 4,
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
        ...returns.asMap().entries.map((e) {
          final i = e.key;
          final r = e.value;
          final bg = i.isEven ? _kAltRow : null;
          final sc = r.isConfirmed ? _kConfirmed : _kDraft;
          return pw.TableRow(
            children: [
              cell(
                '${startNo + i}',
                ttfR,
                align: pw.Alignment.center,
                bgColor: bg,
              ),
              cell(r.returnNo, ttf, bgColor: bg),
              cell(r.supplierName, ttfR, bgColor: bg),
              cell(
                _date.format(r.returnDate),
                ttfR,
                align: pw.Alignment.center,
                bgColor: bg,
              ),
              cell(
                r.isConfirmed ? 'ยืนยันแล้ว' : 'ร่าง',
                ttf,
                align: pw.Alignment.center,
                color: sc,
                bgColor: bg,
              ),
              cell(
                _money.format(r.totalAmount),
                ttfR,
                align: pw.Alignment.centerRight,
                color: _kRed,
                bgColor: bg,
              ),
            ],
          );
        }),
      ],
    );
  }

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
