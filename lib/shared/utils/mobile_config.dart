import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────
// Platform Detection
// ─────────────────────────────────────────
class MobileConfig {
  MobileConfig._();

  /// ตรวจว่า run บน mobile จริงๆ (Android/iOS)
  static bool get isMobile =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  static bool get isAndroid =>
      defaultTargetPlatform == TargetPlatform.android;

  static bool get isIOS =>
      defaultTargetPlatform == TargetPlatform.iOS;

  static bool get isDesktop =>
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux;

  // ─── Screen ───────────────────────────
  /// Design size สำหรับ ScreenUtil แยกตาม platform
  static Size get designSize {
    if (isMobile) return const Size(390, 844); // iPhone 14 Pro
    return const Size(1920, 1080);             // Desktop
  }

  // ─── UI Scaling ───────────────────────
  static double get bottomNavHeight => isMobile ? 80.0 : 0.0;
  static double get fabSize         => isMobile ? 56.0 : 48.0;
  static double get listItemHeight  => isMobile ? 72.0 : 60.0;
  static EdgeInsets get pagePadding =>
      isMobile ? const EdgeInsets.all(12) : const EdgeInsets.all(24);

  // ─── Orientation Lock ─────────────────
  /// Lock portrait สำหรับ mobile POS
  static Future<void> lockPortrait() async {
    if (!isMobile) return;
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  /// Unlock ทุก orientation (เช่น ตอนดู report)
  static Future<void> unlockOrientation() async {
    await SystemChrome.setPreferredOrientations(
      DeviceOrientation.values,
    );
  }

  // ─── Status Bar ───────────────────────
  static void setStatusBarStyle({bool dark = true}) {
    SystemChrome.setSystemUIOverlayStyle(
      dark
          ? SystemUiOverlayStyle.dark
              .copyWith(statusBarColor: Colors.transparent)
          : SystemUiOverlayStyle.light
              .copyWith(statusBarColor: Colors.transparent),
    );
  }

  // ─── Haptic Feedback ──────────────────
  static Future<void> hapticLight()    => HapticFeedback.lightImpact();
  static Future<void> hapticMedium()   => HapticFeedback.mediumImpact();
  static Future<void> hapticSuccess()  => HapticFeedback.selectionClick();
  static Future<void> hapticError()    => HapticFeedback.heavyImpact();
}

// ─────────────────────────────────────────
// Mobile Bottom Navigation
// ใช้แทน NavigationRail ของ Desktop บน Mobile
// ─────────────────────────────────────────
class MobileScaffold extends StatefulWidget {
  const MobileScaffold({
    super.key,
    required this.destinations,
    required this.pages,
    this.floatingActionButton,
    this.appBar,
  });

  final List<MobileNavDestination> destinations;
  final List<Widget> pages;
  final Widget? floatingActionButton;
  final PreferredSizeWidget? appBar;

  @override
  State<MobileScaffold> createState() => _MobileScaffoldState();
}

class _MobileScaffoldState extends State<MobileScaffold> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.appBar,
      body: IndexedStack(
        index: _selectedIndex,
        children: widget.pages,
      ),
      floatingActionButton: widget.floatingActionButton,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          MobileConfig.hapticLight();
          setState(() => _selectedIndex = index);
        },
        destinations: widget.destinations
            .map((d) => NavigationDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selectedIcon ?? d.icon),
                  label: d.label,
                ))
            .toList(),
      ),
    );
  }
}

class MobileNavDestination {
  const MobileNavDestination({
    required this.icon,
    required this.label,
    this.selectedIcon,
  });

  final IconData icon;
  final IconData? selectedIcon;
  final String label;
}

// ─────────────────────────────────────────
// Adaptive Widget — desktop vs mobile
// ─────────────────────────────────────────
class AdaptiveWidget extends StatelessWidget {
  const AdaptiveWidget({
    super.key,
    required this.mobile,
    required this.desktop,
  });

  final Widget mobile;
  final Widget desktop;

  @override
  Widget build(BuildContext context) =>
      MobileConfig.isMobile ? mobile : desktop;
}

// ─────────────────────────────────────────
// Mobile List Tile — ขนาดใหญ่ขึ้น touch-friendly
// ─────────────────────────────────────────
class MobileListTile extends StatelessWidget {
  const MobileListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.selected = false,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        MobileConfig.hapticLight();
        onTap?.call();
      },
      child: Container(
        constraints: BoxConstraints(
          minHeight: MobileConfig.listItemHeight,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: selected
            ? BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    .withValues(alpha: 0.3),
              )
            : null,
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 16)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                          )),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6),
                            )),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}