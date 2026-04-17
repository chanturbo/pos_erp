// lib/features/purchases/presentation/pages/goods_receipt_pdf_report.dart
//
// GoodsReceiptPdfBuilder — รายงาน PDF รายการรับสินค้า
// แสดงทั้ง GR header และรายการสินค้า (items) ในแต่ละใบ

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../settings/shared/settings_defaults.dart';
import '../../data/models/goods_receipt_model.dart';
import '../../data/models/goods_receipt_item_model.dart';

// ── Colors ────────────────────────────────────────────────────────
const _kBorder     = PdfColor.fromInt(0xFFCCCCCC);
const _kItemBorder = PdfColor.fromInt(0xFFE0E0E0);
const _kGrBg       = PdfColor.fromInt(0xFF16213E); // navy — GR group header
const _kHdrBg      = PdfColor.fromInt(0xFF2A3A60); // lighter navy — item table header
const _kAltRow     = PdfColor.fromInt(0xFFF3F6FF); // item alternating row
const _kText       = PdfColors.black;
const _kSub        = PdfColor.fromInt(0xFF555555);
const _kWhite      = PdfColors.white;
const _kDraft      = PdfColor.fromInt(0xFFE65100);
const _kConfirmed  = PdfColor.fromInt(0xFF1B5E20);
const _kGreen      = PdfColor.fromInt(0xFF2E7D32);
const _kOrange     = PdfColor.fromInt(0xFFE65100);
const _kInfo       = PdfColor.fromInt(0xFF1565C0);

class GoodsReceiptPdfBuilder {
  static final _dateFmt     = DateFormat('dd/MM/yy');
  static final _moneyFmt    = NumberFormat('#,##0.00', 'th_TH');
  static final _qtyFmt      = NumberFormat('#,##0.##', 'th_TH');
  static final _dateTimeFmt = DateFormat('dd/MM/yyyy HH:mm');

  static PdfColor _statusColor(String s) =>
      s == 'CONFIRMED' ? _kConfirmed : _kDraft;

  static String _statusLabel(String s) =>
      s == 'CONFIRMED' ? 'ยืนยันแล้ว' : 'ร่าง';

