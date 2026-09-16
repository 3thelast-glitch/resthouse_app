import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:resthouse_app/database_helper.dart';
import 'package:resthouse_app/main.dart';
import 'package:resthouse_app/pages/booking_manager_page.dart';
import 'package:resthouse_app/theme/app_theme.dart';

Future<void> _settleDatabaseUi(WidgetTester tester) async {
  await tester.pump();

  // sqflite_common_ffi runs database work on a real isolate. Advancing the
  // widget-test clock alone does not wait for that isolate. Use bounded real
  // waits and fixed pumps so persistent animations cannot make this helper
  // time out like pumpAndSettle can.
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
  });
  await tester.pump(const Duration(milliseconds: 400));
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
  await tester.pump(const Duration(milliseconds: 100));
}

void _expectNoLayoutException(WidgetTester tester, String reason) {
  final exception = tester.takeException();
  expect(exception, isNull, reason: reason);
}

Widget _bookingTestApp() {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    locale: const Locale('ar', 'SA'),
    supportedLocales: const [Locale('ar', 'SA')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: const BookingManagerPage(),
  );
}

void main() {
  late Directory tempDirectory;
  final db = DatabaseHelper.instance;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('resthouse_a11y_');
    await db.configureDatabasePathForTesting(
      p.join(tempDirectory.path, 'accessibility.db'),
    );
  });

  tearDown(() async {
    await db.clearTestingDatabase();
    if (tempDirectory.existsSync()) {
      tempDirectory.deleteSync(recursive: true);
    }
  });

  testWidgets('200% system text scaling stays usable on target widths', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    const sizes = <Size>[
      Size(360, 800),
      Size(390, 844),
      Size(430, 900),
      Size(800, 600),
      Size(800, 400),
    ];

    for (final size in sizes) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(const ResthouseApp());
      await _settleDatabaseUi(tester);
      _expectNoLayoutException(
        tester,
        'Unexpected layout exception at ${size.width}x${size.height} with 200% text scaling.',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await _settleDatabaseUi(tester);
    }

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('booking form remains reachable and scrollable at 200%', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.binding.setSurfaceSize(const Size(390, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_bookingTestApp());
    await _settleDatabaseUi(tester);

    final addBooking = find.text('تسجيل حجز جديد');
    expect(addBooking, findsOneWidget);
    await tester.ensureVisible(addBooking);
    await tester.pump(const Duration(milliseconds: 150));
    await tester.tap(addBooking, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('إضافة حجز جديد'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsWidgets);
    _expectNoLayoutException(
      tester,
      'Booking dialog overflowed on a short phone viewport with 200% text scaling.',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await _settleDatabaseUi(tester);
  });
}
