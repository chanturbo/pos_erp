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
// Screen Size Helper
// ─────────────────────────────────────────
enum ScreenSize { xs, sm, md, lg, xl }

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

  bool get isXs      => screenWidth < Breakpoints.xs;
  bool get isMobile  => screenWidth < Breakpoints.sm;
  bool get isTablet  => screenWidth >= Breakpoints.sm && screenWidth < Breakpoints.md;
  bool get isDesktop => screenWidth >= Breakpoints.md;
  bool get isLarge   => screenWidth >= Breakpoints.lg;

  /// จำนวน column สำหรับ GridView เมนูหลัก
  int get menuGridColumns {
    final w = screenWidth;
    if (w < Breakpoints.xs)  return 2;
    if (w < Breakpoints.sm)  return 2;
    if (w < Breakpoints.md)  return 3;
    if (w < Breakpoints.lg)  return 4;
    return 5;
  }

  /// จำนวน column สำหรับ Grid ทั่วไป (เช่น product grid)
  int gridColumns({int xs = 1, int sm = 2, int md = 3, int lg = 4, int xl = 5}) {
    final w = screenWidth;
    if (w < Breakpoints.xs)  return xs;
    if (w < Breakpoints.sm)  return sm;
    if (w < Breakpoints.md)  return md;
    if (w < Breakpoints.lg)  return lg;
    return xl;
  }

  /// Padding แบบ responsive
  EdgeInsets get pagePadding {
    if (isMobile)  return const EdgeInsets.all(12);
    if (isTablet)  return const EdgeInsets.all(16);
    return const EdgeInsets.all(24);
  }

  /// Max content width
  double get contentMaxWidth {
    if (isMobile) return double.infinity;
    if (isTablet) return 800;
    return 1200;
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
    if (context.isDesktop && desktop != null) return desktop!;
    if (context.isTablet  && tablet  != null) return tablet!;
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
  if (context.isDesktop && desktop != null) return desktop;
  if (context.isTablet  && tablet  != null) return tablet;
  return mobile;
}

// ─────────────────────────────────────────
// Responsive Layout (Sidebar + Content)
// ─────────────────────────────────────────
/// ใช้กับหน้าที่มี sidebar บน desktop
/// แต่แสดง drawer บน mobile/tablet
class ResponsiveScaffold extends StatelessWidget {
  const ResponsiveScaffold({
    super.key,
    required this.title,
    required this.body,
    this.sidebar,
    this.sidebarWidth = 260,
    this.actions,
    this.floatingActionButton,
    this.bottomNavigationBar,
  });

  final String title;
  final Widget body;
  final Widget? sidebar;
  final double sidebarWidth;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;

  @override
  Widget build(BuildContext context) {
    final hasSidebar = sidebar != null;

    if (context.isDesktop && hasSidebar) {
      // Desktop: sidebar คงที่ข้างซ้าย
      return Scaffold(
        appBar: AppBar(title: Text(title), actions: actions),
        floatingActionButton: floatingActionButton,
        body: Row(
          children: [
            SizedBox(
              width: sidebarWidth,
              child: sidebar!,
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
      );
    }

    // Mobile/Tablet: sidebar เป็น Drawer
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      drawer: hasSidebar
          ? Drawer(
              width: sidebarWidth,
              child: sidebar!,
            )
          : null,
      body: body,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}