// customer_purchase_summary_pdf.dart
// PDF builder สำหรับรายงานสรุปยอดซื้อลูกค้า

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../settings/shared/settings_defaults.dart';
import 'customer_purchase_summary_page.dart';

const _kBorder = PdfColor.fromInt(0xFFCCCCCC);
const _kHeaderBg = PdfColor.fromInt(0xFF1565C0);
const _kHeaderFg = PdfColors.white;
const _kAltBg = PdfColor.fromInt(0xFFF3F6FF);
const _kText = PdfColors.black;
const _kSub = PdfColor.fromInt(0xFF555555);
const _kGreen = PdfColor.fromInt(0xFF2E7D32);
const _kOrange = PdfColor.fromInt(0xFFE65100);

class CustomerPurchaseSummaryPdfBuilder {
  static final _money = NumberFormat('#,##0.00', 'th_TH');
  static final _int = NumberFormat('#,##0', 'th_TH');
  static final _date = DateFormat('dd/MM/yyyy', 'th_TH');
  static final _dateTime = DateFormat('dd/MM/yyyy HH:mm', 'th_TH');

  static Future<pw.Document> build({
    required List<CustomerPurchaseSummaryRow> rows,
    required String periodLabel,
    String? companyName,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final effectiveCompany =
        companyName?.isNotEmpty == true
            ? companyName!
            : await SettingsStorage.getCompanyName();

    final ttf = await PdfGoogleFonts.notoSansThaiBold();
    final regular = await PdfGoogleFonts.notoSansThaiRegular();
    final printedAt = _dateTime.format(DateTime.now());

    final totalPaid = rows.fold<double>(0, (s, r) => s + r.paidAmount);
    final totalCredit = rows.fold<double>(0, (s, r) => s + r.creditAmount);
    final totalOrders = rows.fold<int>(0, (s, r) => s + r.orderCount);
    final avgPerCustomer =
        rows.isEmpty ? 0.0 : totalPaid / rows.length;

    // แบ่งข้อมูลเป็น chunk หน้าละ 30 แถว
    const rowsPerPage = 30;
    final pages = <List<CustomerPurchaseSummaryRow>>[];
    for (var i = 0; i < rows.length; i += rowsPerPage) {
      pages.add(rows.sublist(
          i, i + rowsPerPage > rows.length ? rows.length : i + rowsPerPage));
    }
    if (pages.isEmpty) pages.add([]);

    final totalPages = pages.length;
    final doc = pw.Document(
      title: 'รายงานสรุปยอดซื้อลูกค้า',
      author: effectiveCompany,
    );

    for (var pageIdx = 0; pageIdx < totalPages; pageIdx++) {
      final pageRows = pages[pageIdx];
      final startNo = pageIdx * rowsPerPage + 1;

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (_) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // ── Header ────────────────────────────────────────
              _buildHeader(
                company: effectiveCompany,
                printedAt: printedAt,
                page: pageIdx + 1,
                totalPages: totalPages,
                periodLabel: periodLabel,
                ttf: ttf,
                regular: regular,
              ),
              pw.SizedBox(height: 10),

              // ── Summary grid (page 1 only) ─────────────────────
              if (pageIdx == 0) ...[
                _buildSummaryGrid(
                  customerCount: rows.length,
                  totalPaid: totalPaid,
                  totalCredit: totalCredit,
                  totalOrders: totalOrders,
                  avgPerCustomer: avgPerCustomer,
                  ttf: ttf,
                  regular: regular,
                ),
                pw.SizedBox(height: 12),
              ],

              // ── Table ──────────────────────────────────────────
              _buildTable(
                rows: pageRows,
                startNo: startNo,
                ttf: ttf,
                regular: regular,
              ),
            ],
          ),
        ),
      );
    }

    return doc;
  }

  // ── Header ────────────────────────────────────────────────────
  static pw.Widget _buildHeader({
    required String company,
    required String printedAt,
    required int page,
    required int totalPages,
    required String periodLabel,
    required pw.Font ttf,
    required pw.Font regular,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('พิมพ์เมื่อ $printedAt',
                style: pw.TextStyle(font: regular, fontSize: 8, color: _kSub)),
            pw.Text('หน้า $page / $totalPages',
                style: pw.TextStyle(font: regular, fontSize: 8, color: _kSub)),
          ],
        ),
        pw.SizedBox(height: 3),
        pw.Center(
          child: pw.Text(company,
              style: pw.TextStyle(font: regular, fontSize: 9, color: _kSub)),
        ),
        pw.SizedBox(height: 2),
        pw.Center(
          child: pw.Text('รายงานสรุปยอดซื้อลูกค้า',
              style: pw.TextStyle(font: ttf, fontSize: 14, color: _kText)),
        ),
        pw.SizedBox(height: 2),
        pw.Center(
          child: pw.Text('ช่วงเวลา: $periodLabel',
              style: pw.TextStyle(font: regular, fontSize: 9, color: _kSub)),
        ),
        pw.SizedBox(height: 6),
        pw.Container(height: 0.5, color: _kBorder),
      ],
    );
  }

  // ── Summary grid ─────────────────────────────────────────────
  static pw.Widget _buildSummaryGrid({
    required int customerCount,
    required double totalPaid,
    required double totalCredit,
    required int totalOrders,
    required double avgPerCustomer,
    required pw.Font ttf,
    required pw.Font regular,
  }) {
    final items = [
      ('จำนวนลูกค้า', '$customerCount ราย'),
      ('ออเดอร์รวม', _int.format(totalOrders)),
      ('รับชำระแล้ว', '฿${_money.format(totalPaid)}'),
      ('คงค้างเครดิต', '฿${_money.format(totalCredit)}'),
      ('เฉลี่ยรับชำระ/ลูกค้า', '฿${_money.format(avgPerCustomer)}'),
    ];

    return pw.Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        return pw.Container(
          width: 120,
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _kBorder),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(item.$1,
                  style:
                      pw.TextStyle(font: regular, fontSize: 8, color: _kSub)),
              pw.SizedBox(height: 3),
              pw.Text(item.$2,
                  style: pw.TextStyle(font: ttf, fontSize: 11, color: _kText)),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── Table ─────────────────────────────────────────────────────
  static pw.Widget _buildTable({
    required List<CustomerPurchaseSummaryRow> rows,
    required int startNo,
    required pw.Font ttf,
    required pw.Font regular,
  }) {
    if (rows.isEmpty) {
      return pw.Center(
        child: pw.Text('ไม่มีข้อมูล',
            style: pw.TextStyle(font: regular, fontSize: 10, color: _kSub)),
      );
    }

    // column widths (flex fractions out of 100)
    const colWidths = {
      0: pw.FlexColumnWidth(0.5),  // #
      1: pw.FlexColumnWidth(3.0),  // ชื่อลูกค้า
      2: pw.FlexColumnWidth(1.2),  // ออเดอร์
      3: pw.FlexColumnWidth(1.8),  // รับชำระแล้ว
      4: pw.FlexColumnWidth(1.8),  // คงค้าง
      5: pw.FlexColumnWidth(1.5),  // ซื้อล่าสุด
    };

    final headerRow = pw.TableRow(
      decoration: const pw.BoxDecoration(color: _kHeaderBg),
      children: [
        _hCell('#', ttf),
        _hCell('ชื่อลูกค้า', ttf),
        _hCell('ออเดอร์', ttf, align: pw.TextAlign.center),
        _hCell('รับชำระแล้ว (฿)', ttf, align: pw.TextAlign.right),
        _hCell('คงค้างเครดิต (฿)', ttf, align: pw.TextAlign.right),
        _hCell('ซื้อล่าสุด', ttf, align: pw.TextAlign.center),
      ],
    );

    final dataRows = rows.asMap().entries.map((entry) {
      final idx = entry.key;
      final r = entry.value;
      final isOdd = idx.isOdd;

      return pw.TableRow(
        decoration: pw.BoxDecoration(
          color: isOdd ? _kAltBg : PdfColors.white,
        ),
        children: [
          _dCell('${startNo + idx}', regular,
              align: pw.TextAlign.center, color: _kSub),
          _dCell(r.customerName, regular,
              fontWeight: pw.FontWeight.bold),
          _dCell('${r.orderCount}', regular,
              align: pw.TextAlign.center),
          _dCell('฿${_money.format(r.paidAmount)}', regular,
              align: pw.TextAlign.right, color: _kGreen,
              fontWeight: pw.FontWeight.bold),
          _dCell(
            r.creditAmount > 0 ? '฿${_money.format(r.creditAmount)}' : '-',
            regular,
            align: pw.TextAlign.right,
            color: r.creditAmount > 0 ? _kOrange : _kSub,
          ),
          _dCell(
            r.lastOrderDate != null ? _date.format(r.lastOrderDate!) : '-',
            regular,
            align: pw.TextAlign.center,
            color: _kSub,
          ),
        ],
      );
    }).toList();

    return pw.Table(
      columnWidths: colWidths,
      border: pw.TableBorder.all(color: _kBorder, width: 0.5),
      children: [headerRow, ...dataRows],
    );
  }

  static pw.Widget _hCell(String text, pw.Font ttf,
      {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(font: ttf, fontSize: 8, color: _kHeaderFg),
      ),
    );
  }

  static pw.Widget _dCell(
    String text,
    pw.Font font, {
    pw.TextAlign align = pw.TextAlign.left,
    PdfColor color = _kText,
    pw.FontWeight fontWeight = pw.FontWeight.normal,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          font: font,
          fontSize: 8,
          color: color,
          fontWeight: fontWeight,
        ),
      ),
    );
  }
}
