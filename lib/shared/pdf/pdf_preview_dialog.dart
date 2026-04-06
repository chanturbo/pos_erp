// lib/shared/pdf/pdf_preview_dialog.dart
//
// Shared PDF Preview Dialog — ใช้ร่วมกันได้ทุก module
// รองรับ pinch-to-zoom, zoom buttons (+/-), zoom reset, ปริ้น, ปิด dialog

import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

// ─────────────────────────────────────────────────────────────────
// PdfPreviewDialog — public widget ใช้ได้จากทุก module
// ─────────────────────────────────────────────────────────────────
class PdfPreviewDialog extends StatefulWidget {
  final Uint8List bytes;
  final String title;
  final String filename;

  const PdfPreviewDialog({
    super.key,
    required this.bytes,
    required this.title,
    required this.filename,
  });

  @override
  State<PdfPreviewDialog> createState() => _PdfPreviewDialogState();
}

class _PdfPreviewDialogState extends State<PdfPreviewDialog> {
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

  void _zoomIn() =>
      _applyScale((_scale + _scaleStep).clamp(_minScale, _maxScale));
  void _zoomOut() =>
      _applyScale((_scale - _scaleStep).clamp(_minScale, _maxScale));
  void _resetZoom() => _applyScale(1.0);

  Future<void> _savePdf() async {
    var filepath = await FilePicker.platform.saveFile(
      dialogTitle: 'เลือกตำแหน่งบันทึก PDF',
      fileName: widget.filename,
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (filepath == null || filepath.isEmpty) return;

    final file = File(filepath);
    await file.writeAsBytes(widget.bytes);

    // เปิดไฟล์อัตโนมัติทันที
    if (Platform.isMacOS) {
      await Process.run('open', [file.path]);
    } else if (Platform.isWindows) {
      await Process.run('cmd', ['/c', 'start', '', file.path]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [file.path]);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('บันทึก PDF แล้ว: ${file.path}'),
        backgroundColor: Colors.green[700],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _print() async {
    await Printing.layoutPdf(
      onLayout: (_) async => widget.bytes,
      name: widget.filename,
    );
  }

  void _applyScale(double newScale) {
    final center = _transform.value.getTranslation();
    _transform.value = Matrix4.identity()
      ..translateByDouble(center.x, center.y, 0.0, 1.0)
      ..scaleByDouble(newScale, newScale, 1.0, 1.0);
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
            // ── Dialog Header ─────────────────────────────────────
            _DialogHeader(
              title: widget.title,
              scale: _scale,
              minScale: _minScale,
              maxScale: _maxScale,
              onZoomIn: _zoomIn,
              onZoomOut: _zoomOut,
              onResetZoom: _resetZoom,
              onSavePdf: _savePdf,
              onPrint: _print,
              onClose: () => Navigator.pop(context),
            ),

            // ── PDF Content with zoom ──────────────────────────────
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(12),
                ),
                child: InteractiveViewer(
                  transformationController: _transform,
                  minScale: _minScale,
                  maxScale: _maxScale,
                  boundaryMargin: const EdgeInsets.all(40),
                  onInteractionEnd: (details) {
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
                    onError: (context, error) => _PreviewErrorState(
                      filename: widget.filename,
                      error: error,
                      onSavePdf: _savePdf,
                    ),
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

// ─────────────────────────────────────────────────────────────────
// _DialogHeader — header bar ของ dialog
// ─────────────────────────────────────────────────────────────────
class _DialogHeader extends StatelessWidget {
  final String title;
  final double scale;
  final double minScale;
  final double maxScale;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onResetZoom;
  final VoidCallback onSavePdf;
  final VoidCallback onPrint;
  final VoidCallback onClose;

  const _DialogHeader({
    required this.title,
    required this.scale,
    required this.minScale,
    required this.maxScale,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onResetZoom,
    required this.onSavePdf,
    required this.onPrint,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF16213E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: [
          const Icon(Icons.picture_as_pdf, color: Color(0xFFE8622A), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          // Zoom out
          PdfZoomButton(
            icon: Icons.remove,
            tooltip: 'ย่อ',
            onTap: scale <= minScale ? null : onZoomOut,
          ),
          const SizedBox(width: 4),
          // Zoom % indicator (กด reset)
          GestureDetector(
            onTap: onResetZoom,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${(scale * 100).round()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Zoom in
          PdfZoomButton(
            icon: Icons.add,
            tooltip: 'ขยาย',
            onTap: scale >= maxScale ? null : onZoomIn,
          ),
          const SizedBox(width: 8),
          // Save PDF
          PdfZoomButton(
            icon: Icons.download,
            tooltip: 'บันทึก PDF',
            onTap: onSavePdf,
            color: const Color(0xFF80CBC4),
          ),
          const SizedBox(width: 4),
          // Print
          PdfZoomButton(
            icon: Icons.print,
            tooltip: 'พิมพ์',
            onTap: onPrint,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          // Close
          PdfZoomButton(
            icon: Icons.close,
            tooltip: 'ปิด',
            onTap: onClose,
            color: Colors.white70,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// PdfZoomButton — reusable icon button สำหรับ zoom controls
// export ออกมาให้ใช้ภายนอกได้ด้วย
// ─────────────────────────────────────────────────────────────────
class PdfZoomButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final Color color;

  const PdfZoomButton({
    super.key,
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
        child: Icon(
          icon,
          size: 18,
          color: onTap == null ? Colors.white30 : color,
        ),
      ),
    ),
  );
}

class _PreviewErrorState extends StatelessWidget {
  final String filename;
  final Object error;
  final Future<void> Function() onSavePdf;

  const _PreviewErrorState({
    required this.filename,
    required this.error,
    required this.onSavePdf,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF6F6F6),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.picture_as_pdf_outlined,
              size: 72,
              color: Color(0xFFE8622A),
            ),
            const SizedBox(height: 16),
            const Text(
              'ไม่สามารถแสดงตัวอย่าง PDF ในหน้านี้ได้',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'ไฟล์ $filename ยังสามารถบันทึกหรือเปิดภายนอกได้ตามปกติ\n$error',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onSavePdf,
              icon: const Icon(Icons.save_alt),
              label: const Text('บันทึก PDF'),
            ),
          ],
        ),
      ),
    );
  }
}
