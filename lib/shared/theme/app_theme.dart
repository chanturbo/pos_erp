import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ╔══════════════════════════════════════════════════════════════════╗
/// ║              OAG Identity System — Design Tokens                 ║
/// ╠══════════════════════════════════════════════════════════════════╣
/// ║  01 · Primary    #E57200  OAG Orange                            ║
/// ║  02 · Sidebar    #16213E  Navy                                  ║
/// ║  03 · Success    #2E7D32  Green  → Paid / Completed             ║
/// ║  04 · Error      #C62828  Red    → Overdue / Failed             ║
/// ║  05 · Warning    #F9A825  Yellow → Pending / Low Stock          ║
/// ║  06 · Info       #1565C0  Blue   → Draft / In Progress          ║
/// ║  07 · Surface    #F4F4F0  Neutral Background                    ║
/// ║  08 · Font       IBM Plex Sans Thai → Sarabun (fallback)        ║
/// ╚══════════════════════════════════════════════════════════════════╝
class AppTheme {
  AppTheme._();

  // ─────────────────────────────────────────────────────────────────
  // 01 · Brand Colors
  // ─────────────────────────────────────────────────────────────────

  /// OAG Orange — Primary action / active state / brand identity
  static const Color primaryColor       = Color(0xFFE57200);
  static const Color primaryLight       = Color(0xFFFF9D45);
  static const Color primaryDark        = Color(0xFFAC4F00);
  static const Color primaryContainer   = Color(0xFFFFE0C2);
  static const Color onPrimaryContainer = Color(0xFF4A1900);

  /// Navy — Sidebar / Navigation / AppBar
  static const Color navyColor          = Color(0xFF16213E);
  static const Color navyLight          = Color(0xFF1F2E54);
  static const Color navyDark           = Color(0xFF0D1528);
  static const Color navyBorder         = Color(0xFF2A3A60);

  // ─────────────────────────────────────────────────────────────────
  // 02 · Semantic Colors
  // ─────────────────────────────────────────────────────────────────

  /// Success — เขียว (Paid, Completed, Stock OK)
  static const Color successColor       = Color(0xFF2E7D32);
  static const Color successLight       = Color(0xFF60AD5E);
  static const Color successContainer   = Color(0xFFB9F6CA);

  /// Error — แดง (Overdue, Error, Out of Stock)
  static const Color errorColor         = Color(0xFFC62828);
  static const Color errorLight         = Color(0xFFEF5350);
  static const Color errorContainer     = Color(0xFFFFCDD2);

  /// Warning — เหลือง (Partial, Pending, Low Stock)
  static const Color warningColor       = Color(0xFFF9A825);
  static const Color warningLight       = Color(0xFFFFD54F);
  static const Color warningContainer   = Color(0xFFFFF8E1);

  /// Info — น้ำเงิน (Draft, In Progress)
  static const Color infoColor          = Color(0xFF1565C0);
  static const Color infoLight          = Color(0xFF5E92F3);
  static const Color infoContainer      = Color(0xFFE3F2FD);

  /// Supplementary — ใช้ตามโมดูล
  static const Color purpleColor        = Color(0xFF6A1B9A); // AP/AR บัญชี
  static const Color tealColor          = Color(0xFF00695C); // Payment
  static const Color brownColor         = Color(0xFF4E342E); // เอกสาร/Invoice

  // ─────────────────────────────────────────────────────────────────
  // 03 · Neutral / Surface
  // ─────────────────────────────────────────────────────────────────

  static const Color surfaceColor       = Color(0xFFF4F4F0); // Neutral Background
  static const Color cardWhite          = Color(0xFFFFFFFF);
  static const Color borderColor        = Color(0xFFE0E0E0);
  static const Color subtextColor       = Color(0xFF757575);

  // ─────────────────────────────────────────────────────────────────
  // 04 · Typography helper — IBM Plex Sans Thai → Sarabun fallback
  // ─────────────────────────────────────────────────────────────────

  static TextTheme _buildTextTheme(TextTheme base) =>
      GoogleFonts.ibmPlexSansThaiTextTheme(base);

