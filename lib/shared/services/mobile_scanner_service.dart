import 'package:flutter/material.dart';
import '../../../../shared/theme/app_theme.dart';

// เปิดกล้องทุก platform (Mobile + Desktop ที่มี webcam)
bool get _isMobile => true;

// ─────────────────────────────────────────
// Scanner Result
// ─────────────────────────────────────────
class ScanResult {
  const ScanResult({required this.value, required this.type});

  final String value;
  final ScanType type;

  bool get isBarcode => type == ScanType.barcode;
  bool get isQRCode => type == ScanType.qrCode;
}

enum ScanType { barcode, qrCode, unknown }

// ─────────────────────────────────────────
// Scanner Service
// mobile_scanner package ต้องเพิ่มใน pubspec:
//   mobile_scanner: ^6.0.0
// ─────────────────────────────────────────
class MobileScannerService {
  /// scan() — เปิดกล้องครั้งเดียว สแกนแล้วปิด (เดิม)
  static Future<ScanResult?> scan(BuildContext context) async {
    if (!_isMobile) {
      return _showManualInputDialog(context);
    }
    return Navigator.of(context).push<ScanResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _ScannerPage(
          onScanned: null, // single-scan mode → pop เมื่อสแกนได้
          continuous: false,
        ),
      ),
    );
  }

  /// openContinuous() — เปิดกล้องแบบ overlay (bottom sheet)
  /// มองเห็นหน้าตะกร้าด้านหลังได้ กด ✕ เพื่อปิด
  static Future<void> openContinuous(
    BuildContext context, {
    required void Function(ScanResult result) onScanned,
  }) async {
    if (!_isMobile) {
      // Desktop fallback: วน _ManualInputDialog ซ้ำจนกด ยกเลิก
      while (context.mounted) {
        final result = await _showManualInputDialog(context);
        if (result == null) break;
        onScanned(result);
      }
      return;
    }
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.35), // เห็นหน้าหลังได้
      builder: (_) => _ScannerSheet(onScanned: onScanned),
    );
  }

  static Future<ScanResult?> _showManualInputDialog(
    BuildContext context,
  ) async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => const _ManualInputDialog(),
    );
    if (result == null || result.isEmpty) return null;
    return ScanResult(value: result, type: ScanType.unknown);
  }
}

// ─────────────────────────────────────────
// _ManualInputDialog
// StatefulWidget — controller อยู่ใน State
// dispose() ถูกเรียกโดย Flutter lifecycle เอง
// ─────────────────────────────────────────
class _ManualInputDialog extends StatefulWidget {
  const _ManualInputDialog();

  @override
  State<_ManualInputDialog> createState() => _ManualInputDialogState();
}

