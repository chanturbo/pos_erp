// ar_invoice_routes.dart
// Day 36-38: AR Invoice Routes — ใบแจ้งหนี้ลูกหนี้

import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:drift/drift.dart' hide JsonKey;
import '../../database/app_database.dart';
import 'package:flutter/foundation.dart';

class ArInvoiceRoutes {
  final AppDatabase db;

  ArInvoiceRoutes(this.db);

  Router get router {
    final router = Router();

    router.get('/', _getInvoicesHandler);
    router.get('/<id>', _getInvoiceHandler);
    router.post('/', _createInvoiceHandler);
    router.put('/<id>', _updateInvoiceHandler);
    router.delete('/<id>', _deleteInvoiceHandler);
    router.get('/customer/<customerId>', _getInvoicesByCustomerHandler);

    return router;
  }

  // ─── Helper: แปลง ArInvoice → Map ───────────────────────────────────────
  Map<String, dynamic> _invoiceToMap(ArInvoice inv) => {
        'invoice_id': inv.invoiceId,
        'invoice_no': inv.invoiceNo,
        'invoice_date': inv.invoiceDate.toIso8601String(),
        'due_date': inv.dueDate?.toIso8601String(),
        'customer_id': inv.customerId,
        'customer_name': inv.customerName,
        'total_amount': inv.totalAmount,
        'paid_amount': inv.paidAmount,
        'reference_type': inv.referenceType,
        'reference_id': inv.referenceId,
        'status': inv.status,
        'remark': inv.remark,
        'created_at': inv.createdAt.toIso8601String(),
        'updated_at': inv.updatedAt.toIso8601String(),
      };

  Map<String, dynamic> _itemToMap(ArInvoiceItem item) => {
        'item_id': item.itemId,
        'invoice_id': item.invoiceId,
        'line_no': item.lineNo,
        'product_id': item.productId,
        'product_code': item.productCode,
        'product_name': item.productName,
        'unit': item.unit,
        'quantity': item.quantity,
        'unit_price': item.unitPrice,
        'discount_amount': item.discountAmount,
        'amount': item.amount,
        'remark': item.remark,
      };

