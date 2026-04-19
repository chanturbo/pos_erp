import 'package:go_router/go_router.dart';
import 'pages/home_page.dart';
import 'pages/login_page.dart';
import 'pages/dashboard_page.dart';
import 'services/auth_service.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    final isLoggedIn = AuthService.instance.isLoggedIn;
    final isDashboard = state.matchedLocation.startsWith('/dashboard');
    if (isDashboard && !isLoggedIn) return '/login';
    return null;
  },
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomePage()),
    GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
    GoRoute(path: '/dashboard', builder: (context, state) => const DashboardPage()),
  ],
);
