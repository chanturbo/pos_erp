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
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'pdf_preview_dialog.dart';
import '../widgets/app_dialogs.dart';

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
    final canPreview = await _canPreview(bytes);
    if (!context.mounted) return;

    if (!canPreview) {
      final path = await saveBytes(
        filename: filename,
        bytes: bytes,
        chooseLocation: false,
        openAfterSave: true,
      );
      if (!context.mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AppDialog(
          title: buildAppDialogTitle(
            context,
            title: 'ไม่สามารถแสดงตัวอย่าง PDF ได้',
            icon: Icons.picture_as_pdf_outlined,
            iconColor: Colors.orange,
          ),
          content: Text(
            path == null
                ? 'ระบบ preview ของอุปกรณ์นี้ไม่สามารถ raster PDF ชุดนี้ได้ กรุณาใช้การบันทึกหรือแชร์ PDF แทน'
                : 'ระบบ preview ของอุปกรณ์นี้ไม่สามารถ raster PDF ชุดนี้ได้ จึงเปิดไฟล์ภายนอกให้แทนแล้ว\n\n$path',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('ปิด'),
            ),
          ],
        ),
      );
      return;
    }

    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder: (_) =>
          PdfPreviewDialog(bytes: bytes, title: title, filename: filename),
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

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/pdf')],
        subject: title,
      ),
    );
  }

  // ── บันทึก PDF และเปิดไฟล์ด้วย OS ───────────────────────────────
  static Future<String?> openFile({
    required String filename,
    required Future<pw.Document> Function() buildPdf,
    bool chooseLocation = true,
    bool openAfterSave = true,
  }) async {
    final pdf = await buildPdf();
    final bytes = await pdf.save();
    return saveBytes(
      filename: filename,
      bytes: bytes,
      chooseLocation: chooseLocation,
      openAfterSave: openAfterSave,
    );
  }

  static Future<String?> saveBytes({
    required String filename,
    required Uint8List bytes,
    bool chooseLocation = true,
    bool openAfterSave = true,
  }) async {
    String? filepath;
    if (chooseLocation) {
      filepath = await FilePicker.platform.saveFile(
        dialogTitle: 'เลือกตำแหน่งบันทึก PDF',
        fileName: filename,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (filepath == null || filepath.isEmpty) {
        return null;
      }
    }

    filepath ??= await _fallbackPath(filename);
    final file = File(filepath);
    await file.writeAsBytes(bytes);
    print('✅ PDF saved: ${file.path}');

    if (openAfterSave) {
      await _openSavedFile(file.path);
    }

    return file.path;
  }

  // ── แปลง pw.Document → Uint8List ────────────────────────────────
  static Future<Uint8List> toBytes(pw.Document pdf) => pdf.save();

  static Future<String> _fallbackPath(String filename) async {
    Directory dir;
    try {
      dir = await getApplicationDocumentsDirectory();
    } catch (_) {
      dir = await getTemporaryDirectory();
    }
    return '${dir.path}/$filename';
  }

  static Future<void> _openSavedFile(String path) async {
    if (Platform.isMacOS) {
      await Process.run('open', [path]);
    } else if (Platform.isWindows) {
      await Process.run('cmd', ['/c', 'start', '', path]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [path]);
    }
  }

  static Future<bool> _canPreview(Uint8List bytes) async {
    try {
      await Printing.raster(bytes, pages: const [0]).first;
      return true;
    } catch (_) {
      return false;
    }
  }
}
