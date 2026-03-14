import 'package:flutter/material.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/home/presentation/pages/home_page.dart';
import '../features/sales/presentation/pages/pos_page.dart';
import '../shared/utils/app_transitions.dart'; // ✅ Phase 4

/// ╔══════════════════════════════════════════════════════════════╗
/// ║  AppRouter — Role-based Navigation                           ║
/// ╠══════════════════════════════════════════════════════════════╣
/// ║  CASHIER / SALE / POS  →  /pos   (isCashierMode: true)      ║
/// ║  ADMIN / อื่นๆ          →  /home                             ║
/// ╚══════════════════════════════════════════════════════════════╝
class AppRouter {
  AppRouter._();

  static const String login = '/login';
  static const String home  = '/home';
  static const String pos   = '/pos';

  /// Cashier role IDs — ตรงกับ roleId ใน database
  static const _cashierRoles = {'CASHIER', 'SALE', 'POS'};

  /// ตรวจสอบว่า roleId เป็น Cashier หรือไม่
  static bool isCashierRole(String? roleId) =>
      _cashierRoles.contains(roleId?.toUpperCase());

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      // ── Login ─────────────────────────────────────────────
      case login:
        return FadeSlideRoute(
          settings: settings,
          page: const LoginPage(),
        );

      // ── Home ──────────────────────────────────────────────
      case home:
        return FadeSlideRoute(
          settings: settings,
          page: const HomePage(),
        );

      // ── POS ───────────────────────────────────────────────
      // รับ arguments: true = isCashierMode (ส่งมาจาก login_page)
      // เมื่อ navigate มาจาก HomePage ปกติ arguments จะเป็น null → false
      case pos:
        final isCashierMode =
            settings.arguments is bool ? settings.arguments as bool : false;
        return SlideRightRoute(
          settings: settings,
          page: PosPage(isCashierMode: isCashierMode),
        );

      // ── Default ───────────────────────────────────────────
      default:
        return FadeSlideRoute(
          settings: settings,
          page: Scaffold(
            body: Center(
              child: Text('No route defined for ${settings.name}'),
            ),
          ),
        );
    }
  }
}