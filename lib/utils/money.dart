/// Money is calculated in integer halalas. The existing database and JSON
/// format retain riyal values so older installations and backups stay readable.
class Money {
  const Money._();

  static int toMinor(num value) {
    if (!value.isFinite || value.abs() > 9000000000000) {
      throw ArgumentError('قيمة المبلغ غير صالحة.');
    }
    return (value * 100).round();
  }

  static double fromMinor(int value) => value / 100;

  static double normalize(num value) => fromMinor(toMinor(value));

  static int sumMinor(Iterable<Map<String, dynamic>> rows, String field) =>
      rows.fold<int>(0, (sum, row) => sum + toMinor((row[field] as num?) ?? 0));
}
