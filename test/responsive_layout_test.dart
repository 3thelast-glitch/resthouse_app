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

Future<void> settleDatabaseUi(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
  });
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void expectNoLayoutException(WidgetTester tester, String reason) {
  final exceptions = <Object>[];
  Object? exception;
  while ((exception = tester.takeException()) != null) {
    exceptions.add(exception!);
  }
  expect(exceptions, isEmpty, reason: '$reason\n$exceptions');
}

Widget bookingTestApp() {
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

Future<void> seed(DatabaseHelper db) async {
  await db.insertRenter({
    'phone': '0500000001',
    'full_name': 'عبدالرحمن بن محمد العتيبي صاحب الاسم الطويل للاختبار',
    'notes': 'ملاحظة طويلة لاختبار التفاف النص بصورة طبيعية',
    'rating': 5,
    'rental_count': 12345,
  });
  final bookingId = await db.insertBooking({
    'phone': '0500000001',
    'start_date': '2026-09-15',
    'end_date': '2026-09-20',
    'total_price': 55.0,
    'security_deposit': 500.0,
    'status': DatabaseHelper.statusConfirmed,
    'deposit_status': DatabaseHelper.depositPending,
  });
  await db.insertExpense({
    'description': 'نشاط مالي طويل جداً لاختبار الواجهة العربية والاستجابة',
    'amount': 0.01,
    'date': '2026-09-15',
    'category': 'مصاريف تشغيلية أخرى',
  });
  expect(bookingId, greaterThan(0));
}

void main() {
  late Directory tempDirectory;
  final db = DatabaseHelper.instance;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'resthouse_responsive_',
    );
    await db.configureDatabasePathForTesting(
      p.join(tempDirectory.path, 'responsive.db'),
    );
    await seed(db);
  });

  tearDown(() async {
    await db.clearTestingDatabase();
    if (tempDirectory.existsSync()) {
      tempDirectory.deleteSync(recursive: true);
    }
  });

  testWidgets('seeded dashboard has no overflow across target widths', (
    tester,
  ) async {
    const cases = <(Size, double)>[
      (Size(320, 800), 1.0),
      (Size(360, 800), 1.3),
      (Size(390, 844), 1.5),
      (Size(412, 900), 2.0),
      (Size(480, 850), 1.0),
      (Size(599, 850), 1.3),
      (Size(600, 850), 1.3),
      (Size(768, 900), 1.0),
      (Size(1023, 900), 1.5),
      (Size(1024, 900), 1.0),
      (Size(1280, 900), 1.0),
    ];

    for (final entry in cases) {
      final (size, scale) = entry;
      await tester.binding.setSurfaceSize(size);
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      await tester.pumpWidget(const ResthouseApp());
      await settleDatabaseUi(tester);

      expect(find.text('إجمالي الإيرادات'), findsOneWidget);
      expect(find.text('الحجوزات النشطة حالياً'), findsOneWidget);
      expectNoLayoutException(
        tester,
        'Dashboard overflow at ${size.width}x${size.height}, text scale $scale',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }

    tester.platformDispatcher.clearTextScaleFactorTestValue();
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('booking screen stays vertical and readable on phones', (
    tester,
  ) async {
    const cases = <(Size, double)>[
      (Size(320, 800), 1.0),
      (Size(360, 800), 1.3),
      (Size(390, 844), 1.5),
      (Size(412, 900), 2.0),
      (Size(600, 850), 1.0),
      (Size(1024, 900), 1.0),
    ];

    for (final entry in cases) {
      final (size, scale) = entry;
      await tester.binding.setSurfaceSize(size);
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      await tester.pumpWidget(bookingTestApp());
      await settleDatabaseUi(tester);

      expect(find.text('تسجيل حجز جديد'), findsOneWidget);
      expect(find.textContaining('عبدالرحمن بن محمد'), findsWidgets);
      expectNoLayoutException(
        tester,
        'Bookings overflow at ${size.width}x${size.height}, text scale $scale',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }

    tester.platformDispatcher.clearTextScaleFactorTestValue();
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('booking page reaches content below calendar on short phone', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 600));
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(() async {
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(bookingTestApp());
    await settleDatabaseUi(tester);

    final listHeading = find.text('قائمة الحجوزات');
    final pageScroll = find.descendant(
      of: find.byKey(const ValueKey('bookingPageScroll')),
      matching: find.byType(Scrollable),
    );
    expect(pageScroll, findsOneWidget);
    await tester.scrollUntilVisible(listHeading, 400, scrollable: pageScroll);
    expect(listHeading, findsWidgets);
    expectNoLayoutException(
      tester,
      'Content below the calendar could not be reached on a short phone.',
    );
  });
}