class _ManualInputDialogState extends State<_ManualInputDialog> {
  // ✅ controller อยู่ใน State — dispose() ถูกเรียกหลัง dialog ปิดแน่นอน
  final TextEditingController _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          const Text('กรอกบาร์โค้ด / QR Code'),
        ],
      ),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'สแกนหรือกรอกบาร์โค้ด',
          prefixIcon: const Icon(
            Icons.qr_code_scanner,
            color: AppTheme.primaryColor,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(
              color: AppTheme.primaryColor,
              width: 1.5,
            ),
          ),
        ),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ยกเลิก'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          onPressed: () => Navigator.pop(context, _ctrl.text),
          child: const Text('ตกลง'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────
// _ScannerSheet — Overlay bottom sheet
// กล้องอยู่ใน bottom sheet สูง 55% ของหน้าจอ
// เห็นหน้าตะกร้าสินค้าด้านหลังได้
// ─────────────────────────────────────────
class _ScannerSheet extends StatefulWidget {
  final void Function(ScanResult) onScanned;
  const _ScannerSheet({required this.onScanned});

  @override
  State<_ScannerSheet> createState() => _ScannerSheetState();
}

class _ScannerSheetState extends State<_ScannerSheet> {
  bool _torchOn = false;
  bool _cooldown = false;

  void _handleDetected(String value, ScanType type) {
    if (_cooldown || value.isEmpty) return;
    widget.onScanned(ScanResult(value: value, type: type));
    setState(() => _cooldown = true);
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _cooldown = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final sheetH = MediaQuery.of(context).size.height * 0.55;

    return Container(
      height: sheetH,
      decoration: const BoxDecoration(
        color: Color(0xCC000000), // กึ่งโปร่งใส — เห็นหน้าหลังได้
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // ── Handle + Header ───────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 0),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white30,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.qr_code_scanner,
                      color: AppTheme.primaryLight,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _cooldown
                            ? '✅ เพิ่มแล้ว — พร้อมสแกนต่อ...'
                            : 'สแกน QR / Barcode',
                        style: TextStyle(
                          color: _cooldown
                              ? AppTheme.successColor
                              : Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    // Torch
                    IconButton(
                      icon: Icon(
                        _torchOn ? Icons.flash_on : Icons.flash_off,
                        color: _torchOn ? Colors.yellow : Colors.white54,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _torchOn = !_torchOn),
                    ),
                    // Close
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white70,
                        size: 20,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Camera area ───────────────────────────────────
          Expanded(
            child: Stack(
              children: [
                // ✅ เปิด comment นี้เมื่อเพิ่ม mobile_scanner: ^6.0.0
                //
                // ClipRRect(
                //   child: MobileScanner(
                //     controller: MobileScannerController(
                //         torchEnabled: _torchOn),
                //     onDetect: (capture) {
                //       final barcode = capture.barcodes.firstOrNull;
                //       final value   = barcode?.rawValue;
                //       if (value == null) return;
                //       HapticFeedback.mediumImpact();
                //       _handleDetected(
                //         value,
                //         barcode!.format == BarcodeFormat.qrCode
                //             ? ScanType.qrCode
                //             : ScanType.barcode,
                //       );
                //     },
                //   ),
                // ),
                Container(color: Colors.black54), // placeholder

                Center(child: _ScanOverlay()),

                // Cooldown feedback
                if (_cooldown)
                  Container(
                    color: AppTheme.successColor.withValues(alpha: 0.15),
                    child: const Center(
                      child: Icon(
                        Icons.check_circle,
                        color: Colors.white,
                        size: 64,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Manual input fallback ─────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Colors.white60),
              icon: const Icon(Icons.keyboard, size: 16),
              label: const Text('กรอกเอง', style: TextStyle(fontSize: 12)),
              onPressed: () async {
                final result =
                    await MobileScannerService._showManualInputDialog(context);
                if (result == null) return;
                widget.onScanned(result);
                if (context.mounted) {
                  setState(() => _cooldown = true);
                  Future.delayed(const Duration(milliseconds: 800), () {
                    if (mounted) setState(() => _cooldown = false);
                  });
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// Scanner Page UI
// continuous = true  → สแกนซ้ำได้ ไม่ปิดกล้อง
// continuous = false → สแกนครั้งเดียวแล้ว pop
// ─────────────────────────────────────────
class _ScannerPage extends StatefulWidget {
  final void Function(ScanResult)? onScanned;
  final bool continuous;

  const _ScannerPage({required this.onScanned, required this.continuous});

  @override
  State<_ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<_ScannerPage> {
  bool _torchOn = false;
  bool _scanned = false; // ใช้เฉพาะ single-scan mode เพื่อ debounce

  // ── เรียกเมื่อสแกนได้ barcode ────────────────────────────────
  void _handleDetected(String value, ScanType type) {
    if (!widget.continuous && _scanned)
      return; // single-scan: ป้องกัน double-detect
    if (value.isEmpty) return;

    final result = ScanResult(value: value, type: type);

    if (widget.continuous) {
      // Continuous: เรียก callback แล้วแสดง feedback — ไม่ pop
      widget.onScanned?.call(result);
      // Reset สั้นๆ เพื่อป้องกัน detect ซ้ำจาก frame เดิม
      setState(() => _scanned = true);
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) setState(() => _scanned = false);
      });
    } else {
      // Single: pop กลับพร้อมผล
      setState(() => _scanned = true);
      Navigator.pop(context, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          widget.continuous
              ? 'สแกนต่อเนื่อง — กด ✕ เพื่อปิด'
              : 'สแกนบาร์โค้ด / QR Code',
        ),
        actions: [
          // Torch toggle
          IconButton(
            icon: Icon(
              _torchOn ? Icons.flash_on : Icons.flash_off,
              color: _torchOn ? Colors.yellow : Colors.white,
            ),
            onPressed: () => setState(() => _torchOn = !_torchOn),
          ),
        ],
      ),
      body: Stack(
        children: [
          // ── Camera Preview ──────────────────────────────────
          // ✅ เปิด comment นี้เมื่อเพิ่ม mobile_scanner: ^6.0.0 ใน pubspec
          //
          // MobileScanner(
          //   controller: MobileScannerController(torchEnabled: _torchOn),
          //   onDetect: (capture) {
          //     if (_scanned && !widget.continuous) return;
          //     final barcode = capture.barcodes.first;
          //     final value   = barcode.rawValue;
          //     if (value == null) return;
          //     HapticFeedback.mediumImpact();
          //     _handleDetected(
          //       value,
          //       barcode.format == BarcodeFormat.qrCode
          //           ? ScanType.qrCode
          //           : ScanType.barcode,
          //     );
          //   },
          // ),
          Container(color: Colors.black87),

          // ── Scan Frame Overlay ──────────────────────────────
          Center(child: _ScanOverlay()),

          // ── Feedback เมื่อสแกนได้ (continuous mode) ─────────
          if (widget.continuous && _scanned)
            Positioned(
              top: 20,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'เพิ่มแล้ว!',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── Manual Input Button ─────────────────────────────
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                icon: const Icon(Icons.keyboard),
                label: const Text('กรอกเอง'),
                onPressed: () async {
                  final result =
                      await MobileScannerService._showManualInputDialog(
                        context,
                      );
                  if (result == null || !context.mounted) return;

                  if (widget.continuous) {
                    // Continuous: เรียก callback แล้วอยู่ต่อ
                    widget.onScanned?.call(result);
                  } else {
                    // Single: pop กลับ
                    Navigator.pop(context, result);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// Scan Frame Overlay (viewfinder)
// ─────────────────────────────────────────
class _ScanOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const size = 260.0;
    const cornerSize = 24.0;
    const cornerWidth = 4.0;
    const color = Colors.white;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          // dim border outside frame
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white24, width: 1),
            ),
          ),
          // corner TL
          _corner(
            top: 0,
            left: 0,
            color: color,
            size: cornerSize,
            width: cornerWidth,
            top_: true,
            left_: true,
          ),
          // corner TR
          _corner(
            top: 0,
            right: 0,
            color: color,
            size: cornerSize,
            width: cornerWidth,
            top_: true,
            left_: false,
          ),
          // corner BL
          _corner(
            bottom: 0,
            left: 0,
            color: color,
            size: cornerSize,
            width: cornerWidth,
            top_: false,
            left_: true,
          ),
          // corner BR
          _corner(
            bottom: 0,
            right: 0,
            color: color,
            size: cornerSize,
            width: cornerWidth,
            top_: false,
            left_: false,
          ),
        ],
      ),
    );
  }

  Widget _corner({
    double? top,
    double? left,
    double? right,
    double? bottom,
    required Color color,
    required double size,
    required double width,
    required bool top_,
    required bool left_,
  }) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _CornerPainter(
            color: color,
            strokeWidth: width,
            topLeft: top_ && left_,
            topRight: top_ && !left_,
            bottomLeft: !top_ && left_,
            bottomRight: !top_ && !left_,
          ),
        ),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  _CornerPainter({
    required this.color,
    required this.strokeWidth,
    this.topLeft = false,
    this.topRight = false,
    this.bottomLeft = false,
    this.bottomRight = false,
  });

  final Color color;
  final double strokeWidth;
  final bool topLeft, topRight, bottomLeft, bottomRight;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.square
      ..style = PaintingStyle.stroke;

    if (topLeft) {
      canvas.drawLine(Offset.zero, Offset(size.width, 0), paint);
      canvas.drawLine(Offset.zero, Offset(0, size.height), paint);
    }
    if (topRight) {
      canvas.drawLine(Offset(size.width, 0), Offset.zero, paint);
      canvas.drawLine(
        Offset(size.width, 0),
        Offset(size.width, size.height),
        paint,
      );
    }
    if (bottomLeft) {
      canvas.drawLine(
        Offset(0, size.height),
        Offset(size.width, size.height),
        paint,
      );
      canvas.drawLine(Offset(0, size.height), Offset.zero, paint);
    }
    if (bottomRight) {
      canvas.drawLine(
        Offset(size.width, size.height),
        Offset(0, size.height),
        paint,
      );
      canvas.drawLine(
        Offset(size.width, size.height),
        Offset(size.width, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_CornerPainter old) => false;
}

// ─────────────────────────────────────────
// Scanner Button Widget
// ใช้ต่อกับ TextField ใน POS / Product form
// ─────────────────────────────────────────
class ScannerButton extends StatelessWidget {
  const ScannerButton({
    super.key,
    required this.onScanned,
    this.tooltip = 'สแกนบาร์โค้ด',
  });

  final ValueChanged<String> onScanned;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.qr_code_scanner),
      tooltip: tooltip,
      onPressed: () async {
        final result = await MobileScannerService.scan(context);
        if (result != null) {
          onScanned(result.value);
        }
      },
    );
  }
}
