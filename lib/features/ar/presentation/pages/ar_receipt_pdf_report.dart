// lib/features/ar/presentation/pages/ar_receipt_pdf_report.dart
//
// ArReceiptPdfBuilder — สร้างรายงาน PDF ประวัติการรับเงิน AR

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../settings/shared/settings_defaults.dart';
import '../../data/models/ar_receipt_model.dart';

const _kBorder = PdfColor.fromInt(0xFFBBBBBB);
const _kHdrBg = PdfColor.fromInt(0xFFDDDDDD);
const _kAltRow = PdfColor.fromInt(0xFFF5F5F5);
const _kText = PdfColors.black;
const _kSub = PdfColor.fromInt(0xFF555555);
const _kNavy = PdfColor.fromInt(0xFF16213E);
const _kCash = PdfColor.fromInt(0xFF1B5E20);
const _kTransfer = PdfColor.fromInt(0xFF0D47A1);
const _kCheque = PdfColor.fromInt(0xFFE65100);
const _kCard = PdfColor.fromInt(0xFF4A148C);
const _kTeal = PdfColor.fromInt(0xFF00695C);
const _kCashBg = PdfColor.fromInt(0xFFE8F5E9);
const _kTransferBg = PdfColor.fromInt(0xFFE3F2FD);
const _kChequeBg = PdfColor.fromInt(0xFFFFF3E0);
const _kCardBg = PdfColor.fromInt(0xFFF3E5F5);
const _kTealLight = PdfColor.fromInt(0xFFE0F2F1);
const _kTealBorder = PdfColor.fromInt(0xFF80CBC4);

class ArReceiptPdfBuilder {
  static final _money = NumberFormat('#,##0.00');
  static final _date = DateFormat('dd/MM/yy');

  static String _methodLabel(String m) {
    switch (m) {
      case 'CASH':
        return 'เงินสด';
      case 'TRANSFER':
        return 'โอนเงิน';
      case 'CHEQUE':
        return 'เช็ค';
      case 'CREDIT_CARD':
        return 'บัตร';
      default:
        return m;
    }
  }

  static PdfColor _methodColor(String m) {
    switch (m) {
      case 'CASH':
        return _kCash;
      case 'TRANSFER':
        return _kTransfer;
      case 'CHEQUE':
        return _kCheque;
      case 'CREDIT_CARD':
        return _kCard;
      default:
        return _kTeal;
    }
  }

  static PdfColor _methodBg(String m) {
    switch (m) {
      case 'CASH':
        return _kCashBg;
      case 'TRANSFER':
        return _kTransferBg;
      case 'CHEQUE':
        return _kChequeBg;
      case 'CREDIT_CARD':
        return _kCardBg;
      default:
        return _kTealLight;
    }
  }

