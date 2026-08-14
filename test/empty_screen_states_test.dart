import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:resthouse_app/database_helper.dart';
import 'package:resthouse_app/pages/ultimate_dashboard_page.dart';

void main() {
  final helper = DatabaseHelper.instance;
  late Directory temporaryDirectory;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'resthouse_empty_screen_test_',
    );
    await helper.configureDatabasePathForTesting(
      path.join(temporaryDirectory.path, 'resthouse_empty_screen.db'),
    );
  });

  tearDown(() async {
    await helper.clearTestingDatabase();
    await temporaryDirectory.delete(recursive: true);
  });

  testWidgets('تعرض لوحة التحكم حالة بدء فارغة', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: UltimateDashboardPage()));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();

    expect(find.text('لا توجد بيانات لعرض لوحة التحكم بعد'), findsOneWidget);
    expect(find.text('إجمالي الإيرادات'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
