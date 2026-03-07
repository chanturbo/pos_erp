// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:drift/drift.dart' hide JsonKey;
import '../../database/app_database.dart';

class SupplierRoutes {
  final AppDatabase db;

  SupplierRoutes(this.db) {
    print('🔧 SupplierRoutes initialized');
  }

  Router get router {
    print('🔧 Building SupplierRoutes router...');
    
    final router = Router();

    router.get('/', _getSuppliersHandler);
    router.get('/<id>', _getSupplierHandler);
    router.post('/', _createSupplierHandler);
    router.put('/<id>', _updateSupplierHandler);
    router.delete('/<id>', _deleteSupplierHandler);

    print('🔧 SupplierRoutes configured:');
    print('   GET  / → /api/suppliers');
    print('   GET  /<id> → /api/suppliers/:id');
    print('   POST / → /api/suppliers');
    print('   PUT  /<id> → /api/suppliers/:id');
    print('   DELETE /<id> → /api/suppliers/:id');

    return router;
  }

  /// GET /
  Future<Response> _getSuppliersHandler(Request request) async {
    try {
      print('📡 SupplierRoutes: GET /');

      final suppliers = await db.select(db.suppliers).get();

      final data = suppliers.map((s) => {
            'supplier_id': s.supplierId,
            'supplier_code': s.supplierCode,
            'supplier_name': s.supplierName,
            'contact_person': s.contactPerson,
            'phone': s.phone,
            'email': s.email,
            'line_id': s.lineId,
            'address': s.address,
            'tax_id': s.taxId,
            'credit_term': s.creditTerm,
            'credit_limit': s.creditLimit,
            'current_balance': s.currentBalance,
            'is_active': s.isActive,
            'created_at': s.createdAt.toIso8601String(),
            'updated_at': s.updatedAt.toIso8601String(),
          }).toList();

      print('✅ SupplierRoutes: Found ${suppliers.length} suppliers');

      return Response.ok(
        jsonEncode({'success': true, 'data': data}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('❌ SupplierRoutes: GET / error: $e');
      print('Stack trace: $stack');
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': '$e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// GET /:id
  Future<Response> _getSupplierHandler(Request request, String id) async {
    try {
      print('📡 SupplierRoutes: GET /$id');

      final supplier = await (db.select(db.suppliers)
            ..where((s) => s.supplierId.equals(id)))
          .getSingleOrNull();

      if (supplier == null) {
        return Response.notFound(
          jsonEncode({'success': false, 'message': 'Supplier not found'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final data = {
        'supplier_id': supplier.supplierId,
        'supplier_code': supplier.supplierCode,
        'supplier_name': supplier.supplierName,
        'contact_person': supplier.contactPerson,
        'phone': supplier.phone,
        'email': supplier.email,
        'line_id': supplier.lineId,
        'address': supplier.address,
        'tax_id': supplier.taxId,
        'credit_term': supplier.creditTerm,
        'credit_limit': supplier.creditLimit,
        'current_balance': supplier.currentBalance,
        'is_active': supplier.isActive,
        'created_at': supplier.createdAt.toIso8601String(),
        'updated_at': supplier.updatedAt.toIso8601String(),
      };

      return Response.ok(
        jsonEncode({'success': true, 'data': data}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('❌ SupplierRoutes: GET /$id error: $e');
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': '$e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// POST /
  Future<Response> _createSupplierHandler(Request request) async {
    try {
      print('📡 SupplierRoutes: POST /');

      final payload = await request.readAsString();
      final data = jsonDecode(payload) as Map<String, dynamic>;

      final supplierId = 'SUP${DateTime.now().millisecondsSinceEpoch}';

      final companion = SuppliersCompanion(
        supplierId: Value(supplierId),
        supplierCode: Value(data['supplier_code'] as String),
        supplierName: Value(data['supplier_name'] as String),
        contactPerson: Value(data['contact_person'] as String?),
        phone: Value(data['phone'] as String?),
        email: Value(data['email'] as String?),
        lineId: Value(data['line_id'] as String?),
        address: Value(data['address'] as String?),
        taxId: Value(data['tax_id'] as String?),
        creditTerm: Value(data['credit_term'] as int? ?? 30),
        creditLimit: Value((data['credit_limit'] as num?)?.toDouble() ?? 0),
        currentBalance: Value((data['current_balance'] as num?)?.toDouble() ?? 0),
        isActive: Value(data['is_active'] as bool? ?? true),
      );

      await db.into(db.suppliers).insert(companion);

      print('✅ SupplierRoutes: Created supplier: $supplierId');

      return Response.ok(
        jsonEncode({
          'success': true,
          'message': 'Supplier created',
          'data': {'supplier_id': supplierId}
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('❌ SupplierRoutes: POST / error: $e');
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': '$e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// PUT /:id
  Future<Response> _updateSupplierHandler(Request request, String id) async {
    try {
      print('📡 SupplierRoutes: PUT /$id');

      final payload = await request.readAsString();
      final data = jsonDecode(payload) as Map<String, dynamic>;

      final companion = SuppliersCompanion(
        supplierCode: Value(data['supplier_code'] as String),
        supplierName: Value(data['supplier_name'] as String),
        contactPerson: Value(data['contact_person'] as String?),
        phone: Value(data['phone'] as String?),
        email: Value(data['email'] as String?),
        lineId: Value(data['line_id'] as String?),
        address: Value(data['address'] as String?),
        taxId: Value(data['tax_id'] as String?),
        creditTerm: Value(data['credit_term'] as int? ?? 30),
        creditLimit: Value((data['credit_limit'] as num?)?.toDouble() ?? 0),
        currentBalance: Value((data['current_balance'] as num?)?.toDouble() ?? 0),
        isActive: Value(data['is_active'] as bool? ?? true),
        updatedAt: Value(DateTime.now()),
      );

      await (db.update(db.suppliers)..where((s) => s.supplierId.equals(id)))
          .write(companion);

      print('✅ SupplierRoutes: Updated supplier: $id');

      return Response.ok(
        jsonEncode({'success': true, 'message': 'Supplier updated'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('❌ SupplierRoutes: PUT /$id error: $e');
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': '$e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// DELETE /:id
  Future<Response> _deleteSupplierHandler(Request request, String id) async {
    try {
      print('📡 SupplierRoutes: DELETE /$id');

      await (db.delete(db.suppliers)..where((s) => s.supplierId.equals(id)))
          .go();

      print('✅ SupplierRoutes: Deleted supplier: $id');

      return Response.ok(
        jsonEncode({'success': true, 'message': 'Supplier deleted'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('❌ SupplierRoutes: DELETE /$id error: $e');
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': '$e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }
}