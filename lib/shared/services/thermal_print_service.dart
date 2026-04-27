import 'dart:async';
import 'dart:convert' show utf8;
import 'dart:io';

import '../../core/services/license/license_local_service.dart';
import '../../core/services/license/license_models.dart';
import '../widgets/thermal_receipt.dart';

class ThermalPrintSettings {
  final bool enabled;
  final bool autoPrintOnSale;
  final String host;
  final int port;
  final int paperWidthMm;

  const ThermalPrintSettings({
    required this.enabled,
    required this.autoPrintOnSale,
    required this.host,
    required this.port,
    required this.paperWidthMm,
  });

  bool get canPrintDirect =>
      enabled && host.trim().isNotEmpty && port > 0 && paperWidthMm > 0;

  int get charactersPerLine => paperWidthMm <= 58 ? 32 : 42;
}

class ThermalReceiptDocument {
  final String companyName;
  final String address;
  final String phone;
  final String taxId;
  final String title;
  final String? footerNote;
  final String orderNo;
  final String orderDate;
  final String? customerName;
  final List<ReceiptItem> items;
  final List<ReceiptFreeItem> freeItems;
  final double subtotal;
  final double discount;
  final double serviceCharge;
  final List<ReceiptCoupon> coupons;
  final double total;
  final String paymentLabel;
  final String paymentType;
  final double paidAmount;
  final double changeAmount;
  final int earnedPoints;
  final int pointsUsed;
  final int? pointsBalance;

  const ThermalReceiptDocument({
    required this.companyName,
    required this.address,
    required this.phone,
    required this.taxId,
    this.title = 'ใบเสร็จรับเงิน',
    this.footerNote,
    required this.orderNo,
    required this.orderDate,
    required this.items,
    required this.subtotal,
    required this.discount,
    this.serviceCharge = 0,
    required this.total,
    required this.paymentLabel,
    required this.paymentType,
    required this.paidAmount,
    required this.changeAmount,
    this.customerName,
    this.freeItems = const [],
    this.coupons = const [],
    this.earnedPoints = 0,
    this.pointsUsed = 0,
    this.pointsBalance,
  });
}

// ── Kitchen Ticket ────────────────────────────────────────────────────────────

class KitchenTicketItem {
  final int courseNo;
  final double quantity;
  final String unit;
  final String name;
  final String? specialInstructions;
  final String? station;

  const KitchenTicketItem({
    required this.courseNo,
    required this.quantity,
    required this.unit,
    required this.name,
    this.specialInstructions,
    this.station,
  });
}

class KitchenTicketDocument {
  final String tableName;
  final String orderNo;
  final String orderTime;
  final List<KitchenTicketItem> items;

  const KitchenTicketDocument({
    required this.tableName,
    required this.orderNo,
    required this.orderTime,
    required this.items,
  });
}

class ThermalPrintException implements Exception {
  final String message;

  const ThermalPrintException(this.message);

  @override
  String toString() => message;
}

class ThermalPrintService {
  const ThermalPrintService._();

  static const ThermalPrintService instance = ThermalPrintService._();

  Future<void> printReceipt({
    required ThermalPrintSettings settings,
    required ThermalReceiptDocument document,
  }) async {
    await LicenseLocalService.ensureFeatureAllowed(
      LicenseFeature.printReceipt,
    );
    if (!settings.enabled) {
      throw const ThermalPrintException('ยังไม่ได้เปิดใช้งาน direct thermal print');
    }
    if (settings.host.trim().isEmpty) {
      throw const ThermalPrintException('กรุณาตั้งค่า IP/Host ของเครื่องพิมพ์');
    }
    if (settings.port <= 0) {
      throw const ThermalPrintException('พอร์ตเครื่องพิมพ์ไม่ถูกต้อง');
    }

    final bytes = _buildEscPosBytes(document, settings.charactersPerLine);
    Socket? socket;
    try {
      socket = await Socket.connect(
        settings.host.trim(),
        settings.port,
        timeout: const Duration(seconds: 5),
      );
      socket.add(bytes);
      await socket.flush();
      await Future<void>.delayed(const Duration(milliseconds: 250));
    } on SocketException catch (e) {
      throw ThermalPrintException(
        'เชื่อมต่อเครื่องพิมพ์ไม่สำเร็จ (${settings.host}:${settings.port}) - ${e.message}',
      );
    } on TimeoutException {
      throw ThermalPrintException(
        'หมดเวลาในการเชื่อมต่อเครื่องพิมพ์ (${settings.host}:${settings.port})',
      );
    } finally {
      await socket?.close();
    }
  }