  // ─── GET / — รายการใบแจ้งหนี้ทั้งหมด ──────────────────────────────────
  Future<Response> _getInvoicesHandler(Request request) async {
    try {
      if (kDebugMode) {
        debugPrint('📡 ArInvoiceRoutes: GET /');
      }

      final invoices = await (db.select(db.arInvoices)
            ..orderBy([(inv) => OrderingTerm.desc(inv.invoiceDate)]))
          .get();

      final data = invoices.map(_invoiceToMap).toList();
      if (kDebugMode) {
        debugPrint('✅ ArInvoiceRoutes: Found ${invoices.length} invoices');
      }

      return Response.ok(
        jsonEncode({'success': true, 'data': data}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ ArInvoiceRoutes: GET / error: $e');
      }
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': '$e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // ─── GET /:id — รายละเอียดใบแจ้งหนี้พร้อมรายการสินค้า ────────────────
  Future<Response> _getInvoiceHandler(Request request, String id) async {
    try {
      if (kDebugMode) {
        debugPrint('📡 ArInvoiceRoutes: GET /$id');
      }

      final invoice = await (db.select(db.arInvoices)
            ..where((inv) => inv.invoiceId.equals(id)))
          .getSingleOrNull();

      if (invoice == null) {
        return Response.notFound(
          jsonEncode({'success': false, 'message': 'Invoice not found'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final items = await (db.select(db.arInvoiceItems)
            ..where((item) => item.invoiceId.equals(id))
            ..orderBy([(item) => OrderingTerm(expression: item.lineNo)]))
          .get();

      // ดึงประวัติการรับเงินของใบแจ้งหนี้นี้
      final allocations = await (db.select(db.arReceiptAllocations)
            ..where((alloc) => alloc.invoiceId.equals(id)))
          .get();

      final receiptData = <Map<String, dynamic>>[];
      for (final alloc in allocations) {
        final rec = await (db.select(db.arReceipts)
              ..where((r) => r.receiptId.equals(alloc.receiptId)))
            .getSingleOrNull();
        if (rec != null) {
          receiptData.add({
            'receipt_no': rec.receiptNo,
            'receipt_date': rec.receiptDate.toIso8601String(),
            'allocated_amount': alloc.allocatedAmount,
          });
        }
      }

      final data = {
        ..._invoiceToMap(invoice),
        'items': items.map(_itemToMap).toList(),
        'receipts': receiptData,
      };

      return Response.ok(
        jsonEncode({'success': true, 'data': data}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ ArInvoiceRoutes: GET /$id error: $e');
      }
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': '$e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // ─── Helper: อัปเดตยอดค้างชำระในตาราง customers ────────────────────
  Future<void> _updateCustomerBalance(String customerId, double delta) async {
    final customer = await (db.select(db.customers)
          ..where((c) => c.customerId.equals(customerId)))
        .getSingleOrNull();
    if (customer == null) return;
    final newBalance = (customer.currentBalance + delta).clamp(0.0, double.infinity);
    await (db.update(db.customers)
          ..where((c) => c.customerId.equals(customerId)))
        .write(CustomersCompanion(currentBalance: Value(newBalance)));
    if (kDebugMode) {
      debugPrint('💰 Customer $customerId balance: ${customer.currentBalance} → $newBalance (delta: $delta)');
    }
  }

  // ─── POST / — สร้างใบแจ้งหนี้ ─────────────────────────────────────────
  Future<Response> _createInvoiceHandler(Request request) async {
    try {
      if (kDebugMode) {
        debugPrint('📡 ArInvoiceRoutes: POST /');
      }

      final payload = await request.readAsString();
      final data = jsonDecode(payload) as Map<String, dynamic>;

      final invoiceId = 'ARINV${DateTime.now().millisecondsSinceEpoch}';
      final invoiceNo = data['invoice_no'] as String? ??
          'AR${DateTime.now().millisecondsSinceEpoch}';

      // สร้างใบแจ้งหนี้
      await db.into(db.arInvoices).insert(ArInvoicesCompanion(
            invoiceId: Value(invoiceId),
            invoiceNo: Value(invoiceNo),
            invoiceDate:
                Value(DateTime.parse(data['invoice_date'] as String)),
            dueDate: Value(data['due_date'] != null
                ? DateTime.parse(data['due_date'] as String)
                : null),
            customerId: Value(data['customer_id'] as String),
            customerName: Value(data['customer_name'] as String),
            totalAmount: Value((data['total_amount'] as num).toDouble()),
            paidAmount:
                Value((data['paid_amount'] as num?)?.toDouble() ?? 0),
            referenceType: Value(data['reference_type'] as String?),
            referenceId: Value(data['reference_id'] as String?),
            status: Value(data['status'] as String? ?? 'UNPAID'),
            remark: Value(data['remark'] as String?),
          ));

      // สร้างรายการสินค้า
      if (data['items'] != null) {
        final items = data['items'] as List;
        for (var i = 0; i < items.length; i++) {
          final item = items[i] as Map<String, dynamic>;
          final itemId =
              'ARINVITEM${DateTime.now().millisecondsSinceEpoch}$i';

          await db.into(db.arInvoiceItems).insert(ArInvoiceItemsCompanion(
                itemId: Value(itemId),
                invoiceId: Value(invoiceId),
                lineNo: Value(item['line_no'] as int? ?? i + 1),
                productId: Value(item['product_id'] as String),
                productCode: Value(item['product_code'] as String),
                productName: Value(item['product_name'] as String),
                unit: Value(item['unit'] as String),
                quantity: Value((item['quantity'] as num).toDouble()),
                unitPrice: Value((item['unit_price'] as num).toDouble()),
                discountAmount: Value(
                    (item['discount_amount'] as num?)?.toDouble() ?? 0),
                amount: Value((item['amount'] as num).toDouble()),
                remark: Value(item['remark'] as String?),
              ));
        }
      }

      // ── เพิ่มยอดค้างชำระในตาราง customers ──────────────────────
      final customerId = data['customer_id'] as String;
      final totalAmount = (data['total_amount'] as num).toDouble();
      await _updateCustomerBalance(customerId, totalAmount);

      if (kDebugMode) {
        debugPrint('✅ ArInvoiceRoutes: Created invoice: $invoiceId');
      }

      return Response.ok(
        jsonEncode({
          'success': true,
          'message': 'Invoice created',
          'data': {'invoice_id': invoiceId}
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ ArInvoiceRoutes: POST / error: $e');
      }
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': '$e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // ─── PUT /:id — แก้ไขใบแจ้งหนี้ + items ────────────────────────────
  Future<Response> _updateInvoiceHandler(Request request, String id) async {
    try {
      if (kDebugMode) {
        debugPrint('📡 ArInvoiceRoutes: PUT /$id');
      }

      final payload = await request.readAsString();
      final data = jsonDecode(payload) as Map<String, dynamic>;

      // อัพเดท header
      await (db.update(db.arInvoices)
            ..where((inv) => inv.invoiceId.equals(id)))
          .write(ArInvoicesCompanion(
        invoiceNo: Value(data['invoice_no'] as String),
        invoiceDate: Value(DateTime.parse(data['invoice_date'] as String)),
        dueDate: Value(data['due_date'] != null
            ? DateTime.parse(data['due_date'] as String)
            : null),
        customerId: Value(data['customer_id'] as String),
        customerName: Value(data['customer_name'] as String),
        totalAmount: Value((data['total_amount'] as num).toDouble()),
        referenceType: Value(data['reference_type'] as String?),
        referenceId: Value(data['reference_id'] as String?),
        status: Value(data['status'] as String? ?? 'UNPAID'),
        remark: Value(data['remark'] as String?),
        updatedAt: Value(DateTime.now()),
      ));

      // อัพเดท items: ลบของเก่า แล้ว insert ใหม่ทั้งหมด
      if (data['items'] != null) {
        await (db.delete(db.arInvoiceItems)
              ..where((item) => item.invoiceId.equals(id)))
            .go();

        final items = data['items'] as List;
        for (var i = 0; i < items.length; i++) {
          final item = items[i] as Map<String, dynamic>;
          final itemId = 'ARINVITEM${DateTime.now().millisecondsSinceEpoch}$i';

          await db.into(db.arInvoiceItems).insert(ArInvoiceItemsCompanion(
                itemId: Value(itemId),
                invoiceId: Value(id),
                lineNo: Value(item['line_no'] as int? ?? i + 1),
                productId: Value(item['product_id'] as String),
                productCode: Value(item['product_code'] as String),
                productName: Value(item['product_name'] as String),
                unit: Value(item['unit'] as String? ?? ''),
                quantity: Value((item['quantity'] as num).toDouble()),
                unitPrice: Value((item['unit_price'] as num).toDouble()),
                discountAmount: Value(
                    (item['discount_amount'] as num?)?.toDouble() ?? 0),
                amount: Value((item['amount'] as num).toDouble()),
                remark: Value(item['remark'] as String?),
              ));
        }
        if (kDebugMode) {
          debugPrint('✅ ArInvoiceRoutes: Updated ${items.length} items for $id');
        }
      }

      if (kDebugMode) {
        debugPrint('✅ ArInvoiceRoutes: Updated invoice: $id');
      }

      return Response.ok(
        jsonEncode({'success': true, 'message': 'Invoice updated'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ ArInvoiceRoutes: PUT /$id error: $e');
      }
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': '$e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // ─── DELETE /:id — ลบใบแจ้งหนี้ (UNPAID เท่านั้น) ───────────────────
  Future<Response> _deleteInvoiceHandler(Request request, String id) async {
    try {
      if (kDebugMode) {
        debugPrint('📡 ArInvoiceRoutes: DELETE /$id');
      }

      final invoice = await (db.select(db.arInvoices)
            ..where((inv) => inv.invoiceId.equals(id)))
          .getSingleOrNull();

      if (invoice == null) {
        return Response.notFound(
          jsonEncode({'success': false, 'message': 'Invoice not found'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      if (invoice.status != 'UNPAID') {
        return Response.ok(
          jsonEncode({
            'success': false,
            'message': 'Cannot delete invoice with status: ${invoice.status}'
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // ── ลดยอดค้างชำระ (เฉพาะส่วนที่ยังค้างอยู่) ─────────────────
      final remaining = invoice.totalAmount - invoice.paidAmount;
      await _updateCustomerBalance(invoice.customerId, -remaining);

      // ลบรายการสินค้าก่อน
      await (db.delete(db.arInvoiceItems)
            ..where((item) => item.invoiceId.equals(id)))
          .go();

      // ลบใบแจ้งหนี้
      await (db.delete(db.arInvoices)
            ..where((inv) => inv.invoiceId.equals(id)))
          .go();

      if (kDebugMode) {
        debugPrint('✅ ArInvoiceRoutes: Deleted invoice: $id');
      }

      return Response.ok(
        jsonEncode({'success': true, 'message': 'Invoice deleted'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ ArInvoiceRoutes: DELETE /$id error: $e');
      }
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': '$e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // ─── GET /customer/:customerId — รายการใบแจ้งหนี้ของลูกค้า ──────────
  Future<Response> _getInvoicesByCustomerHandler(
      Request request, String customerId) async {
    try {
      if (kDebugMode) {
        debugPrint('📡 ArInvoiceRoutes: GET /customer/$customerId');
      }

      final invoices = await (db.select(db.arInvoices)
            ..where((inv) => inv.customerId.equals(customerId))
            ..orderBy([(inv) => OrderingTerm.desc(inv.invoiceDate)]))
          .get();

      final data = invoices.map(_invoiceToMap).toList();
      if (kDebugMode) {
        debugPrint('✅ ArInvoiceRoutes: Found ${invoices.length} invoices');
      }

      return Response.ok(
        jsonEncode({'success': true, 'data': data}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ ArInvoiceRoutes: GET /customer/$customerId error: $e');
      }
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': '$e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }
}