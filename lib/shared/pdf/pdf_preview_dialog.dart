// lib/shared/pdf/pdf_preview_dialog.dart
//
// Shared PDF Preview Dialog — ใช้ร่วมกันได้ทุก module
// รองรับ pinch-to-zoom, zoom buttons (+/-), zoom reset, ปิด dialog

import 'dart:typed_data';
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

  static const double _minScale  = 0.5;
  static const double _maxScale  = 4.0;
  static const double _scaleStep = 0.25;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _zoomIn()    => _applyScale((_scale + _scaleStep).clamp(_minScale, _maxScale));
  void _zoomOut()   => _applyScale((_scale - _scaleStep).clamp(_minScale, _maxScale));
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
          maxWidth:  screenW * 0.92,
          maxHeight: screenH * 0.92,
        ),
        child: Column(
          children: [
            // ── Dialog Header ─────────────────────────────────────
            _DialogHeader(
              title:    widget.title,
              scale:    _scale,
              minScale: _minScale,
              maxScale: _maxScale,
              onZoomIn:    _zoomIn,
              onZoomOut:   _zoomOut,
              onResetZoom: _resetZoom,
              onClose: () => Navigator.pop(context),
            ),

            // ── PDF Content with zoom ──────────────────────────────
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
                    final s = _transform.value.getMaxScaleOnAxis();
                    if (mounted) setState(() => _scale = s);
                  },
                  child: PdfPreview(
                    build: (_) async => widget.bytes,
                    allowPrinting:        false,
                    allowSharing:         false,
                    canChangeOrientation: false,
                    canChangePageFormat:  false,
                    canDebug:             false,
                    pdfFileName:          widget.filename,
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
  final VoidCallback onClose;

  const _DialogHeader({
    required this.title,
    required this.scale,
    required this.minScale,
    required this.maxScale,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onResetZoom,
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
                  fontSize: 14),
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
                    fontWeight: FontWeight.w600),
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