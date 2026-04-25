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
///
/// AppColors has been merged into AppTheme.
/// Migration mapping:
///   AppColors.primary        → AppTheme.primaryColor  (or AppTheme.primary)
///   AppColors.primaryDark    → AppTheme.primaryDark
///   AppColors.primaryLight   → AppTheme.primaryContainer
///   AppColors.navy           → AppTheme.navyColor      (or AppTheme.navy)
///   AppColors.border         → AppTheme.borderColor    (or AppTheme.border)
///   AppColors.borderDark     → AppTheme.borderColor    (or AppTheme.border)
///   AppColors.surface        → AppTheme.surfaceColor   (or AppTheme.surface)
///   AppColors.textSub        → AppTheme.subtextColor   (or AppTheme.textSub)
///   AppColors.success        → AppTheme.successColor   (or AppTheme.success)
///   AppColors.successBg      → AppTheme.successContainer
///   AppColors.error          → AppTheme.errorColor     (or AppTheme.error)
///   AppColors.errorBg        → AppTheme.errorContainer
///   AppColors.info           → AppTheme.infoColor      (or AppTheme.info)
///   AppColors.infoBg         → AppTheme.infoContainer
///   AppColors.amber          → AppTheme.warningColor   (or AppTheme.warning)
///   AppColors.amberBg        → AppTheme.warningContainer
///   AppColors.headerBg       → AppTheme.headerBg
///   AppColors.darkBg         → AppTheme.darkBg
///   AppColors.darkCard       → AppTheme.darkCard
///   AppColors.darkElement    → AppTheme.darkElement
///   AppColors.darkTopBar     → AppTheme.darkTopBar

/// ─────────────────────────────────────────────────────────────────
/// Border Radius Design Tokens
///   xs   =  4  (tiny badges, progress indicators)
///   sm   =  8  (inputs, buttons, small containers)
///   md   = 12  (cards, panels, list tiles)
///   lg   = 16  (dialogs, bottom sheets, modals)
///   xl   = 20  (category chips, pill tabs)
///   pill = 999 (fully-rounded status badges, avatars)
/// ─────────────────────────────────────────────────────────────────
class AppRadius {
  AppRadius._();

  static const double _xs   =  4;
  static const double _sm   =  8;
  static const double _md   = 12;
  static const double _lg   = 16;
  static const double _xl   = 20;
  static const double _pill = 999;

  // ── scalar values ──────────────────────────────────────────────
  static const double xsValue   = _xs;
  static const double smValue   = _sm;
  static const double mdValue   = _md;
  static const double lgValue   = _lg;
  static const double xlValue   = _xl;
  static const double pillValue = _pill;

  // ── BorderRadius shortcuts ──────────────────────────────────────
  static BorderRadius get xs   => BorderRadius.circular(_xs);
  static BorderRadius get sm   => BorderRadius.circular(_sm);
  static BorderRadius get md   => BorderRadius.circular(_md);
  static BorderRadius get lg   => BorderRadius.circular(_lg);
  static BorderRadius get xl   => BorderRadius.circular(_xl);
  static BorderRadius get pill => BorderRadius.circular(_pill);

  // ── RoundedRectangleBorder shortcuts (for shape: parameter) ────
  static RoundedRectangleBorder get xsShape   => RoundedRectangleBorder(borderRadius: xs);
  static RoundedRectangleBorder get smShape   => RoundedRectangleBorder(borderRadius: sm);
  static RoundedRectangleBorder get mdShape   => RoundedRectangleBorder(borderRadius: md);
  static RoundedRectangleBorder get lgShape   => RoundedRectangleBorder(borderRadius: lg);
  static RoundedRectangleBorder get xlShape   => RoundedRectangleBorder(borderRadius: xl);
  static RoundedRectangleBorder get pillShape => RoundedRectangleBorder(borderRadius: pill);

