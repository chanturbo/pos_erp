// customer_dividend_run_pdf.dart
// PDF builder สำหรับรายละเอียดงวดปันผลลูกค้า

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../settings/shared/settings_defaults.dart';

const _kBorder   = PdfColor.fromInt(0xFFCCCCCC);
const _kHeaderBg = PdfColor.fromInt(0xFF1565C0);
const _kHeaderFg = PdfColors.white;
const _kAltBg    = PdfColor.fromInt(0xFFF3F6FF);
const _kText     = PdfColors.black;
const _kSub      = PdfColor.fromInt(0xFF555555);
const _kGreen    = PdfColor.fromInt(0xFF2E7D32);
const _kOrange   = PdfColor.fromInt(0xFFE65100);

String _runStatusLabel(String status) {
  return switch (status.toUpperCase()) {
    'DRAFT'     => 'ร่าง',
    'PARTIAL'   => 'จ่ายบางส่วน',
    'PAID'      => 'จ่ายครบแล้ว',
    'CANCELLED' => 'ยกเลิก',
    _           => status,
  };
}

class CustomerDividendRunPdfBuilder {
  static final _money    = NumberFormat('#,##0.00', 'th_TH');
  static final _date     = DateFormat('dd/MM/yyyy', 'th_TH');
  static final _dateTime = DateFormat('dd/MM/yyyy HH:mm', 'th_TH');

