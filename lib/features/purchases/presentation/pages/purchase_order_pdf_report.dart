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
import '../../data/models/purchase_order_item_model.dart';
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

    if (orders.length == 1) {
      final order = orders.first;
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (_) => [
            _buildHeader(
              companyName: effectiveCompanyName,
              printedAt: printedAt,
              page: 1,
              totalPages: 1,
              summaryLine: summaryLine,
              summaryRow: summaryRow,
              ttf: ttf,
              ttfR: ttfRegular,
            ),
            _buildSingleOrderSection(order, ttf: ttf, ttfR: ttfRegular),
          ],
          footer: (_) => _buildFooter(
            companyName: effectiveCompanyName,
            ttfR: ttfRegular,
          ),
        ),
      );
      return doc;
    }

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

  static pw.Widget _buildSingleOrderSection(
    PurchaseOrderModel order, {
    required pw.Font ttf,
    required pw.Font ttfR,
  }) {
    pw.Widget metaCell(String label, String value) => pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: pw.BoxDecoration(
          color: const PdfColor.fromInt(0xFFF8F8F8),
          border: pw.Border.all(color: _kBorder, width: 0.5),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label,
              style: pw.TextStyle(font: ttfR, fontSize: 8, color: _kSub),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              value,
              style: pw.TextStyle(font: ttf, fontSize: 9, color: _kText),
            ),
          ],
        ),
      ),
    );

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Text(
          'รายละเอียดใบสั่งซื้อ ${order.poNo}',
          style: pw.TextStyle(font: ttf, fontSize: 12, color: _kNavy),
        ),
        pw.SizedBox(height: 8),
        pw.Row(
          children: [
            metaCell('เลขที่ PO', order.poNo),
            pw.SizedBox(width: 8),
            metaCell('วันที่สั่งซื้อ', _date.format(order.poDate)),
            pw.SizedBox(width: 8),
            metaCell(
              'วันกำหนดส่ง',
              order.deliveryDate != null ? _date.format(order.deliveryDate!) : '-',
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Row(
          children: [
            metaCell('ผู้จัดจำหน่าย', order.supplierName ?? '-'),
            pw.SizedBox(width: 8),
            metaCell('คลัง', order.warehouseName ?? '-'),
            pw.SizedBox(width: 8),
            metaCell('สถานะ', _statusLabel(order.status)),
          ],
        ),
        if (order.remark != null && order.remark!.trim().isNotEmpty) ...[
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: pw.BoxDecoration(
              color: const PdfColor.fromInt(0xFFF8F8F8),
              border: pw.Border.all(color: _kBorder, width: 0.5),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'หมายเหตุ',
                  style: pw.TextStyle(font: ttfR, fontSize: 8, color: _kSub),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  order.remark!,
                  style: pw.TextStyle(font: ttfR, fontSize: 9, color: _kText),
                ),
              ],
            ),
          ),
        ],
        pw.SizedBox(height: 10),
        _buildItemsTable(order.items ?? const [], ttf: ttf, ttfR: ttfR),
        pw.SizedBox(height: 10),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Container(
              width: 210,
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: const PdfColor.fromInt(0xFFF8F8F8),
                border: pw.Border.all(color: _kBorder, width: 0.5),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
              ),
              child: pw.Column(
                children: [
                  _buildAmountRow('ยอดก่อนส่วนลด', '฿${_money.format(order.subtotal)}', ttfR),
                  _buildAmountRow(
                    'ส่วนลด',
                    order.discountAmount > 0
                        ? '-฿${_money.format(order.discountAmount)}'
                        : '-',
                    ttfR,
                  ),
                  _buildAmountRow('VAT', '฿${_money.format(order.vatAmount)}', ttfR),
                  pw.Divider(color: _kBorder, height: 8),
                  _buildAmountRow(
                    'ยอดรวมสุทธิ',
                    '฿${_money.format(order.totalAmount)}',
                    ttf,
                    color: _kDone,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildItemsTable(
    List<PurchaseOrderItemModel> items, {
    required pw.Font ttf,
    required pw.Font ttfR,
  }) {
    if (items.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _kBorder, width: 0.5),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
        ),
        child: pw.Text(
          'ไม่พบรายการสินค้าในใบสั่งซื้อนี้',
          style: pw.TextStyle(font: ttfR, fontSize: 9, color: _kSub),
        ),
      );
    }

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
      columnWidths: const {
        0: pw.FixedColumnWidth(24),
        1: pw.FixedColumnWidth(64),
        2: pw.FlexColumnWidth(1),
        3: pw.FixedColumnWidth(64),
        4: pw.FixedColumnWidth(64),
        5: pw.FixedColumnWidth(72),
      },
      border: pw.TableBorder.all(color: _kBorder, width: 0.5),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _kHdrBg),
          children: [
            cell('#', ttf, align: pw.Alignment.center),
            cell('รหัสสินค้า', ttf),
            cell('สินค้า', ttf),
            cell('จำนวน', ttf, align: pw.Alignment.center),
            cell('ราคา/หน่วย', ttf, align: pw.Alignment.centerRight),
            cell('รวม', ttf, align: pw.Alignment.centerRight),
          ],
        ),
        ...items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final bg = index.isEven ? _kAltRow : null;
          final qty = item.quantity % 1 == 0
              ? item.quantity.toStringAsFixed(0)
              : item.quantity.toStringAsFixed(2);
          return pw.TableRow(
            children: [
              cell('${index + 1}', ttfR, align: pw.Alignment.center, bgColor: bg),
              cell(item.productCode ?? '-', ttfR, bgColor: bg),
              cell(item.productName ?? '-', ttfR, bgColor: bg),
              cell('$qty ${item.unit ?? ''}', ttfR, align: pw.Alignment.center, bgColor: bg),
              cell(
                _money.format(item.unitPrice),
                ttfR,
                align: pw.Alignment.centerRight,
                bgColor: bg,
              ),
              cell(
                _money.format(item.amount),
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

  static pw.Widget _buildAmountRow(
    String label,
    String value,
    pw.Font font, {
    PdfColor color = _kText,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(font: font, fontSize: 8, color: _kSub),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(font: font, fontSize: 8.5, color: color),
          ),
        ],
      ),
    );
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
    child: pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Text(
        companyName,
        style: pw.TextStyle(font: ttfR, fontSize: 7, color: _kSub),
      ),
    ),
  );
}
