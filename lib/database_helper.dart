import 'package:hijri/hijri_calendar.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DemoDataDeletionResult {
  const DemoDataDeletionResult({
    required this.deletedPayments,
    required this.deletedBookings,
    required this.deletedRenters,
    required this.deletedExpenses,
  });

  final int deletedPayments;
  final int deletedBookings;
  final int deletedRenters;
  final int deletedExpenses;

  int get totalDeleted =>
      deletedPayments + deletedBookings + deletedRenters + deletedExpenses;
}

class LocalDataClearResult {
  const LocalDataClearResult({
    required this.deletedPayments,
    required this.deletedBookings,
    required this.deletedRenters,
    required this.deletedExpenses,
    required this.deletedAuditEvents,
  });

  final int deletedPayments;
  final int deletedBookings;
  final int deletedRenters;
  final int deletedExpenses;
  final int deletedAuditEvents;

  int get totalDeleted =>
      deletedPayments +
      deletedBookings +
      deletedRenters +
      deletedExpenses +
      deletedAuditEvents;
}

class DatabaseHelper {
  static const _databaseName = 'resthouse.db';
  static const _databaseVersion = 8;
  static const backupSchemaVersion = 1;

  static const tableRenters = 'renters';
  static const tableBookings = 'bookings';
  static const tableExpenses = 'expenses';
  static const tablePayments = 'payments';
  static const tableAuditEvents = 'audit_events';

  static const statusConfirmed = 'confirmed';
  static const statusPending = 'pending';
  static const statusCancelled = 'cancelled';

  static const depositPending = 'pending';
  static const depositReturned = 'returned';
  static const depositDeducted = 'deducted';

  static const _demoSeedRows = <Map<String, Object>>[
    {
      'customerName': 'أماني المطيري',
      'hijriDate': '13 محرم 1448',
      'price': 900.0,
      'insurance': 300.0,
      'phone': '0511111113',
    },
    {
      'customerName': 'الراشد',
      'hijriDate': '18 محرم 1448',
      'price': 1500.0,
      'insurance': 500.0,
      'phone': '0511111114',
    },
    {
      'customerName': 'العليان',
      'hijriDate': '19 محرم 1448',
      'price': 950.0,
      'insurance': 300.0,
      'phone': '0511111115',
    },
    {
      'customerName': 'محمد المطيري',
      'hijriDate': '29 محرم 1448',
      'price': 900.0,
      'insurance': 300.0,
      'phone': '0511111116',
    },
    {
      'customerName': 'العايد عبد الرحمن',
      'hijriDate': '5 صفر 1448',
      'price': 950.0,
      'insurance': 300.0,
      'phone': '0511111117',
    },
    {
      'customerName': 'هند عبدالله المصري',
      'hijriDate': '1 شوال 1448',
      'price': 3500.0,
      'insurance': 0.0,
      'phone': '0511111118',
    },
    {
      'customerName': 'نوف البقمي',
      'hijriDate': '3 شوال 1448',
      'price': 0.0,
      'insurance': 0.0,
      'phone': '0511111119',
    },
  ];

  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;
  String? _databasePathOverride;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<String> _resolveDatabasePath() async {
    return _databasePathOverride ??
        join(await getDatabasesPath(), _databaseName);
  }

