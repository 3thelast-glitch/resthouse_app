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

  testWidgets('App loads and renders main shell', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ResthouseApp());

    // Verify that the application structure is rendered.
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}