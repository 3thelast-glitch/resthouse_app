import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:resthouse_app/database_helper.dart';

void main() {
  final helper = DatabaseHelper.instance;
  late Directory temporaryDirectory;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'resthouse_db_test_',
    );
    await helper.configureDatabasePathForTesting(
      path.join(temporaryDirectory.path, 'resthouse_test.db'),
    );
  });

  tearDown(() async {
    await helper.clearTestingDatabase();
    await temporaryDirectory.delete(recursive: true);
  });

  Map<String, dynamic> renter(String phone, String name) => {
    'phone': phone,
    'full_name': name,
    'notes': '',
    'rating': 5,
  };

  Map<String, dynamic> booking({
    required String phone,
    required String startDate,
    required String endDate,
    double totalPrice = 1000,
    double securityDeposit = 0,
    String status = DatabaseHelper.statusConfirmed,
    String depositStatus = DatabaseHelper.depositPending,
  }) => {
    'phone': phone,
    'start_date': startDate,
    'end_date': endDate,
    'total_price': totalPrice,
    'security_deposit': securityDeposit,
    'status': status,
    'deposit_status': depositStatus,
  };

  int rentalCount(List<Map<String, dynamic>> renters, String phone) {
    return renters.singleWhere(
          (renter) => renter['phone'] == phone,
        )['rental_count']
        as int;
  }

  test('يرفض حجزًا مؤكدًا متداخلًا داخل معاملة قاعدة البيانات', () async {
    await helper.insertRenter(renter('0511111111', 'مستأجر أول'));
    await helper.insertBooking(
      booking(
        phone: '0511111111',
        startDate: '2026-08-10',
        endDate: '2026-08-12',
      ),
    );

    await expectLater(
      helper.insertBooking(
        booking(
          phone: '0511111111',
          startDate: '2026-08-12',
          endDate: '2026-08-14',
        ),
      ),
      throwsA(isA<StateError>()),
    );

    expect(await helper.queryAllBookings(), hasLength(1));
  });

  test('يحدّث الحجوزات عند تغيير الهاتف ويمنع حذف مستأجر ذي حجوزات', () async {
    await helper.insertRenter(renter('0511111111', 'مستأجر أول'));
    await helper.insertBooking(
      booking(
        phone: '0511111111',
        startDate: '2026-08-10',
        endDate: '2026-08-11',
      ),
    );

    await helper.updateRenter(
      renter('0522222222', 'مستأجر أول'),
      oldPhone: '0511111111',
    );

    final bookings = await helper.queryAllBookings();
    expect(bookings.single['phone'], '0522222222');
    await expectLater(
      helper.deleteRenter('0522222222'),
      throwsA(isA<StateError>()),
    );
    expect(await helper.queryAllRenters(), hasLength(1));
  });

  test('يعيد حساب مرات الاستئجار عند تغيير الحالة والحذف', () async {
    await helper.insertRenter(renter('0511111111', 'مستأجر أول'));
    final confirmedId = await helper.insertBooking(
      booking(
        phone: '0511111111',
        startDate: '2026-08-10',
        endDate: '2026-08-11',
      ),
    );
    await helper.insertBooking(
      booking(
        phone: '0511111111',
        startDate: '2026-08-10',
        endDate: '2026-08-11',
        status: DatabaseHelper.statusCancelled,
      ),
    );

    expect(rentalCount(await helper.queryAllRenters(), '0511111111'), 1);

    await helper.updateBooking({
      'id': confirmedId,
      'phone': '0511111111',
      'start_date': '2026-08-10',
      'end_date': '2026-08-11',
      'total_price': 1000.0,
      'security_deposit': 0.0,
      'status': DatabaseHelper.statusCancelled,
    });
    expect(rentalCount(await helper.queryAllRenters(), '0511111111'), 0);
  });

  test('يعرض التأمينات المنتهية المعلقة ذات القيمة الموجبة فقط', () async {
    await helper.insertRenter(renter('0511111111', 'مستأجر أول'));
    final endedDate = DateTime.now().subtract(const Duration(days: 2));
    final date =
        '${endedDate.year}-${endedDate.month.toString().padLeft(2, '0')}-${endedDate.day.toString().padLeft(2, '0')}';

    await helper.insertBooking(
      booking(
        phone: '0511111111',
        startDate: date,
        endDate: date,
        securityDeposit: 500,
      ),
    );
    await helper.insertBooking(
      booking(
        phone: '0511111111',
        startDate: date,
        endDate: date,
        securityDeposit: 0,
        status: DatabaseHelper.statusCancelled,
      ),
    );

    final pendingDeposits = await helper.queryEndedBookingsWithPendingDeposit();
    expect(pendingDeposits, hasLength(1));
    expect(pendingDeposits.single['security_deposit'], 500.0);
  });

  test('يستعيد نسخة JSON منظمة ويرفض سجلات الحجوزات اليتيمة', () async {
    await helper.insertRenter(renter('0511111111', 'مستأجر أول'));
    await helper.insertBooking(
      booking(
        phone: '0511111111',
        startDate: '2026-08-10',
        endDate: '2026-08-11',
        securityDeposit: 200,
      ),
    );
    await helper.insertExpense({
      'description': 'صيانة دورية',
      'amount': 250.0,
      'date': '2026-08-10',
      'category': 'صيانة',
    });

    final backup = await helper.exportBackupData();
    await helper.restoreBackupData({
      'app': 'resthouse_app',
      'schemaVersion': DatabaseHelper.backupSchemaVersion,
      'data': {
        DatabaseHelper.tableRenters: <Map<String, dynamic>>[],
        DatabaseHelper.tableBookings: <Map<String, dynamic>>[],
        DatabaseHelper.tableExpenses: <Map<String, dynamic>>[],
      },
    });
    expect(await helper.queryAllBookings(), isEmpty);

    await helper.restoreBackupData(backup);
    expect(await helper.queryAllRenters(), hasLength(1));
    expect(await helper.queryAllBookings(), hasLength(1));
    expect(await helper.queryAllExpenses(), hasLength(1));

    final orphanBackup = {
      'app': 'resthouse_app',
      'schemaVersion': DatabaseHelper.backupSchemaVersion,
      'data': {
        DatabaseHelper.tableRenters: <Map<String, dynamic>>[],
        DatabaseHelper.tableBookings: [
          booking(
            phone: '0599999999',
            startDate: '2026-09-01',
            endDate: '2026-09-02',
          ),
        ],
        DatabaseHelper.tableExpenses: <Map<String, dynamic>>[],
      },
    };

    await expectLater(
      helper.restoreBackupData(orphanBackup),
      throwsA(isA<FormatException>()),
    );
    expect(await helper.queryAllBookings(), hasLength(1));
  });

  test(
    'يرقي قاعدة الإصدار السابق ويحافظ على الحجوزات اليتيمة كسجلات قابلة للإدارة',
    () async {
      final databasePath = await helper.getDatabasePath();
      final legacyDatabase = await openDatabase(
        databasePath,
        version: 3,
        onCreate: (db, version) async {
          await db.execute('''
          CREATE TABLE renters (
            phone TEXT PRIMARY KEY NOT NULL,
            full_name TEXT NOT NULL,
            notes TEXT,
            rating INTEGER DEFAULT 0,
            rental_count INTEGER DEFAULT 0
          )
        ''');
          await db.execute('''
          CREATE TABLE bookings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            phone TEXT NOT NULL,
            start_date TEXT NOT NULL,
            end_date TEXT NOT NULL,
            total_price REAL NOT NULL,
            security_deposit REAL DEFAULT 0.0,
            status TEXT DEFAULT 'confirmed',
            deposit_status TEXT DEFAULT 'pending',
            FOREIGN KEY (phone) REFERENCES renters(phone)
          )
        ''');
          await db.execute('''
          CREATE TABLE expenses (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            description TEXT,
            amount REAL NOT NULL,
            date TEXT NOT NULL,
            category TEXT DEFAULT 'مصاريف تشغيلية أخرى'
          )
        ''');
        },
      );
      await legacyDatabase.insert('bookings', {
        'phone': '0599999999',
        'start_date': '2026-10-10',
        'end_date': '2026-10-11',
        'total_price': 1200.0,
        'security_deposit': 300.0,
        'status': 'confirmed',
        'deposit_status': 'pending',
      });
      await legacyDatabase.close();

      final migratedRenters = await helper.queryAllRenters();
      expect(migratedRenters, hasLength(1));
      expect(migratedRenters.single['phone'], '0599999999');
      expect(migratedRenters.single['full_name'], 'مستأجر مستورد غير معروف');

      await helper.updateRenter(
        renter('0588888888', 'مستأجر مستورد غير معروف'),
        oldPhone: '0599999999',
      );
      final migratedBookings = await helper.queryAllBookings();
      expect(migratedBookings.single['phone'], '0588888888');
      await expectLater(
        helper.deleteRenter('0588888888'),
        throwsA(isA<StateError>()),
      );
    },
  );
}
