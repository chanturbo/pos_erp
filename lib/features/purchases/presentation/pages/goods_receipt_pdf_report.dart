// lib/features/purchases/presentation/pages/goods_receipt_pdf_report.dart
//
// GoodsReceiptPdfBuilder — สร้างรายงาน PDF รายการรับสินค้า
//
// ใช้งาน:
//   PdfReportButton(
//     emptyMessage: 'ไม่มีข้อมูลการรับสินค้า',
//     title:        'รายงานการรับสินค้า',
//     filename:     () => PdfFilename.generate('goods_receipt_report'),
//     buildPdf:     () => GoodsReceiptPdfBuilder.build(filtered),
//     hasData:      filtered.isNotEmpty,
//   )

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../settings/shared/settings_defaults.dart';
import '../../data/models/goods_receipt_model.dart';

const _kBorder = PdfColor.fromInt(0xFFBBBBBB);
const _kHdrBg = PdfColor.fromInt(0xFFDDDDDD);
const _kAltRow = PdfColor.fromInt(0xFFF5F5F5);
const _kText = PdfColors.black;
const _kSub = PdfColor.fromInt(0xFF555555);
const _kDraft = PdfColor.fromInt(0xFFE65100);
const _kConfirmed = PdfColor.fromInt(0xFF1B5E20);
const _kNavy = PdfColor.fromInt(0xFF16213E);
const _kInfo = PdfColor.fromInt(0xFF1565C0);

class GoodsReceiptPdfBuilder {
  static final _date = DateFormat('dd/MM/yy');

