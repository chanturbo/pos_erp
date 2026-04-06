// lib/features/promotions/presentation/pages/coupon_pdf_report.dart
//
// CouponPdfBuilder — สร้าง PDF รายงานคูปอง
// Portrait A4, 30 rows/page
//

import 'package:intl/intl.dart';
import 'package:qr/qr.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../settings/shared/settings_defaults.dart';
import '../../data/models/promotion_model.dart';

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

// Colors retained for CouponCardPdfBuilder (do not remove)
const _kPrimary = PdfColor.fromInt(0xFFE8622A);
const _kNavy = PdfColor.fromInt(0xFF16213E);
const _kTextSub = PdfColor.fromInt(0xFF666666);

// ─────────────────────────────────────────────────────────────────
// CouponPdfBuilder — สร้าง pw.Document เท่านั้น
// ─────────────────────────────────────────────────────────────────
class CouponPdfBuilder {
  static Future<pw.Document> build(
    List<CouponModel> coupons, {
    String? companyName,
  }) async {
    final effectiveCompanyName =
        companyName ?? await SettingsStorage.getCompanyName();
    final doc = pw.Document(title: 'รายงานคูปอง', author: effectiveCompanyName);

    final ttf = await PdfGoogleFonts.notoSansThaiBold();
    final ttfRegular = await PdfGoogleFonts.notoSansThaiRegular();
    final printedAt = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    // คำนวณ summary stats
    int valid = 0, used = 0, expired = 0;
    for (final c in coupons) {
      if (c.isUsed) {
        used++;
      } else if (c.isExpired) {
        expired++;
      } else {
        valid++;
      }
    }

    final summaryLine =
        'ทั้งหมด ${coupons.length} ใบ   ใช้ได้ $valid ใบ   ใช้แล้ว $used ใบ   หมดอายุ $expired ใบ';

    // แบ่ง page (30 rows/page — portrait A4)
    final rowsPerPage = await SettingsStorage.getReportRowsPerPage();
    final pages = <List<CouponModel>>[];
    for (var i = 0; i < coupons.length; i += rowsPerPage) {
      pages.add(
        coupons.sublist(
          i,
          (i + rowsPerPage) > coupons.length ? coupons.length : i + rowsPerPage,
        ),
      );
    }
    if (pages.isEmpty) pages.add([]);
    final totalPages = pages.length;

    for (var pageIdx = 0; pageIdx < pages.length; pageIdx++) {
      final pageCoupons = pages[pageIdx];
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
                reportTitle: 'รายงานคูปอง',
                printedAt: printedAt,
                page: pageIdx + 1,
                totalPages: totalPages,
                ttf: ttf,
                ttfRegular: ttfRegular,
                summaryLine: summaryLine,
              ),
              _buildTable(
                pageCoupons,
                startNo: startNo,
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

  // ── Page Header ───────────────────────────────────────────────
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

  // ── Table ─────────────────────────────────────────────────────
  static pw.Widget _buildTable(
    List<CouponModel> coupons, {
    required int startNo,
    required pw.Font ttf,
    required pw.Font ttfRegular,
  }) {
    const colWidths = {
      0: pw.FixedColumnWidth(30), // ลำดับ
      1: pw.FixedColumnWidth(110), // รหัสคูปอง
      2: pw.FlexColumnWidth(2.0), // โปรโมชั่น
      3: pw.FixedColumnWidth(55), // สถานะ
      4: pw.FixedColumnWidth(80), // สร้างเมื่อ
      5: pw.FixedColumnWidth(80), // หมดอายุ
      6: pw.FlexColumnWidth(2.0), // ผู้ใช้/ใช้เมื่อ
    };

    final dateFmt = DateFormat('dd/MM/yyyy HH:mm');

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
          style: pw.TextStyle(font: font, fontSize: 8, color: color ?? _kText),
        ),
      );
    }

    String statusLabel(CouponModel c) {
      if (c.isUsed) return 'ใช้แล้ว';
      if (c.isExpired) return 'หมดอายุ';
      return 'ใช้ได้';
    }

    PdfColor statusColor(CouponModel c) {
      if (c.isUsed) return _kSub;
      if (c.isExpired) return _kError;
      return _kSuccess;
    }

