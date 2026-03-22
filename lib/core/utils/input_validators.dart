import 'dart:convert';
import 'package:shelf/shelf.dart';

// ─────────────────────────────────────────────────────────────────
// InputValidators — Shared validation helpers ใช้ได้ทุก route
//
// แนวคิด: validation ทำก่อน business logic เสมอ
// ถ้า invalid → return 400 พร้อม message ที่ชัดเจน
// ไม่ให้ข้อมูลผิดรูปแบบเข้าถึง DB เลย
// ─────────────────────────────────────────────────────────────────
class InputValidators {
  // ─────────────────────────────────────────────────────────────
  // Response helpers
  // ─────────────────────────────────────────────────────────────
  static Response badRequest(String message) => Response(
        400,
        body: jsonEncode({'success': false, 'message': message}),
        headers: {'Content-Type': 'application/json'},
      );

  // ─────────────────────────────────────────────────────────────
  // String validators
  // ─────────────────────────────────────────────────────────────

  /// ตรวจสอบว่าเป็น String ไม่ว่างและความยาวไม่เกิน maxLen
  static String? validateString(
    Map<String, dynamic> data,
    String field, {
    required int maxLen,
    bool required = true,
    int minLen = 1,
  }) {
    final val = data[field];
    if (val == null || val.toString().isEmpty) {
      return required ? '$field ไม่สามารถเว้นว่างได้' : null;
    }
    final str = val.toString().trim();
    if (str.length < minLen) return '$field ต้องมีอย่างน้อย $minLen ตัวอักษร';
    if (str.length > maxLen) return '$field ต้องไม่เกิน $maxLen ตัวอักษร';
    return null;
  }

  // ─────────────────────────────────────────────────────────────
  // Number validators
  // ─────────────────────────────────────────────────────────────

  /// ตรวจสอบว่าเป็น num ที่ >= min และ <= max
  static String? validateNumber(
    Map<String, dynamic> data,
    String field, {
    double min = 0,
    double? max,
    bool required = true,
    bool allowZero = true,
  }) {
    final val = data[field];
    if (val == null) {
      return required ? '$field ไม่สามารถเว้นว่างได้' : null;
    }
    if (val is! num) return '$field ต้องเป็นตัวเลข';
    final d = val.toDouble();
    if (!allowZero && d == 0) return '$field ต้องมากกว่า 0';
    if (d < min) return '$field ต้องไม่น้อยกว่า $min';
    if (max != null && d > max) return '$field ต้องไม่เกิน $max';
    return null;
  }

  // ─────────────────────────────────────────────────────────────
  // Format validators
  // ─────────────────────────────────────────────────────────────

  static final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final _phoneRegex = RegExp(r'^[0-9+\-\s()]{7,20}$');

  /// ตรวจสอบรูปแบบ email (optional field)
  static String? validateEmail(Map<String, dynamic> data, String field) {
    final val = data[field];
    if (val == null || val.toString().isEmpty) return null; // optional
    if (!_emailRegex.hasMatch(val.toString().trim())) {
      return '$field รูปแบบ email ไม่ถูกต้อง';
    }
    return null;
  }

