// lib/core/utils/promptpay_utils.dart
//
// PromptPay QR Code Generator
// มาตรฐาน EMV QR Code — Bank of Thailand
// รองรับ: เบอร์โทรศัพท์ (10 หลัก) และเลขประจำตัว (13 หลัก)

class PromptPayUtils {
  PromptPayUtils._();

  // ── EMV Tag Constants ─────────────────────────────────────────
  static const _payloadFormatIndicator   = '000201';
  static const _pointOfInitiationMethod  = '010212'; // dynamic QR (จ่ายครั้งเดียว)
  static const _merchantCategoryCode     = '52040000';
  static const _transactionCurrency      = '5303764'; // THB
  static const _countryCode             = '5802TH';

  // ── PromptPay AID (Application Identifier) ───────────────────
  static const _promptPayAid = 'A000000677010111';

  // ─────────────────────────────────────────────────────────────
  // generatePayload — สร้าง EMV QR string สำหรับ PromptPay
  //
  // [promptPayId] เบอร์โทร 10 หลัก หรือ เลขประจำตัว 13 หลัก
  // [amount]      ยอดเงิน (ถ้าเป็น 0 จะไม่ใส่ยอดใน QR)
  // ─────────────────────────────────────────────────────────────
  static String generatePayload(String promptPayId, double amount) {
    final normalized = _normalizeId(promptPayId);

    // Tag 29: Merchant Account Info (PromptPay)
    final accountInfo = _buildTag('00', _promptPayAid) +
        _buildTag('01', normalized);
    final tag29 = _buildTag('29', accountInfo);

    // Tag 54: Transaction Amount (optional เมื่อ amount > 0)
    final amountStr = amount > 0
        ? _buildTag('54', amount.toStringAsFixed(2))
        : '';

    // ประกอบ payload ก่อนคำนวณ CRC
    final payload =
        '$_payloadFormatIndicator$_pointOfInitiationMethod$tag29'
        '$_merchantCategoryCode$_transactionCurrency$amountStr'
        '${_countryCode}6304'; // Tag 63 header (CRC จะต่อท้าย)

    // คำนวณ CRC16 และต่อท้าย
    final crc = _crc16(payload);
    return '$payload$crc';
  }

  // ─────────────────────────────────────────────────────────────
  // _normalizeId — แปลง phone/national ID เป็น format PromptPay
  // ─────────────────────────────────────────────────────────────
  static String _normalizeId(String id) {
    // ลบ - และ space
    final clean = id.replaceAll(RegExp(r'[-\s]'), '');

    if (clean.length == 10 && clean.startsWith('0')) {
      // เบอร์โทร: 0812345678 → 0066812345678
      return '0066${clean.substring(1)}';
    } else if (clean.length == 13) {
      // เลขประจำตัว 13 หลัก
      return clean;
    }
    // fallback
    return clean;
  }

  // ─────────────────────────────────────────────────────────────
  // _buildTag — สร้าง EMV TLV (Tag + Length + Value)
  // ─────────────────────────────────────────────────────────────
  static String _buildTag(String tag, String value) {
    final length = value.length.toString().padLeft(2, '0');
    return '$tag$length$value';
  }

  // ─────────────────────────────────────────────────────────────
  // _crc16 — CRC16-CCITT (0xFFFF) ตามมาตรฐาน EMV QR
  // ─────────────────────────────────────────────────────────────
  static String _crc16(String payload) {
    const poly = 0x1021;
    var crc = 0xFFFF;

    for (final char in payload.codeUnits) {
      crc ^= char << 8;
      for (var i = 0; i < 8; i++) {
        if ((crc & 0x8000) != 0) {
          crc = ((crc << 1) ^ poly) & 0xFFFF;
        } else {
          crc = (crc << 1) & 0xFFFF;
        }
      }
    }

    return crc.toRadixString(16).toUpperCase().padLeft(4, '0');
  }

  // ─────────────────────────────────────────────────────────────
  // isValidPromptPayId — ตรวจสอบว่าเป็น ID ที่ valid หรือไม่
  // ─────────────────────────────────────────────────────────────
  static bool isValidPromptPayId(String id) {
    final clean = id.replaceAll(RegExp(r'[-\s]'), '');
    if (clean.length == 10 && clean.startsWith('0')) return true;
    if (clean.length == 13 && RegExp(r'^\d+$').hasMatch(clean)) return true;
    return false;
  }

  // ─────────────────────────────────────────────────────────────
  // formatDisplayId — แสดงเลข PromptPay สำหรับ UI
  // 0812345678 → 081-234-5678
  // ─────────────────────────────────────────────────────────────
  static String formatDisplayId(String id) {
    final clean = id.replaceAll(RegExp(r'[-\s]'), '');
    if (clean.length == 10) {
      return '${clean.substring(0, 3)}-${clean.substring(3, 6)}-${clean.substring(6)}';
    }
    return clean;
  }
}