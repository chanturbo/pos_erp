// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:shelf/shelf.dart';
import '../../database/app_database.dart';
import '../../services/auth_service.dart';

/// Middleware สำหรับตรวจสอบ Authentication
Middleware authMiddleware(AppDatabase db) {
  final authService = AuthService(db);

  return (Handler handler) {
    return (Request request) async {
      final path = request.url.path;

      // ==================== PUBLIC PATHS (ไม่ต้อง Auth) ====================
      // TODO: เมื่อ production พร้อม ให้ลบ routes ที่ไม่ใช่ auth/health ออก
      //       แล้วแก้ provider ให้รอ token ก่อน load
      final publicPaths = [
        'api/auth',             // Login, Register
        'api/health',           // Health check
        // ── Products & Customers ──────────────────────────────────────────
        'api/products',         // ✅ Products
        'api/customers',        // ✅ Customers
        // ── Sales & Stock ─────────────────────────────────────────────────
        'api/sales',            // ✅ Sales
        'api/stock',            // ✅ Stock
        'api/warehouses',       // ✅ Warehouses
        'api/reports',          // ✅ Reports
        // ── Procurement ───────────────────────────────────────────────────
        'api/suppliers',        // ✅ Suppliers
        'api/purchases',        // ✅ Purchase Orders
        'api/goods-receipts',   // ✅ Goods Receipts
        'api/purchase-returns', // ✅ Purchase Returns
        // ── Accounts Payable ──────────────────────────────────────────────
        'api/ap-invoices',      // ✅ AP Invoices
        'api/ap-payments',      // ✅ AP Payments
        // ── Accounts Receivable ───────────────────────────────────────────
        'api/ar-invoices',      // ✅ AR Invoices
        'api/ar-receipts',      // ✅ AR Receipts
        // ── Other ─────────────────────────────────────────────────────────
        'api/promotions',       // ✅ Promotions
        'api/branches',         // ✅ Branches
      ];

      // ตรวจสอบว่าเป็น public path หรือไม่
      for (final publicPath in publicPaths) {
        if (path.startsWith(publicPath)) {
          print('✅ Public path: $path - Skip auth');
          return handler(request);
        }
      }

      // ==================== PROTECTED PATHS (ต้อง Auth) ====================
      print('🔒 Protected path: $path - Checking auth...');

      final authHeader = request.headers['authorization'];

      if (authHeader == null || !authHeader.startsWith('Bearer ')) {
        print('❌ Missing or invalid Authorization header');
        return Response(
          401,
          body: jsonEncode({
            'success': false,
            'message': 'Unauthorized - Missing token',
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      try {
        final token = authHeader.replaceFirst('Bearer ', '');
        final user = await authService.verifyToken(token);

        if (user == null) {
          print('❌ Invalid token');
          return Response(
            401,
            body: jsonEncode({
              'success': false,
              'message': 'Unauthorized - Invalid token',
            }),
            headers: {'Content-Type': 'application/json'},
          );
        }

        print('✅ User authenticated: ${user.userId}');

        // เพิ่ม user ลง request context
        final updatedRequest = request.change(context: {'user': user});

        return handler(updatedRequest);
      } catch (e) {
        print('❌ Auth error: $e');
        return Response(
          401,
          body: jsonEncode({
            'success': false,
            'message': 'Unauthorized - Token verification failed',
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }
    };
  };
}