import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_erp/shared/utils/responsive_utils.dart';

// Helper: build widget ใน test environment ด้วยขนาดหน้าจอที่กำหนด
Future<BuildContext> buildContextWithSize(
  WidgetTester tester,
  Size size,
) async {
  late BuildContext ctx;
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: Builder(builder: (c) {
          ctx = c;
          return const SizedBox();
        }),
      ),
    ),
  );
  return ctx;
}

void main() {
  group('Breakpoints & ScreenSize extensions', () {
    // ─── isMobile ───────────────────────
    group('isMobile', () {
      testWidgets('is true at 375px (iPhone SE)', (tester) async {
        final ctx = await buildContextWithSize(tester, const Size(375, 812));
        expect(ctx.isMobile, isTrue);
      });

      testWidgets('is true at 767px (just below sm)', (tester) async {
        final ctx = await buildContextWithSize(tester, const Size(767, 1024));
        expect(ctx.isMobile, isTrue);
      });

      testWidgets('is false at 768px (sm breakpoint)', (tester) async {
        final ctx = await buildContextWithSize(tester, const Size(768, 1024));
        expect(ctx.isMobile, isFalse);
      });
    });

    // ─── isTablet ────────────────────────
    group('isTablet', () {
      testWidgets('is true at 768px', (tester) async {
        final ctx = await buildContextWithSize(tester, const Size(768, 1024));
        expect(ctx.isTablet, isTrue);
      });

      testWidgets('is true at 1023px (just below md)', (tester) async {
        final ctx = await buildContextWithSize(tester, const Size(1023, 768));
        expect(ctx.isTablet, isTrue);
      });

      testWidgets('is false at 1024px (desktop)', (tester) async {
        final ctx = await buildContextWithSize(tester, const Size(1024, 768));
        expect(ctx.isTablet, isFalse);
      });
    });

    // ─── isDesktop ───────────────────────
    group('isDesktop', () {
      testWidgets('is true at 1024px', (tester) async {
        final ctx = await buildContextWithSize(tester, const Size(1024, 768));
        expect(ctx.isDesktop, isTrue);
      });

      testWidgets('is true at 1920px', (tester) async {
        final ctx = await buildContextWithSize(tester, const Size(1920, 1080));
        expect(ctx.isDesktop, isTrue);
      });

      testWidgets('is false at 1023px', (tester) async {
        final ctx = await buildContextWithSize(tester, const Size(1023, 768));
        expect(ctx.isDesktop, isFalse);
      });
    });

    // ─── menuGridColumns ─────────────────
    group('menuGridColumns', () {
      testWidgets('returns 2 on mobile (375px)', (tester) async {
        final ctx = await buildContextWithSize(tester, const Size(375, 812));
        expect(ctx.menuGridColumns, 2);
      });

      testWidgets('returns 3 on tablet (768px)', (tester) async {
        final ctx = await buildContextWithSize(tester, const Size(768, 1024));
        expect(ctx.menuGridColumns, 3);
      });

      testWidgets('returns 4 on desktop (1024px)', (tester) async {
        final ctx = await buildContextWithSize(tester, const Size(1024, 768));
        expect(ctx.menuGridColumns, 4);
      });

      testWidgets('returns 5 on large desktop (1280px+)', (tester) async {
        final ctx = await buildContextWithSize(tester, const Size(1280, 800));
        expect(ctx.menuGridColumns, 5);
      });
    });

    // ─── pagePadding ─────────────────────
    group('pagePadding', () {
      testWidgets('is 12 on mobile', (tester) async {
        final ctx = await buildContextWithSize(tester, const Size(375, 812));
        expect(ctx.pagePadding, const EdgeInsets.all(12));
      });

      testWidgets('is 24 on desktop', (tester) async {
        final ctx = await buildContextWithSize(tester, const Size(1920, 1080));
        expect(ctx.pagePadding, const EdgeInsets.all(24));
      });
    });
  });
}