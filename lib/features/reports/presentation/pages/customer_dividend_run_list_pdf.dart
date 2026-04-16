import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../settings/shared/settings_defaults.dart';

const _kBorder = PdfColor.fromInt(0xFFCCCCCC);
const _kHeaderBg = PdfColor.fromInt(0xFF16213E);
const _kAltBg = PdfColor.fromInt(0xFFF7F9FC);
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

class CustomerDividendRunListPdfBuilder {
  static final _money = NumberFormat('#,##0.00', 'th_TH');
  static final _date = DateFormat('dd/MM/yyyy', 'th_TH');
  static final _dateTime = DateFormat('dd/MM/yyyy HH:mm', 'th_TH');

  static Future<pw.Document> build({
    required List<Map<String, dynamic>> runs,
    required String statusLabel,
    required String search,
    String? companyName,
  }) async {
    final effectiveCompany =
        companyName?.isNotEmpty == true
            ? companyName!
            : await SettingsStorage.getCompanyName();

    final ttf = await PdfGoogleFonts.notoSansThaiBold();
    final regular = await PdfGoogleFonts.notoSansThaiRegular();
    final printedAt = _dateTime.format(DateTime.now());

    final totalAmount = runs.fold<double>(
      0,
      (sum, run) =>
          sum + ((run['total_dividend_amount'] as num?)?.toDouble() ?? 0),
    );
    final paidCount = runs.where((run) {
      return (run['status'] as String? ?? '').toUpperCase() == 'PAID';
    }).length;
    final partialCount = runs.where((run) {
      return (run['status'] as String? ?? '').toUpperCase() == 'PARTIAL';
    }).length;

    final doc = pw.Document(
      title: 'รายการงวดปันผลลูกค้า',
      author: effectiveCompany,
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
        build: (_) => [
          _buildHeader(
            company: effectiveCompany,
            printedAt: printedAt,
            statusLabel: statusLabel,
            search: search,
            ttf: ttf,
            regular: regular,
          ),
          pw.SizedBox(height: 12),
          _buildSummary(
            runCount: runs.length,
            totalAmount: totalAmount,
            paidCount: paidCount,
            partialCount: partialCount,
            ttf: ttf,
            regular: regular,
          ),
          pw.SizedBox(height: 12),
          _buildTable(runs, ttf, regular),
        ],
      ),
    );

    return doc;
  }

  static pw.Widget _buildHeader({
    required String company,
    required String printedAt,
    required String statusLabel,
    required String search,
    required pw.Font ttf,
    required pw.Font regular,
  }) {
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
              'รายการงวดปันผลลูกค้า',
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
        pw.SizedBox(height: 6),
        pw.Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            pw.Text(
              'สถานะ: $statusLabel',
              style: pw.TextStyle(font: regular, fontSize: 9, color: _kSub),
            ),
            pw.Text(
              'ค้นหา: ${search.isEmpty ? '-' : search}',
              style: pw.TextStyle(font: regular, fontSize: 9, color: _kSub),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildSummary({
    required int runCount,
    required double totalAmount,
    required int paidCount,
    required int partialCount,
    required pw.Font ttf,
    required pw.Font regular,
  }) {
    final items = [
      ('จำนวนงวด', '$runCount'),
      ('ยอดปันผลรวม', '฿${_money.format(totalAmount)}'),
      ('จ่ายครบแล้ว', '$paidCount'),
      ('จ่ายบางส่วน', '$partialCount'),
    ];

    return pw.Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        return pw.Container(
          width: 140,
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
    List<Map<String, dynamic>> runs,
    pw.Font ttf,
    pw.Font regular,
  ) {
    final header = pw.TableRow(
      decoration: const pw.BoxDecoration(color: _kHeaderBg),
      children: [
        _hCell('#', ttf),
        _hCell('เลขที่งวด', ttf),
        _hCell('ช่วงเวลา', ttf),
        _hCell('สถานะ', ttf, align: pw.TextAlign.center),
        _hCell('อัตรา', ttf, align: pw.TextAlign.right),
        _hCell('ลูกค้า', ttf, align: pw.TextAlign.center),
        _hCell('ยอดปันผล', ttf, align: pw.TextAlign.right),
      ],
    );

    final rows = runs.asMap().entries.map((entry) {
      final run = entry.value;
      final start = run['period_start'] as String?;
      final end = run['period_end'] as String?;
      final period = start == null && end == null
          ? 'ทุกช่วงเวลา'
          : '${start == null ? '?' : _date.format(DateTime.parse(start))}'
              ' - ${end == null ? '?' : _date.format(DateTime.parse(end))}';

      return pw.TableRow(
        decoration: pw.BoxDecoration(
          color: entry.key.isOdd ? _kAltBg : PdfColors.white,
        ),
        children: [
          _dCell('${entry.key + 1}', regular, align: pw.TextAlign.center),
          _dCell('${run['run_no'] ?? '-'}', regular),
          _dCell(period, regular),
          _dCell(
            _runStatusLabel('${run['status'] ?? '-'}'),
            regular,
            align: pw.TextAlign.center,
          ),
          _dCell(
            '${_money.format((run['dividend_percent'] ?? 0) as num)}%',
            regular,
            align: pw.TextAlign.right,
          ),
          _dCell(
            '${(run['total_customers'] as num?)?.toInt() ?? 0}',
            regular,
            align: pw.TextAlign.center,
          ),
          _dCell(
            '฿${_money.format((run['total_dividend_amount'] ?? 0) as num)}',
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
        1: pw.FlexColumnWidth(1.3),
        2: pw.FlexColumnWidth(2.0),
        3: pw.FlexColumnWidth(1.0),
        4: pw.FlexColumnWidth(0.8),
        5: pw.FlexColumnWidth(0.8),
        6: pw.FlexColumnWidth(1.2),
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
