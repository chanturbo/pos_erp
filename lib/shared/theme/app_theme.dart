import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ─────────────────────────────────────────
  // Brand Colors
  // ─────────────────────────────────────────
  static const primaryColor = Color(0xFF2196F3);
  static const secondaryColor = Color(0xFF03A9F4);
  static const errorColor = Color(0xFFF44336);
  static const successColor = Color(0xFF4CAF50);
  static const warningColor = Color(0xFFFF9800);

  // ─────────────────────────────────────────
  // Light Theme
  // ─────────────────────────────────────────
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
    ),
    textTheme: GoogleFonts.promptTextTheme(ThemeData.light().textTheme),
    scaffoldBackgroundColor: const Color(0xFFF5F5F5),
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 1,
      backgroundColor: Colors.white,
      foregroundColor: Color(0xFF1A1A1A),
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
    ),
    drawerTheme: const DrawerThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: Colors.white,
      selectedIconTheme: const IconThemeData(color: primaryColor),
      unselectedIconTheme: IconThemeData(color: Colors.grey.shade600),
      indicatorColor: primaryColor.withValues(alpha: 0.12),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      filled: true,
      fillColor: Colors.grey.shade50,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    dividerTheme: DividerThemeData(color: Colors.grey.shade200, space: 1),
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
      backgroundColor: Colors.white,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade200),
      ),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: primaryColor,
      unselectedLabelColor: Color(0xFF757575),
      indicatorColor: primaryColor,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      elevation: 2,
    ),
  );

  // ─────────────────────────────────────────
  // Dark Theme
  // ─────────────────────────────────────────
  static const _darkBg = Color(0xFF121212);
  static const _darkSurface = Color(0xFF1E1E1E);
  static const _darkSurface2 = Color(0xFF2A2A2A);
  static const _darkBorder = Color(0xFF333333);
  static const _darkText = Color(0xFFE0E0E0);
  static const _darkSubtext = Color(0xFF9E9E9E);
  static const _darkPrimary = Color(0xFF64B5F6); // lighter blue for dark bg

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme:
        ColorScheme.fromSeed(
          seedColor: primaryColor,
          brightness: Brightness.dark,
        ).copyWith(
          primary: _darkPrimary,
          onPrimary: const Color(0xFF003366),
          secondary: const Color(0xFF4FC3F7),
          surface: _darkSurface,
          onSurface: _darkText,
          error: const Color(0xFFEF9A9A),
        ),
    textTheme: GoogleFonts.promptTextTheme(
      ThemeData.dark().textTheme,
    ).apply(bodyColor: _darkText, displayColor: _darkText),
    scaffoldBackgroundColor: _darkBg,
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 1,
      backgroundColor: _darkSurface,
      foregroundColor: _darkText,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
    ),
    drawerTheme: const DrawerThemeData(
      backgroundColor: _darkSurface,
      surfaceTintColor: Colors.transparent,
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: _darkSurface,
      selectedIconTheme: IconThemeData(color: _darkPrimary),
      unselectedIconTheme: IconThemeData(color: _darkSubtext),
      indicatorColor: Color(0x2264B5F6),
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
        foregroundColor: const Color(0xFF003366),
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
      checkColor: WidgetStateProperty.all(const Color(0xFF003366)),
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
      backgroundColor: Colors.white,
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
      labelColor: primaryColor,
      unselectedLabelColor: Color(0xFF757575),
      indicatorColor: primaryColor,
    ),
    dataTableTheme: const DataTableThemeData(
      headingTextStyle: TextStyle(
        color: _darkText,
        fontWeight: FontWeight.bold,
      ),
      dataTextStyle: TextStyle(color: _darkText),
      headingRowColor: WidgetStatePropertyAll(_darkSurface2),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: _darkPrimary,
      foregroundColor: Color(0xFF003366),
      elevation: 2,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: _darkPrimary,
    ),
    iconTheme: const IconThemeData(color: _darkSubtext),
    primaryIconTheme: const IconThemeData(color: _darkText),
  );

  // ─────────────────────────────────────────
  // Helper: สีตาม brightness
  // ─────────────────────────────────────────
  static Color cardColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? _darkSurface
      : Colors.white;

  static Color surfaceColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? _darkSurface2
      : Colors.grey.shade50;

  static Color borderColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? _darkBorder
      : Colors.grey.shade200;

  static Color subtextColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? _darkSubtext
      : Colors.grey.shade600;

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;
}
