// ignore_for_file: avoid_print
//
// customer_pdf_report.dart
//
// วิธีใช้งาน:
//   1. เพิ่ม dependencies ใน pubspec.yaml (ถ้ายังไม่มี):
//        pdf: ^3.10.8
//        printing: ^5.12.0
//        path_provider: ^2.1.2
//        share_plus: ^9.0.0
//
//   2. import ไฟล์นี้ใน customer_list_page.dart:
//        import 'customer_pdf_report.dart';

import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../data/models/customer_model.dart';

// ─────────────────────────────────────────────────────────────────
// Colors
// ─────────────────────────────────────────────────────────────────
const _kPrimary    = PdfColor.fromInt(0xFFE8622A);
const _kNavy       = PdfColor.fromInt(0xFF16213E);
const _kBorder     = PdfColor.fromInt(0xFFE0E0E0);
const _kTextSub    = PdfColor.fromInt(0xFF666666);
const _kSuccess    = PdfColor.fromInt(0xFF2E7D32);
const _kSuccessBg  = PdfColor.fromInt(0xFFE8F5E9);
const _kInactive   = PdfColor.fromInt(0xFFC62828);
const _kInactiveBg = PdfColor.fromInt(0xFFFFEBEE);
const _kAmber      = PdfColor.fromInt(0xFFFFB300);
const _kWhite      = PdfColors.white;

