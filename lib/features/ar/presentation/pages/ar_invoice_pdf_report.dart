// lib/features/ar/presentation/pages/ar_invoice_pdf_report.dart
//
// ArInvoicePdfBuilder — สร้างรายงาน PDF ใบแจ้งหนี้ลูกหนี้ (AR)

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../settings/shared/settings_defaults.dart';
import '../../data/models/ar_invoice_model.dart';

const _kBorder = PdfColor.fromInt(0xFFBBBBBB);
const _kHdrBg = PdfColor.fromInt(0xFFDDDDDD);
const _kAltRow = PdfColor.fromInt(0xFFF5F5F5);
const _kText = PdfColors.black;
const _kSub = PdfColor.fromInt(0xFF555555);
const _kUnpaid = PdfColor.fromInt(0xFFB71C1C);
const _kPartial = PdfColor.fromInt(0xFFE65100);
const _kPaid = PdfColor.fromInt(0xFF1B5E20);
const _kNavy = PdfColor.fromInt(0xFF16213E);
const _kOverdue = PdfColor.fromInt(0xFFC62828);

class ArInvoicePdfBuilder {
  static final _money = NumberFormat('#,##0.00');
  static final _date = DateFormat('dd/MM/yy');

  static Future<pw.Document> build(
    List<ArInvoiceModel> invoices, {
    String? companyName,
  }) async {
    final effectiveCompanyName =
        companyName ?? await SettingsStorage.getCompanyName();
    final doc = pw.Document(
      title: 'รายงานใบแจ้งหนี้ลูกหนี้',
      author: effectiveCompanyName,
    );
    final ttf = await PdfGoogleFonts.notoSansThaiBold();
    final ttfR = await PdfGoogleFonts.notoSansThaiRegular();
    final printedAt = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    final totalAmt = invoices.fold<double>(0, (s, i) => s + i.totalAmount);
    final remainingAmt = invoices.fold<double>(
      0,
      (s, i) => s + i.remainingAmount,
    );
    final paid = invoices.where((i) => i.status == 'PAID').length;
    final partial = invoices.where((i) => i.status == 'PARTIAL').length;
    final unpaid = invoices.where((i) => i.status == 'UNPAID').length;
    final overdue = invoices.where((i) => i.isOverdue).length;
    final summaryLine =
        'ทั้งหมด ${invoices.length} ใบ   '
        'ยังไม่รับ $unpaid ใบ   '
        'รับบางส่วน $partial ใบ   '
        'รับแล้ว $paid ใบ'
        '${overdue > 0 ? '   เลยกำหนด $overdue ใบ' : ''}';
    final summaryRow = _buildSummaryRow(
      count: invoices.length,
      unpaid: unpaid,
      partial: partial,
      remainingAmt: remainingAmt,
      ttf: ttf,
      ttfR: ttfR,
    );

    final rowsPerPage = await SettingsStorage.getPdfReportRowsPerPage(
      PdfReportType.arInvoice,
    );
    final pages = <List<ArInvoiceModel>>[];
    for (var i = 0; i < invoices.length; i += rowsPerPage) {
      pages.add(
        invoices.sublist(
          i,
          (i + rowsPerPage) > invoices.length ? invoices.length : i + rowsPerPage,
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
                _buildTotalsRow(
                  totalAmt: totalAmt,
                  remainingAmt: remainingAmt,
                  ttf: ttf,
                ),
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
          'รายงานใบแจ้งหนี้ลูกหนี้',
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
    required int unpaid,
    required int partial,
    required double remainingAmt,
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
          cell('จำนวนใบแจ้งหนี้', '$count ใบ', _kNavy),
          pw.Container(width: 0.5, height: 28, color: _kBorder),
          cell('ยังไม่รับ', '$unpaid ใบ', _kUnpaid),
          pw.Container(width: 0.5, height: 28, color: _kBorder),
          cell('รับบางส่วน', '$partial ใบ', _kPartial),
          pw.Container(width: 0.5, height: 28, color: _kBorder),
          cell('คงค้างรวม', '฿${_money.format(remainingAmt)}', _kUnpaid),
        ],
      ),
    );
  }

  static pw.Widget _buildTableHeader({required pw.Font ttf}) => pw.Container(
    color: _kHdrBg,
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
    child: pw.Row(
      children: [
        pw.SizedBox(width: 28, child: _hcell('#', ttf)),
        pw.Expanded(flex: 3, child: _hcell('เลขที่ใบแจ้งหนี้', ttf)),
        pw.Expanded(flex: 3, child: _hcell('ลูกค้า', ttf)),
        pw.SizedBox(width: 60, child: _hcell('วันที่', ttf, right: true)),
        pw.SizedBox(width: 60, child: _hcell('ครบกำหนด', ttf, right: true)),
        pw.SizedBox(width: 52, child: _hcell('สถานะ', ttf, center: true)),
        pw.SizedBox(width: 72, child: _hcell('ยอดรวม', ttf, right: true)),
        pw.SizedBox(width: 72, child: _hcell('คงค้าง', ttf, right: true)),
      ],
    ),
  );

  static pw.Widget _hcell(
    String t,
    pw.Font ttf, {
    bool right = false,
    bool center = false,
  }) => pw.Text(
    t,
    style: pw.TextStyle(font: ttf, fontSize: 8.5, color: _kSub),
    textAlign: right
        ? pw.TextAlign.right
        : center
        ? pw.TextAlign.center
        : pw.TextAlign.left,
  );

