// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; // ✅ เพิ่ม
import 'package:drift/drift.dart' hide Column;
import 'package:intl/date_symbol_data_local.dart';
import 'core/config/app_mode.dart';
import 'core/navigation/navigator_key.dart';
import 'shared/theme/app_theme.dart';
import 'shared/theme/theme_provider.dart';
import 'routes/app_router.dart';
import 'core/database/app_database.dart';
import 'core/server/api_server.dart';
import 'core/services/master_discovery_service.dart';
import 'core/services/backup/backup_service.dart';
import 'core/utils/crypto_utils.dart';
import 'core/database/seed_data.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('th_TH');
  await BackupService.applyPendingRestoreIfAny();

  // Initialize App Mode
  await AppModeConfig.initialize();

  // เริ่ม Server อัตโนมัติ
  await _startServerInBackground();

  // เริ่มประกาศ/ค้นหา Master ในวง Wi-Fi
  await MasterDiscoveryService.instance.start();

  runApp(
    ProviderScope(
      overrides: [
        if (_dbInstance != null)
          appDatabaseProvider.overrideWithValue(_dbInstance!),
      ],
      child: const MyApp(),
    ),
  );
}

// Global server instance
ApiServer? _serverInstance;
AppDatabase? _dbInstance;

/// เริ่ม Server ใน Background
Future<void> _startServerInBackground() async {
  try {
    print('🔧 Initializing database...');
    _dbInstance = AppDatabase();

    print('👤 Creating default user...');
    await _createDefaultUser(_dbInstance!);

    print('🌱 Seeding initial data...');
    await _seedInitialData(_dbInstance!);

    print('🚀 Starting API server...');
    _serverInstance = ApiServer(_dbInstance!);
    await _serverInstance!.start(port: 8080);

    print('✅ API Server started at http://127.0.0.1:8080');
  } catch (e) {
    print('❌ Failed to start server: $e');
  }
}

/// สร้าง User ทดสอบ
Future<void> _createDefaultUser(AppDatabase db) async {
  try {
    // เช็คว่ามี User แล้วหรือยัง
    final users = await db.select(db.users).get();
    if (users.isNotEmpty) {
      print('✅ Users already exist');
      return;
    }

    // สร้าง Role
    await db
        .into(db.roles)
        .insert(
          RolesCompanion.insert(
            roleId: 'ROLE001',
            roleName: 'Administrator',
            permissions: {
              'sales': {'create': true},
            },
          ),
          mode: InsertMode.insertOrIgnore,
        );

    // สร้าง User
    await db
        .into(db.users)
        .insert(
          UsersCompanion.insert(
            userId: 'USR001',
            username: 'admin',
            passwordHash: CryptoUtils.hashPassword('admin123'),
            fullName: 'ผู้ดูแลระบบ',
            roleId: const Value('ROLE001'),
          ),
          mode: InsertMode.insertOrIgnore,
        );

    print('✅ Default user created (admin/admin123)');
  } catch (e) {
    print('⚠️ Create default user error: $e');
  }
}

/// Seed ข้อมูลเริ่มต้น
Future<void> _seedInitialData(AppDatabase db) async {
  try {
    await SeedData.seedAll(db);
    print('✅ Initial data seeded');
  } catch (e) {
    print('⚠️ Seed data error: $e');
  }
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final fontSettings = ref.watch(fontSettingsProvider);
    final navigatorKey = ref.watch(navigatorKeyProvider);

    return ScreenUtilInit(
      designSize: const Size(1920, 1080),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'POS + ERP System',
          theme: AppTheme.buildLightTheme(fontSettings.fontFamily),
          darkTheme: AppTheme.buildDarkTheme(fontSettings.fontFamily),
          themeMode: themeMode,
          debugShowCheckedModeBanner: false,

          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('th', 'TH'), Locale('en', 'US')],
          locale: const Locale('th', 'TH'),

          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(fontSettings.fontScale),
            ),
            child: child!,
          ),

          initialRoute: AppRouter.root,
          onGenerateRoute: AppRouter.generateRoute,
        );
      },
    );
  }
}
