import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:drift/drift.dart' hide JsonKey;
import '../../database/app_database.dart';

class ReportRoutes {
  final AppDatabase db;
  
  ReportRoutes(this.db);
  
  Router get router {
    final router = Router();
    
    router.get('/sales-summary', _getSalesSummaryHandler);
    router.get('/sales-daily', _getSalesDailyHandler);
    router.get('/top-products', _getTopProductsHandler);
    router.get('/top-customers', _getTopCustomersHandler);
    router.get('/sales-by-payment', _getSalesByPaymentHandler);
    
    return router;
  }
  
  /// GET /api/reports/sales-summary - สรุปยอดขายภาพรวม
  Future<Response> _getSalesSummaryHandler(Request request) async {
    try {
      final queryParams = request.url.queryParameters;
      final startDate = queryParams['start_date'];
      final endDate = queryParams['end_date'];
      
      String whereClause = '';
      List<Variable> variables = [];
      
      if (startDate != null && endDate != null) {
        whereClause = 'WHERE DATE(order_date) BETWEEN ? AND ?';
        variables = [
          Variable.withString(startDate),
          Variable.withString(endDate),
        ];
      }
      
      final query = '''
        SELECT 
          COUNT(*) as total_orders,
          COALESCE(SUM(total_amount), 0) as total_sales,
          COALESCE(AVG(total_amount), 0) as avg_order_value,
          COALESCE(SUM(discount_amount), 0) as total_discount
        FROM sales_orders
        $whereClause
      ''';
      
      final result = await db.customSelect(query, variables: variables).getSingle();
      
      return Response.ok(jsonEncode({
        'success': true,
        'data': {
          'total_orders': result.read<int>('total_orders'),
          'total_sales': result.read<double>('total_sales'),
          'avg_order_value': result.read<double>('avg_order_value'),
          'total_discount': result.read<double>('total_discount'),
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
  
  /// GET /api/reports/sales-daily - ยอดขายรายวัน
  Future<Response> _getSalesDailyHandler(Request request) async {
    try {
      final queryParams = request.url.queryParameters;
      final days = int.tryParse(queryParams['days'] ?? '30') ?? 30;
      
      final query = '''
        SELECT 
          DATE(order_date) as date,
          COUNT(*) as orders,
          COALESCE(SUM(total_amount), 0) as sales
        FROM sales_orders
        WHERE order_date >= DATE('now', '-$days days')
        GROUP BY DATE(order_date)
        ORDER BY date DESC
      ''';
      
      final results = await db.customSelect(query).get();
      
      final data = results.map((row) => {
        'date': row.read<String>('date'),
        'orders': row.read<int>('orders'),
        'sales': row.read<double>('sales'),
      }).toList();
      
      return Response.ok(jsonEncode({
        'success': true,
        'data': data,
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
  
  /// GET /api/reports/top-products - สินค้าขายดี
  Future<Response> _getTopProductsHandler(Request request) async {
    try {
      final queryParams = request.url.queryParameters;
      final limit = int.tryParse(queryParams['limit'] ?? '10') ?? 10;
      final startDate = queryParams['start_date'];
      final endDate = queryParams['end_date'];
      
      String whereClause = '';
      List<Variable> variables = [];
      
      if (startDate != null && endDate != null) {
        whereClause = 'WHERE DATE(so.order_date) BETWEEN ? AND ?';
        variables = [
          Variable.withString(startDate),
          Variable.withString(endDate),
        ];
      }
      
      final query = '''
        SELECT 
          soi.product_id,
          soi.product_code,
          soi.product_name,
          SUM(soi.quantity) as total_quantity,
          SUM(soi.amount) as total_sales,
          COUNT(DISTINCT so.order_id) as order_count
        FROM sales_order_items soi
        JOIN sales_orders so ON soi.order_id = so.order_id
        $whereClause
        GROUP BY soi.product_id
        ORDER BY total_sales DESC
        LIMIT $limit
      ''';
      
      final results = await db.customSelect(query, variables: variables).get();
      
      final data = results.map((row) => {
        'product_id': row.read<String>('product_id'),
        'product_code': row.read<String>('product_code'),
        'product_name': row.read<String>('product_name'),
        'total_quantity': row.read<double>('total_quantity'),
        'total_sales': row.read<double>('total_sales'),
        'order_count': row.read<int>('order_count'),
      }).toList();
      
      return Response.ok(jsonEncode({
        'success': true,
        'data': data,
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
  
  /// GET /api/reports/top-customers - ลูกค้าซื้อบ่อย
  Future<Response> _getTopCustomersHandler(Request request) async {
    try {
      final queryParams = request.url.queryParameters;
      final limit = int.tryParse(queryParams['limit'] ?? '10') ?? 10;
      
      final query = '''
        SELECT 
          customer_id,
          customer_name,
          COUNT(*) as order_count,
          SUM(total_amount) as total_sales
        FROM sales_orders
        WHERE customer_id IS NOT NULL
        GROUP BY customer_id
        ORDER BY total_sales DESC
        LIMIT $limit
      ''';
      
      final results = await db.customSelect(query).get();
      
      final data = results.map((row) => {
        'customer_id': row.read<String>('customer_id'),
        'customer_name': row.read<String>('customer_name'),
        'order_count': row.read<int>('order_count'),
        'total_sales': row.read<double>('total_sales'),
      }).toList();
      
      return Response.ok(jsonEncode({
        'success': true,
        'data': data,
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
  
  /// GET /api/reports/sales-by-payment - ยอดขายตามวิธีชำระ
  Future<Response> _getSalesByPaymentHandler(Request request) async {
    try {
      final query = '''
        SELECT 
          payment_type,
          COUNT(*) as count,
          SUM(total_amount) as total
        FROM sales_orders
        GROUP BY payment_type
        ORDER BY total DESC
      ''';
      
      final results = await db.customSelect(query).get();
      
      final data = results.map((row) => {
        'payment_type': row.read<String>('payment_type'),
        'count': row.read<int>('count'),
        'total': row.read<double>('total'),
      }).toList();
      
      return Response.ok(jsonEncode({
        'success': true,
        'data': data,
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