  // ─────────────────────────────────────────────────────────────────
  // 05 · Light Theme
  // ─────────────────────────────────────────────────────────────────
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
    ).copyWith(
      primary: primaryColor,
      onPrimary: Colors.white,
      primaryContainer: primaryContainer,
      onPrimaryContainer: onPrimaryContainer,
      secondary: navyColor,
      onSecondary: Colors.white,
      error: errorColor,
      surface: cardWhite,
      onSurface: const Color(0xFF1A1A1A),
    ),
    scaffoldBackgroundColor: surfaceColor,
    textTheme: _buildTextTheme(ThemeData.light().textTheme),
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 1,
      backgroundColor: navyColor,           // ← Navy AppBar
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      iconTheme: IconThemeData(color: Colors.white),
      actionsIconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: cardWhite,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: borderColor),
      ),
    ),
    drawerTheme: const DrawerThemeData(
      backgroundColor: navyColor,           // ← Navy Sidebar/Drawer
      surfaceTintColor: Colors.transparent,
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: navyColor,           // ← Navy Navigation Rail
      selectedIconTheme: const IconThemeData(color: primaryColor),
      unselectedIconTheme: const IconThemeData(color: Color(0xFF8A9BC0)),
      selectedLabelTextStyle: const TextStyle(
        color: primaryColor,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelTextStyle: const TextStyle(color: Color(0xFF8A9BC0)),
      indicatorColor: primaryColor.withValues(alpha: 0.18),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: primaryColor, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      filled: true,
      fillColor: Colors.grey.shade50,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,     // ← Primary Button = Orange
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryColor,     // ← Secondary Button = Outlined Orange
        side: const BorderSide(color: primaryColor),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: primaryColor),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    dividerTheme: const DividerThemeData(color: borderColor, space: 1),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? primaryColor
            : Colors.grey.shade400,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? primaryColor.withValues(alpha: 0.4)
            : Colors.grey.shade300,
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      surfaceTintColor: Colors.transparent,
      backgroundColor: cardWhite,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: cardWhite,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: borderColor),
      ),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: primaryColor,
      unselectedLabelColor: subtextColor,
      indicatorColor: primaryColor,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      elevation: 2,
    ),
  );

  // ─────────────────────────────────────────────────────────────────
  // 06 · Dark Theme
  // ─────────────────────────────────────────────────────────────────
  static const _darkBg       = Color(0xFF121212);
  static const _darkSurface  = Color(0xFF1E1E1E);
  static const _darkSurface2 = Color(0xFF2A2A2A);
  static const _darkBorder   = Color(0xFF333333);
  static const _darkText     = Color(0xFFE0E0E0);
  static const _darkSubtext  = Color(0xFF9E9E9E);

  /// Dark mode: ใช้ primaryLight (#FF9D45) เพื่อ contrast บน dark bg
  static const _darkPrimary  = Color(0xFFFF9D45);

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.dark,
    ).copyWith(
      primary: _darkPrimary,
      onPrimary: const Color(0xFF4A1900),
      secondary: const Color(0xFF8A9BC0),
      surface: _darkSurface,
      onSurface: _darkText,
      error: const Color(0xFFEF9A9A),
    ),
    textTheme: _buildTextTheme(ThemeData.dark().textTheme)
        .apply(bodyColor: _darkText, displayColor: _darkText),
    scaffoldBackgroundColor: _darkBg,
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 1,
      backgroundColor: navyDark,           // ← Darker Navy for dark mode
      foregroundColor: _darkText,
      surfaceTintColor: Colors.transparent,
      iconTheme: IconThemeData(color: _darkText),
      actionsIconTheme: IconThemeData(color: _darkText),
      titleTextStyle: TextStyle(
        color: _darkText,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: _darkSurface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: _darkBorder),
      ),
    ),
    drawerTheme: const DrawerThemeData(
      backgroundColor: navyDark,
      surfaceTintColor: Colors.transparent,
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: navyDark,
      selectedIconTheme: IconThemeData(color: _darkPrimary),
      unselectedIconTheme: IconThemeData(color: _darkSubtext),
      indicatorColor: Color(0x33FF9D45),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _darkBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _darkBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _darkPrimary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      filled: true,
      fillColor: _darkSurface2,
      labelStyle: const TextStyle(color: _darkSubtext),
      hintStyle: const TextStyle(color: _darkSubtext),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _darkPrimary,
        foregroundColor: const Color(0xFF4A1900),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: _darkPrimary,
        side: const BorderSide(color: _darkPrimary),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: _darkPrimary),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: _darkSurface2,
      selectedColor: _darkPrimary.withValues(alpha: 0.25),
      labelStyle: const TextStyle(color: _darkText),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: const BorderSide(color: _darkBorder),
    ),
    dividerTheme: const DividerThemeData(color: _darkBorder, space: 1),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16),
      textColor: _darkText,
      iconColor: _darkSubtext,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? _darkPrimary : _darkSubtext,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? _darkPrimary.withValues(alpha: 0.4)
            : _darkSurface2,
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? _darkPrimary
            : Colors.transparent,
      ),
      checkColor: WidgetStateProperty.all(const Color(0xFF4A1900)),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? _darkPrimary : _darkSubtext,
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: _darkSurface2,
      contentTextStyle: TextStyle(color: _darkText),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      surfaceTintColor: Colors.transparent,
      backgroundColor: _darkSurface,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: _darkSurface,
      surfaceTintColor: Colors.transparent,
    ),
    popupMenuTheme: const PopupMenuThemeData(
      color: _darkSurface2,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        side: BorderSide(color: _darkBorder),
      ),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: _darkPrimary,
      unselectedLabelColor: _darkSubtext,
      indicatorColor: _darkPrimary,
    ),
    dataTableTheme: const DataTableThemeData(
      headingTextStyle:
          TextStyle(color: _darkText, fontWeight: FontWeight.bold),
      dataTextStyle: TextStyle(color: _darkText),
      headingRowColor: WidgetStatePropertyAll(_darkSurface2),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: _darkPrimary,
      foregroundColor: Color(0xFF4A1900),
      elevation: 2,
    ),
    progressIndicatorTheme:
        const ProgressIndicatorThemeData(color: _darkPrimary),
    iconTheme: const IconThemeData(color: _darkSubtext),
    primaryIconTheme: const IconThemeData(color: _darkText),
  );

  // ─────────────────────────────────────────────────────────────────
  // 07 · Context-aware Helpers (รักษา API เดิม)
  // ─────────────────────────────────────────────────────────────────

  static Color cardColor(BuildContext context) =>
      isDark(context) ? _darkSurface : cardWhite;

  static Color surfaceColorOf(BuildContext context) =>
      isDark(context) ? _darkSurface2 : Colors.grey.shade50;

  static Color borderColorOf(BuildContext context) =>
      isDark(context) ? _darkBorder : borderColor;

  static Color subtextColorOf(BuildContext context) =>
      isDark(context) ? _darkSubtext : subtextColor;

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;
}