// ignore_for_file: avoid_print
//
// product_pdf_report.dart
//
// วิธีใช้งาน:
//   1. เพิ่ม dependencies ใน pubspec.yaml:
//        pdf: ^3.10.8
//        printing: ^5.12.0
//        path_provider: ^2.1.2
//        share_plus: ^9.0.0
//
//   2. import ไฟล์นี้ในหน้าที่ต้องการ:
//        import 'product_pdf_report.dart';
//
//   3. เรียกใช้:
//        await ProductPdfReport.showPreview(context, products);   // แสดง preview
//        await ProductPdfReport.share(products);                  // แชร์ไฟล์

import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../data/models/product_model.dart';

// ─────────────────────────────────────────────────────────────────
// Colors (PDF)
// ─────────────────────────────────────────────────────────────────
const _kPrimary    = PdfColor.fromInt(0xFFE8622A);
const _kNavy       = PdfColor.fromInt(0xFF16213E);
const _kHeaderBg   = PdfColor.fromInt(0xFFF4F4F0);
const _kBorder     = PdfColor.fromInt(0xFFE0E0E0);
const _kTextSub    = PdfColor.fromInt(0xFF666666);
const _kSuccess    = PdfColor.fromInt(0xFF2E7D32);
const _kSuccessBg  = PdfColor.fromInt(0xFFE8F5E9);
const _kInactive   = PdfColor.fromInt(0xFFC62828);
const _kInactiveBg = PdfColor.fromInt(0xFFFFEBEE);
const _kWhite      = PdfColors.white;

