// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/config/app_mode.dart';
import 'core/config/app_config.dart';
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
import 'core/services/license/time_guard_service.dart';

// ─── Global handles ────────────────────────────────────────────────────────
ApiServer? _serverInstance;
AppDatabase? _dbInstance;
_AppHostState? _appHostState; // set when AppHost mounts
const factoryResetSkipSeedKey = 'factory_reset_skip_seed';
const MethodChannel _masterRuntimeChannel = MethodChannel(
  'pos_erp/master_runtime',
);
bool _isEnsuringRuntime = false;

Future<bool?> getMasterBackgroundHostRunning() async {
  if (!Platform.isAndroid) return null;

  try {
    final result = await _masterRuntimeChannel.invokeMethod<bool>(
      'isMasterHostRunning',
    );
    return result ?? false;
  } catch (e) {
    print('⚠️ [Runtime] Unable to query Android background host status: $e');
    return false;
  }
}

/// Called from settings page after prepareRestore() succeeds.
/// Closes the current DB/server, applies pending restore, reopens everything,
/// then rebuilds the entire ProviderScope so all Riverpod streams reload.
Future<void> applyRestoreInPlace() async {
  print('🔄 [RestoreInPlace] starting…');
  try {
    await _serverInstance?.stop();
    await _dbInstance?.close();
    _dbInstance = null;
    _serverInstance = null;

    final didRestore = await BackupService.applyPendingRestoreIfAny();
    print(
      didRestore
          ? '✅ [RestoreInPlace] files swapped'
          : '⚠️ [RestoreInPlace] no pending restore found',
    );

    _dbInstance = AppDatabase();
    _serverInstance = ApiServer(_dbInstance!);
    await _serverInstance!.start(port: 8080);
    await _syncPlatformMasterRuntime();
    print('✅ [RestoreInPlace] server restarted');

    _appHostState?.rebuild();
  } catch (e) {
    print('❌ [RestoreInPlace] error: $e');
    rethrow;
  }
}

Future<void> factoryResetInPlace({required bool skipSeedAfterReset}) async {
  print('🧨 [FactoryReset] starting…');
  try {
    await _serverInstance?.stop();
    await _dbInstance?.close();
    _dbInstance = null;
    _serverInstance = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await prefs.setBool(factoryResetSkipSeedKey, skipSeedAfterReset);

    final docsDir = await AppDatabase.resolveDocumentsDirectory();
    if (docsDir.existsSync()) {
      await docsDir.delete(recursive: true);
    }
    await docsDir.create(recursive: true);

    await AppModeConfig.initialize();
    await _startServerInBackground(skipSeed: skipSeedAfterReset);
    await _syncPlatformMasterRuntime();
    _appHostState?.rebuild();
    print(
      skipSeedAfterReset
          ? '✅ [FactoryReset] completed with skip seed enabled'
          : '✅ [FactoryReset] completed with seed enabled',
    );
  } catch (e) {
    print('❌ [FactoryReset] error: $e');
    rethrow;
  }
}

// ─── Entry point ───────────────────────────────────────────────────────────
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('th_TH');

  // Diagnostic — shows paths on every cold start
  try {
    final docsDir = await AppDatabase.resolveDocumentsDirectory();
    final dbFile = await AppDatabase.resolveDatabaseFile();
    final backupDir = await AppDatabase.resolveBackupDirectory();
    print('📁 [main] docsDir   : ${docsDir.path}');
    print(
      '📁 [main] dbFile    : ${dbFile.path} (exists: ${dbFile.existsSync()})',
    );
    final pendingDir = Directory('${backupDir.path}/restore_pending');
    print(
      '📁 [main] pendingDir: ${pendingDir.path} (exists: ${pendingDir.existsSync()})',
    );
    if (pendingDir.existsSync()) {
      await for (final f in pendingDir.list(recursive: true)) {
        if (f is File) print('   📄 ${f.path}');
      }
    }
  } catch (e) {
    print('⚠️ [main] diagnostic error: $e');
  }

  // Apply any pending restore from a previous session
  bool didRestore = false;
  try {
    didRestore = await BackupService.applyPendingRestoreIfAny();
    if (didRestore) print('✅ [main] Restore applied from previous session');
  } catch (e) {
    print('❌ [main] Restore failed: $e');
  }

  await AppModeConfig.initialize();
  final prefs = await SharedPreferences.getInstance();
  final skipSeedPref = prefs.getBool(factoryResetSkipSeedKey) ?? false;
  await _startServerInBackground(skipSeed: didRestore || skipSeedPref);
  await MasterDiscoveryService.instance.start();
  await _syncPlatformMasterRuntime();
  // Sync NTP time in background (ป้องกันย้อนนาฬิกา)
  unawaited(TimeGuardService.syncNtpTime());

  runApp(const _AppHost());
}

