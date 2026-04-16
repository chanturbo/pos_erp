// lib/features/ap/presentation/pages/ap_payment_pdf_report.dart
//
// ApPaymentPdfBuilder — สร้างรายงาน PDF ประวัติการจ่ายเงิน AP

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../settings/shared/settings_defaults.dart';
import '../../data/models/ap_payment_model.dart';

const _kBorder = PdfColor.fromInt(0xFFBBBBBB);
const _kHdrBg = PdfColor.fromInt(0xFFDDDDDD);
const _kAltRow = PdfColor.fromInt(0xFFF5F5F5);
const _kText = PdfColors.black;
const _kSub = PdfColor.fromInt(0xFF555555);
const _kCash = PdfColor.fromInt(0xFF1B5E20);
const _kTransfer = PdfColor.fromInt(0xFF0D47A1);
const _kCheque = PdfColor.fromInt(0xFFE65100);
const _kTeal = PdfColor.fromInt(0xFF00695C);
const _kWhite70 = PdfColor.fromInt(0xB3FFFFFF);
const _kCashBg = PdfColor.fromInt(0xFFE8F5E9);
const _kTransferBg = PdfColor.fromInt(0xFFE3F2FD);
const _kChequeBg = PdfColor.fromInt(0xFFFFF3E0);
const _kTealLight = PdfColor.fromInt(0xFFE0F2F1);
const _kTealBorder = PdfColor.fromInt(0xFF80CBC4);

