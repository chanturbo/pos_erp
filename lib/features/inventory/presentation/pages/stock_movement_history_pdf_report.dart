import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../settings/shared/settings_defaults.dart';
import '../../data/models/stock_movement_model.dart';

const _kBorder = PdfColor.fromInt(0xFFBBBBBB);
const _kHdrBg = PdfColor.fromInt(0xFFDDDDDD);
const _kAltRow = PdfColor.fromInt(0xFFF5F5F5);
const _kText = PdfColors.black;
const _kSub = PdfColor.fromInt(0xFF555555);
const _kSuccess = PdfColor.fromInt(0xFF1B5E20);
const _kError = PdfColor.fromInt(0xFFB71C1C);
const _kWarning = PdfColor.fromInt(0xFFBF360C);

PdfColor _typeColor(String t) {
  switch (t) {
    case 'IN':
      return _kSuccess;
    case 'OUT':
      return _kWarning;
    case 'ADJUST':
      return const PdfColor.fromInt(0xFF1565C0);
    case 'TRANSFER_IN':
    case 'TRANSFER_OUT':
    case 'TRANSFER':
      return const PdfColor.fromInt(0xFF4A148C);
    case 'SALE':
      return _kError;
    default:
      return _kSub;
  }
}

String _typeLabel(String t) {
  switch (t) {
    case 'IN':
      return 'รับเข้า';
    case 'OUT':
      return 'เบิกออก';
    case 'ADJUST':
      return 'ปรับสต๊อก';
    case 'TRANSFER_IN':
      return 'รับโอน';
    case 'TRANSFER_OUT':
      return 'โอนออก';
    case 'TRANSFER':
      return 'โอนย้าย';
    case 'SALE':
      return 'ขาย';
    default:
      return t;
  }
}

class StockMovementHistoryPdfBuilder {
  static final _moneyFmt = NumberFormat('#,##0.00', 'th');
  static final _dateFmt = DateFormat('dd/MM/yyyy HH:mm');
  static final _shortFmt = DateFormat('dd/MM/yyyy');

