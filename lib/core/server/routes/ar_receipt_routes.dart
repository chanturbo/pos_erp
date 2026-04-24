// ar_receipt_routes.dart
// Day 39-40: AR Receipt Routes — รับเงินจากลูกค้า

import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:drift/drift.dart' hide JsonKey;
import '../../database/app_database.dart';
import 'package:flutter/foundation.dart';

class ArReceiptRoutes {
  final AppDatabase db;

  ArReceiptRoutes(this.db);

  Router get router {
    final router = Router();

    router.get('/', _getReceiptsHandler);
    router.get('/<id>', _getReceiptHandler);
    router.post('/', _createReceiptHandler);
    router.delete('/<id>', _deleteReceiptHandler);
    router.get('/customer/<customerId>', _getReceiptsByCustomerHandler);

    return router;
  }

  // ─── Helper: แปลง ArReceipt → Map ────────────────────────────────────
  Map<String, dynamic> _receiptToMap(ArReceipt rec) => {
        'receipt_id': rec.receiptId,
        'receipt_no': rec.receiptNo,
        'receipt_date': rec.receiptDate.toIso8601String(),
        'customer_id': rec.customerId,
        'customer_name': rec.customerName,
        'total_amount': rec.totalAmount,
        'payment_method': rec.paymentMethod,
        'bank_name': rec.bankName,
        'cheque_no': rec.chequeNo,
        'cheque_date': rec.chequeDate?.toIso8601String(),
        'transfer_ref': rec.transferRef,
        'user_id': rec.userId,
        'remark': rec.remark,
        'created_at': rec.createdAt.toIso8601String(),
      };

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