// ─── Root widget — key-able so ProviderScope rebuilds on restore ────────────
class _AppHost extends StatefulWidget {
  const _AppHost();

  @override
  State<_AppHost> createState() => _AppHostState();
}

class _AppHostState extends State<_AppHost> {
  Key _scopeKey = UniqueKey();
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _appHostState = this;
    _lifecycleListener = AppLifecycleListener(
      onResume: () => unawaited(_handleLifecycleChange(AppLifecycleState.resumed)),
      onInactive: () =>
          unawaited(_handleLifecycleChange(AppLifecycleState.inactive)),
      onHide: () => unawaited(_handleLifecycleChange(AppLifecycleState.hidden)),
      onPause: () => unawaited(_handleLifecycleChange(AppLifecycleState.paused)),
      onDetach: () =>
          unawaited(_handleLifecycleChange(AppLifecycleState.detached)),
    );
    unawaited(_ensureRuntimeForCurrentMode(reason: 'app-host-init'));
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    if (_appHostState == this) _appHostState = null;
    super.dispose();
  }

  Future<void> _handleLifecycleChange(AppLifecycleState state) async {
    print('🔄 [Lifecycle] $state (mode=${AppModeConfig.mode})');

    if (AppModeConfig.isMaster) {
      await _ensureRuntimeForCurrentMode(reason: 'lifecycle:$state');
      return;
    }

    if (state == AppLifecycleState.resumed) {
      await MasterDiscoveryService.instance.refresh();
    }
    await _syncPlatformMasterRuntime();
  }

  /// Flip the key → Flutter tears down and rebuilds the entire ProviderScope,
  /// so every Riverpod provider reads fresh data from the new DB.
  void rebuild() {
    if (mounted) setState(() => _scopeKey = UniqueKey());
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: _scopeKey,
      child: ProviderScope(
        overrides: [
          if (_dbInstance != null)
            appDatabaseProvider.overrideWithValue(_dbInstance!),
        ],
        child: const MyApp(),
      ),
    );
  }
}

// ─── Server / DB init ──────────────────────────────────────────────────────
Future<void> _startServerInBackground({bool skipSeed = false}) async {
  try {
    print('🔧 Initializing database…');
    _dbInstance = AppDatabase();
    await _normalizeLegacyRoleIds(_dbInstance!);

    if (!skipSeed) {
      print('👤 Creating default user…');
      await _createDefaultUser(_dbInstance!);
      print('🌱 Seeding initial data…');
      await _seedInitialData(_dbInstance!);
      await _normalizeLegacyRoleIds(_dbInstance!);
    } else {
      print('⏭️ Skipping seed — restored from backup');
    }

    print('🚀 Starting API server…');
    _serverInstance = ApiServer(_dbInstance!);
    await _serverInstance!.start(port: 8080);
    print('✅ API Server started at http://127.0.0.1:8080');
  } catch (e) {
    print('❌ Failed to start server: $e');
  }
}

Future<void> refreshRuntimeForAppModeChange() async {
  await _ensureRuntimeForCurrentMode(reason: 'mode-change');
}

