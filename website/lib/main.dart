import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'pages/home_page.dart';

void main() {
  runApp(const DeePosApp());
}

class DeePosApp extends StatelessWidget {
  const DeePosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
      home: const HomePage(),
    );
  }
}