  // ── Partial radius helpers ──────────────────────────────────────
  static BorderRadius get topMd    => const BorderRadius.vertical(top: Radius.circular(_md));
  static BorderRadius get topLg    => const BorderRadius.vertical(top: Radius.circular(_lg));
  static BorderRadius get bottomMd => const BorderRadius.vertical(bottom: Radius.circular(_md));
  static BorderRadius get bottomLg => const BorderRadius.vertical(bottom: Radius.circular(_lg));
}

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

  static const Color surfaceColor       = Color(0xFFF4F4F0);
  static const Color cardWhite          = Color(0xFFFFFFFF);
  static const Color borderColor        = Color(0xFFE0E0E0);
  static const Color subtextColor       = Color(0xFF757575);
  static const Color headerBg           = Color(0xFFF9F9F9);

  // ─────────────────────────────────────────────────────────────────
  // 04 · Shorthand aliases
  //      ใช้ชื่อสั้นได้เลยใน widget code เช่น AppTheme.primary
  //      ค่าเหมือนกันทุกอย่าง — เลือกใช้แบบไหนก็ได้
  // ─────────────────────────────────────────────────────────────────

  static const Color primary  = primaryColor;
  static const Color navy     = navyColor;
  static const Color success  = successColor;
  static const Color error    = errorColor;
  static const Color warning  = warningColor;
  static const Color info     = infoColor;
  static const Color textSub  = subtextColor;   // ← AppColors.textSub
  static const Color border   = borderColor;    // ← AppColors.border
  static const Color surface  = surfaceColor;   // ← AppColors.surface

  // ─────────────────────────────────────────────────────────────────
  // 05 · Dark Mode Surface (public)
  // ─────────────────────────────────────────────────────────────────

  static const Color darkBg       = Color(0xFF121212);
  static const Color darkCard     = Color(0xFF1E1E1E);
  static const Color darkElement  = Color(0xFF2A2A2A);
  static const Color darkTopBar   = Color(0xFF1E1E1E);

  // internal aliases ใช้ใน ThemeData ด้านล่าง
  static const _darkSurface  = darkCard;
  static const _darkSurface2 = darkElement;
  static const _darkBorder   = Color(0xFF333333);
  static const _darkText     = Color(0xFFE0E0E0);
  static const _darkSubtext  = Color(0xFF9E9E9E);
  static const _darkPrimary  = primaryLight; // #FF9D45 — contrast บน dark bg

  // ─────────────────────────────────────────────────────────────────
  // 06 · Typography helper — IBM Plex Sans Thai → Sarabun fallback
  // ─────────────────────────────────────────────────────────────────

  static TextTheme _buildTextTheme(TextTheme base, [String fontFamily = 'ibmPlexSansThai']) =>
      switch (fontFamily) {
        'sarabun'      => GoogleFonts.sarabunTextTheme(base),
        'kanit'        => GoogleFonts.kanitTextTheme(base),
        'prompt'       => GoogleFonts.promptTextTheme(base),
        'notoSansThai' => GoogleFonts.notoSansThaiTextTheme(base),
        _              => GoogleFonts.ibmPlexSansThaiTextTheme(base),
      };

  static ThemeData buildLightTheme([String fontFamily = 'ibmPlexSansThai']) =>
      lightTheme.copyWith(
        textTheme: _buildTextTheme(ThemeData.light().textTheme, fontFamily),
      );

  static ThemeData buildDarkTheme([String fontFamily = 'ibmPlexSansThai']) =>
      darkTheme.copyWith(
        textTheme: _buildTextTheme(ThemeData.dark().textTheme, fontFamily)
            .apply(bodyColor: _darkText, displayColor: _darkText),
      );

  // ─────────────────────────────────────────────────────────────────
  // 07 · Light Theme
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
      backgroundColor: navyColor,
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
      backgroundColor: navyColor,
      surfaceTintColor: Colors.transparent,
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: navyColor,
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
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryColor,
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
      width: 300,
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
  // 08 · Dark Theme
  // ─────────────────────────────────────────────────────────────────
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
    scaffoldBackgroundColor: darkBg,
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 1,
      backgroundColor: navyDark,
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
      width: 300,
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
  // 09 · Context-aware Helpers — Surface & Border
  // ─────────────────────────────────────────────────────────────────

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// Card background — white in light, darkCard in dark
  static Color cardColor(BuildContext context) =>
      isDark(context) ? darkCard : cardWhite;

  /// Input / secondary surface — grey50 in light, darkElement in dark
  static Color surfaceColorOf(BuildContext context) =>
      isDark(context) ? darkElement : Colors.grey.shade50;

  /// Border color — borderColor in light, dark border in dark
  static Color borderColorOf(BuildContext context) =>
      isDark(context) ? const Color(0xFF333333) : borderColor;

  /// Subtext color — subtextColor in light, muted in dark
  static Color subtextColorOf(BuildContext context) =>
      isDark(context) ? const Color(0xFF9E9E9E) : subtextColor;

  // ─────────────────────────────────────────────────────────────────
  // 10 · Context-aware Helpers — Text, Icon, Surface Tiers
  // ─────────────────────────────────────────────────────────────────

  /// Primary body text: near-black in light, near-white in dark
  static Color textColorOf(BuildContext context) =>
      isDark(context) ? const Color(0xFFE0E0E0) : const Color(0xFF1A1A1A);

  /// Muted / secondary text: equivalent of Colors.black54, dark-aware
  static Color mutedTextOf(BuildContext context) =>
      isDark(context) ? const Color(0xFF9E9E9E) : const Color(0xFF757575);

  /// Elevated surface element within a card (grey.shade100 in light = #F5F5F5)
  static Color surface3Of(BuildContext context) =>
      isDark(context) ? const Color(0xFF323232) : const Color(0xFFF5F5F5);

  /// Table / list row — even row background
  static Color rowEvenOf(BuildContext context) =>
      isDark(context) ? darkCard : cardWhite;

  /// Table / list row — odd row background (subtle alternating stripe)
  static Color rowOddOf(BuildContext context) =>
      isDark(context) ? const Color(0xFF242424) : const Color(0xFFF9F9F7);

  /// General icon color (grey.shade600 equivalent)
  static Color iconOf(BuildContext context) =>
      isDark(context) ? const Color(0xFF9E9E9E) : const Color(0xFF757575);

  /// Subtle / decorative icon color (grey.shade400 equivalent)
  static Color iconSubtleOf(BuildContext context) =>
      isDark(context) ? const Color(0xFF616161) : const Color(0xFFBDBDBD);

  /// Input field border (grey.shade300 equivalent)
  static Color inputBorderOf(BuildContext context) =>
      isDark(context) ? const Color(0xFF444444) : const Color(0xFFDDDDDD);

  // ─────────────────────────────────────────────────────────────────
  // 11 · Button Style Hierarchy
  //
  //  Use in multi-button sections to create clear visual weight:
  //   L1 = primary action  →  solid filled (highest weight)
  //   L2 = secondary action → tonal filled (medium weight)
  //   L3 = tertiary action  → outlined (lower weight)
  //   L4 = ghost action     → text only (minimum weight)
  // ─────────────────────────────────────────────────────────────────

  /// L1 — Primary filled button.  Most important action per section.
  static ButtonStyle buttonL1({
    Color bg = primaryColor,
    Color fg = Colors.white,
    BorderRadius? radius,
  }) =>
      ElevatedButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: radius ?? AppRadius.md,
        ),
      );

  /// L2 — Secondary tonal button.  Supporting / complementary action.
  static ButtonStyle buttonL2(
    BuildContext context, {
    Color? bg,
    Color? fg,
    BorderRadius? radius,
  }) =>
      ElevatedButton.styleFrom(
        backgroundColor:
            bg ?? (isDark(context) ? darkElement : const Color(0xFFEDEDED)),
        foregroundColor:
            fg ?? (isDark(context) ? const Color(0xFFE0E0E0) : const Color(0xFF424242)),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: radius ?? AppRadius.md,
        ),
      );

  /// L3 — Tertiary outlined button.  Optional / reversible action.
  static ButtonStyle buttonL3({
    Color color = primaryColor,
    BorderRadius? radius,
  }) =>
      OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color),
        shape: RoundedRectangleBorder(
          borderRadius: radius ?? AppRadius.md,
        ),
      );

  /// L4 — Ghost / text-only button.  Least-important or dismiss action.
  static ButtonStyle buttonL4({Color color = primaryColor}) =>
      TextButton.styleFrom(foregroundColor: color);
}