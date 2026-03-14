import 'package:flutter/material.dart';

// ─────────────────────────────────────────
// Breakpoints (Desktop-first สำหรับ POS/ERP)
// ─────────────────────────────────────────
class Breakpoints {
  static const double xs  = 480;   // มือถือเล็ก
  static const double sm  = 768;   // มือถือใหญ่ / tablet portrait
  static const double md  = 1024;  // tablet landscape / laptop เล็ก
  static const double lg  = 1280;  // desktop ปกติ
  static const double xl  = 1600;  // desktop ใหญ่
}

// ─────────────────────────────────────────
// Screen Size Enum
// ─────────────────────────────────────────
enum ScreenSize { xs, sm, md, lg, xl }

// ─────────────────────────────────────────
// BuildContext Extensions
// ─────────────────────────────────────────
extension ScreenSizeExtension on BuildContext {
  double get screenWidth  => MediaQuery.sizeOf(this).width;
  double get screenHeight => MediaQuery.sizeOf(this).height;

  ScreenSize get screenSize {
    final w = screenWidth;
    if (w < Breakpoints.xs)  return ScreenSize.xs;
    if (w < Breakpoints.sm)  return ScreenSize.sm;
    if (w < Breakpoints.md)  return ScreenSize.md;
    if (w < Breakpoints.lg)  return ScreenSize.lg;
    return ScreenSize.xl;
  }

  // ── Boolean checks ───────────────────────────────────────────
  bool get isXs      => screenWidth < Breakpoints.xs;
  bool get isMobile  => screenWidth < Breakpoints.sm;
  bool get isTablet  => screenWidth >= Breakpoints.sm  && screenWidth < Breakpoints.md;
  bool get isDesktop => screenWidth >= Breakpoints.md  && screenWidth < Breakpoints.xl;
  bool get isLarge   => screenWidth >= Breakpoints.lg;

  /// Desktop + Large (md ขึ้นไป)
  bool get isDesktopOrWider => screenWidth >= Breakpoints.md;

  /// Tablet + Desktop + Large (sm ขึ้นไป)
  bool get isTabletOrWider  => screenWidth >= Breakpoints.sm;

  // ── Sidebar ──────────────────────────────────────────────────

  /// Sidebar แบบ permanent (ติดหน้าจอ) เมื่อ md ขึ้นไป
  /// Mobile/Tablet → ใช้ Drawer overlay แทน
  bool get hasPermanentSidebar => isDesktopOrWider;

  /// ความกว้าง sidebar ตามขนาดหน้าจอ
  double get sidebarWidth {
    if (screenWidth >= Breakpoints.xl) return 260;
    if (screenWidth >= Breakpoints.lg) return 240;
    if (screenWidth >= Breakpoints.md) return 220;
    return 220; // mobile/tablet ใช้ใน Drawer
  }

  // ── Grid Columns ─────────────────────────────────────────────

  /// จำนวน column สำหรับ GridView เมนูหลัก
  int get menuGridColumns {
    final w = screenWidth;
    if (w < Breakpoints.xs) return 2;
    if (w < Breakpoints.sm) return 2;
    if (w < Breakpoints.md) return 3;
    if (w < Breakpoints.lg) return 4;
    return 5;
  }

  /// จำนวน column สำหรับ Stats cards ใน Dashboard
  int get statsGridColumns {
    if (isMobile) return 2;
    if (isTablet) return 2;
    return 4; // desktop+
  }

  /// จำนวน column สำหรับ Grid ทั่วไป (product grid ฯลฯ)
  int gridColumns({
    int xs = 1,
    int sm = 2,
    int md = 3,
    int lg = 4,
    int xl = 5,
  }) {
    final w = screenWidth;
    if (w < Breakpoints.xs) return xs;
    if (w < Breakpoints.sm) return sm;
    if (w < Breakpoints.md) return md;
    if (w < Breakpoints.lg) return lg;
    return xl;
  }

  // ── Padding ──────────────────────────────────────────────────

  /// Padding สำหรับหน้า (page-level)
  EdgeInsets get pagePadding {
    if (isMobile)  return const EdgeInsets.all(12);
    if (isTablet)  return const EdgeInsets.all(16);
    return const EdgeInsets.all(24);
  }

  /// Padding สำหรับ Card / panel
  EdgeInsets get cardPadding {
    if (isMobile) return const EdgeInsets.all(12);
    return const EdgeInsets.all(16);
  }

  // ── Content Width ────────────────────────────────────────────

  /// Max width สำหรับ content area
  double get contentMaxWidth {
    if (isMobile) return double.infinity;
    if (isTablet) return 800;
    return 1200;
  }

  // ── Typography ───────────────────────────────────────────────

  double get titleFontSize {
    if (isMobile) return 16;
    if (isTablet) return 18;
    return 20;
  }

  double get bodyFontSize {
    if (isMobile) return 12;
    return 14;
  }

  double get iconSize {
    if (isMobile) return 36;
    if (isTablet) return 44;
    return 48;
  }
}

// ─────────────────────────────────────────
// Responsive Builder Widget
// ─────────────────────────────────────────
class ResponsiveBuilder extends StatelessWidget {
  const ResponsiveBuilder({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  @override
  Widget build(BuildContext context) {
    if (context.isDesktopOrWider && desktop != null) return desktop!;
    if (context.isTabletOrWider  && tablet  != null) return tablet!;
    return mobile;
  }
}

// ─────────────────────────────────────────
// Responsive Value Helper
// ─────────────────────────────────────────
T responsiveValue<T>(
  BuildContext context, {
  required T mobile,
  T? tablet,
  T? desktop,
}) {
  if (context.isDesktopOrWider && desktop != null) return desktop;
  if (context.isTabletOrWider  && tablet  != null) return tablet;
  return mobile;
}

// ─────────────────────────────────────────
// ResponsiveScaffold
// Sidebar คงที่บน desktop, Drawer บน mobile/tablet
// ─────────────────────────────────────────
class ResponsiveScaffold extends StatelessWidget {
  const ResponsiveScaffold({
    super.key,
    required this.title,
    required this.body,
    this.sidebar,
    this.sidebarWidth,    // null = ใช้ context.sidebarWidth อัตโนมัติ
    this.actions,
    this.floatingActionButton,
    this.bottomNavigationBar,
  });

  final String title;
  final Widget body;
  final Widget? sidebar;
  final double? sidebarWidth;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;

  @override
  Widget build(BuildContext context) {
    final hasSidebar  = sidebar != null;
    final effectiveWidth = sidebarWidth ?? context.sidebarWidth;

    if (context.hasPermanentSidebar && hasSidebar) {
      // Desktop: sidebar ติดถาวรซ้ายมือ
      return Scaffold(
        appBar: AppBar(
          title: Text(title),
          automaticallyImplyLeading: false,
          actions: actions,
        ),
        floatingActionButton: floatingActionButton,
        body: Row(
          children: [
            SizedBox(width: effectiveWidth, child: sidebar!),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(child: body),
          ],
        ),
        bottomNavigationBar: bottomNavigationBar,
      );
    }

    // Mobile/Tablet: sidebar เป็น Drawer overlay
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      drawer: hasSidebar
          ? Drawer(width: effectiveWidth, child: sidebar!)
          : null,
      body: body,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}