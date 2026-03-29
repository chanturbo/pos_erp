// lib/features/sales/presentation/pages/sales_history_pdf_report.dart
//
// PDF Report — ประวัติการขาย A4 แนวนอน
// Pattern เดียวกับ product_pdf_report.dart
// — ใช้ PdfGoogleFonts.notoSansThai สำหรับ render ภาษาไทย
// — คืน pw.Document (ให้ PdfExportService เรียก .save() เอง)

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../data/models/sales_order_model.dart';

// ─────────────────────────────────────────────────────────────────
// Standard color palette
// ─────────────────────────────────────────────────────────────────
const _kBorder  = PdfColor.fromInt(0xFFBBBBBB);
const _kHdrBg   = PdfColor.fromInt(0xFFDDDDDD);
const _kAltRow  = PdfColor.fromInt(0xFFF5F5F5);
const _kText    = PdfColors.black;
const _kSub     = PdfColor.fromInt(0xFF555555);
const _kSuccess = PdfColor.fromInt(0xFF1B5E20);
const _kError   = PdfColor.fromInt(0xFFB71C1C);
const _kWarning = PdfColor.fromInt(0xFFBF360C);

// ─────────────────────────────────────────────────────────────────
// SalesHistoryPdfBuilder
// ─────────────────────────────────────────────────────────────────
class SalesHistoryPdfBuilder {
  static final _fmt      = NumberFormat('#,##0.00', 'th');
  static final _dateFmt  = DateFormat('dd/MM/yyyy HH:mm');
  static final _shortFmt = DateFormat('dd/MM/yyyy');