  List<int> _buildEscPosBytes(ThermalReceiptDocument doc, int lineWidth) {
    final bytes = <int>[];
    void write(List<int> data) => bytes.addAll(data);
    void writeln(String text) => write([...utf8.encode('$text\n')]);

    write(const [0x1B, 0x40]); // init
    write(const [0x1B, 0x61, 0x01]); // center
    write(const [0x1B, 0x45, 0x01]); // bold on
    writeln(_fitCenter(doc.companyName, lineWidth));
    write(const [0x1B, 0x45, 0x00]); // bold off
    if (doc.address.trim().isNotEmpty) {
      for (final line in _wrapText(doc.address.trim(), lineWidth)) {
        writeln(_fitCenter(line, lineWidth));
      }
    }
    if (doc.phone.trim().isNotEmpty) {
      writeln(_fitCenter('โทร: ${doc.phone.trim()}', lineWidth));
    }
    if (doc.taxId.trim().isNotEmpty) {
      writeln(_fitCenter('เลขภาษี: ${doc.taxId.trim()}', lineWidth));
    }

    writeln(_divider(lineWidth));
    write(const [0x1B, 0x45, 0x01]);
    writeln(_fitCenter(doc.title, lineWidth));
    write(const [0x1B, 0x45, 0x00]);
    write(const [0x1B, 0x61, 0x00]); // left

    writeln(_pair('เลขที่', doc.orderNo, lineWidth));
    writeln(_pair('วันที่', doc.orderDate, lineWidth));
    if (doc.customerName != null &&
        doc.customerName!.trim().isNotEmpty &&
        doc.customerName != 'ลูกค้าทั่วไป') {
      for (final line in _wrapValuePair('ลูกค้า', doc.customerName!.trim(), lineWidth)) {
        writeln(line);
      }
    }

    writeln(_divider(lineWidth));

    for (final item in doc.items) {
      for (final line in _wrapText(item.name, lineWidth)) {
        writeln(line);
      }
      if (item.note != null && item.note!.trim().isNotEmpty) {
        for (final line in _wrapText(item.note!.trim(), lineWidth - 4)) {
          writeln('  * $line');
        }
      }
      final detail =
          '  ${_formatQty(item.quantity)} x ${_money(item.unitPrice)}';
      writeln(_pair(detail, _money(item.amount), lineWidth));
    }
    writeln(_pair('รวม ${doc.items.length} รายการ', '', lineWidth));

    if (doc.freeItems.isNotEmpty) {
      writeln(_divider(lineWidth));
      write(const [0x1B, 0x45, 0x01]);
      writeln('ของแถมฟรี');
      write(const [0x1B, 0x45, 0x00]);
      for (final item in doc.freeItems) {
        for (final line in _wrapText('  * ${item.name}', lineWidth)) {
          writeln(line);
        }
        writeln(_pair('  จำนวน', _formatQty(item.quantity), lineWidth));
      }
    }

    writeln(_divider(lineWidth));
    writeln(_pair('รวม', _baht(doc.subtotal), lineWidth));
    if (doc.discount > 0) {
      writeln(_pair('ส่วนลด', '-${_baht(doc.discount)}', lineWidth));
    }
    if (doc.serviceCharge > 0) {
      writeln(_pair('Service charge', _baht(doc.serviceCharge), lineWidth));
    }
    for (final coupon in doc.coupons) {
      final label = 'คูปอง ${coupon.code}';
      writeln(_pair(label, '-${_baht(coupon.discount)}', lineWidth));
    }
    if (doc.pointsUsed > 0) {
      writeln(_pair('แลกแต้ม ${doc.pointsUsed} pt', '-${_baht(doc.pointsUsed.toDouble())}', lineWidth));
    }

    writeln(_solidLine(lineWidth));
    write(const [0x1B, 0x45, 0x01]);
    writeln(_pair('ยอดชำระ', _baht(doc.total), lineWidth));
    write(const [0x1B, 0x45, 0x00]);
    writeln(_solidLine(lineWidth));
    writeln(_pair('ชำระด้วย', doc.paymentLabel, lineWidth));
    if (doc.paymentType == 'CASH') {
      writeln(_pair('รับเงิน', _baht(doc.paidAmount), lineWidth));
      writeln(_pair('เงินทอน', _baht(doc.changeAmount), lineWidth));
    }

    if (doc.earnedPoints > 0 || doc.pointsBalance != null) {
      writeln(_divider(lineWidth));
      if (doc.earnedPoints > 0) {
        writeln(_fitCenter('ได้รับ ${doc.earnedPoints} แต้มสะสม', lineWidth));
      }
      if (doc.pointsBalance != null) {
        writeln(_fitCenter('แต้มคงเหลือ ${doc.pointsBalance} แต้ม', lineWidth));
      }
    }

    writeln(_divider(lineWidth));
    write(const [0x1B, 0x61, 0x01]); // center
    write(const [0x1B, 0x45, 0x01]);
    writeln(_fitCenter('ขอบคุณที่ใช้บริการ', lineWidth));
    write(const [0x1B, 0x45, 0x00]);
    writeln(_fitCenter('(THANK YOU)', lineWidth));
    writeln(_fitCenter('โปรดเก็บใบเสร็จไว้เป็นหลักฐาน', lineWidth));
    if (doc.footerNote != null && doc.footerNote!.trim().isNotEmpty) {
      for (final line in _wrapText(doc.footerNote!.trim(), lineWidth)) {
        writeln(_fitCenter(line, lineWidth));
      }
    }
    writeln('');
    writeln('');
    write(const [0x1D, 0x56, 0x41, 0x10]); // cut

    return bytes;
  }