  // ─── GET / — รายการใบเสร็จรับเงินทั้งหมด ─────────────────────────────
  Future<Response> _getReceiptsHandler(Request request) async {
    try {
      if (kDebugMode) {
        debugPrint('📡 ArReceiptRoutes: GET /');
      }

      final receipts = await (db.select(db.arReceipts)
            ..orderBy([(rec) => OrderingTerm.desc(rec.receiptDate)]))
          .get();

      final data = receipts.map(_receiptToMap).toList();
      if (kDebugMode) {
        debugPrint('✅ ArReceiptRoutes: Found ${receipts.length} receipts');
      }

      return Response.ok(
        jsonEncode({'success': true, 'data': data}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ ArReceiptRoutes: GET / error: $e');
      }
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': '$e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // ─── GET /:id — รายละเอียดใบเสร็จพร้อม Allocations ──────────────────
  Future<Response> _getReceiptHandler(Request request, String id) async {
    try {
      if (kDebugMode) {
        debugPrint('📡 ArReceiptRoutes: GET /$id');
      }

      final receipt = await (db.select(db.arReceipts)
            ..where((rec) => rec.receiptId.equals(id)))
          .getSingleOrNull();

      if (receipt == null) {
        return Response.notFound(
          jsonEncode({'success': false, 'message': 'Receipt not found'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // ดึง Allocations พร้อมข้อมูลใบแจ้งหนี้
      final allocations = await (db.select(db.arReceiptAllocations)
            ..where((alloc) => alloc.receiptId.equals(id)))
          .get();

      // ดึง invoiceNo สำหรับแต่ละ allocation
      final allocData = <Map<String, dynamic>>[];
      for (final alloc in allocations) {
        final inv = await (db.select(db.arInvoices)
              ..where((i) => i.invoiceId.equals(alloc.invoiceId)))
            .getSingleOrNull();

        allocData.add({
          'allocation_id': alloc.allocationId,
          'receipt_id': alloc.receiptId,
          'invoice_id': alloc.invoiceId,
          'invoice_no': inv?.invoiceNo,
          'customer_name': inv?.customerName,
          'allocated_amount': alloc.allocatedAmount,
          'created_at': alloc.createdAt.toIso8601String(),
        });
      }

      final data = {
        ..._receiptToMap(receipt),
        'allocations': allocData,
      };

      return Response.ok(
        jsonEncode({'success': true, 'data': data}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ ArReceiptRoutes: GET /$id error: $e');
      }
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': '$e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // ─── POST / — สร้างใบเสร็จรับเงิน + จัดสรรกับใบแจ้งหนี้ ─────────────
  Future<Response> _createReceiptHandler(Request request) async {
    try {
      if (kDebugMode) {
        debugPrint('📡 ArReceiptRoutes: POST /');
      }

      final payload = await request.readAsString();
      final data = jsonDecode(payload) as Map<String, dynamic>;

      final receiptId = 'ARREC${DateTime.now().millisecondsSinceEpoch}';

      // สร้างใบเสร็จรับเงิน
      await db.into(db.arReceipts).insert(ArReceiptsCompanion(
            receiptId: Value(receiptId),
            receiptNo: Value(data['receipt_no'] as String),
            receiptDate:
                Value(DateTime.parse(data['receipt_date'] as String)),
            customerId: Value(data['customer_id'] as String),
            customerName: Value(data['customer_name'] as String),
            totalAmount: Value((data['total_amount'] as num).toDouble()),
            paymentMethod:
                Value(data['payment_method'] as String? ?? 'CASH'),
            bankName: Value(data['bank_name'] as String?),
            chequeNo: Value(data['cheque_no'] as String?),
            chequeDate: Value(data['cheque_date'] != null
                ? DateTime.parse(data['cheque_date'] as String)
                : null),
            transferRef: Value(data['transfer_ref'] as String?),
            userId: Value(data['user_id'] as String),
            remark: Value(data['remark'] as String?),
          ));

      // สร้าง Allocations และอัพเดทใบแจ้งหนี้
      if (data['allocations'] != null) {
        final allocations = data['allocations'] as List;
        for (var i = 0; i < allocations.length; i++) {
          final alloc = allocations[i] as Map<String, dynamic>;
          final allocationId =
              'ARALLOC${DateTime.now().millisecondsSinceEpoch}$i';
          final allocAmount = (alloc['allocated_amount'] as num).toDouble();

          // สร้าง Allocation record
          await db
              .into(db.arReceiptAllocations)
              .insert(ArReceiptAllocationsCompanion(
                allocationId: Value(allocationId),
                receiptId: Value(receiptId),
                invoiceId: Value(alloc['invoice_id'] as String),
                allocatedAmount: Value(allocAmount),
              ));

          // อัพเดทยอดรับในใบแจ้งหนี้ + สถานะ
          final invoice = await (db.select(db.arInvoices)
                ..where(
                    (inv) => inv.invoiceId.equals(alloc['invoice_id'] as String)))
              .getSingleOrNull();

          if (invoice != null) {
            final newPaidAmount = invoice.paidAmount + allocAmount;
            String newStatus = 'UNPAID';
            if (newPaidAmount >= invoice.totalAmount - 0.01) {
              newStatus = 'PAID';
            } else if (newPaidAmount > 0.01) {
              newStatus = 'PARTIAL';
            }

            await (db.update(db.arInvoices)
                  ..where((inv) => inv.invoiceId.equals(invoice.invoiceId)))
                .write(ArInvoicesCompanion(
              paidAmount: Value(newPaidAmount),
              status: Value(newStatus),
              updatedAt: Value(DateTime.now()),
            ));

            // ── สะสมแต้มเมื่อชำระหนี้ครบถ้วน (PAID) ──────────────────────────
            if (newStatus == 'PAID') {
              final customer = await (db.select(db.customers)
                    ..where((c) => c.customerId.equals(invoice.customerId)))
                  .getSingleOrNull();
              if (customer != null && customer.memberNo != null) {
                const double pointsPerBaht = 100.0;
                final earnedPts = (invoice.totalAmount / pointsPerBaht).floor();
                if (earnedPts > 0) {
                  await (db.update(db.customers)
                        ..where((c) => c.customerId.equals(invoice.customerId)))
                      .write(CustomersCompanion(
                    points: Value(customer.points + earnedPts),
                    updatedAt: Value(DateTime.now()),
                  ));
                  final ptxId =
                      'PTX-ARN-${DateTime.now().millisecondsSinceEpoch}-$i';
                  try {
                    await db.into(db.pointsTransactions).insert(
                          PointsTransactionsCompanion(
                            transactionId: Value(ptxId),
                            customerId: Value(invoice.customerId),
                            type: const Value('EARN'),
                            points: Value(earnedPts),
                            referenceNo: Value(invoice.invoiceNo),
                            remark: Value(
                              'สะสมแต้มจากการรับชำระหนี้ ${invoice.invoiceNo}',
                            ),
                          ),
                        );
                  } catch (e) {
                    if (kDebugMode) {
                      debugPrint('⚠️ Points transaction log failed (AR EARN): $e');
                    }
                  }
                  if (kDebugMode) {
                    debugPrint( '⭐ Points earned (AR paid): ${invoice.customerId} +$earnedPts', );
                  }
                }
              }
            }
          }
        }
      }

      // ── ลดยอดค้างชำระในตาราง customers ──────────────────────────
      final customerId = data['customer_id'] as String;
      final totalAmount = (data['total_amount'] as num).toDouble();
      await _updateCustomerBalance(customerId, -totalAmount);

      if (kDebugMode) {
        debugPrint('✅ ArReceiptRoutes: Created receipt: $receiptId');
      }

      return Response.ok(
        jsonEncode({
          'success': true,
          'message': 'Receipt created',
          'data': {'receipt_id': receiptId}
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ ArReceiptRoutes: POST / error: $e');
      }
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': '$e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // ─── DELETE /:id — ลบใบเสร็จ + คืนยอดใบแจ้งหนี้ ─────────────────────
  Future<Response> _deleteReceiptHandler(Request request, String id) async {
    try {
      if (kDebugMode) {
        debugPrint('📡 ArReceiptRoutes: DELETE /$id');
      }

      final receipt = await (db.select(db.arReceipts)
            ..where((rec) => rec.receiptId.equals(id)))
          .getSingleOrNull();

      if (receipt == null) {
        return Response.notFound(
          jsonEncode({'success': false, 'message': 'Receipt not found'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // ดึง Allocations เพื่อคืนยอด
      final allocations = await (db.select(db.arReceiptAllocations)
            ..where((alloc) => alloc.receiptId.equals(id)))
          .get();

      // คืนยอดในใบแจ้งหนี้
      for (final alloc in allocations) {
        final invoice = await (db.select(db.arInvoices)
              ..where((inv) => inv.invoiceId.equals(alloc.invoiceId)))
            .getSingleOrNull();

        if (invoice != null) {
          final newPaidAmount = invoice.paidAmount - alloc.allocatedAmount;
          String newStatus = 'UNPAID';
          if (newPaidAmount >= invoice.totalAmount - 0.01) {
            newStatus = 'PAID';
          } else if (newPaidAmount > 0.01) {
            newStatus = 'PARTIAL';
          }

          await (db.update(db.arInvoices)
                ..where((inv) => inv.invoiceId.equals(invoice.invoiceId)))
              .write(ArInvoicesCompanion(
            paidAmount: Value(newPaidAmount.clamp(0, double.infinity)),
            status: Value(newStatus),
            updatedAt: Value(DateTime.now()),
          ));
        }
      }

      // ── คืนยอดค้างชำระในตาราง customers ─────────────────────────
      await _updateCustomerBalance(receipt.customerId, receipt.totalAmount);

      // ลบ Allocations
      await (db.delete(db.arReceiptAllocations)
            ..where((alloc) => alloc.receiptId.equals(id)))
          .go();

      // ลบใบเสร็จ
      await (db.delete(db.arReceipts)
            ..where((rec) => rec.receiptId.equals(id)))
          .go();

      if (kDebugMode) {
        debugPrint('✅ ArReceiptRoutes: Deleted receipt: $id');
      }

      return Response.ok(
        jsonEncode({'success': true, 'message': 'Receipt deleted'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ ArReceiptRoutes: DELETE /$id error: $e');
      }
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': '$e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // ─── GET /customer/:customerId — ใบเสร็จของลูกค้า ───────────────────
  Future<Response> _getReceiptsByCustomerHandler(
      Request request, String customerId) async {
    try {
      if (kDebugMode) {
        debugPrint('📡 ArReceiptRoutes: GET /customer/$customerId');
      }

      final receipts = await (db.select(db.arReceipts)
            ..where((rec) => rec.customerId.equals(customerId))
            ..orderBy([(rec) => OrderingTerm.desc(rec.receiptDate)]))
          .get();

      final data = receipts.map(_receiptToMap).toList();
      if (kDebugMode) {
        debugPrint('✅ ArReceiptRoutes: Found ${receipts.length} receipts');
      }

      return Response.ok(
        jsonEncode({'success': true, 'data': data}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ ArReceiptRoutes: GET /customer/$customerId error: $e');
      }
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': '$e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }
}