// ─────────────────────────────────────────────────────────────────
// CustomerPdfReport
// ─────────────────────────────────────────────────────────────────
class CustomerPdfReport {
  /// แสดง PDF ใน Preview Dialog
  static Future<void> showPreview(
    BuildContext context,
    List<CustomerModel> customers, {
    String companyName = 'DEE POS',
  }) async {
    final pdf = await _buildPdf(customers, companyName: companyName);
    final bytes = await pdf.save();
    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder: (_) => _PdfPreviewDialog(
        bytes: bytes,
        title: 'รายงานลูกค้า',
        filename: _filename(),
      ),
    );
  }

    /// แชร์ PDF ผ่าน OS share sheet (share_plus)
  static Future<void> shareFile(
    List<CustomerModel> customers, {
    String companyName = 'DEE POS',
  }) async {
    final pdf = await _buildPdf(customers, companyName: companyName);
    final bytes = await pdf.save();

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${_filename()}');
    await file.writeAsBytes(bytes);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      subject: 'รายงานลูกค้า',
    );
  }

    /// บันทึก PDF ลง Documents และเปิดด้วย OS (รองรับ macOS + Windows Desktop)
  static Future<String> openFile(
    List<CustomerModel> customers, {
    String companyName = 'DEE POS',
  }) async {
    final pdf = await _buildPdf(customers, companyName: companyName);
    final bytes = await pdf.save();

    Directory dir;
    try {
      dir = await getApplicationDocumentsDirectory();
    } catch (_) {
      dir = await getTemporaryDirectory();
    }

    final file = File('${dir.path}/${_filename()}');
    await file.writeAsBytes(bytes);
    print('✅ PDF saved: ${file.path}');

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
    return 'customer_report_$ts.pdf';
  }

  // ── สร้าง PDF document ────────────────────────────────────────
  static Future<pw.Document> _buildPdf(
    List<CustomerModel> customers, {
    required String companyName,
  }) async {
    final doc = pw.Document(
      title: 'รายงานรายการลูกค้า',
      author: companyName,
    );

    final ttf        = await PdfGoogleFonts.notoSansThaiBold();
    final ttfRegular = await PdfGoogleFonts.notoSansThaiRegular();

    final printedAt = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    // สถิติ
    final totalCustomers  = customers.length;
    final activeCustomers = customers.where((c) => c.isActive).length;
    final memberCustomers = customers
        .where((c) => c.memberNo != null && c.memberNo!.isNotEmpty)
        .length;
    final creditCustomers = customers.where((c) => c.creditLimit > 0).length;

    // แบ่ง page (28 rows/page — landscape A4)
    const rowsPerPage = 28;
    final pages = <List<CustomerModel>>[];
    for (var i = 0; i < customers.length; i += rowsPerPage) {
      pages.add(customers.sublist(
        i,
        (i + rowsPerPage) > customers.length
            ? customers.length
            : i + rowsPerPage,
      ));
    }
    final totalPages = pages.isEmpty ? 1 : pages.length;

    for (var pageIdx = 0;
        pageIdx < (pages.isEmpty ? 1 : pages.length);
        pageIdx++) {
      final pageCustomers =
          pages.isEmpty ? <CustomerModel>[] : pages[pageIdx];
      final startNo = pageIdx * rowsPerPage + 1;

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(24),
          build: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(
                companyName:    companyName,
                printedAt:      printedAt,
                total:          totalCustomers,
                active:         activeCustomers,
                members:        memberCustomers,
                creditCount:    creditCustomers,
                ttf:            ttf,
                ttfRegular:     ttfRegular,
              ),
              pw.SizedBox(height: 12),

              // Table
              _buildTable(
                pageCustomers,
                startNo:    startNo,
                ttf:        ttf,
                ttfRegular: ttfRegular,
              ),

              pw.Spacer(),

              // Footer
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

  // ── Header ────────────────────────────────────────────────────
  static pw.Widget _buildHeader({
    required String companyName,
    required String printedAt,
    required int total,
    required int active,
    required int members,
    required int creditCount,
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
                pw.Text('รายงานรายการลูกค้า',
                    style: pw.TextStyle(font: ttf, fontSize: 18, color: _kWhite)),
                pw.SizedBox(height: 4),
                pw.Text(companyName,
                    style: pw.TextStyle(
                        font: ttfRegular,
                        fontSize: 11,
                        color: const PdfColor.fromInt(0xFFAAAAAA))),
              ],
            ),
          ),

          // Stats
          pw.Row(
            children: [
              _statChip('ทั้งหมด',  '$total',       _kPrimary, ttf, ttfRegular),
              pw.SizedBox(width: 6),
              _statChip('ใช้งาน',   '$active',      _kSuccess, ttf, ttfRegular),
              pw.SizedBox(width: 6),
              _statChip('สมาชิก',   '$members',     _kAmber,   ttf, ttfRegular),
              pw.SizedBox(width: 6),
              _statChip('มีเครดิต', '$creditCount', const PdfColor.fromInt(0xFF1565C0),
                  ttf, ttfRegular),
            ],
          ),

          pw.SizedBox(width: 16),

          // Date
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('พิมพ์เมื่อ',
                  style: pw.TextStyle(
                      font: ttfRegular,
                      fontSize: 9,
                      color: const PdfColor.fromInt(0xFFAAAAAA))),
              pw.Text(printedAt,
                  style: pw.TextStyle(font: ttf, fontSize: 11, color: _kWhite)),
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
                    color: const PdfColor.fromInt(0xFFCCCCCC))),
          ],
        ),
      );

  // ── Table ──────────────────────────────────────────────────────
  static pw.Widget _buildTable(
    List<CustomerModel> customers, {
    required int startNo,
    required pw.Font ttf,
    required pw.Font ttfRegular,
  }) {
    final headerStyle = pw.TextStyle(
      font: ttf,
      fontSize: 9,
      color: _kWhite,
    );

    // [label, flex, align]
    final cols = [
      ('#',             1, pw.Alignment.center),
      ('รหัสลูกค้า',    2, pw.Alignment.centerLeft),
      ('ชื่อลูกค้า',    4, pw.Alignment.centerLeft),
      ('โทรศัพท์',      2, pw.Alignment.centerLeft),
      ('อีเมล',          3, pw.Alignment.centerLeft),
      ('เลขสมาชิก',     2, pw.Alignment.centerLeft),
      ('คะแนน',         1, pw.Alignment.centerRight),
      ('วงเงินเครดิต',  2, pw.Alignment.centerRight),
      ('สถานะ',          2, pw.Alignment.center),
    ];

    return pw.Table(
      border: pw.TableBorder.all(color: _kBorder, width: 0.5),
      columnWidths: {
        for (var i = 0; i < cols.length; i++)
          i: pw.FlexColumnWidth(cols[i].$2.toDouble()),
      },
      children: [
        // Header row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _kNavy),
          children: cols
              .map((col) => pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 6, vertical: 8),
                    alignment: col.$3,
                    child: pw.Text(col.$1, style: headerStyle),
                  ))
              .toList(),
        ),

        // Data rows
        ...customers.asMap().entries.map((entry) {
          final i = entry.key;
          final c = entry.value;
          final isEven = i.isEven;
          final bg = isEven ? _kWhite : const PdfColor.fromInt(0xFFF9F9F7);
          final isMember =
              c.memberNo != null && c.memberNo!.isNotEmpty;

          final cellStyle = pw.TextStyle(
              font: ttfRegular, fontSize: 9, color: PdfColors.black);
          final subStyle = pw.TextStyle(
              font: ttfRegular, fontSize: 8.5, color: _kTextSub);

          return pw.TableRow(
            decoration: pw.BoxDecoration(color: bg),
            children: [
              // No.
              _cell('${startNo + i}', cellStyle, pw.Alignment.center),

              // รหัส
              _cell(c.customerCode,
                  pw.TextStyle(font: ttfRegular, fontSize: 8.5,
                      color: PdfColors.black)),

              // ชื่อ
              _cell(c.customerName, cellStyle),

              // โทร
              _cell(c.phone ?? '-', subStyle),

              // อีเมล
              _cell(c.email ?? '-', subStyle),

              // เลขสมาชิก
              isMember
                  ? pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 6, vertical: 6),
                      child: pw.Row(
                        children: [
                          pw.Container(
                            width: 7, height: 7,
                            decoration: pw.BoxDecoration(
                              color: _kAmber,
                              shape: pw.BoxShape.circle,
                            ),
                          ),
                          pw.SizedBox(width: 4),
                          pw.Text(c.memberNo!,
                              style: pw.TextStyle(
                                  font: ttfRegular,
                                  fontSize: 8.5,
                                  color: const PdfColor.fromInt(0xFFE65100))),
                        ],
                      ),
                    )
                  : _cell('-', subStyle),

              // คะแนน
              isMember
                  ? _cell('${c.points} pt',
                      pw.TextStyle(
                          font: ttf,
                          fontSize: 8.5,
                          color: const PdfColor.fromInt(0xFFE65100)),
                      pw.Alignment.centerRight)
                  : _cell('-', subStyle, pw.Alignment.centerRight),

              // วงเงินเครดิต
              c.creditLimit > 0
                  ? _cell(
                      '฿${_fmt(c.creditLimit)}',
                      pw.TextStyle(
                          font: ttf,
                          fontSize: 8.5,
                          color: const PdfColor.fromInt(0xFF1565C0)),
                      pw.Alignment.centerRight,
                    )
                  : _cell('-', subStyle, pw.Alignment.centerRight),

              // สถานะ
              pw.Container(
                alignment: pw.Alignment.center,
                padding: const pw.EdgeInsets.all(5),
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: pw.BoxDecoration(
                    color: c.isActive ? _kSuccessBg : _kInactiveBg,
                    borderRadius: pw.BorderRadius.circular(10),
                  ),
                  child: pw.Text(
                    c.isActive ? 'ใช้งาน' : 'ปิดใช้',
                    style: pw.TextStyle(
                      font: ttf,
                      fontSize: 8,
                      color: c.isActive ? _kSuccess : _kInactive,
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
        padding:
            const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
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
          pw.Text('รายงานนี้สร้างโดย DEE POS System',
              style: pw.TextStyle(
                  font: ttfRegular, fontSize: 8, color: _kTextSub)),
          pw.Text('หน้า $page / $totalPages',
              style: pw.TextStyle(
                  font: ttfRegular, fontSize: 8, color: _kTextSub)),
        ],
      );

  static String _fmt(double v) =>
      NumberFormat('#,##0.00', 'th').format(v);
}

// ─────────────────────────────────────────────────────────────────
// CustomerReportButton — ปุ่มสำหรับใส่ใน customer_list_page
// ─────────────────────────────────────────────────────────────────
class CustomerReportButton extends StatefulWidget {
  final List<CustomerModel> customers;

  const CustomerReportButton({super.key, required this.customers});

  @override
  State<CustomerReportButton> createState() => _CustomerReportButtonState();
}

class _CustomerReportButtonState extends State<CustomerReportButton> {
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
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3EE),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: const Color(0xFFE8622A).withValues(alpha: 0.4)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
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
    if (widget.customers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่มีข้อมูลลูกค้า')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      if (action == _PdfAction.preview) {
        await CustomerPdfReport.showPreview(context, widget.customers);
      } else if (action == _PdfAction.share) {
        await CustomerPdfReport.shareFile(widget.customers);
      } else {
        final path = await CustomerPdfReport.openFile(widget.customers);
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