  static Future<pw.Document> build(
    List<ArReceiptModel> receipts, {
    String? companyName,
  }) async {
    final effectiveCompanyName =
        companyName ?? await SettingsStorage.getCompanyName();
    final doc = pw.Document(
      title: 'รายงานการรับเงิน',
      author: effectiveCompanyName,
    );
    final ttf = await PdfGoogleFonts.notoSansThaiBold();
    final ttfR = await PdfGoogleFonts.notoSansThaiRegular();
    final printedAt = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    final totalAmt = receipts.fold<double>(0, (s, r) => s + r.totalAmount);
    final cash = receipts.where((r) => r.paymentMethod == 'CASH').length;
    final transfer = receipts.where((r) => r.paymentMethod == 'TRANSFER').length;
    final cheque = receipts.where((r) => r.paymentMethod == 'CHEQUE').length;
    final card = receipts.where((r) => r.paymentMethod == 'CREDIT_CARD').length;
    final summaryLine =
        'ทั้งหมด ${receipts.length} ใบ   '
        'เงินสด $cash ใบ   '
        'โอนเงิน $transfer ใบ   '
        'เช็ค $cheque ใบ'
        '${card > 0 ? '   บัตร $card ใบ' : ''}';
    final summaryRow = _buildSummaryRow(
      count: receipts.length,
      cash: cash,
      transfer: transfer,
      totalAmt: totalAmt,
      ttf: ttf,
      ttfR: ttfR,
    );

    final rowsPerPage = await SettingsStorage.getPdfReportRowsPerPage(
      PdfReportType.arReceipt,
    );
    final pages = <List<ArReceiptModel>>[];
    for (var i = 0; i < receipts.length; i += rowsPerPage) {
      pages.add(
        receipts.sublist(
          i,
          (i + rowsPerPage) > receipts.length ? receipts.length : i + rowsPerPage,
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
              _buildTableHeader(ttf: ttf),
              ...pages[pi].asMap().entries.map(
                (e) => _buildRow(e.value, e.key.isEven, ttfR: ttfR),
              ),
              pw.Spacer(),
              if (pi == totalPages - 1)
                _buildTotalsRow(totalAmt: totalAmt, ttf: ttf),
              pw.SizedBox(height: 6),
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
          'รายงานการรับเงินลูกหนี้',
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
    required int cash,
    required int transfer,
    required double totalAmt,
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
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
        border: pw.Border.all(color: _kBorder, width: 0.5),
      ),
      child: pw.Row(
        children: [
          cell('จำนวนใบรับ', '$count ใบ', _kNavy),
          pw.Container(width: 0.5, height: 28, color: _kBorder),
          cell('เงินสด', '$cash ใบ', _kCash),
          pw.Container(width: 0.5, height: 28, color: _kBorder),
          cell('โอนเงิน', '$transfer ใบ', _kTransfer),
          pw.Container(width: 0.5, height: 28, color: _kBorder),
          cell('ยอดรับรวม', '฿${_money.format(totalAmt)}', _kTeal),
        ],
      ),
    );
  }

  static pw.Widget _buildTableHeader({required pw.Font ttf}) {
    cell(String t, {pw.TextAlign align = pw.TextAlign.left, int flex = 1}) =>
        pw.Expanded(
          flex: flex,
          child: pw.Text(
            t,
            style: pw.TextStyle(font: ttf, fontSize: 9, color: _kText),
            textAlign: align,
          ),
        );

    return pw.Container(
      color: _kHdrBg,
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 22,
            child: pw.Text('#', style: pw.TextStyle(font: ttf, fontSize: 9), textAlign: pw.TextAlign.center),
          ),
          cell('เลขที่ใบรับเงิน', flex: 3),
          cell('ลูกค้า', flex: 3),
          cell('วันที่', flex: 2),
          cell('วิธีรับ', flex: 2),
          cell('ยอดรับ', flex: 2, align: pw.TextAlign.right),
        ],
      ),
    );
  }

  static pw.Widget _buildRow(
    ArReceiptModel r,
    bool isEven, {
    required pw.Font ttfR,
  }) {
    rcell(String t, {pw.TextAlign align = pw.TextAlign.left, int flex = 1, PdfColor? color}) =>
        pw.Expanded(
          flex: flex,
          child: pw.Text(
            t,
            style: pw.TextStyle(font: ttfR, fontSize: 8.5, color: color ?? _kText),
            textAlign: align,
            overflow: pw.TextOverflow.clip,
          ),
        );

    final methodColor = _methodColor(r.paymentMethod);
    final methodLabel = _methodLabel(r.paymentMethod);
    final methodBg = _methodBg(r.paymentMethod);
    final allocs = r.allocations;
    final hasAllocs = allocs != null && allocs.isNotEmpty;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: pw.BoxDecoration(
            color: isEven ? _kAltRow : PdfColors.white,
            border: hasAllocs
                ? null
                : const pw.Border(
                    bottom: pw.BorderSide(color: _kBorder, width: 0.3),
                  ),
          ),
          child: pw.Row(
            children: [
              pw.SizedBox(
                width: 22,
                child: pw.Text(
                  '${r.receiptNo.hashCode % 9999}',
                  style: pw.TextStyle(font: ttfR, fontSize: 8, color: _kSub),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              rcell(r.receiptNo, flex: 3),
              rcell(r.customerName, flex: 3, color: _kSub),
              rcell(_date.format(r.receiptDate), flex: 2, color: _kSub),
              pw.Expanded(
                flex: 2,
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: pw.BoxDecoration(
                    color: methodBg,
                    borderRadius: pw.BorderRadius.circular(3),
                  ),
                  child: pw.Text(
                    methodLabel,
                    style: pw.TextStyle(font: ttfR, fontSize: 8, color: methodColor),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              ),
              pw.Expanded(
                flex: 2,
                child: pw.Text(
                  '฿${_money.format(r.totalAmount)}',
                  style: pw.TextStyle(font: ttfR, fontSize: 8.5, color: _kTeal),
                  textAlign: pw.TextAlign.right,
                ),
              ),
            ],
          ),
        ),
        if (hasAllocs)
          _buildAllocationDetail(allocs, isEven: isEven, ttfR: ttfR),
      ],
    );
  }

  static pw.Widget _buildAllocationDetail(
    List allocs, {
    required bool isEven,
    required pw.Font ttfR,
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(left: 22, right: 0),
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: pw.BoxDecoration(
        color: isEven ? _kAltRow : PdfColors.white,
        border: const pw.Border(
          left: pw.BorderSide(color: _kTealBorder, width: 2),
          bottom: pw.BorderSide(color: _kBorder, width: 0.3),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Text(
            'รายละเอียดการจัดสรร',
            style: pw.TextStyle(font: ttfR, fontSize: 7.5, color: _kTeal),
          ),
          pw.SizedBox(height: 2),
          ...allocs.map((a) => pw.Padding(
            padding: const pw.EdgeInsets.only(top: 1),
            child: pw.Row(
              children: [
                pw.Expanded(
                  flex: 4,
                  child: pw.Text(
                    '• ${a.invoiceNo}',
                    style: pw.TextStyle(font: ttfR, fontSize: 7.5, color: _kSub),
                  ),
                ),
                pw.Text(
                  '฿${_money.format(a.allocatedAmount)}',
                  style: pw.TextStyle(font: ttfR, fontSize: 7.5, color: _kTeal),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  static pw.Widget _buildTotalsRow({
    required double totalAmt,
    required pw.Font ttf,
  }) => pw.Container(
      margin: const pw.EdgeInsets.only(top: 4),
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: pw.BoxDecoration(
        color: _kHdrBg,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
        border: pw.Border.all(color: _kBorder, width: 0.5),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
        pw.Text(
          'ยอดรับรวมทั้งหมด  ',
          style: pw.TextStyle(font: ttf, fontSize: 10, color: _kSub),
          ),
          pw.Text(
            '฿${_money.format(totalAmt)}',
            style: pw.TextStyle(font: ttf, fontSize: 12, color: _kTeal),
          ),
        ],
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
