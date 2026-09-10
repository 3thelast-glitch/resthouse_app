import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:resthouse_app/database_helper.dart';
import 'package:resthouse_app/services/financial_summary_service.dart';
import 'package:resthouse_app/services/operations_task_service.dart';
import 'package:resthouse_app/services/booking_status_service.dart';

void main() {
  final helper = DatabaseHelper.instance;
  late Directory directory;
  late int bookingId;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('resthouse_integrity_');
    await helper.configureDatabasePathForTesting(
      path.join(directory.path, 'test.db'),
    );
    await helper.insertRenter({
      'phone': '0500000000',
      'full_name': 'عميل اختبار',
    });
    bookingId = await helper.insertBooking({
      'phone': '0500000000',
      'start_date': '2026-09-10',
      'end_date': '2026-09-11',
      'total_price': 1000.30,
    });
  });
  tearDown(() async {
    await helper.clearTestingDatabase();
    await directory.delete(recursive: true);
  });

  Future<int> pay(num amount) => helper.insertPayment({
    'booking_id': bookingId,
    'amount': amount,
    'paid_at': '2026-09-10',
  });
  List<dynamic> rows(Map<String, dynamic> backup, String table) =>
      (backup['data'] as Map)[table] as List<dynamic>;
  Map<String, dynamic> clone(Map<String, dynamic> value) =>
      jsonDecode(jsonEncode(value)) as Map<String, dynamic>;

  test(
    'settles decimal payments exactly and rejects one extra halala',
    () async {
      await pay(900.10);
      await pay(100.20);
      expect(await helper.queryPaymentSummary(bookingId), {
        'total': 1000.30,
        'paid': 1000.30,
        'remaining': 0.0,
      });
      await expectLater(pay(0.01), throwsArgumentError);
    },
  );

  test(
    'price reduction cannot invalidate receipts and leaves booking unchanged',
    () async {
      await pay(800);
      final original = Map<String, dynamic>.from(
        (await helper.queryAllBookings()).single,
      );
      await expectLater(
        helper.updateBooking({...original, 'total_price': 500}),
        throwsArgumentError,
      );
      expect((await helper.queryAllBookings()).single['total_price'], 1000.30);
      await helper.updateBooking({...original, 'total_price': 800});
      expect((await helper.queryPaymentSummary(bookingId))['remaining'], 0);
    },
  );

  test('voiding updates booking, summary, tasks and audit without deleting history', () async {
    final paymentId = await pay(300.10);
    await expectLater(
      helper.voidPayment(paymentId, reason: '  '),
      throwsArgumentError,
    );
    await helper.voidPayment(paymentId, reason: 'دفعة مكررة');
    final bookings = await helper.queryAllBookings();
    final payments = await helper.queryAllPayments();
    expect((await helper.queryPaymentSummary(bookingId))['paid'], 0);
    final summary = FinancialSummaryService.calculate(
      bookings: bookings,
      payments: payments,
      expenses: [],
    );
    expect(summary.receivedPayments, 0);
    expect(summary.outstandingBalance, 1000.30);
    final tasks = OperationsTaskService.calculate(
      bookings: bookings,
      payments: payments,
      now: DateTime(2026, 9, 10),
    );
    expect(
      tasks
          .singleWhere((t) => t.type == OperationsTaskType.outstandingBalance)
          .amount,
      1000.30,
    );
    final events = await helper.queryRecentAuditEvents();
    expect(events.where((e) => e['action'] == 'voided'), hasLength(1));
    expect(
      events.singleWhere((e) => e['action'] == 'voided')['details'],
      contains('دفعة مكررة'),
    );
    expect(await helper.voidPayment(paymentId, reason: 'مرة أخرى'), 0);
    expect((await helper.queryRecentAuditEvents()).length, events.length);
    expect(await helper.queryPaymentsForBooking(bookingId), isEmpty);
    expect(
      await helper.queryPaymentsForBooking(bookingId, includeVoided: true),
      hasLength(1),
    );
    await expectLater(helper.deleteBooking(bookingId), throwsStateError);
    await expectLater(helper.deletePayment(paymentId), throwsStateError);
    expect(await helper.queryAllPayments(), hasLength(1));
  });

  test('booking with no payment history can still be deleted', () async {
    expect(await helper.deleteBooking(bookingId), 1);
    expect(await helper.queryAllBookings(), isEmpty);
  });

  test('restore rejects overlaps, overpayment, duplicate IDs and invalid dates without replacing data', () async {
    await pay(300);
    final original = await helper.exportBackupData();
    final invalid = <Map<String, dynamic>>[];
    final overlap = clone(original);
    rows(overlap, 'bookings').add({
      ...Map<String, dynamic>.from(rows(overlap, 'bookings').single as Map),
      'id': bookingId + 1,
    });
    invalid.add(overlap);
    final overpayment = clone(original);
    (rows(overpayment, 'payments').single as Map)['amount'] = 1100;
    invalid.add(overpayment);
    final duplicate = clone(original);
    rows(
      duplicate,
      'payments',
    ).add(Map<String, dynamic>.from(rows(duplicate, 'payments').single as Map));
    invalid.add(duplicate);
    final badDate = clone(original);
    (rows(badDate, 'bookings').single as Map)['start_date'] = '2026-02-30';
    invalid.add(badDate);
    final badStatus = clone(original);
    (rows(badStatus, 'payments').single as Map)['status'] = 'unknown';
    invalid.add(badStatus);
    final missingVoidReason = clone(original);
    (rows(missingVoidReason, 'payments').single as Map)['status'] = 'voided';
    invalid.add(missingVoidReason);
    for (final backup in invalid) {
      await expectLater(
        helper.restoreBackupData(backup),
        throwsA(isA<FormatException>()),
      );
      expect((await helper.exportBackupData())['data'], original['data']);
    }
  });

  test(
    'valid backup restores void history and excludes it from payment limits',
    () async {
      final paymentId = await pay(900.10);
      await helper.voidPayment(paymentId, reason: 'تصحيح');
      await pay(900.10);
      await pay(100.20);
      final backup = await helper.exportBackupData();
      await helper.clearLocalData();
      await helper.restoreBackupData(backup);
      expect(await helper.queryAllPayments(), hasLength(3));
      expect((await helper.queryPaymentSummary(bookingId))['remaining'], 0);
    },
  );

  test('a SQL failure during restore rolls back all replaced tables', () async {
    await pay(300);
    final original = await helper.exportBackupData();
    final backup = clone(original);
    (rows(backup, 'renters').single as Map)['rating'] = 10;
    await expectLater(
      helper.restoreBackupData(backup),
      throwsA(isA<DatabaseException>()),
    );
    expect((await helper.exportBackupData())['data'], original['data']);
  });

  test(
    'cancelled and pending bookings do not occupy calendar or active count',
    () {
      final booking = {
        'start_date': '2026-09-10',
        'end_date': '2026-09-11',
        'status': 'confirmed',
      };
      expect(BookingStatusService.occupiesDay(booking, '2026-09-10'), isTrue);
      expect(BookingStatusService.isActive(booking, '2026-09-10'), isTrue);
      for (final status in ['cancelled', 'pending']) {
        final other = {...booking, 'status': status};
        expect(BookingStatusService.occupiesDay(other, '2026-09-10'), isFalse);
        expect(BookingStatusService.isActive(other, '2026-09-10'), isFalse);
      }
      expect(BookingStatusService.isActive(booking, '2026-09-12'), isFalse);
    },
  );

  test(
    'rejects non-finite and invalid date input through regular writes',
    () async {
      for (final amount in [double.nan, double.infinity, -1.0, 0.001]) {
        await expectLater(pay(amount), throwsArgumentError);
      }
      await expectLater(
        helper.insertBooking({
          'phone': '0500000000',
          'start_date': '2026-02-30',
          'end_date': '2026-03-02',
          'total_price': 100,
        }),
        throwsArgumentError,
      );
    },
  );
}
