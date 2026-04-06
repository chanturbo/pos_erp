// lib/features/ap/presentation/pages/ap_invoice_pdf_report.dart
//
// ApInvoicePdfBuilder — สร้างรายงาน PDF ใบแจ้งหนี้ค้างชำระ (AP)

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../data/models/ap_invoice_model.dart';

const _kBorder    = PdfColor.fromInt(0xFFBBBBBB);
const _kHdrBg     = PdfColor.fromInt(0xFFDDDDDD);
const _kAltRow    = PdfColor.fromInt(0xFFF5F5F5);
const _kText      = PdfColors.black;
const _kSub       = PdfColor.fromInt(0xFF555555);
const _kUnpaid    = PdfColor.fromInt(0xFFB71C1C);
const _kPartial   = PdfColor.fromInt(0xFFE65100);
const _kPaid      = PdfColor.fromInt(0xFF1B5E20);
const _kNavy      = PdfColor.fromInt(0xFF16213E);
const _kOverdue   = PdfColor.fromInt(0xFFC62828);

class ApInvoicePdfBuilder {
  static final _money = NumberFormat('#,##0.00');
  static final _date  = DateFormat('dd/MM/yy');

  static Future<pw.Document> build(
    List<ApInvoiceModel> invoices, {
    String companyName = 'DEE POS',
  }) async {
    final doc      = pw.Document(title: 'รายงานใบแจ้งหนี้ค้างชำระ', author: companyName);
    final ttf      = await PdfGoogleFonts.notoSansThaiBold();
    final ttfR     = await PdfGoogleFonts.notoSansThaiRegular();
    final printedAt = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    final totalAmt     = invoices.fold<double>(0, (s, i) => s + i.totalAmount);
    final paidAmt      = invoices.fold<double>(0, (s, i) => s + i.paidAmount);
    final remainingAmt = invoices.fold<double>(0, (s, i) => s + i.remainingAmount);
    final paid         = invoices.where((i) => i.status == 'PAID').length;
    final partial      = invoices.where((i) => i.status == 'PARTIAL').length;
    final unpaid       = invoices.where((i) => i.status == 'UNPAID').length;
    final overdue      = invoices.where((i) => i.isOverdue).length;

    final summaryRow = _buildSummaryRow(
      count: invoices.length,
      unpaid: unpaid, partial: partial, paid: paid, overdue: overdue,
      totalAmt: totalAmt, remainingAmt: remainingAmt,
      ttf: ttf, ttfR: ttfR,
    );

    const rowsPerPage = 32;
    final pages = <List<ApInvoiceModel>>[];
    for (var i = 0; i < invoices.length; i += rowsPerPage) {
      pages.add(invoices.sublist(
          i, (i + rowsPerPage) > invoices.length ? invoices.length : i + rowsPerPage));
    }
    if (pages.isEmpty) pages.add([]);
    final totalPages = pages.length;

    for (var pi = 0; pi < pages.length; pi++) {
      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            _buildHeader(companyName: companyName, printedAt: printedAt,
                page: pi + 1, totalPages: totalPages, ttf: ttf, ttfR: ttfR),
            pw.SizedBox(height: 8),
            if (pi == 0) ...[summaryRow, pw.SizedBox(height: 8)],
            _buildTableHeader(ttf: ttf),
            ...pages[pi].asMap().entries.map((e) =>
                _buildRow(e.value, e.key.isEven, ttfR: ttfR)),
            pw.Spacer(),
            if (pi == totalPages - 1)
              _buildTotalsRow(
                totalAmt: totalAmt, paidAmt: paidAmt, remainingAmt: remainingAmt,
                ttf: ttf,
              ),
          ],
        ),
      ));
    }

    return doc;
  }

  // ── Header ────────────────────────────────────────────────────
  static pw.Widget _buildHeader({
    required String companyName,
    required String printedAt,
    required int page,
    required int totalPages,
    required pw.Font ttf,
    required pw.Font ttfR,
  }) =>
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(companyName,
                style: pw.TextStyle(font: ttf, fontSize: 14, color: _kNavy)),
            pw.SizedBox(height: 2),
            pw.Text('รายงานใบแจ้งหนี้ค้างชำระ (AP)',
                style: pw.TextStyle(font: ttf, fontSize: 11, color: _kSub)),
          ]),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text('พิมพ์: $printedAt',
                style: pw.TextStyle(font: ttfR, fontSize: 9, color: _kSub)),
            pw.Text('หน้า $page/$totalPages',
                style: pw.TextStyle(font: ttfR, fontSize: 9, color: _kSub)),
          ]),
        ],
      );

  // ── Summary Row ───────────────────────────────────────────────
  static pw.Widget _buildSummaryRow({
    required int count,
    required int unpaid,
    required int partial,
    required int paid,
    required int overdue,
    required double totalAmt,
    required double remainingAmt,
    required pw.Font ttf,
    required pw.Font ttfR,
  }) =>
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: pw.BoxDecoration(
          color: _kAltRow,
          borderRadius: pw.BorderRadius.circular(4),
          border: pw.Border.all(color: _kBorder),
        ),
        child: pw.Wrap(
          spacing: 16,
          children: [
            _summaryChip('ทั้งหมด $count ใบ', ttf),
            _summaryChip('ยังไม่จ่าย $unpaid ใบ', ttf, color: _kUnpaid),
            _summaryChip('บางส่วน $partial ใบ', ttf, color: _kPartial),
            _summaryChip('จ่ายแล้ว $paid ใบ', ttf, color: _kPaid),
            if (overdue > 0) _summaryChip('เลยกำหนด $overdue ใบ', ttf, color: _kOverdue),
            _summaryChip('ยอดรวม ฿${_money.format(totalAmt)}', ttf),
            _summaryChip('ค้างชำระ ฿${_money.format(remainingAmt)}', ttf, color: _kUnpaid),
          ],
        ),
      );

  static pw.Widget _summaryChip(String text, pw.Font ttf,
          {PdfColor color = _kText}) =>
      pw.Text(text, style: pw.TextStyle(font: ttf, fontSize: 9, color: color));

  // ── Table header ──────────────────────────────────────────────
  static pw.Widget _buildTableHeader({required pw.Font ttf}) =>
      pw.Container(
        color: _kHdrBg,
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: pw.Row(children: [
          pw.SizedBox(width: 28, child: _hcell('#', ttf)),
          pw.Expanded(flex: 3, child: _hcell('เลขที่ใบแจ้งหนี้', ttf)),
          pw.Expanded(flex: 3, child: _hcell('ซัพพลายเออร์', ttf)),
          pw.SizedBox(width: 60, child: _hcell('วันที่', ttf, right: true)),
          pw.SizedBox(width: 60, child: _hcell('ครบกำหนด', ttf, right: true)),
          pw.SizedBox(width: 52, child: _hcell('สถานะ', ttf, center: true)),
          pw.SizedBox(width: 72, child: _hcell('ยอดรวม', ttf, right: true)),
          pw.SizedBox(width: 72, child: _hcell('ค้างชำระ', ttf, right: true)),
        ]),
      );

  static pw.Widget _hcell(String t, pw.Font ttf,
          {bool right = false, bool center = false}) =>
      pw.Text(t,
          style: pw.TextStyle(font: ttf, fontSize: 8.5, color: _kSub),
          textAlign: right
              ? pw.TextAlign.right
              : center
                  ? pw.TextAlign.center
                  : pw.TextAlign.left);

  // ── Data Row ──────────────────────────────────────────────────
  static pw.Widget _buildRow(ApInvoiceModel inv, bool alt,
      {required pw.Font ttfR}) {
    final statusColor = inv.status == 'PAID'
        ? _kPaid
        : inv.status == 'PARTIAL'
            ? _kPartial
            : _kUnpaid;
    final statusLabel = inv.status == 'PAID'
        ? 'จ่ายแล้ว'
        : inv.status == 'PARTIAL'
            ? 'บางส่วน'
            : 'ยังไม่จ่าย';

    return pw.Container(
      color: alt ? _kAltRow : PdfColors.white,
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
        pw.SizedBox(
          width: 28,
          child: pw.Text('',
              style: pw.TextStyle(font: ttfR, fontSize: 8)),
        ),
        pw.Expanded(
          flex: 3,
          child: pw.Row(children: [
            if (inv.isOverdue)
              pw.Container(
                width: 4, height: 4,
                decoration: const pw.BoxDecoration(
                    color: _kOverdue, shape: pw.BoxShape.circle),
                margin: const pw.EdgeInsets.only(right: 3),
              ),
            pw.Expanded(
              child: pw.Text(inv.invoiceNo,
                  style: pw.TextStyle(font: ttfR, fontSize: 8.5, color: _kText),
                  overflow: pw.TextOverflow.clip),
            ),
          ]),
        ),
        pw.Expanded(
          flex: 3,
          child: pw.Text(inv.supplierName,
              style: pw.TextStyle(font: ttfR, fontSize: 8, color: _kSub),
              overflow: pw.TextOverflow.clip),
        ),
        pw.SizedBox(
          width: 60,
          child: pw.Text(_date.format(inv.invoiceDate),
              style: pw.TextStyle(font: ttfR, fontSize: 8, color: _kSub),
              textAlign: pw.TextAlign.right),
        ),
        pw.SizedBox(
          width: 60,
          child: pw.Text(
              inv.dueDate != null ? _date.format(inv.dueDate!) : '-',
              style: pw.TextStyle(
                  font: ttfR,
                  fontSize: 8,
                  color: inv.isOverdue ? _kOverdue : _kSub),
              textAlign: pw.TextAlign.right),
        ),
        pw.SizedBox(
          width: 52,
          child: pw.Center(
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: pw.BoxDecoration(
                color: PdfColor(statusColor.red, statusColor.green,
                    statusColor.blue, 0.12),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Text(statusLabel,
                  style: pw.TextStyle(
                      font: ttfR, fontSize: 7.5, color: statusColor),
                  textAlign: pw.TextAlign.center),
            ),
          ),
        ),
        pw.SizedBox(
          width: 72,
          child: pw.Text('฿${_money.format(inv.totalAmount)}',
              style: pw.TextStyle(font: ttfR, fontSize: 8.5, color: _kText),
              textAlign: pw.TextAlign.right),
        ),
        pw.SizedBox(
          width: 72,
          child: pw.Text('฿${_money.format(inv.remainingAmount)}',
              style: pw.TextStyle(
                  font: ttfR,
                  fontSize: 8.5,
                  color: inv.remainingAmount > 0 ? _kUnpaid : _kSub),
              textAlign: pw.TextAlign.right),
        ),
      ]),
    );
  }

  // ── Totals row ────────────────────────────────────────────────
  static pw.Widget _buildTotalsRow({
    required double totalAmt,
    required double paidAmt,
    required double remainingAmt,
    required pw.Font ttf,
  }) =>
      pw.Container(
        color: _kHdrBg,
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: pw.Row(children: [
          pw.Expanded(flex: 6, child: pw.SizedBox()),
          pw.SizedBox(width: 60, child: pw.SizedBox()),
          pw.SizedBox(width: 60, child: pw.SizedBox()),
          pw.SizedBox(width: 52, child: pw.SizedBox()),
          pw.SizedBox(
            width: 72,
            child: pw.Text('฿${_money.format(totalAmt)}',
                style: pw.TextStyle(font: ttf, fontSize: 9, color: _kNavy),
                textAlign: pw.TextAlign.right),
          ),
          pw.SizedBox(
            width: 72,
            child: pw.Text('฿${_money.format(remainingAmt)}',
                style: pw.TextStyle(font: ttf, fontSize: 9, color: _kUnpaid),
                textAlign: pw.TextAlign.right),
          ),
        ]),
      );
}