  List<String> _wrapValuePair(String label, String value, int lineWidth) {
    final lines = <String>[];
    final initial = '$label: $value';
    if (initial.length <= lineWidth) {
      return [initial];
    }
    lines.add('$label:');
    lines.addAll(_wrapText(value, lineWidth - 2).map((e) => '  $e'));
    return lines;
  }

  String _pair(String left, String right, int lineWidth) {
    if (right.isEmpty) return left;
    final leftTrimmed = left.trimRight();
    final rightTrimmed = right.trimLeft();
    final maxLeft = lineWidth - rightTrimmed.length - 1;
    if (maxLeft <= 0) return '$leftTrimmed $rightTrimmed';
    final normalizedLeft = leftTrimmed.length > maxLeft
        ? '${leftTrimmed.substring(0, maxLeft - 1)}…'
        : leftTrimmed;
    final spaces = (lineWidth - normalizedLeft.length - rightTrimmed.length)
        .clamp(1, lineWidth);
    return '$normalizedLeft${' ' * spaces}$rightTrimmed';
  }

  List<String> _wrapText(String text, int lineWidth) {
    final normalized = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) return [''];

    final words = normalized.split(' ');
    final lines = <String>[];
    var current = '';

    for (final word in words) {
      final next = current.isEmpty ? word : '$current $word';
      if (next.length <= lineWidth) {
        current = next;
        continue;
      }
      if (current.isNotEmpty) {
        lines.add(current);
      }
      if (word.length <= lineWidth) {
        current = word;
        continue;
      }

      var remaining = word;
      while (remaining.length > lineWidth) {
        lines.add(remaining.substring(0, lineWidth));
        remaining = remaining.substring(lineWidth);
      }
      current = remaining;
    }

