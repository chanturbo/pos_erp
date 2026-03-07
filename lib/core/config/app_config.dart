// ignore_for_file: avoid_print

import 'dart:io';
import 'package:flutter/foundation.dart';

class AppConfig {
  // ========================================
  // APP INFORMATION
  // ========================================
  
  static const appName = 'POS + ERP System';
  static const appVersion = '1.0.0';
  static const companyName = 'Your Company';
  
  // ========================================
  // API BASE URL - Auto Detect Platform
  // ========================================
  
  /// API Base URL - เปลี่ยนตาม platform อัตโนมัติ
  static String get apiBaseUrl {
    if (kIsWeb) {
      // Web: ใช้ localhost
      return 'http://127.0.0.1:$defaultServerPort';
    } else if (Platform.isAndroid) {
      // Android Emulator: ใช้ 10.0.2.2
      // Android Real Device: ใช้ IP จริงของเครื่อง Mac
      return _isEmulator 
          ? 'http://10.0.2.2:$defaultServerPort' 
          : 'http://192.168.1.100:$defaultServerPort';
    } else if (Platform.isIOS) {
      // iOS Simulator: ใช้ localhost
      // iOS Real Device: ใช้ IP จริงของเครื่อง Mac
      return _isEmulator 
          ? 'http://127.0.0.1:$defaultServerPort' 
          : 'http://192.168.1.100:$defaultServerPort';
    } else {
      // macOS, Windows, Linux: ใช้ localhost
      return 'http://127.0.0.1:$defaultServerPort';
    }
  }
  
  /// ตรวจสอบว่าเป็น Emulator/Simulator หรือไม่
  /// 
  /// ⚠️ สำหรับการใช้งาน:
  /// - true = ทดสอบบน Emulator/Simulator (ใช้ 10.0.2.2 หรือ 127.0.0.1)
  /// - false = ทดสอบบนเครื่องจริง (ใช้ IP ของเครื่อง Mac)
  static bool get _isEmulator {
    return true; // ⚠️ เปลี่ยนเป็น false เมื่อทดสอบบนมือถือจริง
  }
  
  // ========================================
  // SERVER CONFIGURATION
  // ========================================
  
  static const defaultServerPort = 8080;
  static const webSocketPath = '/ws';
  
  // ========================================
  // ENVIRONMENT MODE (สำหรับ Production)
  // ========================================
  
  /// Environment Mode
  /// - development: ใช้ localhost
  /// - staging: ใช้ staging server
  /// - production: ใช้ production server
  static const String _environment = 'development';
  
  /// API Base URL แบบแยก Environment
  static String get apiBaseUrlByEnv {
    switch (_environment) {
      case 'development':
        return kIsWeb 
            ? 'http://127.0.0.1:$defaultServerPort'
            : Platform.isAndroid
                ? 'http://10.0.2.2:$defaultServerPort'  // Android Emulator
                : 'http://127.0.0.1:$defaultServerPort'; // iOS Simulator or macOS
      case 'staging':
        return 'https://staging-api.yourcompany.com';
      case 'production':
        return 'https://api.yourcompany.com';
      default:
        return 'http://127.0.0.1:$defaultServerPort';
    }
  }
  
  // ========================================
  // NETWORK CONFIGURATION
  // ========================================
  
  /// Timeout Configuration
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 10);
  
  // ========================================
  // DATABASE CONFIGURATION
  // ========================================
  
  static const databaseName = 'pos_erp.db';
  static const databaseVersion = 1;
  
  // ========================================
  // PAGINATION CONFIGURATION
  // ========================================
  
  static const defaultPageSize = 20;
  
  // ========================================
  // SESSION CONFIGURATION
  // ========================================
  
  static const sessionTimeout = Duration(hours: 8);
  
  // ========================================
  // HELPER METHODS
  // ========================================
  
  /// WebSocket URL
  static String get webSocketUrl {
    final host = apiBaseUrl.replaceAll('http://', '').replaceAll('https://', '');
    final protocol = apiBaseUrl.startsWith('https') ? 'wss' : 'ws';
    return '$protocol://$host$webSocketPath';
  }
  
  /// แสดง IP Address ของเครื่อง (สำหรับ Debug)
  static Future<String> getLocalIP() async {
    try {
      final interfaces = await NetworkInterface.list();
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          // หา IPv4 ที่ไม่ใช่ loopback
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            print('📡 Local IP: ${addr.address}');
            return addr.address;
          }
        }
      }
    } catch (e) {
      print('❌ Error getting IP: $e');
    }
    return '127.0.0.1';
  }
  
  /// แสดงข้อมูล Configuration ปัจจุบัน (สำหรับ Debug)
  static void printConfig() {
    print('========================================');
    print('📱 APP CONFIGURATION');
    print('========================================');
    print('App Name: $appName');
    print('Version: $appVersion');
    print('Environment: $_environment');
    print('Platform: ${_getPlatformName()}');
    print('Is Emulator: $_isEmulator');
    print('========================================');
    print('🌐 NETWORK');
    print('========================================');
    print('API Base URL: $apiBaseUrl');
    print('WebSocket URL: $webSocketUrl');
    print('Server Port: $defaultServerPort');
    print('========================================');
    print('💾 DATABASE');
    print('========================================');
    print('Database Name: $databaseName');
    print('Database Version: $databaseVersion');
    print('========================================');
    print('⚙️ OTHER');
    print('========================================');
    print('Page Size: $defaultPageSize');
    print('Session Timeout: ${sessionTimeout.inHours} hours');
    print('========================================');
  }
  
  /// ดึงชื่อ Platform
  static String _getPlatformName() {
    if (kIsWeb) return 'Web';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isLinux) return 'Linux';
    return 'Unknown';
  }
}