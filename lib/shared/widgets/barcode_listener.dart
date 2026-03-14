import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────
// USB Barcode Scanner Listener
//
// USB scanner ส่งข้อมูลเป็น keyboard input
// โดย:
//  - พิมพ์ตัวอักษรเร็วมาก (< 50ms ต่อตัว)
//  - ส่ง Enter (↵) เมื่อสแกนเสร็จ
//
// Widget นี้ดักจับ pattern นั้น และ callback
// ค่า barcode กลับมาโดยไม่ต้อง focus TextField
// ─────────────────────────────────────────

class BarcodeListener extends StatefulWidget {
  const BarcodeListener({
    super.key,
    required this.child,
    required this.onBarcodeScanned,
    this.minLength = 3,
    this.maxInterval = const Duration(milliseconds: 50),
    this.enabled = true,
  });

  final Widget child;

  /// Callback เมื่อสแกนได้ barcode
  final ValueChanged<String> onBarcodeScanned;

  /// ความยาวขั้นต่ำของ barcode (ป้องกัน false positive)
  final int minLength;

  /// ระยะเวลาสูงสุดระหว่างแต่ละตัวอักษร
  /// USB scanner พิมพ์เร็วกว่า 50ms/ตัว
  final Duration maxInterval;

  /// เปิด/ปิด listener
  final bool enabled;

  @override
  State<BarcodeListener> createState() => _BarcodeListenerState();
}

class _BarcodeListenerState extends State<BarcodeListener> {
  final StringBuffer _buffer = StringBuffer();
  DateTime? _lastKeyTime;
  Timer? _resetTimer;

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  void _handleKey(KeyEvent event) {
    if (!widget.enabled) return;
    if (event is! KeyDownEvent) return;

    final now = DateTime.now();

    // ── ตรวจว่าพิมพ์เร็วเกินกว่า human typing ──
    if (_lastKeyTime != null) {
      final gap = now.difference(_lastKeyTime!);
      if (gap > widget.maxInterval) {
        // พิมพ์ช้าเกินไป → น่าจะเป็นมนุษย์พิมพ์เอง reset buffer
        _buffer.clear();
      }
    }
    _lastKeyTime = now;

    // ── Enter = จบ barcode ──
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      final barcode = _buffer.toString().trim();
      _buffer.clear();
      _lastKeyTime = null;
      _resetTimer?.cancel();

      if (barcode.length >= widget.minLength) {
        widget.onBarcodeScanned(barcode);
      }
      return;
    }

    // ── ตัวอักษรปกติ → เพิ่มใน buffer ──
    final char = _keyToChar(event.logicalKey);
    if (char != null) {
      _buffer.write(char);
    }

    // ── Auto reset ถ้าไม่มี Enter ใน 200ms ──
    _resetTimer?.cancel();
    _resetTimer = Timer(const Duration(milliseconds: 200), () {
      _buffer.clear();
      _lastKeyTime = null;
    });
  }

  /// แปลง LogicalKeyboardKey เป็น character
  String? _keyToChar(LogicalKeyboardKey key) {
    // ตัวเลข
    final digits = {
      LogicalKeyboardKey.digit0: '0',
      LogicalKeyboardKey.digit1: '1',
      LogicalKeyboardKey.digit2: '2',
      LogicalKeyboardKey.digit3: '3',
      LogicalKeyboardKey.digit4: '4',
      LogicalKeyboardKey.digit5: '5',
      LogicalKeyboardKey.digit6: '6',
      LogicalKeyboardKey.digit7: '7',
      LogicalKeyboardKey.digit8: '8',
      LogicalKeyboardKey.digit9: '9',
      LogicalKeyboardKey.numpad0: '0',
      LogicalKeyboardKey.numpad1: '1',
      LogicalKeyboardKey.numpad2: '2',
      LogicalKeyboardKey.numpad3: '3',
      LogicalKeyboardKey.numpad4: '4',
      LogicalKeyboardKey.numpad5: '5',
      LogicalKeyboardKey.numpad6: '6',
      LogicalKeyboardKey.numpad7: '7',
      LogicalKeyboardKey.numpad8: '8',
      LogicalKeyboardKey.numpad9: '9',
    };
    if (digits.containsKey(key)) return digits[key];

    // ตัวอักษร A-Z
    final label = key.keyLabel;
    if (label.length == 1) return label.toUpperCase();

    // hyphen, dash (พบใน barcode บางประเภท)
    if (key == LogicalKeyboardKey.minus ||
        key == LogicalKeyboardKey.numpadSubtract)
      return '-';

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      onKeyEvent: _handleKey,
      child: widget.child,
    );
  }
}

// ─────────────────────────────────────────
// BarcodeTextField
// TextField ที่รับ barcode จาก USB scanner
// หรือพิมพ์เองก็ได้ — ใช้แทน TextField + BarcodeListener
// ─────────────────────────────────────────
class BarcodeTextField extends StatefulWidget {
  const BarcodeTextField({
    super.key,
    required this.controller,
    this.label = 'บาร์โค้ด',
    this.hint = 'สแกนหรือพิมพ์บาร์โค้ด',
    this.onScanned,
    this.autofocus = false,
    this.decoration,
  });

  final TextEditingController controller;
  final String label;
  final String hint;

  /// Callback เมื่อสแกนได้ (Enter หรือ USB scanner)
  final ValueChanged<String>? onScanned;
  final bool autofocus;
  final InputDecoration? decoration;

  @override
  State<BarcodeTextField> createState() => _BarcodeTextFieldState();
}

class _BarcodeTextFieldState extends State<BarcodeTextField> {
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      autofocus: widget.autofocus,
      decoration:
          widget.decoration ??
          InputDecoration(
            labelText: widget.label,
            hintText: widget.hint,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.qr_code_scanner),
            suffixIcon: widget.controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      widget.controller.clear();
                      setState(() {});
                    },
                  )
                : null,
          ),
      // ✅ กด Enter = trigger onScanned (รองรับ USB scanner)
      onSubmitted: (value) {
        if (value.isNotEmpty) {
          widget.onScanned?.call(value.trim());
        }
      },
      onChanged: (_) => setState(() {}),
    );
  }
}
