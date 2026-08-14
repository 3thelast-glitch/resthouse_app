import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:hijri/hijri_calendar.dart';

class DatabaseHelper {
  static const _databaseName = "resthouse.db";
  static const _databaseVersion = 2;
  static const tableRenters = 'renters';
  static const tableBookings = 'bookings';
  static const tableExpenses = 'expenses';

  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  _initDatabase() async {
    String path = join(await getDatabasesPath(), _databaseName);
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: (db) async {
        try {
          await db.execute("ALTER TABLE $tableExpenses ADD COLUMN category TEXT DEFAULT 'مصاريف تشغيلية أخرى'");
        } catch (_) {}
        try {
          await db.execute("ALTER TABLE $tableBookings ADD COLUMN security_deposit REAL DEFAULT 0.0");
        } catch (_) {}
        try {
          await db.execute("ALTER TABLE $tableBookings ADD COLUMN deposit_status TEXT DEFAULT 'pending'");
        } catch (_) {}
      },
    );
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('DROP TABLE IF EXISTS $tableRenters');
    await db.execute('DROP TABLE IF EXISTS $tableBookings');
    await db.execute('DROP TABLE IF EXISTS $tableExpenses');
    await db.execute('''CREATE TABLE $tableRenters (phone TEXT PRIMARY KEY NOT NULL, full_name TEXT NOT NULL, notes TEXT, rating INTEGER DEFAULT 0, rental_count INTEGER DEFAULT 0)''');
    await db.execute('''CREATE TABLE $tableBookings (id INTEGER PRIMARY KEY AUTOINCREMENT, phone TEXT NOT NULL, start_date TEXT NOT NULL, end_date TEXT NOT NULL, total_price REAL NOT NULL, security_deposit REAL DEFAULT 0.0, status TEXT DEFAULT 'confirmed', deposit_status TEXT DEFAULT 'pending', FOREIGN KEY (phone) REFERENCES $tableRenters(phone))''');
    await db.execute('''CREATE TABLE $tableExpenses (id INTEGER PRIMARY KEY AUTOINCREMENT, description TEXT, amount REAL NOT NULL, date TEXT NOT NULL, category TEXT DEFAULT 'مصاريف تشغيلية أخرى')''');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute("ALTER TABLE $tableBookings ADD COLUMN security_deposit REAL DEFAULT 0.0");
      } catch (_) {}
    }
  }

  Future<int> insertRenter(Map<String, dynamic> row) async {
    Database db = await instance.database;
    return await db.insert(tableRenters, row);
  }

  Future<List<Map<String, dynamic>>> queryAllRenters() async {
    Database db = await instance.database;
    return await db.query(tableRenters);
  }

  Future<int> updateRenter(Map<String, dynamic> row, {String? oldPhone}) async {
    Database db = await instance.database;
    String targetPhone = oldPhone ?? row['phone'];
    if (oldPhone != null && oldPhone != row['phone']) {
      return await db.transaction((txn) async {
        await txn.update(tableBookings, {'phone': row['phone']}, where: 'phone = ?', whereArgs: [oldPhone]);
        return await txn.update(tableRenters, row, where: 'phone = ?', whereArgs: [oldPhone]);
      });
    }
    return await db.update(tableRenters, row, where: 'phone = ?', whereArgs: [targetPhone]);
  }

  Future<int> deleteRenter(String phone) async {
    Database db = await instance.database;
    return await db.delete(tableRenters, where: 'phone = ?', whereArgs: [phone]);
  }

  Future<int> insertBooking(Map<String, dynamic> row) async {
    Database db = await instance.database;
    return await db.transaction((txn) async {
      final id = await txn.insert(tableBookings, row);
      final phone = row['phone'];
      await txn.execute(
        'UPDATE $tableRenters SET rental_count = rental_count + 1 WHERE phone = ?',
        [phone],
      );
      return id;
    });
  }

  Future<List<Map<String, dynamic>>> queryAllBookings() async {
    Database db = await instance.database;
    return await db.query(tableBookings, orderBy: 'start_date DESC');
  }

  Future<int> updateBooking(Map<String, dynamic> row) async {
    Database db = await instance.database;
    int id = row['id'];
    return await db.update(tableBookings, row, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteBooking(int id) async {
    Database db = await instance.database;
    return await db.delete(tableBookings, where: 'id = ?', whereArgs: [id]);
  }

  Future<bool> hasBookingConflict(String startDate, String endDate, {int? excludeId}) async {
    Database db = await instance.database;
    String query = '''
      SELECT COUNT(*) as count FROM $tableBookings
      WHERE status = 'confirmed'
      AND start_date <= ? AND end_date >= ?
    ''';
    List<dynamic> args = [endDate, startDate];
    if (excludeId != null) {
      query += ' AND id != ?';
      args.add(excludeId);
    }
    final result = await db.rawQuery(query, args);
    final count = Sqflite.firstIntValue(result) ?? 0;
    return count > 0;
  }

  /// Returns all confirmed bookings whose end_date has passed and deposit_status is still 'pending'
  Future<List<Map<String, dynamic>>> queryEndedBookingsWithPendingDeposit() async {
    Database db = await instance.database;
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    return await db.query(
      tableBookings,
      where: "end_date < ? AND deposit_status = 'pending' AND status = 'confirmed'",
      whereArgs: [todayStr],
      orderBy: 'end_date ASC',
    );
  }

  /// Updates the deposit_status for a booking
  Future<int> updateDepositStatus(int bookingId, String status) async {
    Database db = await instance.database;
    return await db.update(
      tableBookings,
      {'deposit_status': status},
      where: 'id = ?',
      whereArgs: [bookingId],
    );
  }

  Future<String> getDatabasePath() async {
    return join(await getDatabasesPath(), _databaseName);
  }

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

  Future<int> insertExpense(Map<String, dynamic> row) async {
    Database db = await instance.database;
    return await db.insert(tableExpenses, row);
  }

  Future<List<Map<String, dynamic>>> queryAllExpenses() async {
    Database db = await instance.database;
    return await db.query(tableExpenses, orderBy: 'date DESC');
  }

  Future<int> updateExpense(Map<String, dynamic> row) async {
    Database db = await instance.database;
    int id = row['id'];
    return await db.update(tableExpenses, row, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteExpense(int id) async {
    Database db = await instance.database;
    return await db.delete(tableExpenses, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<String>> getDistinctExpenseDescriptions() async {
    Database db = await instance.database;
    final List<Map<String, dynamic>> result = await db.rawQuery(
      'SELECT DISTINCT description FROM $tableExpenses WHERE description IS NOT NULL AND description != "" ORDER BY description ASC'
    );
    return result.map((row) => row['description'] as String).toList();
  }

  Future<void> seedInitialData() async {
    final List<Map<String, dynamic>> importedBookings = [
      {'customerName': 'أماني المطيري', 'hijriDate': '13 محرم 1448', 'price': 900.0, 'insurance': 300.0, 'phone': '0511111113'},
      {'customerName': 'الراشد', 'hijriDate': '18 محرم 1448', 'price': 1500.0, 'insurance': 500.0, 'phone': '0511111114'},
      {'customerName': 'العليان', 'hijriDate': '19 محرم 1448', 'price': 950.0, 'insurance': 300.0, 'phone': '0511111115'},
      {'customerName': 'محمد المطيري', 'hijriDate': '29 محرم 1448', 'price': 900.0, 'insurance': 300.0, 'phone': '0511111116'},
      {'customerName': 'العايد عبد الرحمن', 'hijriDate': '5 صفر 1448', 'price': 950.0, 'insurance': 300.0, 'phone': '0511111117'},
      {'customerName': 'هند عبدالله المصري', 'hijriDate': '1 شوال 1448', 'price': 3500.0, 'insurance': 0.0, 'phone': '0511111118'},
      {'customerName': 'نوف البقمي', 'hijriDate': '3 شوال 1448', 'price': 0.0, 'insurance': 0.0, 'phone': '0511111119'},
    ];

    int monthNameToNumber(String name) {
      switch (name.trim()) {
        case 'محرم': return 1;
        case 'صفر': return 2;
        case 'ربيع الأول': return 3;
        case 'ربيع الآخر': return 4;
        case 'جمادى الأولى': return 5;
        case 'جمادى الآخرة': return 6;
        case 'رجب': return 7;
        case 'شعبان': return 8;
        case 'رمضان': return 9;
        case 'شوال': return 10;
        case 'ذو القعدة': return 11;
        case 'ذو الحجة': return 12;
        default: return 1;
      }
    }

    DateTime parseHijriStringToGregorian(String hijriStr) {
      final parts = hijriStr.trim().split(' ');
      if (parts.length < 3) {
        throw FormatException('Invalid Hijri date format: $hijriStr');
      }
      final day = int.parse(parts[0]);
      final monthName = parts.sublist(1, parts.length - 1).join(' ');
      final year = int.parse(parts.last);
      
      final month = monthNameToNumber(monthName);
      
      return HijriCalendar().hijriToGregorian(year, month, day);
    }

    for (final item in importedBookings) {
      final String customerName = item['customerName'];
      final String phone = item['phone'];
      final String hijriDate = item['hijriDate'];
      final double price = (item['price'] as num).toDouble();
      final double insurance = (item['insurance'] as num).toDouble();

      // 1. Insert renter if they don't exist
      final db = await database;
      final existingRenters = await db.query(tableRenters, where: 'phone = ?', whereArgs: [phone]);
      if (existingRenters.isEmpty) {
        await insertRenter({
          'phone': phone,
          'full_name': customerName,
          'notes': '',
          'rating': 5,
          'rental_count': 0,
        });
      }

      // 2. Parse Hijri date to Gregorian
      final DateTime date = parseHijriStringToGregorian(hijriDate);
      final String dateStr = date.toString().split(' ')[0];

      // 3. Insert Booking if it doesn't already exist for this phone and date to prevent duplicate seeding
      final existingBookings = await db.query(
        tableBookings,
        where: 'phone = ? AND start_date = ?',
        whereArgs: [phone, dateStr],
      );
      if (existingBookings.isEmpty) {
        await insertBooking({
          'phone': phone,
          'start_date': dateStr,
          'end_date': dateStr,
          'total_price': price,
          'security_deposit': insurance,
          'status': 'confirmed',
          'deposit_status': 'pending',
        });
      }
    }
  }

  Future<void> seedTenantsOnly() async {
    final List<Map<String, String>> newTenantsToSeed = [
      {'customerName': 'أماني المطيري', 'phone': '0511111113'},
      {'customerName': 'الراشد', 'phone': '0511111114'},
      {'customerName': 'العليان', 'phone': '0511111115'},
      {'customerName': 'محمد المطيري', 'phone': '0511111116'},
      {'customerName': 'العايد عبد الرحمن', 'phone': '0511111117'},
      {'customerName': 'هند عبدالله المصري', 'phone': '0511111118'},
      {'customerName': 'نوف البقمي', 'phone': '0511111119'},
    ];

    final db = await database;
    for (final item in newTenantsToSeed) {
      final String customerName = item['customerName']!;
      final String phone = item['phone']!;

      final existingRenters = await db.query(tableRenters, where: 'phone = ?', whereArgs: [phone]);
      if (existingRenters.isEmpty) {
        await insertRenter({
          'phone': phone,
          'full_name': customerName,
          'notes': '',
          'rating': 5,
          'rental_count': 0,
        });
      }
    }
  }
}
