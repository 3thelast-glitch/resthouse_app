// منطق موحد للتقارير: الحجوزات المؤكدة فقط، والمقبوضات الفعلية، والتأمينات غير المسوّاة.
// لا يعتمد على واجهة Flutter، لذلك يمكن اختباره وإعادة استخدامه في اللوحة والتقارير.
import '../database_helper.dart';
import '../utils/money.dart';

class FinancialSummary {
  const FinancialSummary({
    required this.bookingRevenue,
    required this.receivedPayments,
    required this.outstandingBalance,
    required this.pendingDeposits,
    required this.expenses,
    required this.netCash,
    required this.confirmedBookings,
    required this.monthlyRevenue,
    required this.monthlyExpenses,
  });

  final double bookingRevenue;
  final double receivedPayments;
  final double outstandingBalance;
  final double pendingDeposits;
  final double expenses;
  final double netCash;
  final int confirmedBookings;
  final Map<String, double> monthlyRevenue;
  final Map<String, double> monthlyExpenses;
}

class FinancialSummaryService {
  const FinancialSummaryService._();

  static FinancialSummary calculate({
    required Iterable<Map<String, dynamic>> bookings,
    required Iterable<Map<String, dynamic>> expenses,
    required Iterable<Map<String, dynamic>> payments,
  }) {
    final confirmedBookings = bookings
        .where((booking) => booking['status'] == DatabaseHelper.statusConfirmed)
        .toList();
    final confirmedBookingIds = confirmedBookings
        .map((booking) => booking['id'])
        .whereType<int>()
        .toSet();
    final validPayments = payments
        .where(
          (payment) =>
              confirmedBookingIds.contains(payment['booking_id']) &&
              (payment['status'] ?? 'confirmed') == 'confirmed',
        )
        .toList();

    final revenue = Money.sumMinor(confirmedBookings, 'total_price');
    final received = Money.sumMinor(validPayments, 'amount');
    final expenseTotal = Money.sumMinor(expenses, 'amount');
    final pendingDeposits = Money.sumMinor(
      confirmedBookings.where(
        (booking) =>
            booking['deposit_status'] == DatabaseHelper.depositPending &&
            ((booking['security_deposit'] as num?)?.toDouble() ?? 0) > 0,
      ),
      'security_deposit',
    );

    return FinancialSummary(
      bookingRevenue: Money.fromMinor(revenue),
      receivedPayments: Money.fromMinor(received),
      outstandingBalance: Money.fromMinor(revenue - received),
      pendingDeposits: Money.fromMinor(pendingDeposits),
      expenses: Money.fromMinor(expenseTotal),
      netCash: Money.fromMinor(received - expenseTotal),
      confirmedBookings: confirmedBookings.length,
      monthlyRevenue: _monthlyTotals(
        confirmedBookings,
        'start_date',
        'total_price',
      ),
      monthlyExpenses: _monthlyTotals(expenses, 'date', 'amount'),
    );
  }

  static Map<String, double> _monthlyTotals(
    Iterable<Map<String, dynamic>> rows,
    String dateField,
    String amountField,
  ) {
    final totals = <String, int>{};
    for (final row in rows) {
      final date = row[dateField]?.toString() ?? '';
      if (date.length < 7) continue;
      final month = date.substring(0, 7);
      totals[month] =
          (totals[month] ?? 0) + Money.toMinor((row[amountField] as num?) ?? 0);
    }
    return totals.map((key, value) => MapEntry(key, Money.fromMinor(value)));
  }
}
