// lib/shared/pdf/pdf_report_button.dart
//
// Shared PDF Report Button — ปุ่ม popup menu (แสดง / แชร์ / บันทึก)
// ใช้ร่วมกันได้ทุก module
//
// วิธีใช้งาน:
//   PdfReportButton(
//     emptyMessage: 'ไม่มีข้อมูลสินค้า',
//     title:        'รายงานสินค้า',
//     filename:     () => 'product_report_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf',
//     buildPdf:     () => ProductPdfBuilder.build(products),
//   )

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'pdf_export_service.dart';
import 'package:pdf/widgets.dart' as pw;

class PdfReportButton extends StatefulWidget {
  /// ข้อความเมื่อไม่มีข้อมูล เช่น 'ไม่มีข้อมูลสินค้า'
  final String emptyMessage;

  /// ชื่อรายงาน ใช้ใน dialog title และ share subject
  final String title;

  /// ฟังก์ชันสร้างชื่อไฟล์ (เรียกตอนกดปุ่ม เพื่อให้ timestamp อัปเดต)
  final String Function() filename;

  /// ฟังก์ชัน build PDF document
  final Future<pw.Document> Function() buildPdf;

  /// true = มีข้อมูล, false = ไม่มีข้อมูล (ใช้ตรวจสอบก่อนสร้าง PDF)
  final bool hasData;

  const PdfReportButton({
    super.key,
    required this.emptyMessage,
    required this.title,
    required this.filename,
    required this.buildPdf,
    this.hasData = true,
  });

  @override
  State<PdfReportButton> createState() => _PdfReportButtonState();
}

class _PdfReportButtonState extends State<PdfReportButton> {
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
          child: Row(
            children: [
              Icon(Icons.picture_as_pdf, size: 18, color: Color(0xFFE8622A)),
              SizedBox(width: 10),
              Text('แสดง PDF', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem(
          value: _PdfAction.share,
          child: Row(
            children: [
              Icon(Icons.share, size: 18, color: Color(0xFF1565C0)),
              SizedBox(width: 10),
              Text('แชร์ PDF', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem(
          value: _PdfAction.save,
          child: Row(
            children: [
              Icon(Icons.save_alt, size: 18, color: Color(0xFF388E3C)),
              SizedBox(width: 10),
              Text('บันทึก PDF', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
      ],
      child: _loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3EE),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFE8622A).withValues(alpha: 0.4),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.picture_as_pdf,
                    size: 17,
                    color: Color(0xFFE8622A),
                  ),
                  SizedBox(width: 6),
                  Text(
                    'PDF',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFFE8622A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Future<void> _onAction(_PdfAction action) async {
    if (!widget.hasData) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(widget.emptyMessage)));
      return;
    }

    setState(() => _loading = true);
    try {
      final fname = widget.filename();

      switch (action) {
        case _PdfAction.preview:
          await PdfExportService.showPreview(
            context,
            title: widget.title,
            filename: fname,
            buildPdf: widget.buildPdf,
          );

        case _PdfAction.share:
          await PdfExportService.shareFile(
            title: widget.title,
            filename: fname,
            buildPdf: widget.buildPdf,
          );

        case _PdfAction.save:
          final path = await PdfExportService.openFile(
            filename: fname,
            buildPdf: widget.buildPdf,
          );
          if (mounted && path != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('บันทึก PDF แล้ว: $path'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 4),
              ),
            );
          } else if (mounted && path == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('ยกเลิกการบันทึก PDF'),
                duration: Duration(seconds: 2),
              ),
            );
          }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

enum _PdfAction { preview, share, save }

// ─────────────────────────────────────────────────────────────────
// PdfFilename — helper สร้างชื่อไฟล์มาตรฐาน
// ─────────────────────────────────────────────────────────────────
class PdfFilename {
  static String generate(String prefix) {
    final ts = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    return '${prefix}_$ts.pdf';
  }
}
