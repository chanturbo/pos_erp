// ignore_for_file: avoid_print

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'app_mode.dart';

// ─────────────────────────────────────────
// Environment Enum
// ─────────────────────────────────────────
enum Environment { development, staging, production }

class AppConfig {
  AppConfig._();

  // ========================================
  // APP INFORMATION
  // ========================================

  static const String appName = 'DEE POS';
  static const String appVersion = '1.0.0';
  static const int buildNumber = 1;
  static const String companyName = '';

  // ========================================
  // ENVIRONMENT
  // ✅ เปลี่ยนเป็น production ก่อน build release
  // ========================================

  static const Environment _env = Environment.development;

  static bool get isDevelopment => _env == Environment.development;
  static bool get isStaging => _env == Environment.staging;
  static bool get isProduction => _env == Environment.production;

  // ✅ ซ่อน debug info ใน production
  static bool get showDebugBanner => isDevelopment;
  static bool get enableLogging => !isProduction;
  static bool get enableSeeding => isDevelopment; // seed data เฉพาะ dev

  // ========================================
  // SERVER CONFIGURATION
  // ========================================

  static const int defaultServerPort = 8080;
  static const String webSocketPath = '/ws';

  // Timeout
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // ========================================
  // API BASE URL
  // auto-detect platform + environment
  // ========================================

  static String get apiBaseUrl => resolveApiBaseUrl();

  static String resolveApiBaseUrl() {
    final masterIp = AppModeConfig.masterIp?.trim();
    final masterPort = AppModeConfig.masterPort;

    if (AppModeConfig.isStandalone) {
      if (kIsWeb) {
        return 'http://127.0.0.1:$defaultServerPort';
      }
      return 'http://127.0.0.1:$defaultServerPort';
    }

    if (AppModeConfig.isClient && masterIp != null && masterIp.isNotEmpty) {
      return 'http://$masterIp:$masterPort';
    }

    // Production / Staging — ใช้ remote server
    if (isProduction) {
      return 'https://api.yourcompany.com';
    }

    if (isStaging) {
      return 'https://staging-api.yourcompany.com';
    }

    // Development — localhost ตาม platform
    if (kIsWeb) {
      return 'http://127.0.0.1:$defaultServerPort';
    }

    if (Platform.isAndroid) {
      return _isEmulator
          ? 'http://10.0.2.2:$defaultServerPort'
          : 'http://$_localNetworkIp:$defaultServerPort';
    }

    if (Platform.isIOS) {
      return _isEmulator
          ? 'http://127.0.0.1:$defaultServerPort'
          : 'http://$_localNetworkIp:$defaultServerPort';
    }

    return 'http://127.0.0.1:$defaultServerPort';
  }

  /// WebSocket URL (derived from apiBaseUrl)
  static String get webSocketUrl {
    final host = apiBaseUrl.replaceAll(RegExp(r'https?://'), '');
    final protocol = apiBaseUrl.startsWith('https') ? 'wss' : 'ws';
    return '$protocol://$host$webSocketPath';
  }

  // ─── Emulator / Real device ───────────
  /// ⚠️ เปลี่ยนเป็น false เมื่อทดสอบบนมือถือจริง
  static bool get _isEmulator => isDevelopment;

  /// IP ของเครื่อง dev สำหรับ real device
  /// เปลี่ยนเป็น IP จริงของเครื่อง Mac/PC ที่รัน server
  static String get _localNetworkIp => '192.168.1.100';

  // ========================================
  // DATABASE CONFIGURATION
  // ========================================

  static const String databaseName = 'pos_erp.db';
  static const int databaseVersion = 1;

  /// ที่เก็บ database แยกตาม platform
  static String get databaseDescription {
    if (kIsWeb) return 'IndexedDB (browser)';
    if (Platform.isAndroid) {
      return '/data/data/<package>/databases/$databaseName';
    }
    if (Platform.isIOS) return 'Documents/$databaseName';
    if (Platform.isMacOS) {
      return '~/Library/Application Support/<bundle>/$databaseName';
    }
    if (Platform.isWindows) return '%APPDATA%\\pos_erp\\$databaseName';
    return databaseName;
  }

  // ========================================
  // PAGINATION & SESSION
  // ========================================

  static const int defaultPageSize = 20;
  static const Duration sessionTimeout = Duration(hours: 8);

  // ========================================
  // FEATURE FLAGS
  // ตั้งค่า feature ที่จะเปิด/ปิด per environment
  // ========================================

  static bool get enableBarcodeScanner => true;
  static bool get enableOfflineSync => true;
  static bool get enableMultiBranch => true;
  static bool get enableRestaurantMode => false;
  static bool get showTestingTools => isDevelopment;
  static bool get enableDarkMode => true;

  // ========================================
  // PERFORMANCE LIMITS (production-safe)
  // ========================================

  static const int maxProductsInMemory = 5000;
  static const int maxCustomersInMemory = 2000;
  static const int maxOrdersPerPage = 50;
  static const int searchDebounceMs = 300;

  // ========================================
  // HELPER METHODS
  // ========================================

  /// ดึง Local IP ของเครื่อง (สำหรับ QR setup mobile client)
  static Future<String> getLocalIP() async {
    try {
      final interfaces = await NetworkInterface.list();
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            return addr.address;
          }
        }
      }
    } catch (e) {
      if (enableLogging) print('❌ Error getting IP: $e');
    }
    return '127.0.0.1';
  }

  /// แสดง config ปัจจุบัน (debug เท่านั้น)
  static void printConfig() {
    if (!enableLogging) return;
    print('════════════════════════════════════');
    print('📱 APP CONFIG');
    print('  Name:        $appName v$appVersion ($buildNumber)');
    print('  Environment: ${_env.name.toUpperCase()}');
    print('  Platform:    ${_platformName()}');
    print('  Is Emulator: $_isEmulator');
    print('────────────────────────────────────');
    print('🌐 NETWORK');
    print('  API URL:     $apiBaseUrl');
    print('  WS URL:      $webSocketUrl');
    print('  Port:        $defaultServerPort');
    print('────────────────────────────────────');
    print('💾 DATABASE');
    print('  Name:        $databaseName (v$databaseVersion)');
    print('  Location:    $databaseDescription');
    print('────────────────────────────────────');
    print('🚩 FEATURE FLAGS');
    print('  Scanner:     $enableBarcodeScanner');
    print('  Offline:     $enableOfflineSync');
    print('  Multi-branch:$enableMultiBranch');
    print('  Restaurant:  $enableRestaurantMode');
    print('  Dark Mode:   $enableDarkMode');
    print('════════════════════════════════════');
  }

  static String _platformName() {
    if (kIsWeb) return 'Web';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isLinux) return 'Linux';
    return 'Unknown';
  }
}
