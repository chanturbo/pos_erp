import 'package:flutter/material.dart';
import '../utils/mobile_config.dart';

// ─────────────────────────────────────────
// Scanner Result
// ─────────────────────────────────────────
class ScanResult {
  const ScanResult({
    required this.value,
    required this.type,
  });

  final String value;
  final ScanType type;

  bool get isBarcode => type == ScanType.barcode;
  bool get isQRCode  => type == ScanType.qrCode;
}

enum ScanType { barcode, qrCode, unknown }

// ─────────────────────────────────────────
// Scanner Service
// mobile_scanner package ต้องเพิ่มใน pubspec:
//   mobile_scanner: ^6.0.0
// ─────────────────────────────────────────
class MobileScannerService {
  /// เปิด scanner dialog และ return ค่าที่สแกนได้
  /// ถ้า cancel หรือ error return null
  static Future<ScanResult?> scan(BuildContext context) async {
    if (!MobileConfig.isMobile) {
      // Desktop: แสดง manual input แทน
      return _showManualInputDialog(context);
    }

    return Navigator.of(context).push<ScanResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const _ScannerPage(),
      ),
    );
  }

  /// Fallback สำหรับ Desktop — กรอก barcode มือ
  /// ✅ ใช้ _ManualInputDialog (StatefulWidget) เพื่อจัดการ
  /// controller lifecycle อย่างถูกต้อง
  static Future<ScanResult?> _showManualInputDialog(
      BuildContext context) async {
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
      title: const Text('กรอกบาร์โค้ด / QR Code'),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'สแกนหรือกรอกบาร์โค้ด',
          prefixIcon: Icon(Icons.qr_code_scanner),
        ),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ยกเลิก'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _ctrl.text),
          child: const Text('ตกลง'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────
// Scanner Page UI
// ─────────────────────────────────────────
class _ScannerPage extends StatefulWidget {
  const _ScannerPage();

  @override
  State<_ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<_ScannerPage> {
  bool _torchOn  = false;
  bool _scanned  = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('สแกนบาร์โค้ด / QR Code'),
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
          // ── Camera Preview placeholder ──
          // ในการใช้งานจริง ใช้ MobileScanner widget:
          //
          // MobileScanner(
          //   controller: MobileScannerController(torchEnabled: _torchOn),
          //   onDetect: (capture) {
          //     if (_scanned) return;
          //     final barcode = capture.barcodes.first;
          //     final value = barcode.rawValue;
          //     if (value == null) return;
          //     setState(() => _scanned = true);
          //     MobileConfig.hapticSuccess();
          //     Navigator.pop(context, ScanResult(
          //       value: value,
          //       type: barcode.format == BarcodeFormat.qrCode
          //           ? ScanType.qrCode
          //           : ScanType.barcode,
          //     ));
          //   },
          // ),
          Container(color: Colors.black87),

          // ── Scan Frame Overlay ──
          Center(
            child: _ScanOverlay(),
          ),

          // ── Manual Input Button ──
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
                          context);
                  if (result != null && context.mounted) {
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
              border: Border.all(
                color: Colors.white24,
                width: 1,
              ),
            ),
          ),
          // corner TL
          _corner(top: 0, left: 0, color: color,
              size: cornerSize, width: cornerWidth,
              top_: true, left_: true),
          // corner TR
          _corner(top: 0, right: 0, color: color,
              size: cornerSize, width: cornerWidth,
              top_: true, left_: false),
          // corner BL
          _corner(bottom: 0, left: 0, color: color,
              size: cornerSize, width: cornerWidth,
              top_: false, left_: true),
          // corner BR
          _corner(bottom: 0, right: 0, color: color,
              size: cornerSize, width: cornerWidth,
              top_: false, left_: false),
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
          Offset(size.width, 0), Offset(size.width, size.height), paint);
    }
    if (bottomLeft) {
      canvas.drawLine(
          Offset(0, size.height), Offset(size.width, size.height), paint);
      canvas.drawLine(Offset(0, size.height), Offset.zero, paint);
    }
    if (bottomRight) {
      canvas.drawLine(Offset(size.width, size.height),
          Offset(0, size.height), paint);
      canvas.drawLine(Offset(size.width, size.height),
          Offset(size.width, 0), paint);
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