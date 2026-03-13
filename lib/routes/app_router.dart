import 'package:flutter/material.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/home/presentation/pages/home_page.dart';
import '../features/sales/presentation/pages/pos_page.dart';
import '../shared/utils/app_transitions.dart'; // ✅ Phase 4

class AppRouter {
  static const String login = '/login';
  static const String home  = '/home';
  static const String pos   = '/pos';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case login:
        return FadeSlideRoute(
          settings: settings,
          page: const LoginPage(),
        );

      case home:
        return FadeSlideRoute(
          settings: settings,
          page: const HomePage(),
        );

      case pos:
        return SlideRightRoute(
          settings: settings,
          page: const PosPage(),
        );

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