  static Future<pw.Document> build({
    required Map<String, dynamic> run,
    required List<Map<String, dynamic>> items,
    String? companyName,
  }) async {
    final effectiveCompany =
        companyName?.isNotEmpty == true
            ? companyName!
            : await SettingsStorage.getCompanyName();

    final ttf     = await PdfGoogleFonts.notoSansThaiBold();
    final regular = await PdfGoogleFonts.notoSansThaiRegular();
    final printedAt = _dateTime.format(DateTime.now());

    const rowsPerPage = 28;
    final chunks = <List<Map<String, dynamic>>>[];
    for (var i = 0; i < items.length; i += rowsPerPage) {
      chunks.add(items.sublist(
          i, i + rowsPerPage > items.length ? items.length : i + rowsPerPage));
    }
    if (chunks.isEmpty) chunks.add([]);

    final totalPages = chunks.length;
    final doc = pw.Document(
      title: 'งวดปันผลลูกค้า ${run['run_no'] ?? ''}',
      author: effectiveCompany,
    );

    for (var pageIdx = 0; pageIdx < totalPages; pageIdx++) {
      final pageItems = chunks[pageIdx];
      final startNo  = pageIdx * rowsPerPage + 1;

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (_) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _buildHeader(
                run: run,
                company: effectiveCompany,
                printedAt: printedAt,
                page: pageIdx + 1,
                totalPages: totalPages,
                ttf: ttf,
                regular: regular,
              ),
              pw.SizedBox(height: 10),
              if (pageIdx == 0) ...[
                _buildSummary(run, items, ttf, regular),
                pw.SizedBox(height: 12),
              ],
              _buildTable(pageItems, startNo, ttf, regular),
            ],
          ),
        ),
      );
    }

    return doc;
  }

  // ── Header ──────────────────────────────────────────────────────
  static pw.Widget _buildHeader({
    required Map<String, dynamic> run,
    required String company,
    required String printedAt,
    required int page,
    required int totalPages,
    required pw.Font ttf,
    required pw.Font regular,
  }) {
    final start  = run['period_start'] as String?;
    final end    = run['period_end']   as String?;
    final period = start == null && end == null
        ? 'ทุกช่วงเวลา'
        : '${start == null ? '?' : _date.format(DateTime.parse(start))}'
          ' - ${end == null ? '?' : _date.format(DateTime.parse(end))}';

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
          child: pw.Text('รายละเอียดงวดปันผลลูกค้า',
              style: pw.TextStyle(font: ttf, fontSize: 14, color: _kText)),
        ),
        pw.SizedBox(height: 2),
        pw.Center(
          child: pw.Text(
            'งวด: ${run['run_no'] ?? '-'}  |  ช่วงเวลา: $period',
            style: pw.TextStyle(font: regular, fontSize: 9, color: _kSub),
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Container(height: 0.5, color: _kBorder),
      ],
    );
  }

  // ── Summary cards ───────────────────────────────────────────────
  static pw.Widget _buildSummary(
    Map<String, dynamic> run,
    List<Map<String, dynamic>> items,
    pw.Font ttf,
    pw.Font regular,
  ) {
    final filteredBase = items.fold<double>(
        0, (s, i) => s + ((i['paid_amount'] as num?)?.toDouble() ?? 0));
    final filteredDividend = items.fold<double>(
        0, (s, i) => s + ((i['dividend_amount'] as num?)?.toDouble() ?? 0));
    final filteredActualPaid = items.fold<double>(
        0, (s, i) => s + ((i['paid_amount_actual'] as num?)?.toDouble() ?? 0));
    final paidCount = items
        .where((i) => (i['payment_status'] as String? ?? '').toUpperCase() == 'PAID')
        .length;
    final pendingCount = items
        .where((i) =>
            (i['payment_status'] as String? ?? 'PENDING').toUpperCase() == 'PENDING')
        .length;
    final skippedCount = items
        .where((i) => (i['payment_status'] as String? ?? '').toUpperCase() == 'SKIPPED')
        .length;

    final summaryItems = [
      ('สถานะ',        _runStatusLabel('${run['status'] ?? '-'}')),
      ('อัตราปันผล',   '${_money.format((run['dividend_percent'] ?? 0) as num)}%'),
      ('รายการ',       '${items.length}'),
      ('ฐานคำนวณ',    '฿${_money.format(filteredBase)}'),
      ('ยอดปันผลรวม',  '฿${_money.format(filteredDividend)}'),
      ('จ่ายจริงรวม',  '฿${_money.format(filteredActualPaid)}'),
      ('จ่ายแล้ว',     '$paidCount'),
      ('ค้างจ่าย',     '$pendingCount'),
      ('ข้ามจ่าย',     '$skippedCount'),
    ];

    return pw.Wrap(
      spacing: 8,
      runSpacing: 8,
      children: summaryItems.map((item) {
        return pw.Container(
          width: 110,
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _kBorder),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(item.$1,
                  style: pw.TextStyle(font: regular, fontSize: 8, color: _kSub)),
              pw.SizedBox(height: 3),
              pw.Text(item.$2,
                  style: pw.TextStyle(font: ttf, fontSize: 10, color: _kText)),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── Table ────────────────────────────────────────────────────────
  static pw.Widget _buildTable(
    List<Map<String, dynamic>> items,
    int startNo,
    pw.Font ttf,
    pw.Font regular,
  ) {
    if (items.isEmpty) {
      return pw.Center(
        child: pw.Text('ไม่มีข้อมูล',
            style: pw.TextStyle(font: regular, fontSize: 10, color: _kSub)),
      );
    }

    final header = pw.TableRow(
      decoration: const pw.BoxDecoration(color: _kHeaderBg),
      children: [
        _hCell('#', ttf),
        _hCell('ลูกค้า', ttf),
        _hCell('ยอดรับชำระ', ttf, align: pw.TextAlign.right),
        _hCell('ยอดปันผล',   ttf, align: pw.TextAlign.right),
        _hCell('สถานะจ่าย',  ttf, align: pw.TextAlign.center),
        _hCell('จ่ายจริง',   ttf, align: pw.TextAlign.right),
      ],
    );

    final rows = items.asMap().entries.map((entry) {
      final idx    = entry.key;
      final item   = entry.value;
      final status = (item['payment_status'] as String? ?? '').toUpperCase();
      final statusColor = status == 'PAID'    ? _kGreen
                        : status == 'PENDING' ? _kOrange
                        : _kSub;

      return pw.TableRow(
        decoration: pw.BoxDecoration(
          color: idx.isOdd ? _kAltBg : PdfColors.white,
        ),
        children: [
          _dCell('${startNo + idx}', regular,
              align: pw.TextAlign.center, color: _kSub),
          _dCell('${item['customer_name'] ?? '-'}', regular,
              fontWeight: pw.FontWeight.bold),
          _dCell('฿${_money.format((item['paid_amount'] ?? 0) as num)}', regular,
              align: pw.TextAlign.right),
          _dCell('฿${_money.format((item['dividend_amount'] ?? 0) as num)}', regular,
              align: pw.TextAlign.right,
              color: _kGreen,
              fontWeight: pw.FontWeight.bold),
          _dCell(_translateStatus('${item['payment_status'] ?? ''}'), regular,
              align: pw.TextAlign.center,
              color: statusColor,
              fontWeight: pw.FontWeight.bold),
          _dCell('฿${_money.format((item['paid_amount_actual'] ?? 0) as num)}', regular,
              align: pw.TextAlign.right),
        ],
      );
    }).toList();

    return pw.Table(
      border: pw.TableBorder.all(color: _kBorder, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(0.4),  // #
        1: pw.FlexColumnWidth(2.6),  // ลูกค้า
        2: pw.FlexColumnWidth(1.5),  // ยอดรับชำระ
        3: pw.FlexColumnWidth(1.5),  // ยอดปันผล
        4: pw.FlexColumnWidth(1.2),  // สถานะจ่าย
        5: pw.FlexColumnWidth(1.5),  // จ่ายจริง
      },
      children: [header, ...rows],
    );
  }

  static String _translateStatus(String status) {
    return switch (status.toLowerCase()) {
      'paid'    => 'จ่ายแล้ว',
      'pending' => 'รอจ่าย',
      'skipped' => 'ข้าม',
      ''        => '-',
      _         => status,
    };
  }

  static pw.Widget _hCell(String text, pw.Font ttf,
      {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: pw.Text(text,
          textAlign: align,
          style: pw.TextStyle(font: ttf, fontSize: 8, color: _kHeaderFg)),
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
      child: pw.Text(text,
          textAlign: align,
          style: pw.TextStyle(
              font: font, fontSize: 8, color: color, fontWeight: fontWeight)),
    );
  }
}
