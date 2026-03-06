// ignore_for_file: avoid_print

import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import '../database/app_database.dart';
import 'routes/auth_routes.dart';
import 'routes/product_routes.dart';
import 'routes/customer_routes.dart';
import 'routes/sales_routes.dart';
import 'routes/stock_routes.dart';
import 'routes/report_routes.dart';
import 'routes/supplier_routes.dart';
import 'middleware/auth_middleware.dart';

class ApiServer {
  final AppDatabase db;
  HttpServer? _server;

  ApiServer(this.db);

  /// เริ่ม Server
  Future<void> start({int port = 8080}) async {
    try {
      final router = Router();

      print('🔧 Configuring routes...');

      // ==================== PUBLIC ROUTES ====================
      
      // Health check
      router.get('/api/health', (Request request) {
        print('📡 Health check');
        return Response.ok('OK');
      });

      // Auth routes
      router.mount('/api/auth', AuthRoutes(db).router.call);
      print('   ✅ /api/auth');

      // ==================== PROTECTED ROUTES ====================
      
      // Product routes
      router.mount('/api/products', ProductRoutes(db).router.call);
      print('   ✅ /api/products');

      // Customer routes
      router.mount('/api/customers', CustomerRoutes(db).router.call);
      print('   ✅ /api/customers');

      // Supplier routes
      router.mount('/api/suppliers', SupplierRoutes(db).router.call);
      print('   ✅ /api/suppliers'); // ✅ ต้องเห็นบรรทัดนี้

      // Stock routes
      router.mount('/api/stock', StockRoutes(db).router.call);
      print('   ✅ /api/stock');

      // Sales routes
      router.mount('/api/sales', SalesRoutes(db).router.call);
      print('   ✅ /api/sales');

      // Report routes
      router.mount('/api/reports', ReportRoutes(db).router.call);
      print('   ✅ /api/reports');

      print('🔧 Routes configured successfully');

      // ==================== PIPELINE ====================
      final handler = Pipeline()
          .addMiddleware(logRequests())
          .addMiddleware(_corsHeaders())
          .addMiddleware(authMiddleware(db))
          .addHandler(router.call);

      // ==================== START SERVER ====================
      _server = await io.serve(handler, '127.0.0.1', port);
      print('✅ API Server started at http://127.0.0.1:8080');
    } catch (e, stack) {
      print('❌ Failed to start server: $e');
      print('Stack trace: $stack');
      rethrow;
    }
  }

  /// หยุด Server
  Future<void> stop() async {
    await _server?.close();
    print('⏹️  API Server stopped');
  }

  /// CORS Middleware
  Middleware _corsHeaders() {
    return (Handler handler) {
      return (Request request) async {
        // Handle preflight
        if (request.method == 'OPTIONS') {
          return Response.ok('', headers: _corsHeadersMap);
        }

        final response = await handler(request);
        return response.change(headers: _corsHeadersMap);
      };
    };
  }

  final _corsHeadersMap = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Origin, Content-Type, Authorization',
  };
}