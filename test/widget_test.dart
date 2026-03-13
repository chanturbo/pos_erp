import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_erp/main.dart';

void main() {
  testWidgets('App smoke test - renders without crashing', (tester) async {
    // ✅ ต้อง wrap ด้วย ProviderScope เสมอ เพราะ app ใช้ Riverpod
    await tester.pumpWidget(
      const ProviderScope(
        child: MyApp(),
      ),
    );

    // pump อีกครั้งให้ async init เสร็จ
    await tester.pump();

    // ✅ app เริ่มต้นที่ LoginPage — ตรวจว่า render ได้โดยไม่ crash
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}