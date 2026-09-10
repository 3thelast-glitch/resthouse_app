import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:resthouse_app/database_helper.dart';
import 'package:resthouse_app/main.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  final helper = DatabaseHelper.instance;
  late Directory directory;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('resthouse_ui_');
    await helper.configureDatabasePathForTesting(
      path.join(directory.path, 'ui_test.db'),
    );
  });

  tearDown(() async {
    await helper.clearTestingDatabase();
    await directory.delete(recursive: true);
  });

  Future<void> pumpAt(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ResthouseApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }

  testWidgets('compact width uses Material 3 navigation bar without overflow',
      (tester) async {
    await pumpAt(tester, const Size(390, 844));

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('لوحة التحكم'), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('medium and expanded widths use navigation rail',
      (tester) async {
    await pumpAt(tester, const Size(768, 1024));

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(1280, 800);
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('selected destination survives responsive navigation change',
      (tester) async {
    await pumpAt(tester, const Size(390, 844));

    final financeLabel = find.text('المالية');
    expect(financeLabel, findsOneWidget);
    await tester.tap(financeLabel);
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('الملخص المالي والمصروفات'), findsOneWidget);

    tester.view.physicalSize = const Size(1024, 768);
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.text('الملخص المالي والمصروفات'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
