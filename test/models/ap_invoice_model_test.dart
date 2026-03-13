import 'package:flutter_test/flutter_test.dart';
import 'package:pos_erp/features/ap/data/models/ap_invoice_model.dart';

void main() {
  // ─── Fixture helper ───────────────────
  ApInvoiceModel makeInvoice({
    double totalAmount = 1000.0,
    double paidAmount = 0.0,
    DateTime? dueDate,
    String status = 'UNPAID',
  }) {
    final now = DateTime.now();
    return ApInvoiceModel(
      invoiceId:    'INV001',
      invoiceNo:    'AP2024001',
      invoiceDate:  now,
      dueDate:      dueDate,
      supplierId:   'SUP001',
      supplierName: 'บริษัท ซัพพลายเออร์ จำกัด',
      totalAmount:  totalAmount,
      paidAmount:   paidAmount,
      status:       status,
      createdAt:    now,
      updatedAt:    now,
    );
  }

  // ─── Computed properties ──────────────
  group('ApInvoiceModel computed properties', () {
    test('remainingAmount = totalAmount - paidAmount', () {
      final invoice = makeInvoice(totalAmount: 1000, paidAmount: 400);
      expect(invoice.remainingAmount, 600.0);
    });

    test('remainingAmount is 0 when fully paid', () {
      final invoice = makeInvoice(totalAmount: 1000, paidAmount: 1000);
      expect(invoice.remainingAmount, 0.0);
    });

    test('isFullyPaid is true when paidAmount >= totalAmount', () {
      expect(makeInvoice(totalAmount: 1000, paidAmount: 1000).isFullyPaid, isTrue);
      expect(makeInvoice(totalAmount: 1000, paidAmount: 1001).isFullyPaid, isTrue);
    });

    test('isFullyPaid is false when paidAmount < totalAmount', () {
      expect(makeInvoice(totalAmount: 1000, paidAmount: 999).isFullyPaid, isFalse);
      expect(makeInvoice(totalAmount: 1000, paidAmount: 0).isFullyPaid,   isFalse);
    });

    test('isPartiallyPaid is true when 0 < paidAmount < totalAmount', () {
      expect(makeInvoice(totalAmount: 1000, paidAmount: 500).isPartiallyPaid, isTrue);
    });

    test('isPartiallyPaid is false when unpaid', () {
      expect(makeInvoice(totalAmount: 1000, paidAmount: 0).isPartiallyPaid, isFalse);
    });

    test('isPartiallyPaid is false when fully paid', () {
      expect(makeInvoice(totalAmount: 1000, paidAmount: 1000).isPartiallyPaid, isFalse);
    });
  });

  // ─── isOverdue ────────────────────────
  group('isOverdue', () {
    test('is true when dueDate is in the past and not fully paid', () {
      final past = DateTime.now().subtract(const Duration(days: 1));
      final invoice = makeInvoice(dueDate: past, paidAmount: 0);
      expect(invoice.isOverdue, isTrue);
    });

    test('is false when dueDate is in the future', () {
      final future = DateTime.now().add(const Duration(days: 7));
      final invoice = makeInvoice(dueDate: future, paidAmount: 0);
      expect(invoice.isOverdue, isFalse);
    });

    test('is false when fully paid even if overdue', () {
      final past = DateTime.now().subtract(const Duration(days: 5));
      final invoice = makeInvoice(dueDate: past, paidAmount: 1000);
      expect(invoice.isOverdue, isFalse);
    });

    test('is false when dueDate is null', () {
      final invoice = makeInvoice(dueDate: null, paidAmount: 0);
      expect(invoice.isOverdue, isFalse);
    });
  });

  // ─── fromJson / toJson ────────────────
  group('fromJson / toJson', () {
    final now = DateTime(2024, 6, 15, 10, 30);
    final jsonData = {
      'invoice_id':    'INV001',
      'invoice_no':    'AP2024001',
      'invoice_date':  '2024-06-15T10:30:00.000',
      'due_date':      '2024-07-15T10:30:00.000',
      'supplier_id':   'SUP001',
      'supplier_name': 'บริษัท ซัพพลายเออร์ จำกัด',
      'total_amount':  1000.0,
      'paid_amount':   500.0,
      'status':        'PARTIAL',
      'created_at':    '2024-06-15T10:30:00.000',
      'updated_at':    '2024-06-15T10:30:00.000',
    };

    test('parses all fields correctly', () {
      final model = ApInvoiceModel.fromJson(jsonData);

      expect(model.invoiceId,    'INV001');
      expect(model.invoiceNo,    'AP2024001');
      expect(model.supplierId,   'SUP001');
      expect(model.totalAmount,  1000.0);
      expect(model.paidAmount,   500.0);
      expect(model.status,       'PARTIAL');
      expect(model.dueDate,      isNotNull);
    });

    test('handles null optional fields', () {
      final Map<String, dynamic> minJson = Map<String, dynamic>.from(jsonData);
      minJson['due_date'] = null;
      minJson['remark']   = null;

      final model = ApInvoiceModel.fromJson(minJson);
      expect(model.dueDate, isNull);
      expect(model.remark,  isNull);
    });

    test('toJson roundtrip preserves values', () {
      final original  = ApInvoiceModel.fromJson(jsonData);
      final json      = original.toJson();
      final recreated = ApInvoiceModel.fromJson(json);

      expect(recreated.invoiceId,   original.invoiceId);
      expect(recreated.totalAmount, original.totalAmount);
      expect(recreated.paidAmount,  original.paidAmount);
      expect(recreated.status,      original.status);
    });
  });

  // ─── copyWith ─────────────────────────
  group('copyWith', () {
    test('creates copy with updated paidAmount', () {
      final original = makeInvoice(totalAmount: 1000, paidAmount: 0);
      final updated  = original.copyWith(paidAmount: 500, status: 'PARTIAL');

      expect(updated.paidAmount,   500.0);
      expect(updated.status,       'PARTIAL');
      expect(updated.totalAmount,  original.totalAmount); // ไม่เปลี่ยน
      expect(updated.invoiceId,    original.invoiceId);   // ไม่เปลี่ยน
    });

    test('original is not mutated after copyWith', () {
      final original = makeInvoice(paidAmount: 0);
      original.copyWith(paidAmount: 999);
      expect(original.paidAmount, 0.0);
    });
  });
}