    String usedByLabel(String? usedBy) {
      if (usedBy == null || usedBy.isEmpty) return '-';
      if (usedBy == 'WALK_IN') return 'ลูกค้าทั่วไป';
      return usedBy;
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
                    'รหัสคูปอง',
                    'โปรโมชั่น',
                    'สถานะ',
                    'สร้างเมื่อ',
                    'หมดอายุ',
                    'ผู้ใช้/ใช้เมื่อ',
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
        ...coupons.asMap().entries.map((e) {
          final i = e.key;
          final c = e.value;
          final rowBg = i.isEven ? _kAltRow : null;
          final sColor = statusColor(c);

          // ผู้ใช้/ใช้เมื่อ column
          final usedByText = c.isUsed
              ? '${usedByLabel(c.usedBy)}\n${c.usedAt != null ? dateFmt.format(c.usedAt!) : '-'}'
              : '-';

          return pw.TableRow(
            children: [
              cell(
                '${startNo + i}',
                ttfRegular,
                align: pw.Alignment.center,
                bgColor: rowBg,
              ),
              cell(c.couponCode, ttf, bgColor: rowBg),
              cell(c.promotionName ?? '-', ttfRegular, bgColor: rowBg),
              cell(
                statusLabel(c),
                ttf,
                align: pw.Alignment.center,
                color: sColor,
                bgColor: rowBg,
              ),
              cell(
                dateFmt.format(c.createdAt),
                ttfRegular,
                align: pw.Alignment.center,
                bgColor: rowBg,
              ),
              cell(
                c.expiresAt != null ? dateFmt.format(c.expiresAt!) : 'ไม่จำกัด',
                ttfRegular,
                align: pw.Alignment.center,
                bgColor: rowBg,
              ),
              cell(usedByText, ttfRegular, bgColor: rowBg),
            ],
          );
        }),
      ],
    );
  }

  // ── Footer ────────────────────────────────────────────────────
  static pw.Widget _buildFooter({
    required String companyName,
    required pw.Font ttfRegular,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _kBorder, width: 0.5)),
      ),
      child: pw.Text(
        '$companyName — รายงานคูปอง',
        style: pw.TextStyle(font: ttfRegular, fontSize: 7, color: _kSub),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// CouponPaperSize
// ─────────────────────────────────────────────────────────────────
enum CouponPaperSize {
  a6, // A6 landscape (148×105 mm) — 1 ใบ/หน้า
  a4, // A4 portrait  (210×297 mm) — 1 ใบใหญ่ (เดี่ยว) / 2×4 = 8 ใบ/หน้า (หลายใบ)
}

// ─────────────────────────────────────────────────────────────────
// CouponCardPdfBuilder
// ─────────────────────────────────────────────────────────────────
class CouponCardPdfBuilder {
  // ── A4 grid constants ──────────────────────────────────────────
  static const _cols = 2;
  static const _rows = 4;
  static const _margin = 20.0;
  static const _gap = 8.0;

  // ── Page dimensions (points) ───────────────────────────────────
  static const _a4W = 595.28;
  static const _a4H = 841.89;
  static const _a6LW = 419.53; // A6 landscape width
  static const _a6LH = 297.64; // A6 landscape height

  // ── Derived A4 layout constants ────────────────────────────────
  static const _usableW = _a4W - _margin * 2; // 555.28
  static const _usableH = _a4H - _margin * 2; // 801.89
  static const _cardWA4 = (_usableW - _gap) / _cols; // 273.64
  static const _cardHA4 = (_usableH - (_rows - 1) * _gap) / _rows; // 194.47
  static const _scaleA4Grid = _cardWA4 / _a6LW; // ≈ 0.652
  static const _scaleA4Single = _usableW / _a6LW; // ≈ 1.323

  // ── build — single coupon ──────────────────────────────────────
  static Future<pw.Document> build(
    CouponModel coupon, {
    String? companyName,
    String? discountLabel,
    CouponPaperSize paperSize = CouponPaperSize.a6,
  }) async {
    final effectiveCompanyName =
        companyName ?? await SettingsStorage.getCompanyName();
    final ttf = await PdfGoogleFonts.notoSansThaiBold();
    final ttfRegular = await PdfGoogleFonts.notoSansThaiRegular();
    final dateFmt = DateFormat('dd/MM/yyyy');
    final doc = pw.Document(title: 'คูปองส่วนลด — ${coupon.couponCode}');

    if (paperSize == CouponPaperSize.a6) {
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a6.landscape,
          margin: pw.EdgeInsets.zero,
          build: (ctx) => _buildCard(
            coupon: coupon,
            companyName: effectiveCompanyName,
            discountLabel: discountLabel,
            ttf: ttf,
            ttfRegular: ttfRegular,
            dateFmt: dateFmt,
            scale: 1.0,
          ),
        ),
      );
    } else {
      // A4: card scaled to full usable width, centered at top
      const cardH = _a6LH * _scaleA4Single;
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(_margin),
          build: (ctx) => pw.Align(
            alignment: pw.Alignment.topCenter,
            child: pw.SizedBox(
              width: _usableW,
              height: cardH,
              child: _buildCard(
                coupon: coupon,
                companyName: effectiveCompanyName,
                discountLabel: discountLabel,
                ttf: ttf,
                ttfRegular: ttfRegular,
                dateFmt: dateFmt,
                scale: _scaleA4Single,
              ),
            ),
          ),
        ),
      );
    }
    return doc;
  }

  // ── buildMultiple — หลายคูปอง ──────────────────────────────────
  static Future<pw.Document> buildMultiple(
    List<CouponModel> coupons, {
    String? companyName,
    CouponPaperSize paperSize = CouponPaperSize.a6,
  }) async {
    final effectiveCompanyName =
        companyName ?? await SettingsStorage.getCompanyName();
    if (paperSize == CouponPaperSize.a6) {
      return _buildA6Multiple(coupons, companyName: effectiveCompanyName);
    } else {
      return _buildA4Multiple(coupons, companyName: effectiveCompanyName);
    }
  }

  // ── A6: 1 card per page ────────────────────────────────────────
  static Future<pw.Document> _buildA6Multiple(
    List<CouponModel> coupons, {
    required String companyName,
  }) async {
    final ttf = await PdfGoogleFonts.notoSansThaiBold();
    final ttfRegular = await PdfGoogleFonts.notoSansThaiRegular();
    final dateFmt = DateFormat('dd/MM/yyyy');
    final doc = pw.Document(title: 'คูปองส่วนลด (${coupons.length} ใบ)');

    for (final coupon in coupons) {
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a6.landscape,
          margin: pw.EdgeInsets.zero,
          build: (ctx) => _buildCard(
            coupon: coupon,
            companyName: companyName,
            ttf: ttf,
            ttfRegular: ttfRegular,
            dateFmt: dateFmt,
            scale: 1.0,
          ),
        ),
      );
    }
    return doc;
  }

  // ── A4: 2×4 grid = 8 cards per page ───────────────────────────
  static Future<pw.Document> _buildA4Multiple(
    List<CouponModel> coupons, {
    required String companyName,
  }) async {
    final ttf = await PdfGoogleFonts.notoSansThaiBold();
    final ttfRegular = await PdfGoogleFonts.notoSansThaiRegular();
    final dateFmt = DateFormat('dd/MM/yyyy');
    final doc = pw.Document(title: 'คูปองส่วนลด (${coupons.length} ใบ) — A4');
    const perPage = _cols * _rows; // 8

    for (var start = 0; start < coupons.length; start += perPage) {
      final end = (start + perPage).clamp(0, coupons.length);
      final batch = coupons.sublist(start, end);

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(_margin),
          build: (ctx) {
            final rowWidgets = <pw.Widget>[];
            for (var r = 0; r < _rows; r++) {
              final cells = <pw.Widget>[];
              for (var c = 0; c < _cols; c++) {
                final idx = r * _cols + c;
                if (c > 0) cells.add(pw.SizedBox(width: _gap));
                cells.add(
                  pw.SizedBox(
                    width: _cardWA4,
                    height: _cardHA4,
                    child: idx < batch.length
                        ? _buildCard(
                            coupon: batch[idx],
                            companyName: companyName,
                            ttf: ttf,
                            ttfRegular: ttfRegular,
                            dateFmt: dateFmt,
                            scale: _scaleA4Grid,
                          )
                        : pw.Container(
                            decoration: pw.BoxDecoration(
                              border: pw.Border.all(
                                color: _kBorder,
                                width: 0.5,
                              ),
                              borderRadius: pw.BorderRadius.circular(6),
                            ),
                          ),
                  ),
                );
              }
              if (r > 0) rowWidgets.add(pw.SizedBox(height: _gap));
              rowWidgets.add(pw.Row(children: cells));
            }
            return pw.Column(children: rowWidgets);
          },
        ),
      );
    }
    return doc;
  }

  // ── _buildCard — scalable card widget ─────────────────────────
  static pw.Widget _buildCard({
    required CouponModel coupon,
    required String companyName,
    required pw.Font ttf,
    required pw.Font ttfRegular,
    required DateFormat dateFmt,
    String? discountLabel,
    double scale = 1.0,
  }) {
    final leftW = 160 * scale;
    final hPad = 16 * scale;
    final vPad = 20 * scale;
    final qrPad = 8 * scale;
    final qrSize = 100 * scale;
    final qrSpacing = 10 * scale;
    final innerPad = 20 * scale;
    final titleGap = 4 * scale;
    final codeFs = (11 * scale).clamp(6.0, 20.0);
    final titleFs = (18 * scale).clamp(9.0, 30.0);
    final companyFs = (9 * scale).clamp(5.0, 16.0);
    final promoFs = (10 * scale).clamp(6.0, 18.0);
    final expiryFs = (8 * scale).clamp(5.0, 14.0);
    final qrWidget = _buildQrWidget(coupon.couponCode, qrSize);

    return pw.Container(
      decoration: const pw.BoxDecoration(color: PdfColors.white),
      child: pw.Row(
        children: [
          // ── ฝั่งซ้าย: QR + code ────────────────────────────
          pw.Container(
            width: leftW,
            color: _kNavy,
            padding: pw.EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Container(
                  padding: pw.EdgeInsets.all(qrPad),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.circular(qrPad),
                  ),
                  child: qrWidget,
                ),
                pw.SizedBox(height: qrSpacing),
                pw.Text(
                  coupon.couponCode,
                  style: pw.TextStyle(
                    font: ttf,
                    fontSize: codeFs,
                    color: PdfColors.white,
                    letterSpacing: 2,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              ],
            ),
          ),

          // ── ฝั่งขวา: รายละเอียด ────────────────────────────
          pw.Expanded(
            child: pw.Padding(
              padding: pw.EdgeInsets.all(innerPad),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        companyName,
                        style: pw.TextStyle(
                          font: ttfRegular,
                          fontSize: companyFs,
                          color: _kTextSub,
                        ),
                      ),
                      pw.SizedBox(height: titleGap),
                      pw.Text(
                        'คูปองส่วนลด',
                        style: pw.TextStyle(
                          font: ttf,
                          fontSize: titleFs,
                          color: _kNavy,
                        ),
                      ),
                    ],
                  ),
                  if (discountLabel != null)
                    pw.Container(
                      padding: pw.EdgeInsets.symmetric(
                        horizontal: 12 * scale,
                        vertical: 8 * scale,
                      ),
                      decoration: pw.BoxDecoration(
                        color: _kPrimary,
                        borderRadius: pw.BorderRadius.circular(6),
                      ),
                      child: pw.Text(
                        discountLabel,
                        style: pw.TextStyle(
                          font: ttf,
                          fontSize: titleFs,
                          color: PdfColors.white,
                        ),
                      ),
                    ),
                  if (coupon.promotionName != null)
                    pw.Text(
                      coupon.promotionName!,
                      style: pw.TextStyle(
                        font: ttfRegular,
                        fontSize: promoFs,
                        color: _kTextSub,
                      ),
                    ),
                  pw.Container(
                    padding: pw.EdgeInsets.only(top: 8 * scale),
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(
                        top: pw.BorderSide(color: _kBorder, width: 0.5),
                      ),
                    ),
                    child: pw.Text(
                      coupon.expiresAt != null
                          ? 'ใช้ได้ถึง: ${dateFmt.format(coupon.expiresAt!)}'
                          : 'ไม่มีวันหมดอายุ',
                      style: pw.TextStyle(
                        font: ttfRegular,
                        fontSize: expiryFs,
                        color: _kTextSub,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── _buildQrWidget — draw QR directly on PDF canvas ───────────
  static pw.Widget _buildQrWidget(String data, double size) {
    final qrCode = QrCode.fromData(
      data: data,
      errorCorrectLevel: QrErrorCorrectLevel.H,
    );
    final qrImage = QrImage(qrCode);
    final moduleCount = qrImage.moduleCount;

    return pw.CustomPaint(
      size: PdfPoint(size, size),
      painter: (canvas, box) {
        final moduleSize = size / moduleCount;
        canvas.setFillColor(PdfColors.black);
        for (var row = 0; row < moduleCount; row++) {
          for (var col = 0; col < moduleCount; col++) {
            if (qrImage.isDark(row, col)) {
              final x = col * moduleSize;
              final y = (moduleCount - row - 1) * moduleSize;
              canvas
                ..drawRect(x, y, moduleSize, moduleSize)
                ..fillPath();
            }
          }
        }
      },
    );
  }
}
