// lib/features/sales/presentation/pages/sales_history_pdf_report.dart
//
// PDF Report — ประวัติการขาย A4 แนวตั้ง
// Pattern เดียวกับ product_pdf_report.dart
// — ใช้ PdfGoogleFonts.notoSansThai สำหรับ render ภาษาไทย
// — คืน pw.Document (ให้ PdfExportService เรียก .save() เอง)

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../data/models/sales_order_model.dart';

// ─────────────────────────────────────────────────────────────────
// PDF Colors — ตรงกับ AppTheme palette
// ─────────────────────────────────────────────────────────────────
const _kPrimary   = PdfColor.fromInt(0xFFE57200); // AppTheme.primary
const _kNavy      = PdfColor.fromInt(0xFF16213E); // AppTheme.navy
const _kHeaderBg  = PdfColor.fromInt(0xFFF4F4F0); // AppTheme.surface
const _kBorder    = PdfColor.fromInt(0xFFE0E0E0); // AppTheme.border
const _kTextSub   = PdfColor.fromInt(0xFF757575); // AppTheme.textSub
const _kSuccess   = PdfColor.fromInt(0xFF2E7D32); // AppTheme.success
const _kSuccessBg = PdfColor.fromInt(0xFFB9F6CA); // AppTheme.successContainer
const _kError     = PdfColor.fromInt(0xFFC62828); // AppTheme.error
const _kErrorBg   = PdfColor.fromInt(0xFFFFCDD2); // AppTheme.errorContainer
const _kWarning   = PdfColor.fromInt(0xFFF9A825); // AppTheme.warning
const _kWarningBg = PdfColor.fromInt(0xFFFFF8E1); // AppTheme.warningContainer
const _kInfo      = PdfColor.fromInt(0xFF1565C0); // AppTheme.info
const _kInfoBg    = PdfColor.fromInt(0xFFE3F2FD); // AppTheme.infoContainer
const _kPurple    = PdfColor.fromInt(0xFF6A1B9A); // AppTheme.purpleColor
const _kPurpleBg  = PdfColor.fromInt(0xFFF3E5F5);
const _kWhite     = PdfColors.white;

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

    // ── โหลด font ภาษาไทย (เหมือน product_pdf_report.dart) ────────
    final ttf        = await PdfGoogleFonts.notoSansThaiBold();
    final ttfRegular = await PdfGoogleFonts.notoSansThaiRegular();
    final printedAt  = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    // ── คำนวณ summary ───────────────────────────────────────────────
    final completed     = orders.where((o) => o.status == 'COMPLETED').toList();
    final cancelled     = orders.where((o) => o.status == 'CANCELLED').toList();
    final pending       = orders.where((o) => o.status == 'PENDING').toList();
    final totalRevenue  = completed.fold(0.0, (s, o) => s + o.totalAmount);

    // ── แบ่งหน้า 25 rows / page (A4 แนวตั้ง) ───────────────────────
    const rowsPerPage = 30;
    final pages = <List<SalesOrderModel>>[];
    for (var i = 0; i < orders.length; i += rowsPerPage) {
      final end = (i + rowsPerPage) > orders.length
          ? orders.length
          : i + rowsPerPage;
      pages.add(orders.sublist(i, end));
    }
    if (pages.isEmpty) pages.add([]);
    final totalPages = pages.length;

    for (var pageIdx = 0; pageIdx < pages.length; pageIdx++) {
      final isFirst = pageIdx == 0;
      final chunk   = pages[pageIdx];
      final startNo = pageIdx * rowsPerPage + 1;

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape, // A4 แนวนอน
          margin: const pw.EdgeInsets.all(24),
          build: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              if (isFirst) ...[
                _buildHeader(
                  companyName:   companyName,
                  printedAt:     printedAt,
                  total:         orders.length,
                  completed:     completed.length,
                  cancelled:     cancelled.length,
                  pending:       pending.length,
                  totalRevenue:  totalRevenue,
                  dateFrom:      dateFrom,
                  dateTo:        dateTo,
                  paymentFilter: paymentFilter,
                  statusFilter:  statusFilter,
                  ttf:           ttf,
                  ttfRegular:    ttfRegular,
                ),
                pw.SizedBox(height: 10),
              ],
              _buildTable(
                chunk,
                startNo:    startNo,
                ttf:        ttf,
                ttfRegular: ttfRegular,
              ),
              pw.Spacer(),
              _buildFooter(
                page:       pageIdx + 1,
                totalPages: totalPages,
                ttfRegular: ttfRegular,
              ),
            ],
          ),
        ),
      );
    }

    return doc;
  }

  // ── Header ────────────────────────────────────────────────────────
  static pw.Widget _buildHeader({
    required String   companyName,
    required String   printedAt,
    required int      total,
    required int      completed,
    required int      cancelled,
    required int      pending,
    required double   totalRevenue,
    required pw.Font  ttf,
    required pw.Font  ttfRegular,
    DateTime?         dateFrom,
    DateTime?         dateTo,
    String            paymentFilter = 'ALL',
    String            statusFilter  = 'ALL',
  }) {
    String periodText = 'ทั้งหมด';
    if (dateFrom != null && dateTo != null) {
      periodText =
          '${_shortFmt.format(dateFrom)} – ${_shortFmt.format(dateTo)}';
    } else if (dateFrom != null) {
      periodText = 'ตั้งแต่ ${_shortFmt.format(dateFrom)}';
    } else if (dateTo != null) {
      periodText = 'ถึง ${_shortFmt.format(dateTo)}';
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // Title bar
        pw.Container(
          decoration: pw.BoxDecoration(
            color: _kNavy,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          padding: const pw.EdgeInsets.symmetric(
              horizontal: 20, vertical: 14),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'รายงานประวัติการขาย',
                      style: pw.TextStyle(
                          font: ttf, fontSize: 18, color: _kWhite),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      companyName,
                      style: pw.TextStyle(
                        font: ttfRegular,
                        fontSize: 11,
                        color: const PdfColor.fromInt(0xFFAAAAAA),
                      ),
                    ),
                  ],
                ),
              ),
              pw.Row(
                children: [
                  _statChip('ช่วงเวลา', periodText, _kInfo, ttf, ttfRegular),
                  if (paymentFilter != 'ALL') ...[
                    pw.SizedBox(width: 6),
                    _statChip('ชำระ',
                        _paymentLabel(paymentFilter), _kPurple, ttf, ttfRegular),
                  ],
                  if (statusFilter != 'ALL') ...[
                    pw.SizedBox(width: 6),
                    _statChip('สถานะ',
                        _statusLabel(statusFilter), _kWarning, ttf, ttfRegular),
                  ],
                  pw.SizedBox(width: 6),
                  _statChip('พิมพ์เมื่อ', printedAt, _kTextSub, ttf, ttfRegular),
                ],
              ),
            ],
          ),
        ),

        pw.SizedBox(height: 8),

        // Summary row
        pw.Row(
          children: [
            _summaryCard('รายการทั้งหมด', '$total ใบ',
                _kInfo, ttf, ttfRegular),
            pw.SizedBox(width: 6),
            _summaryCard('สำเร็จ', '$completed ใบ',
                _kSuccess, ttf, ttfRegular),
            pw.SizedBox(width: 6),
            _summaryCard('รอดำเนินการ', '$pending ใบ',
                _kWarning, ttf, ttfRegular),
            pw.SizedBox(width: 6),
            _summaryCard('ยกเลิก', '$cancelled ใบ',
                _kError, ttf, ttfRegular),
            pw.SizedBox(width: 6),
            _summaryCard(
              'ยอดรวม (สำเร็จ)',
              '฿${_fmt.format(totalRevenue)}',
              _kPrimary, ttf, ttfRegular,
              flex: 2,
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _statChip(
    String label, String value, PdfColor color,
    pw.Font ttf, pw.Font ttfRegular,
  ) =>
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: pw.BoxDecoration(
          color: _kWhite,
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(label,
                style: pw.TextStyle(
                    font: ttfRegular, fontSize: 7, color: _kTextSub)),
            pw.SizedBox(height: 2),
            pw.Text(value,
                style: pw.TextStyle(font: ttf, fontSize: 9, color: color)),
          ],
        ),
      );

  static pw.Widget _summaryCard(
    String label, String value, PdfColor color,
    pw.Font ttf, pw.Font ttfRegular, {
    int flex = 1,
  }) =>
      pw.Expanded(
        flex: flex,
        child: pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: pw.BoxDecoration(
            color: _kWhite,
            borderRadius: pw.BorderRadius.circular(6),
            border: pw.Border.all(color: _kBorder),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(label,
                  style: pw.TextStyle(
                      font: ttfRegular, fontSize: 8, color: _kTextSub)),
              pw.SizedBox(height: 3),
              pw.Text(value,
                  style: pw.TextStyle(font: ttf, fontSize: 12, color: color)),
            ],
          ),
        ),
      );

  // ── Table ─────────────────────────────────────────────────────────
  static pw.Widget _buildTable(
    List<SalesOrderModel> orders, {
    required int     startNo,
    required pw.Font ttf,
    required pw.Font ttfRegular,
  }) {
    // A4 landscape usable ≈ 794pt (841 - 24*2)
    const colWidths = {
      0: pw.FixedColumnWidth(32),   // #
      1: pw.FixedColumnWidth(100),  // วันที่
      2: pw.FixedColumnWidth(110),  // เลขที่
      3: pw.FlexColumnWidth(2),     // ลูกค้า (flex — ใช้พื้นที่ landscape)
      4: pw.FixedColumnWidth(65),   // ชำระด้วย
      5: pw.FixedColumnWidth(70),   // ส่วนลด
      6: pw.FixedColumnWidth(85),   // ยอดรวม
      7: pw.FixedColumnWidth(65),   // สถานะ
    };

    return pw.Table(
      columnWidths: colWidths,
      border: pw.TableBorder.all(color: _kBorder, width: 0.5),
      children: [
        // Header row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _kNavy),
          children: [
            '#', 'วันที่-เวลา', 'เลขที่ใบขาย', 'ลูกค้า',
            'ชำระด้วย', 'ส่วนลด', 'ยอดรวม', 'สถานะ',
          ]
              .map((h) => pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 5, vertical: 7),
                    child: pw.Text(h,
                        style: pw.TextStyle(
                            font: ttf, fontSize: 9, color: _kWhite)),
                  ))
              .toList(),
        ),

        // Data rows
        ...orders.asMap().entries.map((entry) {
          final i = entry.key;
          final o = entry.value;
          final rowBg       = i.isEven ? _kHeaderBg : _kWhite;
          final isCancelled = o.status == 'CANCELLED';

          return pw.TableRow(
            children: [
              // #
              _cell('${startNo + i}', ttfRegular,
                  align: pw.Alignment.center, bgColor: rowBg),
              // วันที่
              _cell(_dateFmt.format(o.orderDate), ttfRegular,
                  fontSize: 7.5, color: _kTextSub, bgColor: rowBg),
              // เลขที่ใบขาย
              _cell(o.orderNo, ttf, bgColor: rowBg),
              // ลูกค้า
              _cell(o.customerName ?? 'Walk-in', ttfRegular,
                  color: o.customerName == null ? _kTextSub : null,
                  bgColor: rowBg),
              // ชำระด้วย
              _cellBadge(
                _paymentLabel(o.paymentType),
                _paymentColor(o.paymentType),
                _paymentBgColor(o.paymentType),
                ttf,
              ),
              // ส่วนลด
              _cell(
                o.discountAmount > 0
                    ? '฿${_fmt.format(o.discountAmount)}'
                    : '-',
                ttfRegular,
                align: pw.Alignment.centerRight,
                color: o.discountAmount > 0 ? _kWarning : _kTextSub,
                bgColor: rowBg,
              ),
              // ยอดรวม
              _cell(
                '฿${_fmt.format(o.totalAmount)}',
                isCancelled ? ttfRegular : ttf,
                align: pw.Alignment.centerRight,
                color: isCancelled ? _kTextSub : _kInfo,
                strikethrough: isCancelled,
                bgColor: rowBg,
              ),
              // สถานะ
              _cellBadge(
                _statusLabel(o.status),
                _statusColor(o.status),
                _statusBgColor(o.status),
                ttf,
              ),
            ],
          );
        }),
      ],
    );
  }

  // ── Footer ────────────────────────────────────────────────────────
  static pw.Widget _buildFooter({
    required int     page,
    required int     totalPages,
    required pw.Font ttfRegular,
  }) =>
      pw.Container(
        padding: const pw.EdgeInsets.only(top: 8),
        decoration: const pw.BoxDecoration(
          border: pw.Border(
              top: pw.BorderSide(color: _kBorder, width: 0.5)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'DEE POS — รายงานประวัติการขาย',
              style: pw.TextStyle(
                  font: ttfRegular, fontSize: 8, color: _kTextSub),
            ),
            pw.Text(
              'หน้า $page / $totalPages',
              style: pw.TextStyle(
                  font: ttfRegular, fontSize: 8, color: _kTextSub),
            ),
          ],
        ),
      );

  // ── Cell helpers ──────────────────────────────────────────────────
  static pw.Widget _cell(
    String text,
    pw.Font font, {
    pw.Alignment align        = pw.Alignment.centerLeft,
    PdfColor?    color,
    PdfColor?    bgColor,
    double       fontSize     = 8.5,
    bool         strikethrough = false,
  }) =>
      pw.Container(
        color: bgColor,
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
        alignment: align,
        child: pw.Text(
          text,
          style: pw.TextStyle(
            font:       font,
            fontSize:   fontSize,
            color:      color ?? PdfColors.black,
            decoration: strikethrough
                ? pw.TextDecoration.lineThrough
                : pw.TextDecoration.none,
          ),
        ),
      );

  static pw.Widget _cellBadge(
    String text, PdfColor color, PdfColor bgColor, pw.Font ttf,
  ) =>
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 4),
        alignment: pw.Alignment.center,
        child: pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: pw.BoxDecoration(
            color: bgColor,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Text(
            text,
            style: pw.TextStyle(font: ttf, fontSize: 8, color: color),
          ),
        ),
      );

  // ── Label / Color helpers ─────────────────────────────────────────
  static String _paymentLabel(String type) => switch (type) {
        'CASH'     => 'เงินสด',
        'CARD'     => 'บัตร',
        'TRANSFER' => 'โอน',
        _          => type,
      };

  static PdfColor _paymentColor(String type) => switch (type) {
        'CASH'     => _kSuccess,
        'CARD'     => _kInfo,
        'TRANSFER' => _kPurple,
        _          => _kTextSub,
      };

  static PdfColor _paymentBgColor(String type) => switch (type) {
        'CASH'     => _kSuccessBg,
        'CARD'     => _kInfoBg,
        'TRANSFER' => _kPurpleBg,
        _          => _kHeaderBg,
      };

  static String _statusLabel(String status) => switch (status) {
        'COMPLETED' => 'สำเร็จ',
        'PENDING'   => 'รอดำเนิน',
        'CANCELLED' => 'ยกเลิก',
        _           => status,
      };

  static PdfColor _statusColor(String status) => switch (status) {
        'COMPLETED' => _kSuccess,
        'PENDING'   => _kWarning,
        'CANCELLED' => _kError,
        _           => _kTextSub,
      };

  static PdfColor _statusBgColor(String status) => switch (status) {
        'COMPLETED' => _kSuccessBg,
        'PENDING'   => _kWarningBg,
        'CANCELLED' => _kErrorBg,
        _           => _kHeaderBg,
      };
}