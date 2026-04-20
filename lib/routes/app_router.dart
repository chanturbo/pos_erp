import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/config/app_mode.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/providers/auth_provider.dart'; // ✅ เพิ่ม สำหรับ _RootRedirect
import '../features/license/presentation/pages/license_page.dart';
import '../features/restaurant/presentation/pages/table_overview_page.dart';
import '../features/restaurant/presentation/pages/kitchen_display_page.dart';
import '../features/sales/presentation/pages/mobile_order_page.dart';
import '../features/sales/presentation/pages/pos_page.dart';
import '../features/setup/presentation/pages/setup_onboarding_page.dart';
import '../shared/utils/app_transitions.dart'; // ✅ Phase 4

/// ╔══════════════════════════════════════════════════════════════╗
/// ║  AppRouter — Role-based Navigation                           ║
/// ╠══════════════════════════════════════════════════════════════╣
/// ║  /            → redirect ตาม auth state (แก้ "no route /")  ║
/// ║  CASHIER       →  /pos   (isCashierMode: true)              ║
/// ║  ADMIN / อื่นๆ →  /home                                     ║
/// ╚══════════════════════════════════════════════════════════════╝
class AppRouter {
  AppRouter._();

  static const String root = '/'; // ✅ เพิ่ม — แก้ back จาก PosPage
  static const String login = '/login';
  static const String home = '/home';
  static const String pos = '/pos';
  static const String mobileOrder = '/mobile-order';
  static const String license = '/license';
  static const String setup = '/setup';
  static const String tableOverview = '/restaurant/tables';
  static const String kitchenDisplay = '/restaurant/kitchen';

  /// Cashier role IDs — ตรงกับ roleId ใน database
  static const _cashierRoles = {'CASHIER', 'SALE', 'POS'};

  /// ตรวจสอบว่า roleId เป็น Cashier หรือไม่
  static bool isCashierRole(String? roleId) =>
      _cashierRoles.contains(roleId?.toUpperCase());

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      // ── Root: redirect ตาม auth state ──────────────────────
      // ✅ เพิ่มใหม่ — ป้องกัน "no route defined for /"
      // MaterialApp จะ push '/' เข้า stack โดยอัตโนมัติเมื่อ
      // initialRoute ไม่ใช่ '/' ทำให้เกิด error เมื่อ back
      case root:
        return FadeSlideRoute(settings: settings, page: const _RootRedirect());

      // ── Login ─────────────────────────────────────────────
      case login:
        return FadeSlideRoute(settings: settings, page: const LoginPage());

      // ── Home ──────────────────────────────────────────────
      case home:
        if (AppModeConfig.mode == AppMode.clientMobile) {
          return SlideRightRoute(
            settings: settings,
            page: const MobileOrderPage(),
          );
        }
        return FadeSlideRoute(settings: settings, page: const SetupGatePage());

      // ── POS ───────────────────────────────────────────────
      // รับ arguments: true = isCashierMode (ส่งมาจาก login_page)
      // เมื่อ navigate มาจาก HomePage ปกติ arguments จะเป็น null → false
      case pos:
        if (AppModeConfig.mode == AppMode.clientMobile) {
          return SlideRightRoute(
            settings: settings,
            page: const MobileOrderPage(),
          );
        }
        final isCashierMode = settings.arguments is bool
            ? settings.arguments as bool
            : false;
        return SlideRightRoute(
          settings: settings,
          page: PosPage(isCashierMode: isCashierMode),
        );

      case mobileOrder:
        return SlideRightRoute(
          settings: settings,
          page: const MobileOrderPage(),
        );

      // ── License ───────────────────────────────────────────
      case license:
        return FadeSlideRoute(
          settings: settings,
          page: const LicenseRegistrationPage(),
        );

      case setup:
        return FadeSlideRoute(
          settings: settings,
          page: const SetupOnboardingPage(),
        );

      // ── Restaurant ────────────────────────────────────────
      case tableOverview:
        return SlideRightRoute(
          settings: settings,
          page: const TableOverviewPage(),
        );

      case kitchenDisplay:
        return SlideRightRoute(
          settings: settings,
          page: const KitchenDisplayPage(),
        );

      // ── Default ───────────────────────────────────────────
      default:
        return FadeSlideRoute(
          settings: settings,
          page: Scaffold(
            body: Center(child: Text('No route defined for ${settings.name}')),
          ),
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────────
// _RootRedirect
// อ่าน auth state แล้ว pushReplacement ไปหน้าที่ถูกต้อง
// ทำให้ route '/' มีอยู่จริง → ไม่เกิด "no route defined for /"
// ─────────────────────────────────────────────────────────────────
class _RootRedirect extends ConsumerWidget {
  const _RootRedirect();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    // ✅ ยังกำลัง restore token จาก storage — แสดง Splash ก่อน
    // ป้องกัน race condition: provider อื่น call API ก่อนมี token → 401
    if (authState.isRestoring) {
      return const _SplashScreen();
    }

    // ยัง login อยู่ — รอก่อน
    if (authState.isLoading) {
      return const _SplashScreen();
    }

    // ✅ Restore เสร็จแล้ว → redirect ตาม auth state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;

      if (authState.isAuthenticated) {
        if (AppModeConfig.mode == AppMode.clientMobile) {
          Navigator.of(context).pushReplacementNamed(AppRouter.mobileOrder);
          return;
        }

        final roleId = authState.user?.roleId?.toUpperCase() ?? '';
        if (AppRouter.isCashierRole(roleId)) {
          Navigator.of(context).pushReplacementNamed(
            AppRouter.pos,
            arguments: true, // isCashierMode
          );
        } else {
          Navigator.of(context).pushReplacementNamed(AppRouter.home);
        }
      } else {
        Navigator.of(context).pushReplacementNamed(AppRouter.login);
      }
    });

    return const _SplashScreen();
  }
}

// ─────────────────────────────────────────────────────────────────
// _SplashScreen — แสดงขณะรอ token restore
// ─────────────────────────────────────────────────────────────────
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.point_of_sale, size: 64, color: Color(0xFFE57200)),
            SizedBox(height: 20),
            Text(
              'DEE POS',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF16213E),
              ),
            ),
            SizedBox(height: 32),
            CircularProgressIndicator(color: Color(0xFFE57200)),
          ],
        ),
      ),
    );
  }
}