  static Future<pw.Document> build(
    List<GoodsReceiptModel> receipts, {
    String? companyName,
  }) async {
    final effectiveCompanyName =
        companyName ?? await SettingsStorage.getCompanyName();
    final doc = pw.Document(
      title: 'รายงานการรับสินค้า',
      author: effectiveCompanyName,
    );

    final ttf = await PdfGoogleFonts.notoSansThaiBold();
    final ttfRegular = await PdfGoogleFonts.notoSansThaiRegular();
    final printedAt = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    final totalItems = receipts.fold<int>(
      0,
      (s, r) => s + (r.items?.length ?? 0),
    );
    final summaryLine =
        'ทั้งหมด ${receipts.length} ใบ   '
        'ร่าง ${_count(receipts, 'DRAFT')} ใบ   '
        'ยืนยันแล้ว ${_count(receipts, 'CONFIRMED')} ใบ   '
        'รายการสินค้า $totalItems รายการ';

    final summaryRow = _buildSummaryRow(
      count: receipts.length,
      confirmed: _count(receipts, 'CONFIRMED'),
      totalItems: totalItems,
      ttf: ttf,
      ttfR: ttfRegular,
    );

    final rowsPerPage = await SettingsStorage.getReportRowsPerPage();
    final pages = <List<GoodsReceiptModel>>[];
    for (var i = 0; i < receipts.length; i += rowsPerPage) {
      pages.add(
        receipts.sublist(
          i,
          (i + rowsPerPage) > receipts.length
              ? receipts.length
              : i + rowsPerPage,
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
                ttfR: ttfRegular,
              ),
              _buildTable(
                pages[pi],
                startNo: pi * rowsPerPage + 1,
                ttf: ttf,
                ttfR: ttfRegular,
              ),
              pw.Spacer(),
              _buildFooter(companyName: effectiveCompanyName, ttfR: ttfRegular),
            ],
          ),
        ),
      );
    }

    return doc;
  }

  static int _count(List<GoodsReceiptModel> list, String status) =>
      list.where((r) => r.status == status).length;

  static PdfColor _statusColor(String status) =>
      status == 'CONFIRMED' ? _kConfirmed : _kDraft;

  static String _statusLabel(String status) =>
      status == 'CONFIRMED' ? 'ยืนยันแล้ว' : 'ร่าง';

  // ── Page Header ──────────────────────────────────────────────────
  static pw.Widget _buildHeader({
    required String companyName,
    required String printedAt,
    required int page,
    required int totalPages,
    required String summaryLine,
    required pw.Widget summaryRow,
    required pw.Font ttf,
    required pw.Font ttfR,
  }) {
    return pw.Column(
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
            'รายงานการรับสินค้า',
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
  }

  // ── Summary Row ──────────────────────────────────────────────────
  static pw.Widget _buildSummaryRow({
    required int count,
    required int confirmed,
    required int totalItems,
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
        border: pw.Border.all(color: _kBorder, width: 0.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
      ),
      child: pw.Row(
        children: [
          cell('จำนวนใบรับ', '$count ใบ', _kNavy),
          pw.Container(width: 0.5, height: 28, color: _kBorder),
          cell('ยืนยันแล้ว', '$confirmed ใบ', _kConfirmed),
          pw.Container(width: 0.5, height: 28, color: _kBorder),
          cell('รายการสินค้ารวม', '$totalItems รายการ', _kInfo),
        ],
      ),
    );
  }

  // ── Table ────────────────────────────────────────────────────────
  static pw.Widget _buildTable(
    List<GoodsReceiptModel> receipts, {
    required int startNo,
    required pw.Font ttf,
    required pw.Font ttfR,
  }) {
    const colWidths = {
      0: pw.FixedColumnWidth(24), // #
      1: pw.FixedColumnWidth(72), // เลขที่ GR
      2: pw.FixedColumnWidth(68), // อ้างอิง PO
      3: pw.FlexColumnWidth(1), // ผู้จัดจำหน่าย
      4: pw.FixedColumnWidth(54), // คลังสินค้า
      5: pw.FixedColumnWidth(52), // วันที่รับ
      6: pw.FixedColumnWidth(52), // สถานะ
      7: pw.FixedColumnWidth(36), // รายการ
    };

    pw.Widget cell(
      String text,
      pw.Font font, {
      pw.Alignment align = pw.Alignment.centerLeft,
      PdfColor? color,
      PdfColor? bgColor,
    }) => pw.Container(
      color: bgColor,
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      alignment: align,
      child: pw.Text(
        text,
        style: pw.TextStyle(font: font, fontSize: 8, color: color ?? _kText),
      ),
    );

    return pw.Table(
      columnWidths: colWidths,
      border: pw.TableBorder.all(color: _kBorder, width: 0.5),
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _kHdrBg),
          children:
              [
                    '#',
                    'เลขที่ GR',
                    'อ้างอิง PO',
                    'ผู้จัดจำหน่าย',
                    'คลังสินค้า',
                    'วันที่รับ',
                    'สถานะ',
                    'รายการ',
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
        ...receipts.asMap().entries.map((e) {
          final i = e.key;
          final r = e.value;
          final bg = i.isEven ? _kAltRow : null;
          final sc = _statusColor(r.status);
          return pw.TableRow(
            children: [
              cell(
                '${startNo + i}',
                ttfR,
                align: pw.Alignment.center,
                bgColor: bg,
              ),
              cell(r.grNo, ttf, bgColor: bg),
              cell(
                r.poNo ?? '-',
                ttfR,
                align: pw.Alignment.center,
                bgColor: bg,
              ),
              cell(r.supplierName, ttfR, bgColor: bg),
              cell(r.warehouseName, ttfR, bgColor: bg),
              cell(
                _date.format(r.grDate),
                ttfR,
                align: pw.Alignment.center,
                bgColor: bg,
              ),
              cell(
                _statusLabel(r.status),
                ttf,
                align: pw.Alignment.center,
                color: sc,
                bgColor: bg,
              ),
              cell(
                '${r.items?.length ?? 0}',
                ttfR,
                align: pw.Alignment.center,
                bgColor: bg,
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
    required pw.Font ttfR,
  }) => pw.Container(
    padding: const pw.EdgeInsets.only(top: 6),
    decoration: const pw.BoxDecoration(
      border: pw.Border(top: pw.BorderSide(color: _kBorder, width: 0.5)),
    ),
    child: pw.Text(
      '$companyName — รายงานการรับสินค้า',
      style: pw.TextStyle(font: ttfR, fontSize: 7, color: _kSub),
    ),
  );
}