class ApPaymentPdfBuilder {
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
      default:
        return _kTeal;
    }
  }

  static Future<pw.Document> build(
    List<ApPaymentModel> payments, {
    String? companyName,
  }) async {
    final effectiveCompanyName =
        companyName ?? await SettingsStorage.getCompanyName();
    final doc = pw.Document(
      title: 'รายงานการจ่ายเงิน',
      author: effectiveCompanyName,
    );
    final ttf = await PdfGoogleFonts.notoSansThaiBold();
    final ttfR = await PdfGoogleFonts.notoSansThaiRegular();
    final printedAt = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    final totalAmt = payments.fold<double>(0, (s, p) => s + p.totalAmount);
    final cash = payments.where((p) => p.paymentMethod == 'CASH').length;
    final transfer = payments
        .where((p) => p.paymentMethod == 'TRANSFER')
        .length;
    final cheque = payments.where((p) => p.paymentMethod == 'CHEQUE').length;

    final rowsPerPage = await SettingsStorage.getPdfReportRowsPerPage(
      PdfReportType.apPayment,
    );
    final pages = <List<ApPaymentModel>>[];
    for (var i = 0; i < payments.length; i += rowsPerPage) {
      pages.add(
        payments.sublist(
          i,
          (i + rowsPerPage) > payments.length
              ? payments.length
              : i + rowsPerPage,
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
                ttf: ttf,
                ttfR: ttfR,
              ),
              pw.SizedBox(height: 8),
              if (pi == 0) ...[
                _buildSummaryRow(
                  count: payments.length,
                  cash: cash,
                  transfer: transfer,
                  cheque: cheque,
                  totalAmt: totalAmt,
                  ttf: ttf,
                  ttfR: ttfR,
                ),
                pw.SizedBox(height: 8),
              ],
              _buildTableHeader(ttf: ttf),
              ...pages[pi].asMap().entries.map(
                (e) => _buildRow(e.value, e.key.isEven, ttfR: ttfR),
              ),
              pw.Spacer(),
              if (pi == totalPages - 1)
                _buildTotalsRow(totalAmt: totalAmt, ttf: ttf),
            ],
          ),
        ),
      );
    }

    return doc;
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  static pw.Widget _buildHeader({
    required String companyName,
    required String printedAt,
    required int page,
    required int totalPages,
    required pw.Font ttf,
    required pw.Font ttfR,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: pw.BoxDecoration(
        color: _kTeal,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  companyName,
                  style: pw.TextStyle(
                    font: ttf,
                    fontSize: 10,
                    color: _kWhite70,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'รายงานการจ่ายเงิน',
                  style: pw.TextStyle(
                    font: ttf,
                    fontSize: 15,
                    color: PdfColors.white,
                  ),
                ),
              ],
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'พิมพ์: $printedAt',
                style: pw.TextStyle(font: ttfR, fontSize: 9, color: _kWhite70),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'หน้า $page/$totalPages',
                style: pw.TextStyle(font: ttfR, fontSize: 9, color: _kWhite70),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Summary Row ────────────────────────────────────────────────────────────
  static pw.Widget _buildSummaryRow({
    required int count,
    required int cash,
    required int transfer,
    required int cheque,
    required double totalAmt,
    required pw.Font ttf,
    required pw.Font ttfR,
  }) {
    chip(String label, int n, PdfColor fg, PdfColor bg, PdfColor br) =>
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: pw.BoxDecoration(
            color: bg,
            borderRadius: pw.BorderRadius.circular(4),
            border: pw.Border.all(color: br, width: 0.5),
          ),
          child: pw.Text(
            '$label: $n',
            style: pw.TextStyle(font: ttf, fontSize: 9, color: fg),
          ),
        );

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: pw.BoxDecoration(
        color: _kAltRow,
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: _kBorder, width: 0.5),
      ),
      child: pw.Row(
        children: [
          chip('ทั้งหมด', count, _kTeal, _kTealLight, _kTealBorder),
          pw.SizedBox(width: 6),
          chip(
            'เงินสด',
            cash,
            _kCash,
            _kCashBg,
            const PdfColor.fromInt(0xFFA5D6A7),
          ),
          pw.SizedBox(width: 6),
          chip(
            'โอนเงิน',
            transfer,
            _kTransfer,
            _kTransferBg,
            const PdfColor.fromInt(0xFF90CAF9),
          ),
          pw.SizedBox(width: 6),
          chip(
            'เช็ค',
            cheque,
            _kCheque,
            _kChequeBg,
            const PdfColor.fromInt(0xFFFFCC80),
          ),
          pw.Spacer(),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'ยอดจ่ายรวม',
                style: pw.TextStyle(font: ttfR, fontSize: 9, color: _kSub),
              ),
              pw.Text(
                '฿${NumberFormat('#,##0.00').format(totalAmt)}',
                style: pw.TextStyle(font: ttf, fontSize: 12, color: _kTeal),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Table Header ───────────────────────────────────────────────────────────
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
            child: pw.Text(
              '#',
              style: pw.TextStyle(font: ttf, fontSize: 9),
              textAlign: pw.TextAlign.center,
            ),
          ),
          cell('เลขที่ใบจ่ายเงิน', flex: 3),
          cell('ซัพพลายเออร์', flex: 3),
          cell('วันที่', flex: 2),
          cell('วิธีจ่าย', flex: 2),
          cell('ยอดจ่าย', flex: 2, align: pw.TextAlign.right),
        ],
      ),
    );
  }

  // ── Data Row ───────────────────────────────────────────────────────────────
  static PdfColor _methodBg(String m) {
    switch (m) {
      case 'CASH':
        return _kCashBg;
      case 'TRANSFER':
        return _kTransferBg;
      case 'CHEQUE':
        return _kChequeBg;
      default:
        return _kTealLight;
    }
  }

  static pw.Widget _buildRow(
    ApPaymentModel p,
    bool isEven, {
    required pw.Font ttfR,
  }) {
    rcell(
      String t, {
      pw.TextAlign align = pw.TextAlign.left,
      int flex = 1,
      PdfColor? color,
    }) => pw.Expanded(
      flex: flex,
      child: pw.Text(
        t,
        style: pw.TextStyle(font: ttfR, fontSize: 8.5, color: color ?? _kText),
        textAlign: align,
        overflow: pw.TextOverflow.clip,
      ),
    );

    final methodColor = _methodColor(p.paymentMethod);
    final methodLabel = _methodLabel(p.paymentMethod);
    final methodBg = _methodBg(p.paymentMethod);

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: pw.BoxDecoration(
        color: isEven ? _kAltRow : PdfColors.white,
        border: const pw.Border(
          bottom: pw.BorderSide(color: _kBorder, width: 0.3),
        ),
      ),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 22,
            child: pw.Text(
              '${p.paymentNo.hashCode % 9999}',
              style: pw.TextStyle(font: ttfR, fontSize: 8, color: _kSub),
              textAlign: pw.TextAlign.center,
            ),
          ),
          rcell(p.paymentNo, flex: 3),
          rcell(p.supplierName, flex: 3, color: _kSub),
          rcell(_date.format(p.paymentDate), flex: 2, color: _kSub),
          pw.Expanded(
            flex: 2,
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 5,
                vertical: 2,
              ),
              decoration: pw.BoxDecoration(
                color: methodBg,
                borderRadius: pw.BorderRadius.circular(3),
              ),
              child: pw.Text(
                methodLabel,
                style: pw.TextStyle(
                  font: ttfR,
                  fontSize: 8,
                  color: methodColor,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ),
          ),
          pw.Expanded(
            flex: 2,
            child: pw.Text(
              '฿${_money.format(p.totalAmount)}',
              style: pw.TextStyle(font: ttfR, fontSize: 8.5, color: _kTeal),
              textAlign: pw.TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  // ── Totals Row ─────────────────────────────────────────────────────────────
  static pw.Widget _buildTotalsRow({
    required double totalAmt,
    required pw.Font ttf,
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 4),
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: pw.BoxDecoration(
        color: _kTealLight,
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: _kTealBorder, width: 0.5),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
          pw.Text(
            'ยอดจ่ายรวมทั้งหมด  ',
            style: pw.TextStyle(font: ttf, fontSize: 10, color: _kSub),
          ),
          pw.Text(
            '฿${NumberFormat('#,##0.00').format(totalAmt)}',
            style: pw.TextStyle(font: ttf, fontSize: 13, color: _kTeal),
          ),
        ],
      ),
    );
  }
}
