import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:resthouse_app/database_helper.dart';
import 'package:resthouse_app/pages/booking_payments_dialog.dart';

void main() {
  final helper = DatabaseHelper.instance;
  late Directory directory;
  late int bookingId;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('resthouse_payment_ui_');
    await helper.configureDatabasePathForTesting(
      path.join(directory.path, 'test.db'),
    );
    await helper.insertRenter({'phone': '0500000000', 'full_name': 'عميل'});
    bookingId = await helper.insertBooking({
      'phone': '0500000000',
      'start_date': '2026-09-10',
      'end_date': '2026-09-11',
      'total_price': 1000,
    });
    await helper.insertPayment({
      'booking_id': bookingId,
      'amount': 300,
      'paid_at': '2026-09-10',
    });
  });
  tearDown(() async {
    await helper.clearTestingDatabase();
    await directory.delete(recursive: true);
  });

  testWidgets(
    'phone user must give a reason and sees corrected receipt history',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      // Start the entire interaction in the real async zone. Starting the
      // dialog in fake time and only wrapping the final tap leaves its SQLite
      // continuation in fake time and can strand an open transaction.
      await tester.runAsync(() async {
        Future<void> waitForText(String text) async {
          final deadline = DateTime.now().add(const Duration(seconds: 5));
          while (find.text(text).evaluate().isEmpty &&
              DateTime.now().isBefore(deadline)) {
            await Future<void>.delayed(const Duration(milliseconds: 20));
            await tester.pump();
          }
          expect(find.text(text), findsOneWidget);
        }

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: BookingPaymentsDialog(bookingId: bookingId)),
          ),
        );
        await waitForText('المسدد: 300.00 ر.س');
        await tester.tap(find.text('إلغاء الدفعة'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('تأكيد إلغاء الدفعة'));
        await tester.pumpAndSettle();
        expect(find.text('اكتب سبب إلغاء الدفعة.'), findsOneWidget);
        await tester.enterText(find.byType(TextFormField), 'دفعة مكررة');
        await tester.tap(find.text('تأكيد إلغاء الدفعة'));
        await waitForText('المسدد: 0.00 ر.س');
        await tester.pumpAndSettle();
        expect(find.text('المتبقي: 1000.00 ر.س'), findsOneWidget);
        expect(find.text('السبب: دفعة مكررة'), findsOneWidget);
        expect(find.text('إلغاء الدفعة'), findsNothing);
        final payments = await helper.queryPaymentsForBooking(
          bookingId,
          includeVoided: true,
        );
        expect(payments.single['status'], 'voided');
        expect(payments.single['void_reason'], 'دفعة مكررة');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    },
    timeout: const Timeout(Duration(seconds: 45)),
  );
}
