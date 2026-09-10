import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:resthouse_app/database_helper.dart';
import 'package:resthouse_app/pages/ultimate_dashboard_page.dart';
import 'package:resthouse_app/ui/app_theme.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  final helper = DatabaseHelper.instance;
  late Directory directory;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('resthouse_dashboard_ui_');
    await helper.configureDatabasePathForTesting(
      path.join(directory.path, 'dashboard_test.db'),
    );

    await helper.insertRenter({
      'phone': '0500000000',
      'full_name': 'مستأجر باسم عربي طويل لاختبار وضوح الواجهة',
      'notes': '',
      'rating': 5,
    });
    final bookingId = await helper.insertBooking({
      'phone': '0500000000',
      'start_date': '2026-09-10',
      'end_date': '2026-09-11',
      'total_price': 1000.0,
      'security_deposit': 200.0,
      'status': DatabaseHelper.statusConfirmed,
    });
    await helper.insertPayment({
      'booking_id': bookingId,
      'amount': 400.0,
      'paid_at': '2026-09-10',
      'method': 'cash',
    });
    await helper.insertExpense({
      'description': 'صيانة دورية',
      'amount': 100.0,
      'date': '2026-09-10',
      'category': 'صيانة',
    });
  });

  tearDown(() async {
    await helper.clearTestingDatabase();
    await directory.delete(recursive: true);
  });

  Future<void> pumpDashboard(
    WidgetTester tester, {
    required Size size,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
          ),
          child: const UltimateDashboardPage(),
        ),
      ),
    );
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('populated dashboard remains usable at 320 width and 140% text',
      (tester) async {
    await pumpDashboard(
      tester,
      size: const Size(320, 568),
      textScale: 1.4,
    );

    expect(find.text('قيمة الحجوزات'), findsOneWidget);
    expect(find.text('المقبوض فعليًا'), findsOneWidget);
    expect(find.text('الرصيد المستحق'), findsOneWidget);
    expect(find.text('1000.00 ر.س'), findsOneWidget);
    expect(find.text('400.00 ر.س'), findsOneWidget);
    expect(find.text('600.00 ر.س'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('populated dashboard uses wide composition without overflow',
      (tester) async {
    await pumpDashboard(tester, size: const Size(1280, 800));

    expect(find.text('الأداء المالي'), findsOneWidget);
    expect(find.text('آخر العمليات'), findsOneWidget);
    expect(find.text('تأمينات معلقة'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
