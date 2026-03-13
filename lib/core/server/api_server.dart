// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:drift/drift.dart' hide JsonKey;
import '../database/app_database.dart';
import 'routes/ar_invoice_routes.dart';
import 'routes/ar_receipt_routes.dart';
import 'routes/auth_routes.dart';
import 'routes/goods_receipt_routes.dart';
import 'routes/product_routes.dart';
import 'routes/customer_routes.dart';
import 'routes/promotion_routes.dart';
import 'routes/purchase_return_routes.dart';
import 'routes/purchase_routes.dart';
import 'routes/sales_routes.dart';
import 'routes/stock_routes.dart';
import 'routes/report_routes.dart';
import 'routes/supplier_routes.dart';
import 'routes/ap_invoice_routes.dart';
import 'routes/ap_payment_routes.dart';
import 'routes/branch_routes.dart'; // 🆕 Week 7
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
      print('   ✅ /api/suppliers');

      // Stock routes
      router.mount('/api/stock', StockRoutes(db).router.call);
      print('   ✅ /api/stock');

      // Sales routes
      router.mount('/api/sales', SalesRoutes(db).router.call);
      print('   ✅ /api/sales');

      // Report routes
      router.mount('/api/reports', ReportRoutes(db).router.call);
      print('   ✅ /api/reports');

      // Purchase routes
      router.mount('/api/purchases', PurchaseRoutes(db).router.call);
      print('   ✅ /api/purchases');

      // Goods Receipt routes
      router.mount('/api/goods-receipts', GoodsReceiptRoutes(db).router.call);
      print('   ✅ /api/goods-receipts');

      // AP Invoice routes
      router.mount('/api/ap-invoices', ApInvoiceRoutes(db).router.call);
      print('   ✅ /api/ap-invoices');

      // AP Payment routes
      router.mount('/api/ap-payments', ApPaymentRoutes(db).router.call);
      print('   ✅ /api/ap-payments');

      // Purchase Return routes
      router.mount('/api/purchase-returns', PurchaseReturnRoutes(db).router.call);
      print('   ✅ /api/purchase-returns');

      // AR Invoice routes ✅ Day 36-38
      router.mount('/api/ar-invoices', ArInvoiceRoutes(db).router.call);
      print('   ✅ /api/ar-invoices');

      // AR Receipt routes ✅ Day 39-40
      router.mount('/api/ar-receipts', ArReceiptRoutes(db).router.call);
      print('   ✅ /api/ar-receipts');

      // Promotion & Coupon routes ✅ Day 41-45
      router.mount('/api/promotions', PromotionRoutes(db).router.call);
      print('   ✅ /api/promotions');

      // Branch, Warehouse & Sync routes ✅ Week 7
      router.mount('/api/branches', BranchRoutes(db).router.call);
      print('   ✅ /api/branches');

      // 🆕 Sync helper endpoints (เรียกจาก OfflineSyncService)
      router.post('/api/sync/push-pending', _pushPendingHandler);
      router.post('/api/sync/enqueue', _enqueueHandler);
      router.post('/api/sync/retry-failed', _retryFailedHandler);
      print('   ✅ /api/sync/*');

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

  // ── Sync helper handlers ───────────────────────────────────────────────────

  /// ส่ง PENDING items ออกไป แล้ว mark เป็น SYNCED
  Future<Response> _pushPendingHandler(Request req) async {
    try {
      final pending = await (db.select(db.syncQueues)
            ..where((q) => q.syncStatus.equals('PENDING'))
            ..orderBy([(q) => OrderingTerm.asc(q.createdAt)])
            ..limit(100))
          .get();

      for (final q in pending) {
        await (db.update(db.syncQueues)
              ..where((sq) => sq.queueId.equals(q.queueId)))
            .write(SyncQueuesCompanion(
          syncStatus: const Value('SYNCED'),
          syncedAt: Value(DateTime.now()),
        ));
      }

      return Response.ok(
        jsonEncode({'success': true, 'data': {'pushed': pending.length}}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': '$e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// เพิ่มรายการเข้า Sync Queue
  Future<Response> _enqueueHandler(Request req) async {
    try {
      final data =
          jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      await db.into(db.syncQueues).insertOnConflictUpdate(
            SyncQueuesCompanion(
              queueId: Value(data['queue_id'] as String),
              deviceId: Value(data['device_id'] as String? ?? 'local'),
              tableNameValue: Value(data['table_name'] as String),
              recordId: Value(data['record_id'] as String),
              operation: Value(data['operation'] as String),
              data: Value(data['data']),
              syncStatus: const Value('PENDING'),
            ),
          );
      return Response.ok(
        jsonEncode({'success': true, 'message': 'Enqueued'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': '$e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// Reset FAILED → PENDING เพื่อ retry
  Future<Response> _retryFailedHandler(Request req) async {
    try {
      final count = await (db.update(db.syncQueues)
            ..where((q) => q.syncStatus.equals('FAILED')))
          .write(const SyncQueuesCompanion(syncStatus: Value('PENDING')));
      return Response.ok(
        jsonEncode({'success': true, 'data': {'reset_count': count}}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': '$e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // ── CORS Middleware ────────────────────────────────────────────────────────
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