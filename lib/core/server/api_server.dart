import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import '../database/app_database.dart';
import 'routes/auth_routes.dart';
import 'middleware/auth_middleware.dart';

class ApiServer {
  final AppDatabase db;
  HttpServer? _server;
  
  ApiServer(this.db);
  
  /// เริ่ม Server
  Future<void> start({int port = 8080}) async {
    try {
      final router = Router();
      
      // Health check
      router.get('/api/health', (Request request) {
        return Response.ok('OK');
      });
      
      // Auth routes
      router.mount('/api/auth', AuthRoutes(db).router.call);
      
      // TODO: เพิ่ม routes อื่นๆ ในอนาคต
      // router.mount('/api/products', ProductRoutes(db).router.call);
      // router.mount('/api/sales', SalesRoutes(db).router.call);
      
      // Pipeline
      final handler = Pipeline()
          .addMiddleware(logRequests())
          .addMiddleware(_corsHeaders())
          .addMiddleware(authMiddleware(db))
          .addHandler(router.call);
      
      // Start server
      _server = await io.serve(handler, '0.0.0.0', port);
      print('✅ API Server started at http://0.0.0.0:$port');
      
    } catch (e) {
      print('❌ Failed to start server: $e');
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