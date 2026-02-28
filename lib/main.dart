import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:drift/drift.dart' hide Column;
import 'core/config/app_mode.dart';
import 'shared/theme/app_theme.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'routes/app_router.dart';
import 'core/database/app_database.dart';
import 'core/server/api_server.dart';
import 'core/utils/crypto_utils.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize App Mode
  await AppModeConfig.initialize();
  
  // เริ่ม Server อัตโนมัติ
  _startServerInBackground();
  
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

// Global server instance
ApiServer? _serverInstance;

/// เริ่ม Server ใน Background
void _startServerInBackground() async {
  try {
    final db = AppDatabase();
    
    // สร้าง User ทดสอบ (ถ้ายังไม่มี)
    await _createDefaultUser(db);
    
    _serverInstance = ApiServer(db);
    await _serverInstance!.start(port: 8080);
    debugPrint('✅ API Server started at http://127.0.0.1:8080');
  } catch (e) {
    debugPrint('❌ Failed to start server: $e');
  }
}

/// สร้าง User ทดสอบ
Future<void> _createDefaultUser(AppDatabase db) async {
  try {
    // เช็คว่ามี User แล้วหรือยัง
    final users = await db.select(db.users).get();
    if (users.isNotEmpty) {
      debugPrint('✅ Users already exist');
      return;
    }
    
    // สร้าง Role
    await db.into(db.roles).insert(
      RolesCompanion.insert(
        roleId: 'ROLE001',
        roleName: 'Administrator',
        permissions: {'sales': {'create': true}},
      ),
    );
    
    // สร้าง User
    await db.into(db.users).insert(
      UsersCompanion.insert(
        userId: 'USR001',
        username: 'admin',
        passwordHash: CryptoUtils.hashPassword('admin123'),
        fullName: 'ผู้ดูแลระบบ',
        roleId: const Value('ROLE001'),
      ),
    );
    
    debugPrint('✅ Default user created (admin/admin123)');
  } catch (e) {
    debugPrint('⚠️ Create default user error: $e');
  }
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    
    return ScreenUtilInit(
      designSize: const Size(1920, 1080),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp(
          title: 'POS + ERP System',
          theme: AppTheme.lightTheme,
          debugShowCheckedModeBanner: false,
          
          // เลือกหน้าเริ่มต้นตาม Auth State
          initialRoute: authState.isAuthenticated 
              ? AppRouter.home 
              : AppRouter.login,
          
          onGenerateRoute: AppRouter.generateRoute,
          // ✅ ลบ builder ออก
        );
      },
    );
  }
}