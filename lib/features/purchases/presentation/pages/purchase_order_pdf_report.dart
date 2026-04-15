// lib/features/purchases/presentation/pages/purchase_order_pdf_report.dart
//
// PurchaseOrderPdfBuilder — สร้างรายงาน PDF รายการใบสั่งซื้อ
//
// ใช้งาน:
//   PdfReportButton(
//     emptyMessage: 'ไม่มีข้อมูลใบสั่งซื้อ',
//     title:        'รายงานใบสั่งซื้อ',
//     filename:     () => PdfFilename.generate('purchase_order_report'),
//     buildPdf:     () => PurchaseOrderPdfBuilder.build(filtered),
//     hasData:      filtered.isNotEmpty,
//   )

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../settings/shared/settings_defaults.dart';
import '../../data/models/purchase_order_model.dart';

const _kBorder = PdfColor.fromInt(0xFFBBBBBB);
const _kHdrBg = PdfColor.fromInt(0xFFDDDDDD);
const _kAltRow = PdfColor.fromInt(0xFFF5F5F5);
const _kText = PdfColors.black;
const _kSub = PdfColor.fromInt(0xFF555555);
const _kDraft = PdfColor.fromInt(0xFF757575);
const _kApproved = PdfColor.fromInt(0xFF1565C0);
const _kPartial = PdfColor.fromInt(0xFFE65100);
const _kDone = PdfColor.fromInt(0xFF1B5E20);
const _kNavy = PdfColor.fromInt(0xFF16213E);

class PurchaseOrderPdfBuilder {
  static final _money = NumberFormat('#,##0.00');
  static final _date = DateFormat('dd/MM/yy');

  static Future<pw.Document> build(
    List<PurchaseOrderModel> orders, {
    String? companyName,
  }) async {
    final effectiveCompanyName =
        companyName ?? await SettingsStorage.getCompanyName();
    final doc = pw.Document(
      title: 'รายงานใบสั่งซื้อ',
      author: effectiveCompanyName,
    );

    final ttf = await PdfGoogleFonts.notoSansThaiBold();
    final ttfRegular = await PdfGoogleFonts.notoSansThaiRegular();
    final printedAt = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    final totalAmt = orders.fold<double>(0, (s, o) => s + o.totalAmount);
    final totalVat = orders.fold<double>(0, (s, o) => s + o.vatAmount);
    final summaryLine =
        'ทั้งหมด ${orders.length} ใบ   '
        'ร่าง ${_count(orders, 'DRAFT')} ใบ   '
        'อนุมัติแล้ว ${_count(orders, 'APPROVED')} ใบ   '
        'รับบางส่วน ${_count(orders, 'PARTIAL')} ใบ   '
        'เสร็จสิ้น ${_count(orders, 'COMPLETED')} ใบ';

    final summaryRow = _buildSummaryRow(
      total: totalAmt,
      vat: totalVat,
      count: orders.length,
      ttf: ttf,
      ttfR: ttfRegular,
    );

    final rowsPerPage = await SettingsStorage.getPdfReportRowsPerPage(
      PdfReportType.purchaseOrder,
    );
    final pages = <List<PurchaseOrderModel>>[];
    for (var i = 0; i < orders.length; i += rowsPerPage) {
      pages.add(
        orders.sublist(
          i,
          (i + rowsPerPage) > orders.length ? orders.length : i + rowsPerPage,
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

  // ── helpers ──────────────────────────────────────────────────────
  static int _count(List<PurchaseOrderModel> list, String status) =>
      list.where((o) => o.status == status).length;

  static PdfColor _statusColor(String status) {
    switch (status) {
      case 'APPROVED':
        return _kApproved;
      case 'PARTIAL':
        return _kPartial;
      case 'COMPLETED':
        return _kDone;
      default:
        return _kDraft;
    }
  }

  static String _statusLabel(String status) {
    switch (status) {
      case 'DRAFT':
        return 'ร่าง';
      case 'APPROVED':
        return 'อนุมัติ';
      case 'PARTIAL':
        return 'รับบางส่วน';
      case 'COMPLETED':
        return 'เสร็จสิ้น';
      default:
        return status;
    }
  }

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
            'รายงานใบสั่งซื้อ',
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
    required double total,
    required double vat,
    required int count,
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
          cell('จำนวนใบสั่งซื้อ', '$count ใบ', _kNavy),
          pw.Container(width: 0.5, height: 28, color: _kBorder),
          cell('VAT รวม', '฿${_money.format(vat)}', _kApproved),
          pw.Container(width: 0.5, height: 28, color: _kBorder),
          cell('มูลค่ารวมทั้งหมด', '฿${_money.format(total)}', _kDone),
        ],
      ),
    );
  }

  // ── Table ────────────────────────────────────────────────────────
  static pw.Widget _buildTable(
    List<PurchaseOrderModel> orders, {
    required int startNo,
    required pw.Font ttf,
    required pw.Font ttfR,
  }) {
    const colWidths = {
      0: pw.FixedColumnWidth(24), // #
      1: pw.FixedColumnWidth(70), // เลขที่ PO
      2: pw.FlexColumnWidth(1), // ผู้จัดจำหน่าย
      3: pw.FixedColumnWidth(54), // วันที่สั่ง
      4: pw.FixedColumnWidth(54), // วันส่ง
      5: pw.FixedColumnWidth(52), // สถานะ
      6: pw.FixedColumnWidth(72), // ยอดรวม
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
                    'เลขที่ PO',
                    'ผู้จัดจำหน่าย',
                    'วันสั่งซื้อ',
                    'วันกำหนดส่ง',
                    'สถานะ',
                    'ยอดรวม (฿)',
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
        ...orders.asMap().entries.map((e) {
          final i = e.key;
          final o = e.value;
          final bg = i.isEven ? _kAltRow : null;
          final sc = _statusColor(o.status);
          return pw.TableRow(
            children: [
              cell(
                '${startNo + i}',
                ttfR,
                align: pw.Alignment.center,
                bgColor: bg,
              ),
              cell(o.poNo, ttf, bgColor: bg),
              cell(o.supplierName ?? '-', ttfR, bgColor: bg),
              cell(
                _date.format(o.poDate),
                ttfR,
                align: pw.Alignment.center,
                bgColor: bg,
              ),
              cell(
                o.deliveryDate != null ? _date.format(o.deliveryDate!) : '-',
                ttfR,
                align: pw.Alignment.center,
                bgColor: bg,
              ),
              cell(
                _statusLabel(o.status),
                ttf,
                align: pw.Alignment.center,
                color: sc,
                bgColor: bg,
              ),
              cell(
                _money.format(o.totalAmount),
                ttfR,
                align: pw.Alignment.centerRight,
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
      '$companyName — รายงานใบสั่งซื้อ',
      style: pw.TextStyle(font: ttfR, fontSize: 7, color: _kSub),
    ),
  );
}