Future<void> _ensureRuntimeForCurrentMode({required String reason}) async {
  if (_isEnsuringRuntime) {
    print('ℹ️ [Runtime] ensure skipped ($reason) because another run is active');
    return;
  }

  _isEnsuringRuntime = true;
  try {
    print('🔧 [Runtime] ensure start ($reason)');

    if (_dbInstance == null) {
      _dbInstance = AppDatabase();
      print('✅ [Runtime] recreated AppDatabase');
    }

    _serverInstance ??= ApiServer(_dbInstance!);

    if (!_serverInstance!.isRunning) {
      await _serverInstance!.start(port: 8080);
      print('✅ [Runtime] API server ensured');
    }

    await MasterDiscoveryService.instance.refresh();
    await _syncPlatformMasterRuntime();
    print('✅ [Runtime] ensure complete ($reason)');
  } catch (e) {
    print('❌ [Runtime] ensure failed ($reason): $e');
  } finally {
    _isEnsuringRuntime = false;
  }
}

Future<void> _syncPlatformMasterRuntime() async {
  if (!Platform.isAndroid) return;

  try {
    if (AppModeConfig.isMaster) {
      await _masterRuntimeChannel.invokeMethod('startMasterHost', {
        'deviceName': AppModeConfig.deviceName,
      });
    } else {
      await _masterRuntimeChannel.invokeMethod('stopMasterHost');
    }
  } catch (e) {
    print('⚠️ [Runtime] Android background host sync failed: $e');
  }
}

Future<void> _createDefaultUser(AppDatabase db) async {
  try {
    final users = await db.select(db.users).get();
    if (users.isNotEmpty) {
      print('✅ Users already exist');
      return;
    }
    await db
        .into(db.roles)
        .insert(
          RolesCompanion.insert(
            roleId: 'ADMIN',
            roleName: 'ผู้ดูแลระบบ',
            permissions: {
              'sales': <String, dynamic>{'create': true},
            },
          ),
          mode: InsertMode.insertOrIgnore,
        );
    await db
        .into(db.users)
        .insert(
          UsersCompanion.insert(
            userId: 'USR001',
            username: 'admin',
            passwordHash: CryptoUtils.hashPassword('admin123'),
            fullName: 'ผู้ดูแลระบบ',
            roleId: const Value('ADMIN'),
          ),
          mode: InsertMode.insertOrIgnore,
        );
    print('✅ Default user created (admin/admin123)');
  } catch (e) {
    print('⚠️ Create default user error: $e');
  }
}

Future<void> _normalizeLegacyRoleIds(AppDatabase db) async {
  try {
    await db.customStatement('''
      INSERT OR IGNORE INTO roles (role_id, role_name, permissions, created_at)
      VALUES ('ADMIN', 'ผู้ดูแลระบบ', '{}', CURRENT_TIMESTAMP)
    ''');
    await db.customStatement('''
      UPDATE users
      SET role_id = 'ADMIN'
      WHERE UPPER(COALESCE(role_id, '')) IN ('ROLE001', 'ADMINISTRATOR')
    ''');
    await db.customStatement('''
      DELETE FROM roles
      WHERE role_id = 'ROLE001'
        AND NOT EXISTS (
          SELECT 1 FROM users WHERE users.role_id = roles.role_id
        )
    ''');
  } catch (e) {
    print('⚠️ Legacy role normalization error: $e');
  }
}

Future<void> _seedInitialData(AppDatabase db) async {
  try {
    await SeedData.seedAll(db);
    print('✅ Initial data seeded');
  } catch (e) {
    print('⚠️ Seed data error: $e');
  }
}

// ─── App widget ────────────────────────────────────────────────────────────
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
          title: AppConfig.appName,
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
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(fontSettings.fontScale)),
            child: child!,
          ),
          initialRoute: AppRouter.root,
          onGenerateRoute: AppRouter.generateRoute,
        );
      },
    );
  }
}