  Future<Database> _initDatabase() async {
    final path = await _resolveDatabasePath();
    return openDatabase(
      path,
      version: _databaseVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableRenters (
        phone TEXT PRIMARY KEY NOT NULL,
        full_name TEXT NOT NULL,
        notes TEXT,
        rating INTEGER NOT NULL DEFAULT 0 CHECK (rating BETWEEN 0 AND 5),
        rental_count INTEGER NOT NULL DEFAULT 0,
        is_demo INTEGER NOT NULL DEFAULT 0 CHECK (is_demo IN (0, 1))
      )
    ''');

    await _createBookingsTable(db);

    await db.execute('''
      CREATE TABLE $tableExpenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        description TEXT,
        amount REAL NOT NULL CHECK (amount > 0),
        date TEXT NOT NULL,
        category TEXT NOT NULL DEFAULT 'مصاريف تشغيلية أخرى',
        is_demo INTEGER NOT NULL DEFAULT 0 CHECK (is_demo IN (0, 1))
      )
    ''');

    await _createPaymentsTable(db);
    await _createAuditEventsTable(db);
    await _createIndexes(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _addColumnIfMissing(
        db,
        tableBookings,
        'security_deposit',
        'security_deposit REAL NOT NULL DEFAULT 0.0',
      );
    }

    if (oldVersion < 3) {
      await _addColumnIfMissing(
        db,
        tableBookings,
        'deposit_status',
        "deposit_status TEXT NOT NULL DEFAULT '$depositPending'",
      );
      await _addColumnIfMissing(
        db,
        tableExpenses,
        'category',
        "category TEXT NOT NULL DEFAULT 'مصاريف تشغيلية أخرى'",
      );
    }

    if (oldVersion < 4) {
      await _migrateBookingsForeignKey(db);
    }

    if (oldVersion < 5) {
      await _createPaymentsTable(db);
    }

    if (oldVersion < 6) {
      await _createAuditEventsTable(db);
    }

    if (oldVersion < 7) {
      await _addColumnIfMissing(
        db,
        tablePayments,
        'status',
        "status TEXT NOT NULL DEFAULT 'confirmed'",
      );
      await _addColumnIfMissing(
        db,
        tablePayments,
        'voided_at',
        'voided_at TEXT',
      );
      await _addColumnIfMissing(
        db,
        tablePayments,
        'void_reason',
        'void_reason TEXT',
      );
    }

    if (oldVersion < 8) {
      await _addColumnIfMissing(
        db,
        tableRenters,
        'is_demo',
        'is_demo INTEGER NOT NULL DEFAULT 0 CHECK (is_demo IN (0, 1))',
      );
      await _addColumnIfMissing(
        db,
        tableBookings,
        'is_demo',
        'is_demo INTEGER NOT NULL DEFAULT 0 CHECK (is_demo IN (0, 1))',
      );
      await _addColumnIfMissing(
        db,
        tableExpenses,
        'is_demo',
        'is_demo INTEGER NOT NULL DEFAULT 0 CHECK (is_demo IN (0, 1))',
      );
      await _addColumnIfMissing(
        db,
        tablePayments,
        'is_demo',
        'is_demo INTEGER NOT NULL DEFAULT 0 CHECK (is_demo IN (0, 1))',
      );
      await _markLegacyDemoData(db);
    }

    await _recalculateRentalCounts(db);
    await _createIndexes(db);
  }

  Future<void> _addColumnIfMissing(
    DatabaseExecutor db,
    String table,
    String column,
    String definition,
  ) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    final exists = columns.any((item) => item['name'] == column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $definition');
    }
  }

  Future<void> _createBookingsTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE $tableBookings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        phone TEXT NOT NULL,
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        total_price REAL NOT NULL CHECK (total_price >= 0),
        security_deposit REAL NOT NULL DEFAULT 0.0 CHECK (security_deposit >= 0),
        status TEXT NOT NULL DEFAULT '$statusConfirmed'
          CHECK (status IN ('$statusConfirmed', '$statusPending', '$statusCancelled')),
        deposit_status TEXT NOT NULL DEFAULT '$depositPending'
          CHECK (deposit_status IN ('$depositPending', '$depositReturned', '$depositDeducted')),
        is_demo INTEGER NOT NULL DEFAULT 0 CHECK (is_demo IN (0, 1)),
        FOREIGN KEY (phone) REFERENCES $tableRenters(phone)
          ON UPDATE CASCADE ON DELETE RESTRICT
      )
    ''');
  }

  Future<void> _migrateBookingsForeignKey(Database db) async {
    const legacyTable = '${tableBookings}_legacy_v3';
    await db.execute('DROP INDEX IF EXISTS idx_bookings_dates_status');
    await db.execute('DROP INDEX IF EXISTS idx_bookings_phone');
    await db.execute('ALTER TABLE $tableBookings RENAME TO $legacyTable');

    // قواعد البيانات القديمة كانت تسمح بحجوزات بلا مستأجر بعد الحذف.
    // ننشئ سجلات محافظة مؤقتة بدل إسقاط أي حجز أثناء الترقية.
    await db.execute('''
      INSERT OR IGNORE INTO $tableRenters (phone, full_name, notes, rating, rental_count)
      SELECT DISTINCT legacy.phone,
        'مستأجر مستورد غير معروف',
        'تم إنشاء السجل تلقائياً أثناء ترقية قاعدة البيانات للحفاظ على حجز قديم.',
        0,
        0
      FROM $legacyTable legacy
      LEFT JOIN $tableRenters renter ON renter.phone = legacy.phone
      WHERE renter.phone IS NULL
    ''');

    await _createBookingsTable(db);
    await db.execute('''
      INSERT INTO $tableBookings (
        id, phone, start_date, end_date, total_price, security_deposit, status, deposit_status
      )
      SELECT
        id,
        phone,
        start_date,
        end_date,
        CASE WHEN total_price < 0 THEN 0 ELSE total_price END,
        CASE WHEN security_deposit < 0 THEN 0 ELSE COALESCE(security_deposit, 0) END,
        CASE
          WHEN status IN ('$statusConfirmed', '$statusPending', '$statusCancelled') THEN status
          ELSE '$statusConfirmed'
        END,
        CASE
          WHEN deposit_status IN ('$depositPending', '$depositReturned', '$depositDeducted') THEN deposit_status
          ELSE '$depositPending'
        END
      FROM $legacyTable
    ''');
    await db.execute('DROP TABLE $legacyTable');
  }

  Future<void> _createPaymentsTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tablePayments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        booking_id INTEGER NOT NULL,
        amount REAL NOT NULL CHECK (amount > 0),
        paid_at TEXT NOT NULL,
        method TEXT NOT NULL DEFAULT 'cash',
        note TEXT,
        status TEXT NOT NULL DEFAULT 'confirmed',
        voided_at TEXT,
        void_reason TEXT,
        is_demo INTEGER NOT NULL DEFAULT 0 CHECK (is_demo IN (0, 1)),
        FOREIGN KEY (booking_id) REFERENCES $tableBookings(id)
          ON UPDATE CASCADE ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _createAuditEventsTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableAuditEvents (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        action TEXT NOT NULL,
        details TEXT,
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createIndexes(DatabaseExecutor db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_bookings_dates_status '
      'ON $tableBookings(start_date, end_date, status)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_bookings_phone ON $tableBookings(phone)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_expenses_date ON $tableExpenses(date)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_payments_booking ON $tablePayments(booking_id, paid_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_audit_events_created ON $tableAuditEvents(created_at DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_bookings_is_demo ON $tableBookings(is_demo)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_renters_is_demo ON $tableRenters(is_demo)',
    );
  }

  Future<void> _markLegacyDemoData(DatabaseExecutor db) async {
    // قواعد البيانات قبل الإصدار 8 لا تحمل وسمًا للبذور. لذا لا نوسم إلا
    // السجلات المطابقة تمامًا لتعريف البذر والمعزولة عن أي دفعة فعلية.
    for (final seed in _demoSeedRows) {
      final phone = seed['phone'] as String;
      final date = _parseHijriStringToGregorian(
        seed['hijriDate'] as String,
      ).toIso8601String().split('T').first;
      await db.update(
        tableBookings,
        {'is_demo': 1},
        where:
            '''
          phone = ?
          AND start_date = ?
          AND end_date = ?
          AND total_price = ?
          AND security_deposit = ?
          AND status = ?
          AND deposit_status = ?
          AND NOT EXISTS (
            SELECT 1 FROM $tablePayments payment
            WHERE payment.booking_id = $tableBookings.id
          )
        ''',
        whereArgs: [
          phone,
          date,
          date,
          seed['price'],
          seed['insurance'],
          statusConfirmed,
          depositPending,
        ],
      );
    }

    for (final seed in _demoSeedRows) {
      await db.update(
        tableRenters,
        {'is_demo': 1},
        where:
            '''
          phone = ?
          AND full_name = ?
          AND COALESCE(notes, '') = ''
          AND rating = 5
          AND NOT EXISTS (
            SELECT 1 FROM $tableBookings booking
            WHERE booking.phone = $tableRenters.phone
              AND booking.is_demo = 0
          )
        ''',
        whereArgs: [seed['phone'], seed['customerName']],
      );
    }
  }

  Future<void> _recordAudit(
    DatabaseExecutor db, {
    required String entityType,
    required Object entityId,
    required String action,
    String? details,
  }) async {
    await db.insert(tableAuditEvents, {
      'entity_type': entityType,
      'entity_id': entityId.toString(),
      'action': action,
      'details': details,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> _recalculateRentalCounts(DatabaseExecutor db) async {
    await db.execute('''
      UPDATE $tableRenters
      SET rental_count = (
        SELECT COUNT(*)
        FROM $tableBookings
        WHERE $tableBookings.phone = $tableRenters.phone
          AND status != '$statusCancelled'
      )
    ''');
  }

  Future<int> insertRenter(
    Map<String, dynamic> row, {
    bool isDemo = false,
  }) async {
    final db = await database;
    final renterRow = Map<String, dynamic>.from(row)
      ..['is_demo'] = isDemo ? 1 : 0;
    return db.insert(
      tableRenters,
      renterRow,
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<List<Map<String, dynamic>>> queryAllRenters() async {
    final db = await database;
    return db.rawQuery('''
      SELECT renter.*,
        (
          SELECT COUNT(*)
          FROM $tableBookings booking
          WHERE booking.phone = renter.phone
            AND booking.status != '$statusCancelled'
        ) AS rental_count
      FROM $tableRenters renter
      ORDER BY renter.full_name COLLATE NOCASE ASC
    ''');
  }

  Future<int> updateRenter(Map<String, dynamic> row, {String? oldPhone}) async {
    final db = await database;
    final renterRow = Map<String, dynamic>.from(row)..['is_demo'] = 0;
    final targetPhone = oldPhone ?? renterRow['phone'] as String;

    if (oldPhone != null && oldPhone != renterRow['phone']) {
      return db.transaction((txn) async {
        final updated = await txn.update(
          tableRenters,
          renterRow,
          where: 'phone = ?',
          whereArgs: [oldPhone],
        );
        if (updated == 0) {
          throw StateError('المستأجر المطلوب تعديله غير موجود.');
        }
        return updated;
      });
    }

    return db.update(
      tableRenters,
      renterRow,
      where: 'phone = ?',
      whereArgs: [targetPhone],
    );
  }

  Future<int> deleteRenter(String phone) async {
    final db = await database;
    final linkedBookings =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM $tableBookings WHERE phone = ?',
            [phone],
          ),
        ) ??
        0;

    if (linkedBookings > 0) {
      throw StateError('لا يمكن حذف المستأجر لوجود حجوزات مرتبطة به.');
    }

    return db.delete(tableRenters, where: 'phone = ?', whereArgs: [phone]);
  }

  Future<int> insertBooking(
    Map<String, dynamic> row, {
    bool isDemo = false,
  }) async {
    final bookingRow = Map<String, dynamic>.from(row)
      ..['is_demo'] = isDemo ? 1 : 0;
    _validateBooking(bookingRow);
    final db = await database;

    return db.transaction((txn) async {
      await _assertNoBookingConflict(txn, bookingRow);
      final id = await txn.insert(tableBookings, bookingRow);
      final phone = bookingRow['phone'];
      if (!isDemo && phone is String) {
        await _markRenterAsUserData(txn, phone);
      }
      await _recordAudit(
        txn,
        entityType: 'booking',
        entityId: id,
        action: 'created',
      );
      await _recalculateRentalCounts(txn);
      return id;
    });
  }

  Future<List<Map<String, dynamic>>> queryAllBookings() async {
    final db = await database;
    return db.query(tableBookings, orderBy: 'start_date DESC, id DESC');
  }

  Future<int> updateBooking(Map<String, dynamic> row) async {
    final bookingRow = Map<String, dynamic>.from(row)..['is_demo'] = 0;
    _validateBooking(bookingRow);
    final id = bookingRow['id'];
    if (id is! int) {
      throw ArgumentError.value(id, 'id', 'معرف الحجز غير صالح.');
    }

    final db = await database;
    return db.transaction((txn) async {
      await _assertNoBookingConflict(txn, bookingRow, excludeId: id);
      final updated = await txn.update(
        tableBookings,
        bookingRow,
        where: 'id = ?',
        whereArgs: [id],
      );
      if (updated > 0) {
        final phone = bookingRow['phone'];
        if (phone is String) {
          await _markRenterAsUserData(txn, phone);
        }
        await _recordAudit(
          txn,
          entityType: 'booking',
          entityId: id,
          action: 'updated',
        );
      }
      await _recalculateRentalCounts(txn);
      return updated;
    });
  }

  Future<int> deleteBooking(int id) async {
    final db = await database;
    return db.transaction((txn) async {
      await _recordAudit(
        txn,
        entityType: 'booking',
        entityId: id,
        action: 'deleted',
      );
      final deleted = await txn.delete(
        tableBookings,
        where: 'id = ?',
        whereArgs: [id],
      );
      await _recalculateRentalCounts(txn);
      return deleted;
    });
  }

  Future<bool> hasBookingConflict(
    String startDate,
    String endDate, {
    int? excludeId,
  }) async {
    final db = await database;
    return _hasBookingConflict(db, startDate, endDate, excludeId: excludeId);
  }

  Future<bool> _hasBookingConflict(
    DatabaseExecutor db,
    String startDate,
    String endDate, {
    int? excludeId,
  }) async {
    var query =
        '''
      SELECT COUNT(*) AS count FROM $tableBookings
      WHERE status = '$statusConfirmed'
        AND start_date <= ?
        AND end_date >= ?
    ''';
    final args = <Object?>[endDate, startDate];
    if (excludeId != null) {
      query += ' AND id != ?';
      args.add(excludeId);
    }
    final result = await db.rawQuery(query, args);
    return (Sqflite.firstIntValue(result) ?? 0) > 0;
  }

  Future<void> _assertNoBookingConflict(
    DatabaseExecutor db,
    Map<String, dynamic> row, {
    int? excludeId,
  }) async {
    final status = row['status'] ?? statusConfirmed;
    if (status != statusConfirmed) return;

    final hasConflict = await _hasBookingConflict(
      db,
      row['start_date'] as String,
      row['end_date'] as String,
      excludeId: excludeId,
    );
    if (hasConflict) {
      throw StateError('توجد حجز مؤكد آخر في الفترة المحددة.');
    }
  }

  void _validateBooking(Map<String, dynamic> row) {
    final startDate = row['start_date'];
    final endDate = row['end_date'];
    final totalPrice = row['total_price'];
    final securityDeposit = row['security_deposit'] ?? 0;
    final status = row['status'] ?? statusConfirmed;

    if (startDate is! String ||
        endDate is! String ||
        startDate.isEmpty ||
        endDate.isEmpty) {
      throw ArgumentError('يجب إدخال تاريخ بداية ونهاية صالحين.');
    }
    if (endDate.compareTo(startDate) < 0) {
      throw ArgumentError(
        'تاريخ النهاية يجب أن يكون بعد أو مساويًا لتاريخ البداية.',
      );
    }
    if (totalPrice is! num || totalPrice < 0) {
      throw ArgumentError('إجمالي سعر الحجز غير صالح.');
    }
    if (securityDeposit is! num || securityDeposit < 0) {
      throw ArgumentError('قيمة التأمين غير صالحة.');
    }
    if (![statusConfirmed, statusPending, statusCancelled].contains(status)) {
      throw ArgumentError('حالة الحجز غير صالحة.');
    }
  }

  /// Returns ended, confirmed bookings with a positive unresolved deposit.
  Future<List<Map<String, dynamic>>>
  queryEndedBookingsWithPendingDeposit() async {
    final db = await database;
    final today = DateTime.now();
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    return db.query(
      tableBookings,
      where: '''
        end_date < ?
        AND deposit_status = ?
        AND status = ?
        AND security_deposit > 0
      ''',
      whereArgs: [todayStr, depositPending, statusConfirmed],
      orderBy: 'end_date ASC',
    );
  }

  Future<int> updateDepositStatus(int bookingId, String status) async {
    if (![depositPending, depositReturned, depositDeducted].contains(status)) {
      throw ArgumentError.value(status, 'status', 'حالة التأمين غير صالحة.');
    }

    final db = await database;
    return db.transaction((txn) async {
      final updated = await txn.update(
        tableBookings,
        {'deposit_status': status, 'is_demo': 0},
        where: 'id = ?',
        whereArgs: [bookingId],
      );
      if (updated > 0) {
        await txn.execute(
          '''
          UPDATE $tableRenters
          SET is_demo = 0
          WHERE phone = (
            SELECT phone FROM $tableBookings WHERE id = ?
          )
          ''',
          [bookingId],
        );
        await _recordAudit(
          txn,
          entityType: 'deposit',
          entityId: bookingId,
          action: status,
        );
      }
      return updated;
    });
  }

  Future<int> insertPayment(Map<String, dynamic> row) async {
    final paymentRow = Map<String, dynamic>.from(row)..['is_demo'] = 0;
    final bookingId = paymentRow['booking_id'];
    final amount = paymentRow['amount'];
    final paidAt = paymentRow['paid_at'];
    if (bookingId is! int ||
        amount is! num ||
        amount <= 0 ||
        paidAt is! String ||
        paidAt.isEmpty) {
      throw ArgumentError('بيانات الدفعة غير صالحة.');
    }

    final db = await database;
    return db.transaction((txn) async {
      final bookingRows = await txn.query(
        tableBookings,
        columns: ['total_price', 'phone'],
        where: 'id = ?',
        whereArgs: [bookingId],
      );
      if (bookingRows.isEmpty) {
        throw StateError('الحجز المرتبط بالدفعة غير موجود.');
      }
      final totalPrice = (bookingRows.single['total_price'] as num).toDouble();
      final paidResult = await txn.rawQuery(
        "SELECT COALESCE(SUM(amount), 0) AS paid FROM $tablePayments WHERE booking_id = ? AND status = 'confirmed'",
        [bookingId],
      );
      final paid = (paidResult.single['paid'] as num).toDouble();
      if (paid + amount > totalPrice) {
        throw ArgumentError('لا يمكن أن تتجاوز الدفعات إجمالي قيمة الحجز.');
      }
      final id = await txn.insert(tablePayments, paymentRow);
      await txn.update(
        tableBookings,
        {'is_demo': 0},
        where: 'id = ?',
        whereArgs: [bookingId],
      );
      final phone = bookingRows.single['phone'];
      if (phone is String) {
        await _markRenterAsUserData(txn, phone);
      }
      await _recordAudit(
        txn,
        entityType: 'payment',
        entityId: id,
        action: 'created',
        details: 'booking_id=$bookingId; amount=$amount',
      );
      return id;
    });
  }

  Future<List<Map<String, dynamic>>> queryPaymentsForBooking(
    int bookingId,
  ) async {
    final db = await database;
    return db.query(
      tablePayments,
      where: "booking_id = ? AND status = 'confirmed'",
      whereArgs: [bookingId],
      orderBy: 'paid_at DESC, id DESC',
    );
  }

  Future<List<Map<String, dynamic>>> queryAllPayments() async {
    final db = await database;
    return db.query(tablePayments, orderBy: 'paid_at DESC, id DESC');
  }

  Future<Map<String, double>> queryPaymentSummary(int bookingId) async {
    final db = await database;
    final rows = await db.rawQuery(
      '''
      SELECT b.total_price AS total, COALESCE(SUM(p.amount), 0) AS paid
      FROM $tableBookings b
      LEFT JOIN $tablePayments p ON p.booking_id = b.id
        AND p.status = 'confirmed'
      WHERE b.id = ?
      GROUP BY b.id
    ''',
      [bookingId],
    );
    if (rows.isEmpty) throw StateError('الحجز غير موجود.');
    final total = (rows.single['total'] as num).toDouble();
    final paid = (rows.single['paid'] as num).toDouble();
    return {'total': total, 'paid': paid, 'remaining': total - paid};
  }

  Future<int> deletePayment(int paymentId) async {
    final db = await database;
    return db.transaction((txn) async {
      final deleted = await txn.delete(
        tablePayments,
        where: 'id = ?',
        whereArgs: [paymentId],
      );
      if (deleted > 0) {
        await _recordAudit(
          txn,
          entityType: 'payment',
          entityId: paymentId,
          action: 'deleted',
        );
      }
      return deleted;
    });
  }

  Future<List<Map<String, dynamic>>> queryRecentAuditEvents({
    int limit = 100,
  }) async {
    final db = await database;
    return db.query(
      tableAuditEvents,
      orderBy: 'created_at DESC, id DESC',
      limit: limit,
    );
  }

  Future<int> voidPayment(int paymentId, {required String reason}) async {
    if (reason.trim().isEmpty) {
      throw ArgumentError('سبب إلغاء الدفعة مطلوب.');
    }
    final db = await database;
    return db.transaction((txn) async {
      return txn.update(
        tablePayments,
        {
          'status': 'voided',
          'voided_at': DateTime.now().toUtc().toIso8601String(),
          'void_reason': reason.trim(),
          'is_demo': 0,
        },
        where: "id = ? AND status = 'confirmed'",
        whereArgs: [paymentId],
      );
    });
  }

  Future<void> _markRenterAsUserData(DatabaseExecutor db, String phone) async {
    await db.update(
      tableRenters,
      {'is_demo': 0},
      where: 'phone = ?',
      whereArgs: [phone],
    );
  }

  Future<DemoDataDeletionResult> deleteDemoData() async {
    final db = await database;
    return db.transaction((txn) async {
      // الحذف لا يستهدف أي سجل إلا إذا حمل وسم البيانات التجريبية صراحةً.
      final deletedPayments = await txn.delete(
        tablePayments,
        where:
            'booking_id IN (SELECT id FROM $tableBookings WHERE is_demo = 1)',
      );
      final deletedBookings = await txn.delete(
        tableBookings,
        where: 'is_demo = 1',
      );
      await txn.execute('''
        UPDATE $tableRenters
        SET is_demo = 0
        WHERE is_demo = 1
          AND EXISTS (
            SELECT 1 FROM $tableBookings booking
            WHERE booking.phone = $tableRenters.phone
              AND booking.is_demo = 0
          )
      ''');
      final deletedRenters = await txn.delete(
        tableRenters,
        where:
            '''
          is_demo = 1
          AND NOT EXISTS (
            SELECT 1 FROM $tableBookings booking
            WHERE booking.phone = $tableRenters.phone
          )
        ''',
      );
      final deletedExpenses = await txn.delete(
        tableExpenses,
        where: 'is_demo = 1',
      );
      await _recalculateRentalCounts(txn);

      final result = DemoDataDeletionResult(
        deletedPayments: deletedPayments,
        deletedBookings: deletedBookings,
        deletedRenters: deletedRenters,
        deletedExpenses: deletedExpenses,
      );
      if (result.totalDeleted > 0) {
        await _recordAudit(
          txn,
          entityType: 'demo_data',
          entityId: 'cleanup',
          action: 'deleted',
          details: 'total=${result.totalDeleted}',
        );
      }
      return result;
    });
  }

  Future<LocalDataClearResult> clearLocalData() async {
    final db = await database;
    return db.transaction((txn) async {
      final deletedPayments = await txn.delete(tablePayments);
      final deletedBookings = await txn.delete(tableBookings);
      final deletedExpenses = await txn.delete(tableExpenses);
      final deletedRenters = await txn.delete(tableRenters);
      final deletedAuditEvents = await txn.delete(tableAuditEvents);

      return LocalDataClearResult(
        deletedPayments: deletedPayments,
        deletedBookings: deletedBookings,
        deletedRenters: deletedRenters,
        deletedExpenses: deletedExpenses,
        deletedAuditEvents: deletedAuditEvents,
      );
    });
  }

  Future<String> getDatabasePath() => _resolveDatabasePath();

  Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  Future<void> resetDatabase() async {
    await closeDatabase();
    _database = await _initDatabase();
  }

  Future<void> configureDatabasePathForTesting(String path) async {
    await closeDatabase();
    _databasePathOverride = path;
  }

  Future<void> clearTestingDatabase() async {
    final path = _databasePathOverride;
    if (path == null) {
      throw StateError('لا يوجد مسار قاعدة اختبار مهيأ.');
    }
    await closeDatabase();
    await deleteDatabase(path);
  }

  Future<int> insertExpense(Map<String, dynamic> row) async {
    final amount = row['amount'];
    if (amount is! num || amount <= 0) {
      throw ArgumentError('قيمة المصروف يجب أن تكون أكبر من صفر.');
    }
    final db = await database;
    final expenseRow = Map<String, dynamic>.from(row)..['is_demo'] = 0;
    return db.insert(tableExpenses, expenseRow);
  }

  Future<List<Map<String, dynamic>>> queryAllExpenses() async {
    final db = await database;
    return db.query(tableExpenses, orderBy: 'date DESC, id DESC');
  }

  Future<int> updateExpense(Map<String, dynamic> row) async {
    final id = row['id'];
    final amount = row['amount'];
    if (id is! int || amount is! num || amount <= 0) {
      throw ArgumentError('بيانات المصروف غير صالحة.');
    }
    final db = await database;
    final expenseRow = Map<String, dynamic>.from(row)..['is_demo'] = 0;
    return db.update(
      tableExpenses,
      expenseRow,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteExpense(int id) async {
    final db = await database;
    return db.delete(tableExpenses, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<String>> getDistinctExpenseDescriptions() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT DISTINCT description
      FROM $tableExpenses
      WHERE description IS NOT NULL AND description != ''
      ORDER BY description ASC
    ''');
    return result.map((row) => row['description'] as String).toList();
  }

  Future<Map<String, dynamic>> exportBackupData() async {
    final db = await database;
    final renters = await db.query(tableRenters, orderBy: 'phone ASC');
    final bookings = await db.query(tableBookings, orderBy: 'id ASC');
    final expenses = await db.query(tableExpenses, orderBy: 'id ASC');
    final payments = await db.query(tablePayments, orderBy: 'id ASC');

    return {
      'app': 'resthouse_app',
      'schemaVersion': backupSchemaVersion,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'data': {
        tableRenters: renters,
        tableBookings: bookings,
        tableExpenses: expenses,
        tablePayments: payments,
      },
    };
  }

  Future<void> restoreBackupData(Map<String, dynamic> backup) async {
    final backupData = _validateBackup(backup);
    final renters = _rowsFromBackup(backupData[tableRenters], tableRenters);
    final bookings = _rowsFromBackup(backupData[tableBookings], tableBookings);
    final expenses = _rowsFromBackup(backupData[tableExpenses], tableExpenses);
    final payments = _rowsFromBackup(
      backupData[tablePayments] ?? const [],
      tablePayments,
    );

    _validateBackupRows(renters, bookings, expenses, payments);

    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(tablePayments);
      await txn.delete(tableBookings);
      await txn.delete(tableExpenses);
      await txn.delete(tableRenters);

      final batch = txn.batch();
      for (final renter in renters) {
        final row = Map<String, dynamic>.from(renter)..remove('rental_count');
        batch.insert(
          tableRenters,
          row,
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      }
      for (final booking in bookings) {
        batch.insert(
          tableBookings,
          booking,
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      }
      for (final expense in expenses) {
        batch.insert(
          tableExpenses,
          expense,
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      }
      for (final payment in payments) {
        batch.insert(
          tablePayments,
          payment,
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      }
      await batch.commit(noResult: true);

      await _recalculateRentalCounts(txn);
      final violations = await txn.rawQuery('PRAGMA foreign_key_check');
      if (violations.isNotEmpty) {
        throw StateError('النسخة الاحتياطية تحتوي علاقات بيانات غير صالحة.');
      }
    });
  }

  Map<String, dynamic> _validateBackup(Map<String, dynamic> backup) {
    if (backup['app'] != 'resthouse_app') {
      throw const FormatException(
        'الملف ليس نسخة احتياطية لتطبيق إدارة الاستراحات.',
      );
    }
    if (backup['schemaVersion'] != backupSchemaVersion) {
      throw const FormatException('إصدار النسخة الاحتياطية غير مدعوم.');
    }
    final data = backup['data'];
    if (data is! Map) {
      throw const FormatException('بنية بيانات النسخة الاحتياطية غير صالحة.');
    }
    final normalized = Map<String, dynamic>.from(data);
    normalized.putIfAbsent(tablePayments, () => <Object>[]);
    for (final table in [
      tableRenters,
      tableBookings,
      tableExpenses,
      tablePayments,
    ]) {
      if (normalized[table] is! List) {
        throw FormatException(
          'النسخة الاحتياطية لا تحتوي بيانات $table بشكل صالح.',
        );
      }
    }
    return normalized;
  }

  List<Map<String, dynamic>> _rowsFromBackup(Object? rawRows, String table) {
    if (rawRows is! List) {
      throw FormatException('بيانات جدول $table غير صالحة.');
    }
    return rawRows.map((row) {
      if (row is! Map) {
        throw FormatException('أحد سجلات جدول $table غير صالح.');
      }
      return Map<String, dynamic>.from(row);
    }).toList();
  }

  void _validateBackupRows(
    List<Map<String, dynamic>> renters,
    List<Map<String, dynamic>> bookings,
    List<Map<String, dynamic>> expenses,
    List<Map<String, dynamic>> payments,
  ) {
    final renterPhones = <String>{};
    for (final renter in renters) {
      final phone = renter['phone'];
      final fullName = renter['full_name'];
      if (phone is! String ||
          phone.isEmpty ||
          fullName is! String ||
          fullName.trim().isEmpty) {
        throw const FormatException(
          'بيانات المستأجرين في النسخة الاحتياطية غير صالحة.',
        );
      }
      if (!renterPhones.add(phone)) {
        throw const FormatException(
          'تحتوي النسخة الاحتياطية على رقم مستأجر مكرر.',
        );
      }
    }

    for (final booking in bookings) {
      final phone = booking['phone'];
      if (phone is! String || !renterPhones.contains(phone)) {
        throw const FormatException('يوجد حجز غير مرتبط بمستأجر صالح.');
      }
      _validateBooking(booking);
      final depositStatus = booking['deposit_status'] ?? depositPending;
      if (![
        depositPending,
        depositReturned,
        depositDeducted,
      ].contains(depositStatus)) {
        throw const FormatException(
          'تحتوي النسخة الاحتياطية على حالة تأمين غير صالحة.',
        );
      }
    }

    for (final expense in expenses) {
      final amount = expense['amount'];
      final date = expense['date'];
      if (amount is! num || amount <= 0 || date is! String || date.isEmpty) {
        throw const FormatException(
          'بيانات المصروفات في النسخة الاحتياطية غير صالحة.',
        );
      }
    }

    final bookingIds = bookings
        .map((booking) => booking['id'])
        .whereType<int>()
        .toSet();
    for (final payment in payments) {
      final bookingId = payment['booking_id'];
      final amount = payment['amount'];
      final paidAt = payment['paid_at'];
      if (bookingId is! int ||
          !bookingIds.contains(bookingId) ||
          amount is! num ||
          amount <= 0 ||
          paidAt is! String ||
          paidAt.isEmpty) {
        throw const FormatException(
          'بيانات الدفعات في النسخة الاحتياطية غير صالحة.',
        );
      }
    }
  }

  DateTime _parseHijriStringToGregorian(String hijriDate) {
    final parts = hijriDate.trim().split(' ');
    if (parts.length < 3) {
      throw FormatException('Invalid Hijri date format: $hijriDate');
    }

    final day = int.parse(parts.first);
    final monthName = parts.sublist(1, parts.length - 1).join(' ');
    final year = int.parse(parts.last);
    const monthNames = <String, int>{
      'محرم': 1,
      'صفر': 2,
      'ربيع الأول': 3,
      'ربيع الآخر': 4,
      'جمادى الأولى': 5,
      'جمادى الآخرة': 6,
      'رجب': 7,
      'شعبان': 8,
      'رمضان': 9,
      'شوال': 10,
      'ذو القعدة': 11,
      'ذو الحجة': 12,
    };
    final month = monthNames[monthName];
    if (month == null) {
      throw FormatException('Invalid Hijri month: $monthName');
    }

    return HijriCalendar().hijriToGregorian(year, month, day);
  }
}
