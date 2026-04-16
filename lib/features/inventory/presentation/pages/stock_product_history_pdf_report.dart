import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../settings/shared/settings_defaults.dart';

// ─────────────────────────────────────────────────────────────────
// Standard color palette
// ─────────────────────────────────────────────────────────────────
const _kBorder = PdfColor.fromInt(0xFFBBBBBB);
const _kHdrBg = PdfColor.fromInt(0xFFDDDDDD);
const _kAltRow = PdfColor.fromInt(0xFFF5F5F5);
const _kText = PdfColors.black;
const _kSub = PdfColor.fromInt(0xFF555555);
const _kSuccess = PdfColor.fromInt(0xFF1B5E20);
const _kError = PdfColor.fromInt(0xFFB71C1C);
const _kWarning = PdfColor.fromInt(0xFFBF360C);

// ── type helpers ──────────────────────────────────────────────────
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
    case 'SALE':
      return 'ขาย';
    default:
      return t;
  }
}

// ── Model (minimal — รับจาก dialog) ──────────────────────────────
class StockHistoryPdfItem {
  final DateTime movementDate;
  final String movementType;
  final String warehouseName;
  final double quantity;
  final String? referenceNo;
  final String? remark;

  const StockHistoryPdfItem({
    required this.movementDate,
    required this.movementType,
    required this.warehouseName,
    required this.quantity,
    this.referenceNo,
    this.remark,
  });
}

// ── Builder ───────────────────────────────────────────────────────
class StockProductHistoryPdfBuilder {
  static Future<pw.Document> build({
    required String productCode,
    required String productName,
    required String baseUnit,
    required double currentBalance,
    required List<StockHistoryPdfItem> items,
    String filterLabel = 'ทั้งหมด',
    String? companyName,
  }) async {
    final effectiveCompanyName =
        companyName ?? await SettingsStorage.getCompanyName();
    final doc = pw.Document(
      title: 'ประวัติสต๊อก $productName',
      author: effectiveCompanyName,
    );

    final ttf = await PdfGoogleFonts.notoSansThaiBold();
    final ttfRegular = await PdfGoogleFonts.notoSansThaiRegular();
    final printedAt = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    final balanceFmt = NumberFormat('#,##0.##');
    final subtitle = '$productCode  $productName';
    final summaryLine =
        'หน่วย: $baseUnit   คงเหลือ: ${balanceFmt.format(currentBalance)} $baseUnit   รายการ: ${items.length}   ตัวกรอง: $filterLabel';

    final rowsPerPage = await SettingsStorage.getPdfReportRowsPerPage(
      PdfReportType.stockProductHistory,
    );
    final pages = <List<StockHistoryPdfItem>>[];
    for (var i = 0; i < items.length; i += rowsPerPage) {
      pages.add(
        items.sublist(
          i,
          (i + rowsPerPage) > items.length ? items.length : i + rowsPerPage,
        ),
      );
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
                reportTitle: 'ประวัติสต๊อกสินค้า',
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
                baseUnit: baseUnit,
                ttf: ttf,
                ttfRegular: ttfRegular,
              ),
              pw.Spacer(),
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

  // ── Page Header ──────────────────────────────────────────────────
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

  // ── Table ────────────────────────────────────────────────────────
  static pw.Widget _buildTable(
    List<StockHistoryPdfItem> items, {
    required int startNo,
    required String baseUnit,
    required pw.Font ttf,
    required pw.Font ttfRegular,
  }) {
    const colWidths = {
      0: pw.FixedColumnWidth(30), // #
      1: pw.FixedColumnWidth(110), // วันที่
      2: pw.FixedColumnWidth(70), // ประเภท
      3: pw.FlexColumnWidth(1.5), // คลัง
      4: pw.FixedColumnWidth(70), // จำนวน
      5: pw.FlexColumnWidth(1.5), // อ้างอิง
      6: pw.FlexColumnWidth(2.0), // หมายเหตุ
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
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
        alignment: align,
        child: pw.Text(
          text,
          style: pw.TextStyle(
            font: font,
            fontSize: 8.5,
            color: color ?? _kText,
          ),
        ),
      );
    }

    return pw.Table(
      columnWidths: colWidths,
      border: pw.TableBorder.all(color: _kBorder, width: 0.5),
      children: [
        // Header row
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _kHdrBg),
          children:
              [
                    '#',
                    'วันที่/เวลา',
                    'ประเภท',
                    'คลัง',
                    'จำนวน',
                    'อ้างอิง',
                    'หมายเหตุ',
                  ]
                  .map(
                    (h) => pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 5,
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
        // Data rows
        ...items.asMap().entries.map((e) {
          final i = e.key;
          final item = e.value;
          final rowBg = i.isEven ? _kAltRow : null;
          final isPos = item.quantity >= 0;
          final qtyColor = isPos ? _kSuccess : _kError;
          final tColor = _typeColor(item.movementType);

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
                DateFormat('dd/MM/yy HH:mm').format(item.movementDate),
                ttfRegular,
                bgColor: rowBg,
              ),
              // ประเภท — plain text with mild color, no bg badge
              cell(
                _typeLabel(item.movementType),
                ttf,
                color: tColor,
                bgColor: rowBg,
              ),
              cell(item.warehouseName, ttfRegular, bgColor: rowBg),
              cell(
                '${isPos ? '+' : ''}${item.quantity.toStringAsFixed(0)} $baseUnit',
                ttf,
                align: pw.Alignment.centerRight,
                color: qtyColor,
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

  // ── Footer ───────────────────────────────────────────────────────
  static pw.Widget _buildFooter({
    required String companyName,
    required pw.Font ttfRegular,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _kBorder, width: 0.5)),
      ),
      child: pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          companyName,
          style: pw.TextStyle(font: ttfRegular, fontSize: 7, color: _kSub),
        ),
      ),
    );
  }
}
