// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:drift/drift.dart' hide JsonKey;
import '../../database/app_database.dart';

class ApPaymentRoutes {
  final AppDatabase db;

  ApPaymentRoutes(this.db);

  Router get router {
    final router = Router();

    router.get('/', _getPaymentsHandler);
    router.get('/<id>', _getPaymentHandler);
    router.post('/', _createPaymentHandler);
    router.delete('/<id>', _deletePaymentHandler);

    return router;
  }

  /// GET / - รายการจ่ายเงินทั้งหมด
  Future<Response> _getPaymentsHandler(Request request) async {
    try {
      print('📡 ApPaymentRoutes: GET /');

      final payments = await db.select(db.apPayments).get();

      final data = payments.map((pay) => {
            'payment_id': pay.paymentId,
            'payment_no': pay.paymentNo,
            'payment_date': pay.paymentDate.toIso8601String(),
            'supplier_id': pay.supplierId,
            'supplier_name': pay.supplierName,
            'total_amount': pay.totalAmount,
            'payment_method': pay.paymentMethod,
            'bank_name': pay.bankName,
            'cheque_no': pay.chequeNo,
            'cheque_date': pay.chequeDate?.toIso8601String(),
            'transfer_ref': pay.transferRef,
            'user_id': pay.userId,
            'remark': pay.remark,
            'created_at': pay.createdAt.toIso8601String(),
          }).toList();

      print('✅ ApPaymentRoutes: Found ${payments.length} payments');

      return Response.ok(
        jsonEncode({'success': true, 'data': data}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('❌ ApPaymentRoutes: GET / error: $e');
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': '$e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// GET /:id - รายละเอียดการจ่ายเงินพร้อม Allocations
  Future<Response> _getPaymentHandler(Request request, String id) async {
    try {
      print('📡 ApPaymentRoutes: GET /$id');

      final payment = await (db.select(db.apPayments)
            ..where((pay) => pay.paymentId.equals(id)))
          .getSingleOrNull();

      if (payment == null) {
        return Response.notFound(
          jsonEncode({'success': false, 'message': 'Payment not found'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // ดึง Allocations
      final allocations = await (db.select(db.apPaymentAllocations)
            ..where((alloc) => alloc.paymentId.equals(id)))
          .get();

      final data = {
        'payment_id': payment.paymentId,
        'payment_no': payment.paymentNo,
        'payment_date': payment.paymentDate.toIso8601String(),
        'supplier_id': payment.supplierId,
        'supplier_name': payment.supplierName,
        'total_amount': payment.totalAmount,
        'payment_method': payment.paymentMethod,
        'bank_name': payment.bankName,
        'cheque_no': payment.chequeNo,
        'cheque_date': payment.chequeDate?.toIso8601String(),
        'transfer_ref': payment.transferRef,
        'user_id': payment.userId,
        'remark': payment.remark,
        'created_at': payment.createdAt.toIso8601String(),
        'allocations': allocations.map((alloc) => {
              'allocation_id': alloc.allocationId,
              'payment_id': alloc.paymentId,
              'invoice_id': alloc.invoiceId,
              'allocated_amount': alloc.allocatedAmount,
              'created_at': alloc.createdAt.toIso8601String(),
            }).toList(),
      };

      return Response.ok(
        jsonEncode({'success': true, 'data': data}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('❌ ApPaymentRoutes: GET /$id error: $e');
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': '$e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// POST / - สร้างการจ่ายเงิน
  Future<Response> _createPaymentHandler(Request request) async {
    try {
      print('📡 ApPaymentRoutes: POST /');

      final payload = await request.readAsString();
      final data = jsonDecode(payload) as Map<String, dynamic>;

      final paymentId = 'APPAY${DateTime.now().millisecondsSinceEpoch}';

      // สร้างการจ่ายเงิน
      final paymentCompanion = ApPaymentsCompanion(
        paymentId: Value(paymentId),
        paymentNo: Value(data['payment_no'] as String),
        paymentDate: Value(DateTime.parse(data['payment_date'] as String)),
        supplierId: Value(data['supplier_id'] as String),
        supplierName: Value(data['supplier_name'] as String),
        totalAmount: Value((data['total_amount'] as num).toDouble()),
        paymentMethod: Value(data['payment_method'] as String? ?? 'CASH'),
        bankName: Value(data['bank_name'] as String?),
        chequeNo: Value(data['cheque_no'] as String?),
        chequeDate: Value(data['cheque_date'] != null ? DateTime.parse(data['cheque_date'] as String) : null),
        transferRef: Value(data['transfer_ref'] as String?),
        userId: Value(data['user_id'] as String),
        remark: Value(data['remark'] as String?),
      );

      await db.into(db.apPayments).insert(paymentCompanion);

      // สร้าง Allocations และอัพเดทใบแจ้งหนี้
      if (data['allocations'] != null) {
        final allocations = data['allocations'] as List;
        for (var i = 0; i < allocations.length; i++) {
          final alloc = allocations[i] as Map<String, dynamic>;
          final allocationId = 'APALLOC${DateTime.now().millisecondsSinceEpoch}$i';

          // สร้าง Allocation
          final allocCompanion = ApPaymentAllocationsCompanion(
            allocationId: Value(allocationId),
            paymentId: Value(paymentId),
            invoiceId: Value(alloc['invoice_id'] as String),
            allocatedAmount: Value((alloc['allocated_amount'] as num).toDouble()),
          );

          await db.into(db.apPaymentAllocations).insert(allocCompanion);

          // อัพเดทยอดจ่ายในใบแจ้งหนี้
          final invoice = await (db.select(db.apInvoices)
                ..where((inv) => inv.invoiceId.equals(alloc['invoice_id'] as String)))
              .getSingleOrNull();

          if (invoice != null) {
            final newPaidAmount = invoice.paidAmount + (alloc['allocated_amount'] as num).toDouble();
            String newStatus = 'UNPAID';
            if (newPaidAmount >= invoice.totalAmount) {
              newStatus = 'PAID';
            } else if (newPaidAmount > 0) {
              newStatus = 'PARTIAL';
            }

            await (db.update(db.apInvoices)
                  ..where((inv) => inv.invoiceId.equals(invoice.invoiceId)))
                .write(ApInvoicesCompanion(
              paidAmount: Value(newPaidAmount),
              status: Value(newStatus),
              updatedAt: Value(DateTime.now()),
            ));
          }
        }
      }

      // อัพเดท Supplier Current Balance
      final supplier = await (db.select(db.suppliers)
            ..where((s) => s.supplierId.equals(data['supplier_id'] as String)))
          .getSingleOrNull();

      if (supplier != null) {
        final newBalance = supplier.currentBalance - (data['total_amount'] as num).toDouble();
        await (db.update(db.suppliers)..where((s) => s.supplierId.equals(supplier.supplierId)))
            .write(SuppliersCompanion(
          currentBalance: Value(newBalance),
          updatedAt: Value(DateTime.now()),
        ));
      }

      print('✅ ApPaymentRoutes: Created payment: $paymentId');

      return Response.ok(
        jsonEncode({
          'success': true,
          'message': 'Payment created',
          'data': {'payment_id': paymentId}
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('❌ ApPaymentRoutes: POST / error: $e');
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': '$e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// DELETE /:id - ลบการจ่ายเงิน
  Future<Response> _deletePaymentHandler(Request request, String id) async {
    try {
      print('📡 ApPaymentRoutes: DELETE /$id');

      // ลบ Allocations ก่อน
      await (db.delete(db.apPaymentAllocations)
            ..where((alloc) => alloc.paymentId.equals(id)))
          .go();

      // ลบการจ่ายเงิน
      await (db.delete(db.apPayments)..where((pay) => pay.paymentId.equals(id)))
          .go();

      print('✅ ApPaymentRoutes: Deleted payment: $id');

      return Response.ok(
        jsonEncode({'success': true, 'message': 'Payment deleted'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('❌ ApPaymentRoutes: DELETE /$id error: $e');
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': '$e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }
}