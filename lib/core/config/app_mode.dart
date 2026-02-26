import 'package:shared_preferences/shared_preferences.dart';

enum AppMode {
  master,      // เครื่องหลัก
  clientPOS,   // เครื่องขาย
  clientMobile // มือถือ
}

class AppModeConfig {
  static AppMode? _currentMode;
  static String? _masterIp;
  
  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final modeStr = prefs.getString('app_mode');
    
    if (modeStr != null) {
      _currentMode = AppMode.values.firstWhere(
        (e) => e.toString() == modeStr,
      );
      _masterIp = prefs.getString('master_ip');
    }
  }
  
  static AppMode? get mode => _currentMode;
  static bool get isMaster => _currentMode == AppMode.master;
  static bool get isClient => _currentMode != null && !isMaster;
  static String? get masterIp => _masterIp;
  
  static Future<void> setMode(AppMode mode, {String? masterIp}) async {
    _currentMode = mode;
    _masterIp = masterIp;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_mode', mode.toString());
    if (masterIp != null) {
      await prefs.setString('master_ip', masterIp);
    }
  }
  
  static Future<void> clear() async {
    _currentMode = null;
    _masterIp = null;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('app_mode');
    await prefs.remove('master_ip');
  }
}