  static pw.Widget _buildRow(
    ArInvoiceModel inv,
    bool alt, {
    required pw.Font ttfR,
  }) {
    final statusColor = inv.status == 'PAID'
        ? _kPaid
        : inv.status == 'PARTIAL'
        ? _kPartial
        : _kUnpaid;
    final statusLabel = inv.status == 'PAID'
        ? 'รับแล้ว'
        : inv.status == 'PARTIAL'
        ? 'บางส่วน'
        : 'ยังไม่รับ';

    final receipts = inv.receipts;
    final hasReceipts = receipts != null && receipts.isNotEmpty;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(
          color: alt ? _kAltRow : PdfColors.white,
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.SizedBox(
                width: 28,
                child: pw.Text('', style: pw.TextStyle(font: ttfR, fontSize: 8)),
              ),
              pw.Expanded(
                flex: 3,
                child: pw.Row(
                  children: [
                    if (inv.isOverdue)
                      pw.Container(
                        width: 4,
                        height: 4,
                        decoration: const pw.BoxDecoration(
                          color: _kOverdue,
                          shape: pw.BoxShape.circle,
                        ),
                        margin: const pw.EdgeInsets.only(right: 3),
                      ),
                    pw.Expanded(
                      child: pw.Text(
                        inv.invoiceNo,
                        style: pw.TextStyle(font: ttfR, fontSize: 8.5, color: _kText),
                        overflow: pw.TextOverflow.clip,
                      ),
                    ),
                  ],
                ),
              ),
              pw.Expanded(
                flex: 3,
                child: pw.Text(
                  inv.customerName,
                  style: pw.TextStyle(font: ttfR, fontSize: 8, color: _kSub),
                  overflow: pw.TextOverflow.clip,
                ),
              ),
              pw.SizedBox(
                width: 60,
                child: pw.Text(
                  _date.format(inv.invoiceDate),
                  style: pw.TextStyle(font: ttfR, fontSize: 8, color: _kSub),
                  textAlign: pw.TextAlign.right,
                ),
              ),
              pw.SizedBox(
                width: 60,
                child: pw.Text(
                  inv.dueDate != null ? _date.format(inv.dueDate!) : '-',
                  style: pw.TextStyle(
                    font: ttfR,
                    fontSize: 8,
                    color: inv.isOverdue ? _kOverdue : _kSub,
                  ),
                  textAlign: pw.TextAlign.right,
                ),
              ),
              pw.SizedBox(
                width: 52,
                child: pw.Center(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: pw.BoxDecoration(
                      color: PdfColor(
                        statusColor.red,
                        statusColor.green,
                        statusColor.blue,
                        0.12,
                      ),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Text(
                      statusLabel,
                      style: pw.TextStyle(font: ttfR, fontSize: 7.5, color: statusColor),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                ),
              ),
              pw.SizedBox(
                width: 72,
                child: pw.Text(
                  '฿${_money.format(inv.totalAmount)}',
                  style: pw.TextStyle(font: ttfR, fontSize: 8.5, color: _kText),
                  textAlign: pw.TextAlign.right,
                ),
              ),
              pw.SizedBox(
                width: 72,
                child: pw.Text(
                  '฿${_money.format(inv.remainingAmount)}',
                  style: pw.TextStyle(
                    font: ttfR,
                    fontSize: 8.5,
                    color: inv.remainingAmount > 0 ? _kUnpaid : _kSub,
                  ),
                  textAlign: pw.TextAlign.right,
                ),
              ),
            ],
          ),
        ),
        if (hasReceipts)
          _buildReceiptDetail(receipts, alt: alt, ttfR: ttfR),
      ],
    );
  }

  static pw.Widget _buildReceiptDetail(
    List<ArInvoiceReceiptModel> receipts, {
    required bool alt,
    required pw.Font ttfR,
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(left: 34, right: 0),
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: pw.BoxDecoration(
        color: alt ? _kAltRow : PdfColors.white,
        border: const pw.Border(
          left: pw.BorderSide(color: _kPaid, width: 2),
          bottom: pw.BorderSide(color: _kBorder, width: 0.3),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Text(
            'ประวัติการรับเงิน',
            style: pw.TextStyle(font: ttfR, fontSize: 7.5, color: _kPaid),
          ),
          pw.SizedBox(height: 2),
          ...receipts.map(
            (r) => pw.Padding(
              padding: const pw.EdgeInsets.only(top: 1),
              child: pw.Row(
                children: [
                  pw.Expanded(
                    flex: 3,
                    child: pw.Text(
                      '• ${r.receiptNo}',
                      style: pw.TextStyle(font: ttfR, fontSize: 7.5, color: _kSub),
                    ),
                  ),
                  pw.Text(
                    _date.format(r.receiptDate),
                    style: pw.TextStyle(font: ttfR, fontSize: 7.5, color: _kSub),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Text(
                    '฿${_money.format(r.allocatedAmount)}',
                    style: pw.TextStyle(font: ttfR, fontSize: 7.5, color: _kPaid),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildTotalsRow({
    required double totalAmt,
    required double remainingAmt,
    required pw.Font ttf,
  }) => pw.Container(
    color: _kHdrBg,
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
    child: pw.Row(
      children: [
        pw.Expanded(flex: 6, child: pw.SizedBox()),
        pw.SizedBox(width: 60, child: pw.SizedBox()),
        pw.SizedBox(width: 60, child: pw.SizedBox()),
        pw.SizedBox(width: 52, child: pw.SizedBox()),
        pw.SizedBox(
          width: 72,
          child: pw.Text(
            '฿${_money.format(totalAmt)}',
            style: pw.TextStyle(font: ttf, fontSize: 9, color: _kNavy),
            textAlign: pw.TextAlign.right,
          ),
        ),
        pw.SizedBox(
          width: 72,
          child: pw.Text(
            '฿${_money.format(remainingAmt)}',
            style: pw.TextStyle(font: ttf, fontSize: 9, color: _kUnpaid),
            textAlign: pw.TextAlign.right,
          ),
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
