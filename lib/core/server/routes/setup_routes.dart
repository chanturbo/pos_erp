// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../../database/app_database.dart';
import '../../database/seed_data.dart';

class SetupRoutes {
  final AppDatabase db;

  SetupRoutes(this.db);

  Router get router {
    final r = Router();
    r.post('/seed-demo', _seedDemoHandler);
    return r;
  }

  /// POST /api/setup/seed-demo
  /// body: {"mode": "pos" | "restaurant" | "both" | "none"}
  Future<Response> _seedDemoHandler(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final modeStr = (data['mode'] as String? ?? '').toLowerCase();

      final mode = switch (modeStr) {
        'pos' => DemoMode.posOnly,
        'restaurant' => DemoMode.restaurantOnly,
        'both' => DemoMode.both,
        'none' => DemoMode.none,
        _ => null,
      };

      if (mode == null) {
        return Response(
          400,
          body: jsonEncode({
            'success': false,
            'message': 'mode ต้องเป็น pos | restaurant | both | none',
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      print('🌱 [SetupRoutes] Seeding demo data: $modeStr');
      await SeedData.seedByMode(db, mode);
      print('✅ [SetupRoutes] Demo seeding complete: $modeStr');

      return Response.ok(
        jsonEncode({
          'success': true,
          'mode': modeStr,
          'message': 'Seed demo ($modeStr) เสร็จแล้ว',
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('❌ [SetupRoutes] seed-demo error: $e');
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': 'เกิดข้อผิดพลาด: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }
}
