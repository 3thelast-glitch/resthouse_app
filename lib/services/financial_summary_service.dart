// منطق موحد للتقارير: الحجوزات المؤكدة فقط، والمقبوضات الفعلية، والتأمينات غير المسوّاة.
// لا يعتمد على واجهة Flutter، لذلك يمكن اختباره وإعادة استخدامه في اللوحة والتقارير.
import '../database_helper.dart';

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
        .where((payment) => confirmedBookingIds.contains(payment['booking_id']))
        .toList();

    final revenue = _sum(confirmedBookings, 'total_price');
    final received = _sum(validPayments, 'amount');
    final expenseTotal = _sum(expenses, 'amount');
    final pendingDeposits = confirmedBookings
        .where(
          (booking) =>
              booking['deposit_status'] == DatabaseHelper.depositPending &&
              ((booking['security_deposit'] as num?)?.toDouble() ?? 0) > 0,
        )
        .fold<double>(
          0,
          (sum, booking) =>
              sum + ((booking['security_deposit'] as num?)?.toDouble() ?? 0),
        );

    return FinancialSummary(
      bookingRevenue: revenue,
      receivedPayments: received,
      outstandingBalance: revenue - received,
      pendingDeposits: pendingDeposits,
      expenses: expenseTotal,
      netCash: received - expenseTotal,
      confirmedBookings: confirmedBookings.length,
      monthlyRevenue: _monthlyTotals(
        confirmedBookings,
        'start_date',
        'total_price',
      ),
      monthlyExpenses: _monthlyTotals(expenses, 'date', 'amount'),
    );
  }

  static double _sum(Iterable<Map<String, dynamic>> rows, String field) {
    return rows.fold<double>(
      0,
      (sum, row) => sum + ((row[field] as num?)?.toDouble() ?? 0),
    );
  }

  static Map<String, double> _monthlyTotals(
    Iterable<Map<String, dynamic>> rows,
    String dateField,
    String amountField,
  ) {
    final totals = <String, double>{};
    for (final row in rows) {
      final date = row[dateField]?.toString() ?? '';
      if (date.length < 7) continue;
      final month = date.substring(0, 7);
      totals[month] =
          (totals[month] ?? 0) + ((row[amountField] as num?)?.toDouble() ?? 0);
    }
    return totals;
  }
}
