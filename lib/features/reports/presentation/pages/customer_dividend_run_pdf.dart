// customer_dividend_run_pdf.dart
// PDF builder สำหรับรายละเอียดงวดปันผลลูกค้า

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../settings/shared/settings_defaults.dart';

const _kBorder = PdfColor.fromInt(0xFFCCCCCC);
const _kHeaderBg = PdfColor.fromInt(0xFF00695C);
const _kAltBg = PdfColor.fromInt(0xFFF4FBFA);
const _kText = PdfColors.black;
const _kSub = PdfColor.fromInt(0xFF555555);

String _runStatusLabel(String status) {
  return switch (status.toUpperCase()) {
    'DRAFT' => 'ร่าง',
    'PARTIAL' => 'จ่ายบางส่วน',
    'PAID' => 'จ่ายครบแล้ว',
    'CANCELLED' => 'ยกเลิก',
    _ => status,
  };
}

class CustomerDividendRunPdfBuilder {
  static final _money = NumberFormat('#,##0.00', 'th_TH');
  static final _date = DateFormat('dd/MM/yyyy', 'th_TH');
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

    final ttf = await PdfGoogleFonts.notoSansThaiBold();
    final regular = await PdfGoogleFonts.notoSansThaiRegular();
    final printedAt = _dateTime.format(DateTime.now());

    final doc = pw.Document(
      title: 'งวดปันผลลูกค้า ${run['run_no'] ?? ''}',
      author: effectiveCompany,
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
        build: (_) => [
          _buildHeader(run, effectiveCompany, printedAt, ttf, regular),
          pw.SizedBox(height: 12),
          _buildSummary(run, items, ttf, regular),
          pw.SizedBox(height: 12),
          _buildTable(items, ttf, regular),
        ],
      ),
    );

    return doc;
  }

  static pw.Widget _buildHeader(
    Map<String, dynamic> run,
    String company,
    String printedAt,
    pw.Font ttf,
    pw.Font regular,
  ) {
    final start = run['period_start'] as String?;
    final end = run['period_end'] as String?;
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
            pw.Text(
              'พิมพ์เมื่อ $printedAt',
              style: pw.TextStyle(font: regular, fontSize: 8, color: _kSub),
            ),
            pw.Text(
              '${run['run_no'] ?? '-'}',
              style: pw.TextStyle(font: ttf, fontSize: 12, color: _kText),
            ),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Center(
          child: pw.Text(
            company,
            style: pw.TextStyle(font: regular, fontSize: 9, color: _kSub),
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Center(
          child: pw.Text(
            'รายละเอียดงวดปันผลลูกค้า',
            style: pw.TextStyle(font: ttf, fontSize: 14, color: _kText),
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Center(
          child: pw.Text(
            'ช่วงเวลา: $period',
            style: pw.TextStyle(font: regular, fontSize: 9, color: _kSub),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildSummary(
    Map<String, dynamic> run,
    List<Map<String, dynamic>> items,
    pw.Font ttf,
    pw.Font regular,
  ) {
    final filteredBase = items.fold<double>(
      0,
      (sum, item) => sum + ((item['paid_amount'] as num?)?.toDouble() ?? 0),
    );
    final filteredDividend = items.fold<double>(
      0,
      (sum, item) =>
          sum + ((item['dividend_amount'] as num?)?.toDouble() ?? 0),
    );
    final filteredActualPaid = items.fold<double>(
      0,
      (sum, item) =>
          sum + ((item['paid_amount_actual'] as num?)?.toDouble() ?? 0),
    );
    final paidCount = items.where((item) {
      final status = (item['payment_status'] as String? ?? '').toUpperCase();
      return status == 'PAID';
    }).length;
    final pendingCount = items.where((item) {
      final status =
          (item['payment_status'] as String? ?? 'PENDING').toUpperCase();
      return status == 'PENDING';
    }).length;
    final skippedCount = items.where((item) {
      final status = (item['payment_status'] as String? ?? '').toUpperCase();
      return status == 'SKIPPED';
    }).length;

    final summaryItems = [
      ('สถานะ', _runStatusLabel('${run['status'] ?? '-'}')),
      ('อัตราปันผล', '${_money.format((run['dividend_percent'] ?? 0) as num)}%'),
      ('รายการที่แสดง', '${items.length}'),
      ('ฐานคำนวณ', '฿${_money.format(filteredBase)}'),
      ('ยอดปันผลรวม', '฿${_money.format(filteredDividend)}'),
      ('ยอดจ่ายจริงรวม', '฿${_money.format(filteredActualPaid)}'),
      ('จ่ายแล้ว', '$paidCount'),
      ('ค้างจ่าย', '$pendingCount'),
      ('ข้ามจ่าย', '$skippedCount'),
    ];

    return pw.Wrap(
      spacing: 8,
      runSpacing: 8,
      children: summaryItems.map((item) {
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
              pw.Text(
                item.$1,
                style: pw.TextStyle(font: regular, fontSize: 8, color: _kSub),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                item.$2,
                style: pw.TextStyle(font: ttf, fontSize: 10, color: _kText),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  static pw.Widget _buildTable(
    List<Map<String, dynamic>> items,
    pw.Font ttf,
    pw.Font regular,
  ) {
    final header = pw.TableRow(
      decoration: const pw.BoxDecoration(color: _kHeaderBg),
      children: [
        _hCell('#', ttf),
        _hCell('ลูกค้า', ttf),
        _hCell('ยอดรับชำระ', ttf, align: pw.TextAlign.right),
        _hCell('ยอดปันผล', ttf, align: pw.TextAlign.right),
        _hCell('สถานะจ่าย', ttf, align: pw.TextAlign.center),
        _hCell('จ่ายจริง', ttf, align: pw.TextAlign.right),
      ],
    );

    final rows = items.asMap().entries.map((entry) {
      final item = entry.value;
      return pw.TableRow(
        decoration: pw.BoxDecoration(
          color: entry.key.isOdd ? _kAltBg : PdfColors.white,
        ),
        children: [
          _dCell('${entry.key + 1}', regular, align: pw.TextAlign.center),
          _dCell('${item['customer_name'] ?? '-'}', regular),
          _dCell(
            '฿${_money.format((item['paid_amount'] ?? 0) as num)}',
            regular,
            align: pw.TextAlign.right,
          ),
          _dCell(
            '฿${_money.format((item['dividend_amount'] ?? 0) as num)}',
            regular,
            align: pw.TextAlign.right,
          ),
          _dCell(
            '${item['payment_status'] ?? '-'}',
            regular,
            align: pw.TextAlign.center,
          ),
          _dCell(
            '฿${_money.format((item['paid_amount_actual'] ?? 0) as num)}',
            regular,
            align: pw.TextAlign.right,
          ),
        ],
      );
    }).toList();

    return pw.Table(
      border: pw.TableBorder.all(color: _kBorder, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(0.5),
        1: pw.FlexColumnWidth(2.8),
        2: pw.FlexColumnWidth(1.5),
        3: pw.FlexColumnWidth(1.5),
        4: pw.FlexColumnWidth(1.2),
        5: pw.FlexColumnWidth(1.5),
      },
      children: [header, ...rows],
    );
  }

  static pw.Widget _hCell(
    String text,
    pw.Font ttf, {
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(font: ttf, fontSize: 9, color: PdfColors.white),
      ),
    );
  }

  static pw.Widget _dCell(
    String text,
    pw.Font regular, {
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(font: regular, fontSize: 9, color: _kText),
      ),
    );
  }
}
