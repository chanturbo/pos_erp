import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'router.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService.instance.tryRestoreSession();
  runApp(const DeePosApp());
}

class DeePosApp extends StatelessWidget {
  const DeePosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'DEE POS — ระบบ POS สำหรับร้านค้าไทย',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E88E5),
          brightness: Brightness.light,
        ),
        textTheme: GoogleFonts.ibmPlexSansThaiTextTheme(),
        useMaterial3: true,
      ),
      routerConfig: appRouter,
    );
  }
}