  /// ตรวจสอบรูปแบบเบอร์โทร (optional field)
  static String? validatePhone(Map<String, dynamic> data, String field) {
    final val = data[field];
    if (val == null || val.toString().isEmpty) return null; // optional
    if (!_phoneRegex.hasMatch(val.toString().trim())) {
      return '$field รูปแบบเบอร์โทรไม่ถูกต้อง';
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────────
  // Composite validators — ใช้สำหรับ entity แต่ละประเภท
  // คืน list ของ error messages ทั้งหมด (ให้แก้ได้ทีเดียว)
  // ─────────────────────────────────────────────────────────────

  /// Validate product create/update
  static List<String> validateProduct(Map<String, dynamic> data,
      {bool isUpdate = false}) {
    final errors = <String>[];

    _addIfError(errors,
        validateString(data, 'product_code', maxLen: 50, required: !isUpdate));
    _addIfError(errors,
        validateString(data, 'product_name', maxLen: 500, required: !isUpdate));
    _addIfError(errors,
        validateString(data, 'base_unit', maxLen: 20, required: !isUpdate));

    // ✅ ราคาต้องไม่ติดลบ
    for (final f in ['price_level1', 'price_level2', 'price_level3',
        'price_level4', 'price_level5']) {
      if (data.containsKey(f)) {
        _addIfError(errors, validateNumber(data, f, min: 0));
      }
    }
    // ✅ price_level1 ต้องมีราคา (ถ้าสร้างใหม่)
    if (!isUpdate && data.containsKey('price_level1')) {
      final p1 = (data['price_level1'] as num?)?.toDouble() ?? 0;
      if (p1 == 0) errors.add('price_level1 ต้องมากกว่า 0');
    }

    if (data.containsKey('standard_cost')) {
      _addIfError(errors, validateNumber(data, 'standard_cost', min: 0));
    }
    if (data.containsKey('barcode') && data['barcode'] != null) {
      _addIfError(errors,
          validateString(data, 'barcode', maxLen: 100, required: false));
    }

    return errors;
  }

  /// Validate customer create/update
  static List<String> validateCustomer(Map<String, dynamic> data,
      {bool isUpdate = false}) {
    final errors = <String>[];

    _addIfError(
        errors,
        validateString(data, 'customer_code',
            maxLen: 50, required: !isUpdate));
    _addIfError(
        errors,
        validateString(data, 'customer_name',
            maxLen: 300, required: !isUpdate));

    // Contact (optional แต่ตรวจ format)
    _addIfError(errors, validateEmail(data, 'email'));
    _addIfError(errors, validatePhone(data, 'phone'));

    if (data.containsKey('tax_id') && data['tax_id'] != null) {
      _addIfError(errors,
          validateString(data, 'tax_id', maxLen: 20, required: false));
    }

    // ✅ credit_limit ต้องไม่ติดลบ ไม่เกิน 100 ล้าน
    if (data.containsKey('credit_limit')) {
      _addIfError(errors,
          validateNumber(data, 'credit_limit', min: 0, max: 100000000));
    }
    // ✅ credit_days ต้องอยู่ระหว่าง 0-365
    if (data.containsKey('credit_days')) {
      _addIfError(
          errors, validateNumber(data, 'credit_days', min: 0, max: 365));
    }

    return errors;
  }

  /// Validate sales order item
  static List<String> validateOrderItem(
      Map<String, dynamic> item, int lineNo) {
    final errors = <String>[];
    final label = 'รายการที่ $lineNo';

    if (item['product_id'] is! String ||
        (item['product_id'] as String).isEmpty) {
      errors.add('$label: product_id ไม่ถูกต้อง');
    }
    if (item['quantity'] is! num || (item['quantity'] as num) <= 0) {
      errors.add('$label: quantity ต้องมากกว่า 0');
    }
    if (item['unit_price'] is! num || (item['unit_price'] as num) < 0) {
      errors.add('$label: unit_price ต้องไม่ติดลบ');
    }
    // ✅ ส่วนลดต่อรายการต้องไม่มากกว่าราคา
    if (item['unit_price'] is num && item['quantity'] is num) {
      final lineTotal =
          (item['unit_price'] as num) * (item['quantity'] as num);
      final discAmt =
          (item['discount_amount'] as num?)?.toDouble() ?? 0;
      final discPct =
          (item['discount_percent'] as num?)?.toDouble() ?? 0;
      if (discPct > 100) {
        errors.add('$label: discount_percent ต้องไม่เกิน 100%');
      }
      if (discAmt > lineTotal) {
        errors.add('$label: discount_amount ต้องไม่เกินยอดรวมของรายการ');
      }
    }

    return errors;
  }

  // ─────────────────────────────────────────────────────────────
  // Private helpers
  // ─────────────────────────────────────────────────────────────
  static void _addIfError(List<String> errors, String? error) {
    if (error != null) errors.add(error);
  }
}