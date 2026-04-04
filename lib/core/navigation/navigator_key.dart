import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// GlobalKey สำหรับ Navigator หลักของแอป
/// ใช้ navigate โดยไม่ต้องมี BuildContext — เช่น จาก authProvider เมื่อ 401
final navigatorKeyProvider = Provider<GlobalKey<NavigatorState>>(
  (_) => GlobalKey<NavigatorState>(),
);