  // ── Build ──────────────────────────────────────────────────────
  static Future<pw.Document> build(
    List<GoodsReceiptModel> receipts, {
    String? companyName,
  }) async {
    final company   = companyName ?? await SettingsStorage.getCompanyName();
    final ttf       = await PdfGoogleFonts.notoSansThaiBold();
    final ttfR      = await PdfGoogleFonts.notoSansThaiRegular();
    final printedAt = _dateTimeFmt.format(DateTime.now());

    final totalItems = receipts.fold<int>(
        0, (s, r) => s + (r.items?.length ?? r.itemCount));
    final confirmedCount = receipts.where((r) => r.status == 'CONFIRMED').length;

    final doc = pw.Document(
      title: 'รายงานการรับสินค้า',
      author: company,
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(24, 24, 24, 28),
        // ── Page header (repeats every page) ──
        header: (ctx) => _buildPageHeader(
          company: company,
          printedAt: printedAt,
          totalReceipts: receipts.length,
          confirmedCount: confirmedCount,
          totalItems: totalItems,
          pageNumber: ctx.pageNumber,
          pagesCount: ctx.pagesCount,
          ttf: ttf,
          ttfR: ttfR,
        ),
        // ── Page footer ──
        footer: (ctx) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(company,
              style: pw.TextStyle(font: ttfR, fontSize: 7, color: _kSub)),
        ),
        build: (_) => [
          for (final r in receipts) ...[
            _buildGrHeader(r, ttf, ttfR),
            pw.SizedBox(height: 3),
            _buildItemsTable(r.items ?? [], ttf, ttfR),
            pw.SizedBox(height: 10),
          ],
        ],
      ),
    );

    return doc;
  }

  // ── Page Header ───────────────────────────────────────────────
  static pw.Widget _buildPageHeader({
    required String company,
    required String printedAt,
    required int totalReceipts,
    required int confirmedCount,
    required int totalItems,
    required int pageNumber,
    required int pagesCount,
    required pw.Font ttf,
    required pw.Font ttfR,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('พิมพ์เมื่อ $printedAt',
                style: pw.TextStyle(font: ttfR, fontSize: 8, color: _kSub)),
            pw.Text('หน้าที่ $pageNumber / $pagesCount',
                style: pw.TextStyle(font: ttfR, fontSize: 8, color: _kSub)),
          ],
        ),
        pw.SizedBox(height: 3),
        pw.Center(
          child: pw.Text(company,
              style: pw.TextStyle(font: ttfR, fontSize: 9, color: _kSub)),
        ),
        pw.SizedBox(height: 2),
        pw.Center(
          child: pw.Text('รายงานการรับสินค้า',
              style: pw.TextStyle(font: ttf, fontSize: 14, color: _kText)),
        ),
        pw.SizedBox(height: 6),
        // Summary bar
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: pw.BoxDecoration(
            color: const PdfColor.fromInt(0xFFF5F5F5),
            border: pw.Border.all(color: _kBorder, width: 0.5),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
          ),
          child: pw.Row(
            children: [
              _summaryCell('จำนวนใบรับ', '$totalReceipts ใบ', _kInfo, ttf, ttfR),
              _divider(),
              _summaryCell('ยืนยันแล้ว', '$confirmedCount ใบ', _kConfirmed, ttf, ttfR),
              _divider(),
              _summaryCell('รายการสินค้ารวม', '$totalItems รายการ', _kInfo, ttf, ttfR),
            ],
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Container(height: 0.5, color: _kBorder),
        pw.SizedBox(height: 6),
      ],
    );
  }

  static pw.Widget _summaryCell(
      String label, String value, PdfColor vc, pw.Font ttf, pw.Font ttfR) {
    return pw.Expanded(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(label,
              style: pw.TextStyle(font: ttfR, fontSize: 8, color: _kSub)),
          pw.SizedBox(height: 2),
          pw.Text(value,
              style: pw.TextStyle(font: ttf, fontSize: 10, color: vc)),
        ],
      ),
    );
  }

  static pw.Widget _divider() =>
      pw.Container(width: 0.5, height: 28, color: _kBorder);

  // ── GR Group Header bar ───────────────────────────────────────
  static pw.Widget _buildGrHeader(
      GoodsReceiptModel r, pw.Font ttf, pw.Font ttfR) {
    final statusColor = _statusColor(r.status);
    final itemCount   = r.items?.length ?? r.itemCount;

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: const pw.BoxDecoration(color: _kGrBg),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          // GR number
          pw.Text(r.grNo,
              style: pw.TextStyle(font: ttf, fontSize: 10, color: _kWhite)),
          pw.SizedBox(width: 8),
          // Status badge
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: pw.BoxDecoration(
              color: statusColor,
              borderRadius: pw.BorderRadius.circular(3),
            ),
            child: pw.Text(
              _statusLabel(r.status),
              style: pw.TextStyle(font: ttf, fontSize: 7, color: _kWhite),
            ),
          ),
          pw.SizedBox(width: 12),
          // Info fields
          _grInfoText('ผู้จำหน่าย: ', r.supplierName, ttf, ttfR),
          pw.SizedBox(width: 10),
          _grInfoText('วันที่รับ: ', _dateFmt.format(r.grDate), ttf, ttfR),
          if (r.poNo != null) ...[
            pw.SizedBox(width: 10),
            _grInfoText('PO: ', r.poNo!, ttf, ttfR),
          ],
          pw.SizedBox(width: 10),
          _grInfoText('คลัง: ', r.warehouseName, ttf, ttfR),
          pw.Spacer(),
          // Item count
          pw.Text(
            '$itemCount รายการ',
            style: pw.TextStyle(
                font: ttf,
                fontSize: 8,
                color: const PdfColor.fromInt(0xFFB0C4DE)),
          ),
        ],
      ),
    );
  }

  static pw.Widget _grInfoText(
      String label, String value, pw.Font ttf, pw.Font ttfR) {
    return pw.Row(children: [
      pw.Text(label,
          style: pw.TextStyle(
              font: ttfR, fontSize: 8, color: const PdfColor.fromInt(0xFF8A9BC0))),
      pw.Text(value,
          style: pw.TextStyle(font: ttf, fontSize: 8, color: _kWhite)),
    ]);
  }

  // ── Items Sub-table ────────────────────────────────────────────
  static pw.Widget _buildItemsTable(
    List<GoodsReceiptItemModel> items,
    pw.Font ttf,
    pw.Font ttfR,
  ) {
    if (items.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        color: const PdfColor.fromInt(0xFFFAFAFA),
        child: pw.Text('ไม่มีรายการสินค้า',
            style: pw.TextStyle(font: ttfR, fontSize: 8, color: _kSub)),
      );
    }

    // Check if any item has lot/expiry to decide column visibility
    final hasLot    = items.any((i) => i.lotNumber != null && i.lotNumber!.isNotEmpty);
    final hasExpiry = items.any((i) => i.expiryDate != null);

    // Column widths — A4 portrait usable ~547pt
    final colWidths = <int, pw.TableColumnWidth>{
      0: const pw.FixedColumnWidth(20),   // #
      1: const pw.FixedColumnWidth(56),   // รหัสสินค้า
      2: const pw.FlexColumnWidth(1),     // ชื่อสินค้า (flex)
      3: const pw.FixedColumnWidth(36),   // หน่วย
      4: const pw.FixedColumnWidth(46),   // สั่ง
      5: const pw.FixedColumnWidth(46),   // รับ
      6: const pw.FixedColumnWidth(54),   // ราคา/หน่วย
      7: const pw.FixedColumnWidth(60),   // มูลค่า
    };
    if (hasLot)    colWidths[8]  = const pw.FixedColumnWidth(52); // Lot#
    if (hasExpiry) colWidths[hasLot ? 9 : 8] = const pw.FixedColumnWidth(52); // EXP

    // Build header row labels
    final headers = ['#', 'รหัสสินค้า', 'ชื่อสินค้า', 'หน่วย', 'สั่ง', 'รับ', 'ราคา/หน่วย', 'มูลค่า'];
    if (hasLot)    headers.add('Lot#');
    if (hasExpiry) headers.add('วันหมดอายุ');

    final headerRow = pw.TableRow(
      decoration: const pw.BoxDecoration(color: _kHdrBg),
      children: headers.asMap().entries.map((e) {
        final alignRight = e.key >= 4 && e.key <= 7;
        return pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
          child: pw.Text(e.value,
              textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
              style: pw.TextStyle(font: ttf, fontSize: 7.5, color: _kWhite)),
        );
      }).toList(),
    );

    final dataRows = items.asMap().entries.map((entry) {
      final idx  = entry.key;
      final item = entry.value;
      final bg   = idx.isOdd ? _kAltRow : PdfColors.white;
      final qtyDiff = item.receivedQuantity - item.orderedQuantity;
      final recvColor = qtyDiff < -0.001 ? _kOrange
                      : qtyDiff > 0.001  ? _kInfo
                      : _kGreen;

      final cells = <pw.Widget>[
        _iCell('${idx + 1}', ttfR, bg: bg, align: pw.TextAlign.center, color: _kSub),
        _iCell(item.productCode, ttfR, bg: bg, color: _kSub),
        _iCell(item.productName, ttfR, bg: bg),
        _iCell(item.unit, ttfR, bg: bg, align: pw.TextAlign.center),
        _iCell(_qtyFmt.format(item.orderedQuantity), ttfR, bg: bg, align: pw.TextAlign.right),
        _iCell(_qtyFmt.format(item.receivedQuantity), ttf, bg: bg,
            align: pw.TextAlign.right, color: recvColor),
        _iCell(_moneyFmt.format(item.unitPrice), ttfR, bg: bg, align: pw.TextAlign.right),
        _iCell(_moneyFmt.format(item.amount), ttf, bg: bg,
            align: pw.TextAlign.right, color: _kText),
      ];

      if (hasLot) {
        cells.add(_iCell(
          item.lotNumber?.isNotEmpty == true ? item.lotNumber! : '-',
          ttfR, bg: bg, align: pw.TextAlign.center, color: _kSub,
        ));
      }
      if (hasExpiry) {
        cells.add(_iCell(
          item.expiryDate != null ? _dateFmt.format(item.expiryDate!) : '-',
          ttfR, bg: bg, align: pw.TextAlign.center, color: _kSub,
        ));
      }

      return pw.TableRow(children: cells);
    }).toList();

    // Total row
    final totalAmount = items.fold<double>(0, (s, i) => s + i.amount);
    final totalOrdered  = items.fold<double>(0, (s, i) => s + i.orderedQuantity);
    final totalReceived = items.fold<double>(0, (s, i) => s + i.receivedQuantity);
    final totalColCount = headers.length;

    final totalRow = pw.TableRow(
      decoration: const pw.BoxDecoration(
        color: PdfColor.fromInt(0xFFEEF2F8),
      ),
      children: List.generate(totalColCount, (i) {
        if (i == 1) {
          return _iCell('รวม', ttf, align: pw.TextAlign.left, color: _kText);
        }
        if (i == 4) return _iCell(_qtyFmt.format(totalOrdered), ttf, align: pw.TextAlign.right);
        if (i == 5) return _iCell(_qtyFmt.format(totalReceived), ttf, align: pw.TextAlign.right, color: _kGreen);
        if (i == 7) return _iCell(_moneyFmt.format(totalAmount), ttf, align: pw.TextAlign.right, color: _kInfo);
        return _iCell('', ttfR);
      }),
    );

    return pw.Table(
      columnWidths: colWidths,
      border: pw.TableBorder.all(color: _kItemBorder, width: 0.5),
      children: [headerRow, ...dataRows, totalRow],
    );
  }

  static pw.Widget _iCell(
    String text,
    pw.Font font, {
    PdfColor? bg,
    pw.TextAlign align = pw.TextAlign.left,
    PdfColor color = _kText,
  }) {
    return pw.Container(
      color: bg,
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      alignment: align == pw.TextAlign.right
          ? pw.Alignment.centerRight
          : align == pw.TextAlign.center
              ? pw.Alignment.center
              : pw.Alignment.centerLeft,
      child: pw.Text(text,
          style: pw.TextStyle(font: font, fontSize: 8, color: color)),
    );
  }
}
