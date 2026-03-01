import 'package:flutter/material.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/home/presentation/pages/home_page.dart';
import '../features/sales/presentation/pages/pos_page.dart'; // ✅ เพิ่ม

class AppRouter {
  static const String login = '/login';
  static const String home = '/home';
  static const String pos = '/pos'; // ✅ เพิ่ม

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case login:
        return MaterialPageRoute(builder: (_) => const LoginPage());

      case home:
        return MaterialPageRoute(builder: (_) => const HomePage());

      case pos: // ✅ เพิ่ม
        return MaterialPageRoute(builder: (_) => const PosPage());

      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(child: Text('No route defined for ${settings.name}')),
          ),
        );
    }
  }
}
