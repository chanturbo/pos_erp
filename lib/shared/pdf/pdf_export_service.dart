// ignore_for_file: avoid_print
//
// lib/shared/pdf/pdf_export_service.dart
//
// Shared PDF module — ใช้ร่วมกันได้ทุก module
//
// วิธีใช้งาน:
//   import 'package:your_app/shared/pdf/pdf_export_service.dart';
//
//   // แสดง preview
//   await PdfExportService.showPreview(
//     context,
//     title: 'รายงานสินค้า',
//     filename: 'product_report_20250101.pdf',
//     buildPdf: () => ProductPdfBuilder.build(products),
//   );
//
//   // แชร์
//   await PdfExportService.shareFile(
//     title: 'รายงานสินค้า',
//     filename: 'product_report_20250101.pdf',
//     buildPdf: () => ProductPdfBuilder.build(products),
//   );
//
//   // บันทึก
//   final path = await PdfExportService.openFile(
//     filename: 'product_report_20250101.pdf',
//     buildPdf: () => ProductPdfBuilder.build(products),
//   );

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'pdf_preview_dialog.dart';

class PdfExportService {
  // ── แสดง Preview Dialog ──────────────────────────────────────────
  static Future<void> showPreview(
    BuildContext context, {
    required String title,
    required String filename,
    required Future<pw.Document> Function() buildPdf,
  }) async {
    final pdf = await buildPdf();
    final bytes = await pdf.save();
    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder: (_) => PdfPreviewDialog(
        bytes: bytes,
        title: title,
        filename: filename,
      ),
    );
  }

  // ── แชร์ผ่าน OS Share Sheet ──────────────────────────────────────
  static Future<void> shareFile({
    required String title,
    required String filename,
    required Future<pw.Document> Function() buildPdf,
  }) async {
    final pdf = await buildPdf();
    final bytes = await pdf.save();

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes);

    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: 'application/pdf')],
      subject: title,
    ));
  }

  // ── บันทึกลง Documents และเปิดด้วย OS ───────────────────────────
  static Future<String> openFile({
    required String filename,
    required Future<pw.Document> Function() buildPdf,
  }) async {
    final pdf = await buildPdf();
    final bytes = await pdf.save();

    Directory dir;
    try {
      dir = await getApplicationDocumentsDirectory();
    } catch (_) {
      dir = await getTemporaryDirectory();
    }

    final file = File('${dir.path}/$filename');
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

  // ── แปลง pw.Document → Uint8List ────────────────────────────────
  static Future<Uint8List> toBytes(pw.Document pdf) => pdf.save();
}