// ─────────────────────────────────────────────────────────────────
// ProductPdfReport
// ─────────────────────────────────────────────────────────────────
class ProductPdfReport {
  /// แสดง PDF ใน Preview Dialog
  static Future<void> showPreview(
    BuildContext context,
    List<ProductModel> products, {
    String companyName = 'DEE POS',
  }) async {
    final pdf = await _buildPdf(products, companyName: companyName);
    final bytes = await pdf.save();
    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder: (_) => _PdfPreviewDialog(
        bytes: bytes,
        title: 'รายงานสินค้า',
        filename: _filename(),
      ),
    );
  }

    /// แชร์ PDF ผ่าน OS share sheet (share_plus)
  static Future<void> shareFile(
    List<ProductModel> products, {
    String companyName = 'DEE POS',
  }) async {
    final pdf = await _buildPdf(products, companyName: companyName);
    final bytes = await pdf.save();

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${_filename()}');
    await file.writeAsBytes(bytes);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      subject: 'รายงานสินค้า',
    );
  }

    /// บันทึก PDF ลง Documents และเปิดด้วย OS (รองรับ macOS + Windows Desktop)
  static Future<String> openFile(
    List<ProductModel> products, {
    String companyName = 'DEE POS',
  }) async {
    final pdf = await _buildPdf(products, companyName: companyName);
    final bytes = await pdf.save();

    // บันทึกไปที่ Documents
    Directory dir;
    try {
      dir = await getApplicationDocumentsDirectory();
    } catch (_) {
      dir = await getTemporaryDirectory();
    }

    final file = File('${dir.path}/${_filename()}');
    await file.writeAsBytes(bytes);
    print('✅ PDF saved: ${file.path}');

    // เปิดด้วย OS (macOS: open, Windows: start)
    if (Platform.isMacOS) {
      await Process.run('open', [file.path]);
    } else if (Platform.isWindows) {
      await Process.run('cmd', ['/c', 'start', '', file.path]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [file.path]);
    }

    return file.path;
  }

  // ── ชื่อไฟล์ ──────────────────────────────────────────────────
  static String _filename() {
    final ts = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    return 'product_report_$ts.pdf';
  }

  // ── สร้าง PDF document ────────────────────────────────────────
  static Future<pw.Document> _buildPdf(
    List<ProductModel> products, {
    required String companyName,
  }) async {
    final doc = pw.Document(
      title: 'รายงานรายการสินค้า',
      author: companyName,
    );

    // โหลด font รองรับภาษาไทย (ใช้ font จาก Google Fonts ใน printing package)
    final ttf = await PdfGoogleFonts.notoSansThaiBold();
    final ttfRegular = await PdfGoogleFonts.notoSansThaiRegular();

    final now = DateTime.now();
    final printedAt = DateFormat('dd/MM/yyyy HH:mm').format(now);

    // แบ่ง products เป็น pages (ประมาณ 30 rows/page)
    const rowsPerPage = 30;
    final pages = <List<ProductModel>>[];
    for (var i = 0; i < products.length; i += rowsPerPage) {
      pages.add(products.sublist(
        i,
        (i + rowsPerPage) > products.length ? products.length : i + rowsPerPage,
      ));
    }

    final totalPages = pages.isEmpty ? 1 : pages.length;

    for (var pageIdx = 0; pageIdx < (pages.isEmpty ? 1 : pages.length); pageIdx++) {
      final pageProducts = pages.isEmpty ? <ProductModel>[] : pages[pageIdx];
      final startNo = pageIdx * rowsPerPage + 1;

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(24),
          build: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────
              _buildHeader(
                companyName: companyName,
                printedAt: printedAt,
                total: products.length,
                active: products.where((p) => p.isActive).length,
                ttf: ttf,
                ttfRegular: ttfRegular,
              ),
              pw.SizedBox(height: 12),

              // ── Table ────────────────────────────────────────
              _buildTable(
                pageProducts,
                startNo: startNo,
                ttf: ttf,
                ttfRegular: ttfRegular,
              ),

              pw.Spacer(),

              // ── Footer ───────────────────────────────────────
              _buildFooter(
                page: pageIdx + 1,
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

  // ── Header section ────────────────────────────────────────────
  static pw.Widget _buildHeader({
    required String companyName,
    required String printedAt,
    required int total,
    required int active,
    required pw.Font ttf,
    required pw.Font ttfRegular,
  }) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: _kNavy,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          // Title
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'รายงานรายการสินค้า',
                  style: pw.TextStyle(
                    font: ttf,
                    fontSize: 18,
                    color: _kWhite,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  companyName,
                  style: pw.TextStyle(
                    font: ttfRegular,
                    fontSize: 11,
                    color: PdfColor.fromInt(0xFFAAAAAA),
                  ),
                ),
              ],
            ),
          ),

          // Stats chips
          pw.Row(
            children: [
              _statChip('ทั้งหมด', '$total รายการ', _kPrimary, ttf, ttfRegular),
              pw.SizedBox(width: 8),
              _statChip('ใช้งาน', '$active รายการ', _kSuccess, ttf, ttfRegular),
              pw.SizedBox(width: 8),
              _statChip('ปิดใช้', '${total - active} รายการ',
                  _kInactive, ttf, ttfRegular),
            ],
          ),

          pw.SizedBox(width: 16),

          // Print date
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'พิมพ์เมื่อ',
                style: pw.TextStyle(
                    font: ttfRegular,
                    fontSize: 9,
                    color: PdfColor.fromInt(0xFFAAAAAA)),
              ),
              pw.Text(
                printedAt,
                style: pw.TextStyle(
                    font: ttf, fontSize: 11, color: _kWhite),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _statChip(
    String label,
    String value,
    PdfColor color,
    pw.Font ttf,
    pw.Font ttfRegular,
  ) =>
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: pw.BoxDecoration(
          color: color.shade(0.3),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(value,
                style: pw.TextStyle(font: ttf, fontSize: 13, color: _kWhite)),
            pw.Text(label,
                style: pw.TextStyle(
                    font: ttfRegular,
                    fontSize: 9,
                    color: PdfColor.fromInt(0xFFCCCCCC))),
          ],
        ),
      );

  // ── Table ──────────────────────────────────────────────────────
  static pw.Widget _buildTable(
    List<ProductModel> products, {
    required int startNo,
    required pw.Font ttf,
    required pw.Font ttfRegular,
  }) {
    final headerTextStyle = pw.TextStyle(
      font: ttf,
      fontSize: 9,
      color: _kWhite,
    );

    // Column definitions: [label, flex, align]
    final cols = [
      ('#', 1, pw.Alignment.center),
      ('รหัสสินค้า', 2, pw.Alignment.centerLeft),
      ('ชื่อสินค้า', 5, pw.Alignment.centerLeft),
      ('บาร์โค้ด', 2, pw.Alignment.centerLeft),
      ('หน่วย', 1, pw.Alignment.center),
      ('ราคาขาย', 2, pw.Alignment.centerRight),
      ('ต้นทุน', 2, pw.Alignment.centerRight),
      ('สต๊อก', 1, pw.Alignment.center),
      ('สถานะ', 2, pw.Alignment.center),
    ];

    return pw.Table(
      border: pw.TableBorder.all(
        color: _kBorder,
        width: 0.5,
      ),
      columnWidths: {
        for (var i = 0; i < cols.length; i++)
          i: pw.FlexColumnWidth(cols[i].$2.toDouble()),
      },
      children: [
        // ── Header row ───────────────────────────────────────
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _kNavy),
          children: cols
              .map((col) => pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 6, vertical: 8),
                    alignment: col.$3,
                    child: pw.Text(col.$1, style: headerTextStyle),
                  ))
              .toList(),
        ),

        // ── Data rows ─────────────────────────────────────────
        ...products.asMap().entries.map((entry) {
          final i = entry.key;
          final p = entry.value;
          final isEven = i.isEven;
          final bg = isEven
              ? _kWhite
              : const PdfColor.fromInt(0xFFF9F9F7);

          final cellStyle = pw.TextStyle(
            font: ttfRegular,
            fontSize: 9,
            color: isEven
                ? PdfColors.black
                : PdfColors.black,
          );

          return pw.TableRow(
            decoration: pw.BoxDecoration(color: bg),
            children: [
              // No.
              _cell('${startNo + i}', cellStyle,
                  pw.Alignment.center),
              // รหัส
              _cell(p.productCode, cellStyle.copyWith(
                font: ttfRegular,
                fontSize: 8.5,
              )),
              // ชื่อ
              _cell(p.productName,
                  pw.TextStyle(font: ttfRegular, fontSize: 9,
                      color: PdfColors.black)),
              // บาร์โค้ด
              _cell(p.barcode ?? '-',
                  pw.TextStyle(font: ttfRegular, fontSize: 8,
                      color: _kTextSub)),
              // หน่วย
              _cell(p.baseUnit,
                  pw.TextStyle(font: ttfRegular, fontSize: 8.5,
                      color: PdfColors.black),
                  pw.Alignment.center),
              // ราคาขาย
              _cell(
                '฿${_fmt(p.priceLevel1)}',
                pw.TextStyle(
                  font: ttf,
                  fontSize: 9,
                  color: const PdfColor.fromInt(0xFF1565C0),
                ),
                pw.Alignment.centerRight,
              ),
              // ต้นทุน
              _cell(
                p.standardCost > 0 ? '฿${_fmt(p.standardCost)}' : '-',
                pw.TextStyle(
                  font: ttfRegular,
                  fontSize: 8.5,
                  color: _kTextSub,
                ),
                pw.Alignment.centerRight,
              ),
              // สต๊อก control
              pw.Container(
                alignment: pw.Alignment.center,
                padding: const pw.EdgeInsets.symmetric(vertical: 6),
                child: pw.Container(
                  width: 8,
                  height: 8,
                  decoration: pw.BoxDecoration(
                    color: p.isStockControl
                        ? _kSuccess
                        : const PdfColor.fromInt(0xFFCCCCCC),
                    shape: pw.BoxShape.circle,
                  ),
                ),
              ),
              // สถานะ
              pw.Container(
                alignment: pw.Alignment.center,
                padding: const pw.EdgeInsets.all(6),
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: pw.BoxDecoration(
                    color: p.isActive ? _kSuccessBg : _kInactiveBg,
                    borderRadius: pw.BorderRadius.circular(10),
                  ),
                  child: pw.Text(
                    p.isActive ? 'ใช้งาน' : 'ปิดใช้',
                    style: pw.TextStyle(
                      font: ttf,
                      fontSize: 8,
                      color: p.isActive ? _kSuccess : _kInactive,
                    ),
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _cell(
    String text,
    pw.TextStyle style, [
    pw.Alignment alignment = pw.Alignment.centerLeft,
  ]) =>
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        alignment: alignment,
        child: pw.Text(text, style: style),
      );

  // ── Footer ────────────────────────────────────────────────────
  static pw.Widget _buildFooter({
    required int page,
    required int totalPages,
    required pw.Font ttfRegular,
  }) =>
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'รายงานนี้สร้างโดย DEE POS System',
            style: pw.TextStyle(
                font: ttfRegular, fontSize: 8, color: _kTextSub),
          ),
          pw.Text(
            'หน้า $page / $totalPages',
            style: pw.TextStyle(
                font: ttfRegular, fontSize: 8, color: _kTextSub),
          ),
        ],
      );

  static String _fmt(double v) =>
      NumberFormat('#,##0.00', 'th').format(v);
}

// ─────────────────────────────────────────────────────────────────
// ProductReportButton — ปุ่มที่ใส่ใน product_list_page ได้เลย
// ─────────────────────────────────────────────────────────────────
class ProductReportButton extends StatefulWidget {
  final List<ProductModel> products;

  const ProductReportButton({super.key, required this.products});

  @override
  State<ProductReportButton> createState() => _ProductReportButtonState();
}

class _ProductReportButtonState extends State<ProductReportButton> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_PdfAction>(
      tooltip: 'สร้างรายงาน PDF',
      position: PopupMenuPosition.under,
      onSelected: _onAction,
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: _PdfAction.preview,
          child: Row(children: [
            Icon(Icons.picture_as_pdf, size: 18, color: Color(0xFFE8622A)),
            SizedBox(width: 10),
            Text('แสดง PDF', style: TextStyle(fontSize: 13)),
          ]),
        ),
        PopupMenuItem(
          value: _PdfAction.share,
          child: Row(children: [
            Icon(Icons.share, size: 18, color: Color(0xFF1565C0)),
            SizedBox(width: 10),
            Text('แชร์ PDF', style: TextStyle(fontSize: 13)),
          ]),
        ),
        PopupMenuItem(
          value: _PdfAction.save,
          child: Row(children: [
            Icon(Icons.save_alt, size: 18, color: Color(0xFF388E3C)),
            SizedBox(width: 10),
            Text('บันทึก PDF', style: TextStyle(fontSize: 13)),
          ]),
        ),
      ],
      child: _loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3EE),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: const Color(0xFFE8622A).withValues(alpha: 0.4)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.picture_as_pdf,
                      size: 17, color: Color(0xFFE8622A)),
                  SizedBox(width: 6),
                  Text('PDF',
                      style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFFE8622A),
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
    );
  }

  Future<void> _onAction(_PdfAction action) async {
    if (widget.products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่มีข้อมูลสินค้า')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      if (action == _PdfAction.preview) {
        await ProductPdfReport.showPreview(context, widget.products);
      } else if (action == _PdfAction.share) {
        await ProductPdfReport.shareFile(widget.products);
      } else {
        final path = await ProductPdfReport.openFile(widget.products);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('บันทึก PDF แล้ว: \$path'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('เกิดข้อผิดพลาด: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

enum _PdfAction { preview, share, save }

// ─────────────────────────────────────────────────────────────────
// _PdfPreviewDialog — แสดง PDF bytes ใน dialog
// ─────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────
// _PdfPreviewDialog — แสดง PDF พร้อม pinch-to-zoom + zoom buttons
// ─────────────────────────────────────────────────────────────────
class _PdfPreviewDialog extends StatefulWidget {
  final Uint8List bytes;
  final String title;
  final String filename;

  const _PdfPreviewDialog({
    required this.bytes,
    required this.title,
    required this.filename,
  });

  @override
  State<_PdfPreviewDialog> createState() => _PdfPreviewDialogState();
}

class _PdfPreviewDialogState extends State<_PdfPreviewDialog> {
  final TransformationController _transform = TransformationController();
  double _scale = 1.0;

  static const double _minScale = 0.5;
  static const double _maxScale = 4.0;
  static const double _scaleStep = 0.25;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _zoomIn() {
    final newScale = (_scale + _scaleStep).clamp(_minScale, _maxScale);
    _applyScale(newScale);
  }

  void _zoomOut() {
    final newScale = (_scale - _scaleStep).clamp(_minScale, _maxScale);
    _applyScale(newScale);
  }

  void _resetZoom() => _applyScale(1.0);

  void _applyScale(double newScale) {
    final center = _transform.value.getTranslation();
    _transform.value = Matrix4.identity()
      ..translate(center.x, center.y)
      ..scale(newScale);
    setState(() => _scale = newScale);
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final screenW = MediaQuery.of(context).size.width;

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: screenW * 0.92,
          maxHeight: screenH * 0.92,
        ),
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFF16213E),
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.picture_as_pdf,
                      color: Color(0xFFE8622A), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(widget.title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14)),
                  ),
                  // Zoom controls
                  _ZoomBtn(
                    icon: Icons.remove,
                    tooltip: 'ย่อ',
                    onTap: _scale <= _minScale ? null : _zoomOut,
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: _resetZoom,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${(_scale * 100).round()}%',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  _ZoomBtn(
                    icon: Icons.add,
                    tooltip: 'ขยาย',
                    onTap: _scale >= _maxScale ? null : _zoomIn,
                  ),
                  const SizedBox(width: 8),
                  _ZoomBtn(
                    icon: Icons.close,
                    tooltip: 'ปิด',
                    onTap: () => Navigator.pop(context),
                    color: Colors.white70,
                  ),
                ],
              ),
            ),

            // ── PDF content with zoom ─────────────────────────────
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(12)),
                child: InteractiveViewer(
                  transformationController: _transform,
                  minScale: _minScale,
                  maxScale: _maxScale,
                  boundaryMargin: const EdgeInsets.all(40),
                  onInteractionEnd: (details) {
                    // sync scale indicator
                    final s = _transform.value.getMaxScaleOnAxis();
                    if (mounted) setState(() => _scale = s);
                  },
                  child: PdfPreview(
                    build: (_) async => widget.bytes,
                    allowPrinting: false,
                    allowSharing: false,
                    canChangeOrientation: false,
                    canChangePageFormat: false,
                    canDebug: false,
                    pdfFileName: widget.filename,
                    scrollViewDecoration: const BoxDecoration(
                      color: Color(0xFFF0F0F0),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ZoomBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final Color color;

  const _ZoomBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(icon,
                size: 18,
                color: onTap == null ? Colors.white30 : color),
          ),
        ),
      );
}