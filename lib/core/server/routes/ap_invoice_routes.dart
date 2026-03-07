// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:drift/drift.dart' hide JsonKey;
import '../../database/app_database.dart';

class ApInvoiceRoutes {
  final AppDatabase db;

  ApInvoiceRoutes(this.db);

  Router get router {
    final router = Router();

    router.get('/', _getInvoicesHandler);
    router.get('/<id>', _getInvoiceHandler);
    router.post('/', _createInvoiceHandler);
    router.put('/<id>', _updateInvoiceHandler);
    router.delete('/<id>', _deleteInvoiceHandler);
    router.get('/supplier/<supplierId>', _getInvoicesBySupplierHandler);

    return router;
  }

  /// GET / - รายการใบแจ้งหนี้ทั้งหมด
  Future<Response> _getInvoicesHandler(Request request) async {
    try {
      print('📡 ApInvoiceRoutes: GET /');

      final invoices = await db.select(db.apInvoices).get();

      final data = invoices.map((inv) => {
            'invoice_id': inv.invoiceId,
            'invoice_no': inv.invoiceNo,
            'invoice_date': inv.invoiceDate.toIso8601String(),
            'due_date': inv.dueDate?.toIso8601String(),
            'supplier_id': inv.supplierId,
            'supplier_name': inv.supplierName,
            'total_amount': inv.totalAmount,
            'paid_amount': inv.paidAmount,
            'reference_type': inv.referenceType,
            'reference_id': inv.referenceId,
            'status': inv.status,
            'remark': inv.remark,
            'created_at': inv.createdAt.toIso8601String(),
            'updated_at': inv.updatedAt.toIso8601String(),
          }).toList();

      print('✅ ApInvoiceRoutes: Found ${invoices.length} invoices');

      return Response.ok(
        jsonEncode({'success': true, 'data': data}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('❌ ApInvoiceRoutes: GET / error: $e');
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': '$e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// GET /:id - รายละเอียดใบแจ้งหนี้พร้อมรายการสินค้า
  Future<Response> _getInvoiceHandler(Request request, String id) async {
    try {
      print('📡 ApInvoiceRoutes: GET /$id');

      final invoice = await (db.select(db.apInvoices)
            ..where((inv) => inv.invoiceId.equals(id)))
          .getSingleOrNull();

      if (invoice == null) {
        return Response.notFound(
          jsonEncode({'success': false, 'message': 'Invoice not found'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // ดึงรายการสินค้า
      final items = await (db.select(db.apInvoiceItems)
            ..where((item) => item.invoiceId.equals(id))
            ..orderBy([(item) => OrderingTerm(expression: item.lineNo)]))
          .get();

      final data = {
        'invoice_id': invoice.invoiceId,
        'invoice_no': invoice.invoiceNo,
        'invoice_date': invoice.invoiceDate.toIso8601String(),
        'due_date': invoice.dueDate?.toIso8601String(),
        'supplier_id': invoice.supplierId,
        'supplier_name': invoice.supplierName,
        'total_amount': invoice.totalAmount,
        'paid_amount': invoice.paidAmount,
        'reference_type': invoice.referenceType,
        'reference_id': invoice.referenceId,
        'status': invoice.status,
        'remark': invoice.remark,
        'created_at': invoice.createdAt.toIso8601String(),
        'updated_at': invoice.updatedAt.toIso8601String(),
        'items': items.map((item) => {
              'item_id': item.itemId,
              'invoice_id': item.invoiceId,
              'line_no': item.lineNo,
              'product_id': item.productId,
              'product_code': item.productCode,
              'product_name': item.productName,
              'unit': item.unit,
              'quantity': item.quantity,
              'unit_price': item.unitPrice,
              'amount': item.amount,
              'remark': item.remark,
            }).toList(),
      };

      return Response.ok(
        jsonEncode({'success': true, 'data': data}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('❌ ApInvoiceRoutes: GET /$id error: $e');
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': '$e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// POST / - สร้างใบแจ้งหนี้
  Future<Response> _createInvoiceHandler(Request request) async {
    try {
      print('📡 ApInvoiceRoutes: POST /');

      final payload = await request.readAsString();
      final data = jsonDecode(payload) as Map<String, dynamic>;

      final invoiceId = 'APINV${DateTime.now().millisecondsSinceEpoch}';

      // สร้างใบแจ้งหนี้
      final invoiceCompanion = ApInvoicesCompanion(
        invoiceId: Value(invoiceId),
        invoiceNo: Value(data['invoice_no'] as String),
        invoiceDate: Value(DateTime.parse(data['invoice_date'] as String)),
        dueDate: Value(data['due_date'] != null ? DateTime.parse(data['due_date'] as String) : null),
        supplierId: Value(data['supplier_id'] as String),
        supplierName: Value(data['supplier_name'] as String),
        totalAmount: Value((data['total_amount'] as num).toDouble()),
        paidAmount: Value((data['paid_amount'] as num?)?.toDouble() ?? 0),
        referenceType: Value(data['reference_type'] as String?),
        referenceId: Value(data['reference_id'] as String?),
        status: Value(data['status'] as String? ?? 'UNPAID'),
        remark: Value(data['remark'] as String?),
      );

      await db.into(db.apInvoices).insert(invoiceCompanion);

      // สร้างรายการสินค้า
      if (data['items'] != null) {
        final items = data['items'] as List;
        for (var i = 0; i < items.length; i++) {
          final item = items[i] as Map<String, dynamic>;
          final itemId = 'APINVITEM${DateTime.now().millisecondsSinceEpoch}$i';

          final itemCompanion = ApInvoiceItemsCompanion(
            itemId: Value(itemId),
            invoiceId: Value(invoiceId),
            lineNo: Value(item['line_no'] as int? ?? i + 1),
            productId: Value(item['product_id'] as String),
            productCode: Value(item['product_code'] as String),
            productName: Value(item['product_name'] as String),
            unit: Value(item['unit'] as String),
            quantity: Value((item['quantity'] as num).toDouble()),
            unitPrice: Value((item['unit_price'] as num).toDouble()),
            amount: Value((item['amount'] as num).toDouble()),
            remark: Value(item['remark'] as String?),
          );

          await db.into(db.apInvoiceItems).insert(itemCompanion);
        }
      }

      // อัพเดท Supplier Current Balance
      final supplier = await (db.select(db.suppliers)
            ..where((s) => s.supplierId.equals(data['supplier_id'] as String)))
          .getSingleOrNull();

      if (supplier != null) {
        final newBalance = supplier.currentBalance + (data['total_amount'] as num).toDouble();
        await (db.update(db.suppliers)..where((s) => s.supplierId.equals(supplier.supplierId)))
            .write(SuppliersCompanion(
          currentBalance: Value(newBalance),
          updatedAt: Value(DateTime.now()),
        ));
      }

      print('✅ ApInvoiceRoutes: Created invoice: $invoiceId');

      return Response.ok(
        jsonEncode({
          'success': true,
          'message': 'Invoice created',
          'data': {'invoice_id': invoiceId}
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('❌ ApInvoiceRoutes: POST / error: $e');
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': '$e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// PUT /:id - แก้ไขใบแจ้งหนี้
  Future<Response> _updateInvoiceHandler(Request request, String id) async {
    try {
      print('📡 ApInvoiceRoutes: PUT /$id');

      final payload = await request.readAsString();
      final data = jsonDecode(payload) as Map<String, dynamic>;

      final companion = ApInvoicesCompanion(
        invoiceNo: Value(data['invoice_no'] as String),
        invoiceDate: Value(DateTime.parse(data['invoice_date'] as String)),
        dueDate: Value(data['due_date'] != null ? DateTime.parse(data['due_date'] as String) : null),
        supplierId: Value(data['supplier_id'] as String),
        supplierName: Value(data['supplier_name'] as String),
        totalAmount: Value((data['total_amount'] as num).toDouble()),
        referenceType: Value(data['reference_type'] as String?),
        referenceId: Value(data['reference_id'] as String?),
        status: Value(data['status'] as String? ?? 'UNPAID'),
        remark: Value(data['remark'] as String?),
        updatedAt: Value(DateTime.now()),
      );

      await (db.update(db.apInvoices)..where((inv) => inv.invoiceId.equals(id)))
          .write(companion);

      print('✅ ApInvoiceRoutes: Updated invoice: $id');

      return Response.ok(
        jsonEncode({'success': true, 'message': 'Invoice updated'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('❌ ApInvoiceRoutes: PUT /$id error: $e');
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': '$e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// DELETE /:id - ลบใบแจ้งหนี้
  Future<Response> _deleteInvoiceHandler(Request request, String id) async {
    try {
      print('📡 ApInvoiceRoutes: DELETE /$id');

      // ลบรายการสินค้าก่อน
      await (db.delete(db.apInvoiceItems)
            ..where((item) => item.invoiceId.equals(id)))
          .go();

      // ลบใบแจ้งหนี้
      await (db.delete(db.apInvoices)..where((inv) => inv.invoiceId.equals(id)))
          .go();

      print('✅ ApInvoiceRoutes: Deleted invoice: $id');

      return Response.ok(
        jsonEncode({'success': true, 'message': 'Invoice deleted'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('❌ ApInvoiceRoutes: DELETE /$id error: $e');
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': '$e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// GET /supplier/:supplierId - รายการใบแจ้งหนี้ของซัพพลายเออร์
  Future<Response> _getInvoicesBySupplierHandler(
      Request request, String supplierId) async {
    try {
      print('📡 ApInvoiceRoutes: GET /supplier/$supplierId');

      final invoices = await (db.select(db.apInvoices)
            ..where((inv) => inv.supplierId.equals(supplierId))
            ..orderBy([(inv) => OrderingTerm.desc(inv.invoiceDate)]))
          .get();

      final data = invoices.map((inv) => {
            'invoice_id': inv.invoiceId,
            'invoice_no': inv.invoiceNo,
            'invoice_date': inv.invoiceDate.toIso8601String(),
            'due_date': inv.dueDate?.toIso8601String(),
            'supplier_id': inv.supplierId,
            'supplier_name': inv.supplierName,
            'total_amount': inv.totalAmount,
            'paid_amount': inv.paidAmount,
            'status': inv.status,
            'created_at': inv.createdAt.toIso8601String(),
          }).toList();

      print('✅ ApInvoiceRoutes: Found ${invoices.length} invoices');

      return Response.ok(
        jsonEncode({'success': true, 'data': data}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('❌ ApInvoiceRoutes: GET /supplier/$supplierId error: $e');
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': '$e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }
}