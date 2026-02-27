import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'core/config/app_mode.dart';
import 'shared/theme/app_theme.dart';
import 'core/database/database_test.dart';  // เพิ่มบรรทัดนี้

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize App Mode
  await AppModeConfig.initialize();
  
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(1920, 1080),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp(
          title: 'POS + ERP System',
          theme: AppTheme.lightTheme,
          debugShowCheckedModeBanner: false,
          home: const DatabaseTestPage(),  // เปลี่ยนเป็นหน้าทดสอบ
        );
      },
    );
  }
}