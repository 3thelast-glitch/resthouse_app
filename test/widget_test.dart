import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:resthouse_app/main.dart';

void main() {
  // تهيئة قاعدة البيانات ffi للاختبارات البرمجية
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('App shell keeps the sidebar usable on short screens', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // Build our app and trigger a frame.
    await tester.pumpWidget(const ResthouseApp());

    // Verify that the application structure is rendered.
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.drag(
      find.byKey(const ValueKey('mainSidebar')),
      const Offset(0, -500),
    );
    await tester.pump();

    expect(find.text('إعدادات النظام والنسخ').hitTestable(), findsOneWidget);
    expect(find.text('الإصدار 1.0.0 (تجريبي)').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
