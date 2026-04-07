import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

enum AppMode {
  standalone,  // ใช้งานเครื่องเดียว
  master,      // เครื่องหลัก
  clientPOS,   // เครื่องขาย
  clientMobile // มือถือ
}

class AppModeConfig {
  static AppMode? _currentMode;
  static String? _masterIp;
  static String? _masterName;
  static String? _deviceName;
  static int _masterPort = 8080;
  
  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final modeStr = prefs.getString('app_mode');
    
    if (modeStr != null) {
      _currentMode = AppMode.values.firstWhere(
        (e) => e.toString() == modeStr,
      );
      _masterIp = prefs.getString('master_ip');
      _masterName = prefs.getString('master_name');
      _masterPort = prefs.getInt('master_port') ?? 8080;
    } else {
      _currentMode = AppMode.standalone;
      await prefs.setString('app_mode', AppMode.standalone.toString());
    }

    _deviceName = prefs.getString('device_name');
    if (_deviceName == null || _deviceName!.trim().isEmpty) {
      _deviceName = Platform.localHostname.trim();
      await prefs.setString('device_name', _deviceName!);
    }
  }
  
  static AppMode? get mode => _currentMode;
  static bool get isStandalone => _currentMode == AppMode.standalone;
  static bool get isMaster => _currentMode == AppMode.master;
  static bool get isClient =>
      _currentMode == AppMode.clientPOS || _currentMode == AppMode.clientMobile;
  static String? get masterIp => _masterIp;
  static String? get masterName => _masterName;
  static int get masterPort => _masterPort;
  static String get deviceName => _deviceName ?? Platform.localHostname;

  static Future<void> setMode(
    AppMode mode, {
    String? masterIp,
    String? masterName,
    int? masterPort,
    String? deviceName,
  }) async {
    _currentMode = mode;
    _masterIp = masterIp;
    _masterName = masterName;
    _masterPort = masterPort ?? _masterPort;
    if (deviceName != null && deviceName.trim().isNotEmpty) {
      _deviceName = deviceName.trim();
    }
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_mode', mode.toString());
    if (masterIp != null) {
      await prefs.setString('master_ip', masterIp);
    } else {
      await prefs.remove('master_ip');
    }
    if (masterName != null) {
      await prefs.setString('master_name', masterName);
    } else {
      await prefs.remove('master_name');
    }
    await prefs.setInt('master_port', _masterPort);
    if (_deviceName != null) {
      await prefs.setString('device_name', _deviceName!);
    }
  }

  static Future<void> setDeviceName(String deviceName) async {
    final value = deviceName.trim();
    if (value.isEmpty) return;

    _deviceName = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('device_name', value);
  }

  static Future<void> setMasterConnection({
    required String masterIp,
    required String masterName,
    int masterPort = 8080,
  }) async {
    _masterIp = masterIp;
    _masterName = masterName;
    _masterPort = masterPort;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('master_ip', masterIp);
    await prefs.setString('master_name', masterName);
    await prefs.setInt('master_port', masterPort);
  }

  static Future<void> clearMasterConnection() async {
    _masterIp = null;
    _masterName = null;
    _masterPort = 8080;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('master_ip');
    await prefs.remove('master_name');
    await prefs.remove('master_port');
  }
  
  static Future<void> clear() async {
    _currentMode = null;
    _masterIp = null;
    _masterName = null;
    _masterPort = 8080;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('app_mode');
    await prefs.remove('master_ip');
    await prefs.remove('master_name');
    await prefs.remove('master_port');
  }
}