  /// สร้าง PDF — รับ list ที่ filter แล้ว + filter params สำหรับแสดงใน header
  static Future<pw.Document> build(
    List<SalesOrderModel> orders, {
    DateTime? dateFrom,
    DateTime? dateTo,
    String paymentFilter = 'ALL',
    String statusFilter  = 'ALL',
    String companyName   = 'DEE POS',
  }) async {
    final doc = pw.Document(
      title:  'รายงานประวัติการขาย',
      author: companyName,
    );

    final ttf        = await PdfGoogleFonts.notoSansThaiBold();
    final ttfRegular = await PdfGoogleFonts.notoSansThaiRegular();
    final printedAt  = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    // คำนวณ summary
    final completed    = orders.where((o) => o.status == 'COMPLETED').toList();
    final cancelled    = orders.where((o) => o.status == 'CANCELLED').toList();
    final pending      = orders.where((o) => o.status == 'PENDING').toList();
    final totalRevenue = completed.fold(0.0, (s, o) => s + o.totalAmount);

    // สร้าง subtitle (ช่วงเวลา + filter)
    String periodText = 'ทั้งหมด';
    if (dateFrom != null && dateTo != null) {
      periodText = '${_shortFmt.format(dateFrom)} – ${_shortFmt.format(dateTo)}';
    } else if (dateFrom != null) {
      periodText = 'ตั้งแต่ ${_shortFmt.format(dateFrom)}';
    } else if (dateTo != null) {
      periodText = 'ถึง ${_shortFmt.format(dateTo)}';
    }

    var subtitle = 'ช่วงเวลา: $periodText';
    if (paymentFilter != 'ALL') subtitle += '   ชำระ: ${_paymentLabel(paymentFilter)}';
    if (statusFilter != 'ALL')  subtitle += '   สถานะ: ${_statusLabel(statusFilter)}';

    final summaryLine =
        'ทั้งหมด ${orders.length} ใบ   สำเร็จ ${completed.length} ใบ   รอดำเนิน ${pending.length} ใบ   ยกเลิก ${cancelled.length} ใบ   ยอดรวม ฿${_fmt.format(totalRevenue)}';

    // แบ่งหน้า 30 rows / page (A4 แนวนอน)
    const rowsPerPage = 30;
    final pages = <List<SalesOrderModel>>[];
    for (var i = 0; i < orders.length; i += rowsPerPage) {
      final end = (i + rowsPerPage) > orders.length ? orders.length : i + rowsPerPage;
      pages.add(orders.sublist(i, end));
    }
    if (pages.isEmpty) pages.add([]);
    final totalPages = pages.length;

    for (var pageIdx = 0; pageIdx < pages.length; pageIdx++) {
      final chunk   = pages[pageIdx];
      final startNo = pageIdx * rowsPerPage + 1;

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(24),
          build: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _buildPageHeader(
                companyName: companyName,
                reportTitle: 'รายงานประวัติการขาย',
                printedAt:   printedAt,
                page:        pageIdx + 1,
                totalPages:  totalPages,
                ttf:         ttf,
                ttfRegular:  ttfRegular,
                subtitle:    subtitle,
                summaryLine: summaryLine,
              ),
              _buildTable(
                chunk,
                startNo:    startNo,
                ttf:        ttf,
                ttfRegular: ttfRegular,
              ),
              pw.Spacer(),
              _buildFooter(ttfRegular: ttfRegular),
            ],
          ),
        ),
      );
    }

    return doc;
  }

  // ── Page Header ────────────────────────────────────────────────
  static pw.Widget _buildPageHeader({
    required String  companyName,
    required String  reportTitle,
    required String  printedAt,
    required int     page,
    required int     totalPages,
    required pw.Font ttf,
    required pw.Font ttfRegular,
    String?          subtitle,
    String?          summaryLine,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('พิมพ์เมื่อ $printedAt',
                style: pw.TextStyle(font: ttfRegular, fontSize: 8, color: _kSub)),
            pw.Text('หน้าที่ $page / $totalPages',
                style: pw.TextStyle(font: ttfRegular, fontSize: 8, color: _kSub)),
          ],
        ),
        pw.SizedBox(height: 3),
        pw.Center(
          child: pw.Text(companyName,
              style: pw.TextStyle(font: ttfRegular, fontSize: 9, color: _kSub)),
        ),
        pw.SizedBox(height: 2),
        pw.Center(
          child: pw.Text(reportTitle,
              style: pw.TextStyle(font: ttf, fontSize: 14, color: _kText)),
        ),
        if (subtitle != null) ...[
          pw.SizedBox(height: 3),
          pw.Center(
            child: pw.Text(subtitle,
                style: pw.TextStyle(font: ttfRegular, fontSize: 8, color: _kSub)),
          ),
        ],
        if (summaryLine != null) ...[
          pw.SizedBox(height: 2),
          pw.Center(
            child: pw.Text(summaryLine,
                style: pw.TextStyle(font: ttfRegular, fontSize: 8, color: _kSub)),
          ),
        ],
        pw.SizedBox(height: 6),
        pw.Container(height: 0.5, color: _kBorder),
        pw.SizedBox(height: 6),
      ],
    );
  }

  // ── Table ─────────────────────────────────────────────────────────
  static pw.Widget _buildTable(
    List<SalesOrderModel> orders, {
    required int     startNo,
    required pw.Font ttf,
    required pw.Font ttfRegular,
  }) {
    const colWidths = {
      0: pw.FixedColumnWidth(32),   // #
      1: pw.FixedColumnWidth(100),  // วันที่
      2: pw.FixedColumnWidth(110),  // เลขที่
      3: pw.FlexColumnWidth(2),     // ลูกค้า
      4: pw.FixedColumnWidth(65),   // ชำระด้วย
      5: pw.FixedColumnWidth(70),   // ส่วนลด
      6: pw.FixedColumnWidth(85),   // ยอดรวม
      7: pw.FixedColumnWidth(65),   // สถานะ
    };

    pw.Widget cell(String text, pw.Font font,
        {pw.Alignment align     = pw.Alignment.centerLeft,
        PdfColor?    color,
        PdfColor?    bgColor,
        double       fontSize   = 8.5,
        bool         strikethrough = false}) {
      return pw.Container(
        color: bgColor,
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
        alignment: align,
        child: pw.Text(
          text,
          style: pw.TextStyle(
            font:       font,
            fontSize:   fontSize,
            color:      color ?? _kText,
            decoration: strikethrough
                ? pw.TextDecoration.lineThrough
                : pw.TextDecoration.none,
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
          children: [
            '#', 'วันที่-เวลา', 'เลขที่ใบขาย', 'ลูกค้า',
            'ชำระด้วย', 'ส่วนลด', 'ยอดรวม', 'สถานะ',
          ]
              .map((h) => pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 5, vertical: 6),
                    child: pw.Text(h,
                        style: pw.TextStyle(
                            font: ttf, fontSize: 8, color: _kText)),
                  ))
              .toList(),
        ),

        // Data rows
        ...orders.asMap().entries.map((entry) {
          final i           = entry.key;
          final o           = entry.value;
          final rowBg       = i.isEven ? _kAltRow : null;
          final isCancelled = o.status == 'CANCELLED';

          return pw.TableRow(
            children: [
              // #
              cell('${startNo + i}', ttfRegular,
                  align: pw.Alignment.center, bgColor: rowBg),
              // วันที่
              cell(_dateFmt.format(o.orderDate), ttfRegular,
                  fontSize: 7.5, color: _kSub, bgColor: rowBg),
              // เลขที่ใบขาย
              cell(o.orderNo, ttf, bgColor: rowBg),
              // ลูกค้า
              cell(o.customerName ?? 'Walk-in', ttfRegular,
                  color: o.customerName == null ? _kSub : null,
                  bgColor: rowBg),
              // ชำระด้วย
              cell(_paymentLabel(o.paymentType), ttfRegular,
                  align: pw.Alignment.center,
                  color: _paymentColor(o.paymentType),
                  bgColor: rowBg),
              // ส่วนลด
              cell(
                o.discountAmount > 0
                    ? '฿${_fmt.format(o.discountAmount)}'
                    : '-',
                ttfRegular,
                align: pw.Alignment.centerRight,
                color: o.discountAmount > 0 ? _kWarning : _kSub,
                bgColor: rowBg,
              ),
              // ยอดรวม
              cell(
                '฿${_fmt.format(o.totalAmount)}',
                isCancelled ? ttfRegular : ttf,
                align: pw.Alignment.centerRight,
                color: isCancelled ? _kSub : _kText,
                strikethrough: isCancelled,
                bgColor: rowBg,
              ),
              // สถานะ
              cell(_statusLabel(o.status), ttf,
                  align: pw.Alignment.center,
                  color: _statusColor(o.status),
                  bgColor: rowBg),
            ],
          );
        }),
      ],
    );
  }

  // ── Footer ────────────────────────────────────────────────────────
  static pw.Widget _buildFooter({required pw.Font ttfRegular}) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
            top: pw.BorderSide(color: _kBorder, width: 0.5)),
      ),
      child: pw.Text(
        'DEE POS — รายงานประวัติการขาย',
        style: pw.TextStyle(font: ttfRegular, fontSize: 7, color: _kSub),
      ),
    );
  }

  // ── Label / Color helpers ─────────────────────────────────────────
  static String _paymentLabel(String type) => switch (type) {
        'CASH'     => 'เงินสด',
        'CARD'     => 'บัตร',
        'TRANSFER' => 'โอน',
        _          => type,
      };

  static PdfColor _paymentColor(String type) => switch (type) {
        'CASH'     => _kSuccess,
        'CARD'     => const PdfColor.fromInt(0xFF1565C0),
        'TRANSFER' => const PdfColor.fromInt(0xFF6A1B9A),
        _          => _kSub,
      };

  static String _statusLabel(String status) => switch (status) {
        'COMPLETED' => 'สำเร็จ',
        'PENDING'   => 'รอดำเนิน',
        'CANCELLED' => 'ยกเลิก',
        _           => status,
      };

  static PdfColor _statusColor(String status) => switch (status) {
        'COMPLETED' => _kSuccess,
        'PENDING'   => const PdfColor.fromInt(0xFFE65100),
        'CANCELLED' => _kError,
        _           => _kSub,
      };
}