  static Future<pw.Document> build(
    List<StockMovementModel> items, {
    DateTime? dateFrom,
    DateTime? dateTo,
    String filterType = 'ALL',
    String? companyName,
  }) async {
    final effectiveCompanyName =
        companyName ?? await SettingsStorage.getCompanyName();
    final doc = pw.Document(
      title: 'รายงานประวัติการเคลื่อนไหวสต๊อก',
      author: effectiveCompanyName,
    );

    final ttf = await PdfGoogleFonts.notoSansThaiBold();
    final ttfRegular = await PdfGoogleFonts.notoSansThaiRegular();
    final printedAt = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    String periodText = 'ทั้งหมด';
    if (dateFrom != null && dateTo != null) {
      periodText =
          '${_shortFmt.format(dateFrom)} – ${_shortFmt.format(dateTo)}';
    } else if (dateFrom != null) {
      periodText = 'ตั้งแต่ ${_shortFmt.format(dateFrom)}';
    } else if (dateTo != null) {
      periodText = 'ถึง ${_shortFmt.format(dateTo)}';
    }

    var subtitle = 'ช่วงเวลา: $periodText';
    if (filterType != 'ALL') {
      subtitle += '   ประเภท: ${_typeLabel(filterType)}';
    }

    final totalValue = items.fold<double>(0, (sum, m) => sum + m.lineValue);
    final inCount = items.where((m) => m.movementType == 'IN').length;
    final outCount = items.where((m) => m.movementType == 'OUT').length;
    final summaryLine =
        'ทั้งหมด ${items.length} รายการ   รับเข้า $inCount   เบิกออก $outCount   มูลค่ารวม ฿${_moneyFmt.format(totalValue)}';

    final rowsPerPage = await SettingsStorage.getPdfReportRowsPerPage(
      PdfReportType.stockMovementHistory,
    );
    final pages = <List<StockMovementModel>>[];
    for (var i = 0; i < items.length; i += rowsPerPage) {
      final end = (i + rowsPerPage) > items.length
          ? items.length
          : i + rowsPerPage;
      pages.add(items.sublist(i, end));
    }
    if (pages.isEmpty) pages.add([]);
    final totalPages = pages.length;

    for (var pageIdx = 0; pageIdx < pages.length; pageIdx++) {
      final pageItems = pages[pageIdx];
      final startNo = pageIdx * rowsPerPage + 1;

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _buildPageHeader(
                companyName: effectiveCompanyName,
                reportTitle: 'รายงานประวัติการเคลื่อนไหวสต๊อก',
                printedAt: printedAt,
                page: pageIdx + 1,
                totalPages: totalPages,
                ttf: ttf,
                ttfRegular: ttfRegular,
                subtitle: subtitle,
                summaryLine: summaryLine,
              ),
              _buildTable(
                pageItems,
                startNo: startNo,
                ttf: ttf,
                ttfRegular: ttfRegular,
              ),
              pw.SizedBox(height: 8),
              _buildFooter(
                companyName: effectiveCompanyName,
                ttfRegular: ttfRegular,
              ),
            ],
          ),
        ),
      );
    }

    return doc;
  }

  static pw.Widget _buildPageHeader({
    required String companyName,
    required String reportTitle,
    required String printedAt,
    required int page,
    required int totalPages,
    required pw.Font ttf,
    required pw.Font ttfRegular,
    String? subtitle,
    String? summaryLine,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'พิมพ์เมื่อ $printedAt',
              style: pw.TextStyle(font: ttfRegular, fontSize: 8, color: _kSub),
            ),
            pw.Text(
              'หน้าที่ $page / $totalPages',
              style: pw.TextStyle(font: ttfRegular, fontSize: 8, color: _kSub),
            ),
          ],
        ),
        pw.SizedBox(height: 3),
        pw.Center(
          child: pw.Text(
            companyName,
            style: pw.TextStyle(font: ttfRegular, fontSize: 9, color: _kSub),
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Center(
          child: pw.Text(
            reportTitle,
            style: pw.TextStyle(font: ttf, fontSize: 14, color: _kText),
          ),
        ),
        if (subtitle != null) ...[
          pw.SizedBox(height: 3),
          pw.Center(
            child: pw.Text(
              subtitle,
              style: pw.TextStyle(font: ttfRegular, fontSize: 8, color: _kSub),
            ),
          ),
        ],
        if (summaryLine != null) ...[
          pw.SizedBox(height: 2),
          pw.Center(
            child: pw.Text(
              summaryLine,
              style: pw.TextStyle(font: ttfRegular, fontSize: 8, color: _kSub),
            ),
          ),
        ],
        pw.SizedBox(height: 6),
        pw.Container(height: 0.5, color: _kBorder),
        pw.SizedBox(height: 6),
      ],
    );
  }

  static pw.Widget _buildTable(
    List<StockMovementModel> items, {
    required int startNo,
    required pw.Font ttf,
    required pw.Font ttfRegular,
  }) {
    const colWidths = {
      0: pw.FixedColumnWidth(24),
      1: pw.FixedColumnWidth(82),
      2: pw.FixedColumnWidth(52),
      3: pw.FixedColumnWidth(62),
      4: pw.FixedColumnWidth(46),
      5: pw.FixedColumnWidth(42),
      6: pw.FlexColumnWidth(1),
      7: pw.FlexColumnWidth(1.4),
    };

    pw.Widget cell(
      String text,
      pw.Font font, {
      pw.Alignment align = pw.Alignment.centerLeft,
      PdfColor? color,
      PdfColor? bgColor,
    }) {
      return pw.Container(
        color: bgColor,
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
        alignment: align,
        child: pw.Text(
          text,
          style: pw.TextStyle(font: font, fontSize: 8, color: color ?? _kText),
        ),
      );
    }

    return pw.Table(
      columnWidths: colWidths,
      border: pw.TableBorder.all(color: _kBorder, width: 0.5),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _kHdrBg),
          children:
              [
                    '#',
                    'วันที่/เวลา',
                    'ประเภท',
                    'รหัสสินค้า',
                    'คลัง',
                    'จำนวน',
                    'เลขอ้างอิง',
                    'หมายเหตุ',
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
        ...items.asMap().entries.map((e) {
          final i = e.key;
          final item = e.value;
          final rowBg = i.isEven ? _kAltRow : null;
          final isPositive = item.quantity >= 0;
          return pw.TableRow(
            children: [
              cell(
                '${startNo + i}',
                ttfRegular,
                align: pw.Alignment.center,
                color: _kSub,
                bgColor: rowBg,
              ),
              cell(
                _dateFmt.format(item.movementDate),
                ttfRegular,
                bgColor: rowBg,
              ),
              cell(
                _typeLabel(item.movementType),
                ttf,
                color: _typeColor(item.movementType),
                bgColor: rowBg,
              ),
              cell(item.productId, ttfRegular, bgColor: rowBg),
              cell(item.warehouseId, ttfRegular, bgColor: rowBg),
              cell(
                '${isPositive ? '+' : ''}${item.quantity.toStringAsFixed(0)}',
                ttf,
                align: pw.Alignment.center,
                color: isPositive ? _kSuccess : _kError,
                bgColor: rowBg,
              ),
              cell(
                item.referenceNo ?? '—',
                ttfRegular,
                color: _kSub,
                bgColor: rowBg,
              ),
              cell(
                item.remark ?? '—',
                ttfRegular,
                color: _kSub,
                bgColor: rowBg,
              ),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _buildFooter({
    required String companyName,
    required pw.Font ttfRegular,
  }) {
    return pw.Column(
      children: [
        pw.SizedBox(height: 8),
        pw.Container(height: 0.5, color: _kBorder),
        pw.SizedBox(height: 4),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            companyName,
            style: pw.TextStyle(font: ttfRegular, fontSize: 8, color: _kSub),
          ),
        ),
      ],
    );
  }
}
