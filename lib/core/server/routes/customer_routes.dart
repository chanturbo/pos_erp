import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:drift/drift.dart' hide JsonKey;
import '../../database/app_database.dart';

class CustomerRoutes {
  final AppDatabase db;
  
  CustomerRoutes(this.db);
  
  Router get router {
    final router = Router();
    
    router.get('/', _getCustomersHandler);
    router.get('/<id>', _getCustomerHandler);
    router.post('/', _createCustomerHandler);
    router.put('/<id>', _updateCustomerHandler);
    router.delete('/<id>', _deleteCustomerHandler);
    router.get('/code/<code>', _getCustomerByCodeHandler);
    
    return router;
  }
  
  /// GET /api/customers - รายการลูกค้าทั้งหมด
  Future<Response> _getCustomersHandler(Request request) async {
    try {
      final customers = await db.select(db.customers).get();
      
      return Response.ok(jsonEncode({
        'success': true,
        'data': customers.map((c) => {
          'customer_id': c.customerId,
          'customer_code': c.customerCode,
          'customer_name': c.customerName,
          'customer_group_id': c.customerGroupId,
          'address': c.address,
          'phone': c.phone,
          'email': c.email,
          'tax_id': c.taxId,
          'credit_limit': c.creditLimit,
          'credit_days': c.creditDays,
          'current_balance': c.currentBalance,
          'member_no': c.memberNo,
          'points': c.points,
          'is_active': c.isActive,
        }).toList(),
      }), headers: {
        'Content-Type': 'application/json',
      });
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'เกิดข้อผิดพลาด: $e',
        }),
      );
    }
  }
  
  /// GET /api/customers/:id - ดึงลูกค้า 1 รายการ
  Future<Response> _getCustomerHandler(Request request, String id) async {
    try {
      final customer = await (db.select(db.customers)
            ..where((t) => t.customerId.equals(id)))
          .getSingleOrNull();
      
      if (customer == null) {
        return Response.notFound(jsonEncode({
          'success': false,
          'message': 'ไม่พบลูกค้า',
        }));
      }
      
      return Response.ok(jsonEncode({
        'success': true,
        'data': {
          'customer_id': customer.customerId,
          'customer_code': customer.customerCode,
          'customer_name': customer.customerName,
          'customer_group_id': customer.customerGroupId,
          'address': customer.address,
          'phone': customer.phone,
          'email': customer.email,
          'tax_id': customer.taxId,
          'credit_limit': customer.creditLimit,
          'credit_days': customer.creditDays,
          'current_balance': customer.currentBalance,
          'member_no': customer.memberNo,
          'points': customer.points,
          'is_active': customer.isActive,
        },
      }), headers: {
        'Content-Type': 'application/json',
      });
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'เกิดข้อผิดพลาด: $e',
        }),
      );
    }
  }
  
  /// POST /api/customers - สร้างลูกค้าใหม่
  Future<Response> _createCustomerHandler(Request request) async {
    try {
      final payload = await request.readAsString();
      final data = jsonDecode(payload) as Map<String, dynamic>;
      
      // Generate Customer ID
      final customerId = 'CUS${DateTime.now().millisecondsSinceEpoch}';
      
      await db.into(db.customers).insert(CustomersCompanion.insert(
        customerId: customerId,
        customerCode: data['customer_code'] as String,
        customerName: data['customer_name'] as String,
        customerGroupId: Value(data['customer_group_id'] as String?),
        address: Value(data['address'] as String?),
        phone: Value(data['phone'] as String?),
        email: Value(data['email'] as String?),
        taxId: Value(data['tax_id'] as String?),
        creditLimit: Value(data['credit_limit'] as double? ?? 0),
        creditDays: Value(data['credit_days'] as int? ?? 0),
        memberNo: Value(data['member_no'] as String?),
      ));
      
      return Response.ok(jsonEncode({
        'success': true,
        'message': 'สร้างลูกค้าสำเร็จ',
        'data': {'customer_id': customerId},
      }), headers: {
        'Content-Type': 'application/json',
      });
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'เกิดข้อผิดพลาด: $e',
        }),
      );
    }
  }
  
  /// PUT /api/customers/:id - แก้ไขลูกค้า
  Future<Response> _updateCustomerHandler(Request request, String id) async {
    try {
      final payload = await request.readAsString();
      final data = jsonDecode(payload) as Map<String, dynamic>;
      
      await (db.update(db.customers)..where((t) => t.customerId.equals(id)))
          .write(CustomersCompanion(
        customerCode: Value(data['customer_code'] as String),
        customerName: Value(data['customer_name'] as String),
        customerGroupId: Value(data['customer_group_id'] as String?),
        address: Value(data['address'] as String?),
        phone: Value(data['phone'] as String?),
        email: Value(data['email'] as String?),
        taxId: Value(data['tax_id'] as String?),
        creditLimit: Value(data['credit_limit'] as double? ?? 0),
        creditDays: Value(data['credit_days'] as int? ?? 0),
        memberNo: Value(data['member_no'] as String?),
        updatedAt: Value(DateTime.now()),
      ));
      
      return Response.ok(jsonEncode({
        'success': true,
        'message': 'แก้ไขลูกค้าสำเร็จ',
      }), headers: {
        'Content-Type': 'application/json',
      });
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'เกิดข้อผิดพลาด: $e',
        }),
      );
    }
  }
  
  /// DELETE /api/customers/:id - ลบลูกค้า
  Future<Response> _deleteCustomerHandler(Request request, String id) async {
    try {
      await (db.delete(db.customers)..where((t) => t.customerId.equals(id))).go();
      
      return Response.ok(jsonEncode({
        'success': true,
        'message': 'ลบลูกค้าสำเร็จ',
      }), headers: {
        'Content-Type': 'application/json',
      });
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'เกิดข้อผิดพลาด: $e',
        }),
      );
    }
  }
  
  /// GET /api/customers/code/:code - ค้นหาด้วยรหัส
  Future<Response> _getCustomerByCodeHandler(Request request, String code) async {
    try {
      final customer = await (db.select(db.customers)
            ..where((t) => t.customerCode.equals(code)))
          .getSingleOrNull();
      
      if (customer == null) {
        return Response.notFound(jsonEncode({
          'success': false,
          'message': 'ไม่พบลูกค้า',
        }));
      }
      
      return Response.ok(jsonEncode({
        'success': true,
        'data': {
          'customer_id': customer.customerId,
          'customer_code': customer.customerCode,
          'customer_name': customer.customerName,
          'phone': customer.phone,
          'credit_limit': customer.creditLimit,
          'current_balance': customer.currentBalance,
        },
      }), headers: {
        'Content-Type': 'application/json',
      });
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'เกิดข้อผิดพลาด: $e',
        }),
      );
    }
  }
}