    if (current.isNotEmpty) {
      lines.add(current);
    }
    return lines;
  }

  String _divider(int width) => '-' * width;
  String _solidLine(int width) => '=' * width;
  String _fitCenter(String text, int width) {
    if (text.length >= width) return text;
    final left = ((width - text.length) / 2).floor();
    return '${' ' * left}$text';
  }

  String _formatQty(double qty) {
    if (qty == qty.roundToDouble()) {
      return qty.toStringAsFixed(0);
    }
    return qty.toStringAsFixed(2);
  }

  String _money(double value) => value.toStringAsFixed(2);
  String _baht(double value) => '฿${_money(value)}';

  // ── Kitchen Ticket ──────────────────────────────────────────────────────────

  Future<void> printKitchenTicket({
    required ThermalPrintSettings settings,
    required KitchenTicketDocument document,
  }) async {
    if (!settings.canPrintDirect) return;
    final bytes = _buildKitchenTicketBytes(document, settings.charactersPerLine);
    Socket? socket;
    try {
      socket = await Socket.connect(
        settings.host.trim(),
        settings.port,
        timeout: const Duration(seconds: 5),
      );
      socket.add(bytes);
      await socket.flush();
      await Future<void>.delayed(const Duration(milliseconds: 200));
    } on SocketException {
      // silent fail — ไม่ block การสั่งอาหาร
    } on TimeoutException {
      // silent fail
    } finally {
      await socket?.close();
    }
  }

  List<int> _buildKitchenTicketBytes(KitchenTicketDocument doc, int lineWidth) {
    final bytes = <int>[];
    void write(List<int> data) => bytes.addAll(data);
    void writeln(String text) => write([...utf8.encode('$text\n')]);

    write(const [0x1B, 0x40]); // init
    // ── header ──
    write(const [0x1B, 0x61, 0x01]); // center
    write(const [0x1D, 0x21, 0x11]); // double width+height
    write(const [0x1B, 0x45, 0x01]); // bold on
    writeln('ORDER TICKET');
    write(const [0x1D, 0x21, 0x00]); // normal size
    write(const [0x1B, 0x45, 0x00]); // bold off
    final destination = doc.tableName.trim().isEmpty ? 'ไม่ระบุโต๊ะ' : doc.tableName.trim();
    final isTakeaway =
        destination.toUpperCase() == 'TAKEAWAY' || destination == 'ซื้อกลับบ้าน';
    writeln(
      _fitCenter(isTakeaway ? 'TAKEAWAY' : 'TABLE: $destination', lineWidth),
    );
    writeln(_fitCenter('#${doc.orderNo}  ${doc.orderTime}', lineWidth));
    writeln(_divider(lineWidth));

    // ── items ──
    write(const [0x1B, 0x61, 0x00]); // left align

    // group by station
    final stations = <String, List<KitchenTicketItem>>{};
    for (final item in doc.items) {
      final s = (item.station ?? 'kitchen').toLowerCase();
      (stations[s] ??= []).add(item);
    }
    const stationOrder = ['kitchen', 'bar', 'dessert', 'cashier'];
    final keys = [
      ...stationOrder.where(stations.containsKey),
      ...stations.keys.where((k) => !stationOrder.contains(k)),
    ];

    for (final station in keys) {
      if (keys.length > 1) {
        write(const [0x1B, 0x45, 0x01]);
        writeln('[ ${_stationLabel(station)} ]');
        write(const [0x1B, 0x45, 0x00]);
      }
      for (final item in stations[station]!) {
        final courseTag = item.courseNo > 1 ? '[C${item.courseNo}] ' : '';
        final qty = _formatQty(item.quantity);
        final qtyPad = '$courseTag$qty ${item.unit}';
        // Bold item name
        write(const [0x1B, 0x45, 0x01]);
        writeln(_pair(item.name, qtyPad, lineWidth));
        write(const [0x1B, 0x45, 0x00]);
        if (item.specialInstructions != null &&
            item.specialInstructions!.trim().isNotEmpty) {
          writeln('  * ${item.specialInstructions!.trim()}');
        }
      }
      writeln('');
    }

    writeln(_divider(lineWidth));
    // cut paper
    write(const [0x1D, 0x56, 0x42, 0x00]);
    return bytes;
  }

  String _stationLabel(String station) {
    switch (station) {
      case 'kitchen': return 'KITCHEN';
      case 'bar': return 'BAR';
      case 'dessert': return 'DESSERT';
      case 'cashier': return 'CASHIER';
      default: return station.toUpperCase();
    }
  }
}
