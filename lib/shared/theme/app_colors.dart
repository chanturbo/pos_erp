// lib/shared/theme/app_colors.dart
//
// 🎨 Centralized color palette — ใช้ร่วมกันทุก module
//
// วิธีใช้งาน:
//   import 'package:your_app/shared/theme/app_colors.dart';
//
//   Container(color: AppColors.primary)
//   Text('hello', style: TextStyle(color: AppColors.textSub))

import 'package:flutter/material.dart';

class AppColors {
  AppColors._(); // prevent instantiation

  // ── Brand ────────────────────────────────────────────────────
  /// สีส้มหลัก #E8622A
  static const Color primary      = Color(0xFFE8622A);
  /// สีส้มเข้มกว่าเล็กน้อย #E57200 (ใช้ใน product_list highlight)
  static const Color primaryDark  = Color(0xFFE57200);
  /// พื้นหลังส้มอ่อน #FFF3EE
  static const Color primaryLight = Color(0xFFFFF3EE);

  // ── Navy ─────────────────────────────────────────────────────
  /// Navy header / dark text #16213E
  static const Color navy         = Color(0xFF16213E);

  // ── Neutral ──────────────────────────────────────────────────
  /// เส้นขอบ #E8E8E8
  static const Color border       = Color(0xFFE8E8E8);
  /// เส้นขอบเข้มกว่า (ใช้ใน product table) #E0E0E0
  static const Color borderDark   = Color(0xFFE0E0E0);
  /// พื้นหลัง header แถว #F9F9F9
  static const Color headerBg     = Color(0xFFF9F9F9);
  /// พื้นหลัง surface อ่อน #F4F4F0
  static const Color surface      = Color(0xFFF4F4F0);
  /// ข้อความรอง #8A8A8A
  static const Color textSub      = Color(0xFF8A8A8A);

  // ── Semantic ─────────────────────────────────────────────────
  /// สีเขียว สำเร็จ / ใช้งาน #2E7D32
  static const Color success      = Color(0xFF2E7D32);
  /// พื้นหลังเขียวอ่อน #E8F5E9
  static const Color successBg    = Color(0xFFE8F5E9);
  /// สีแดง error / ปิดใช้งาน #C62828
  static const Color error        = Color(0xFFC62828);
  /// พื้นหลังแดงอ่อน #FFEBEE
  static const Color errorBg      = Color(0xFFFFEBEE);
  /// สีน้ำเงิน info #1565C0
  static const Color info         = Color(0xFF1565C0);
  /// พื้นหลังน้ำเงินอ่อน #E3F2FD
  static const Color infoBg       = Color(0xFFE3F2FD);
  /// สีเหลืองทอง สมาชิก #FFB300
  static const Color amber        = Color(0xFFFFB300);
  /// พื้นหลังเหลืองอ่อน #FFF8E1
  static const Color amberBg      = Color(0xFFFFF8E1);

  // ── Dark Mode Surface ─────────────────────────────────────────
  /// พื้นหลัง dark mode #1A1A1A
  static const Color darkBg       = Color(0xFF1A1A1A);
  /// Card dark mode #252525
  static const Color darkCard     = Color(0xFF252525);
  /// Element dark mode #2A2A2A
  static const Color darkElement  = Color(0xFF2A2A2A);
  /// Top bar dark mode #1E1E1E
  static const Color darkTopBar   = Color(0xFF1E1E1E);
}