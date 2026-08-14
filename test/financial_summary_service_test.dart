import 'package:flutter_test/flutter_test.dart';
import 'package:resthouse_app/services/financial_summary_service.dart';

void main() {
  test('يحسب المؤشرات من الحجوزات المؤكدة والدفعات الصالحة فقط', () {
    final summary = FinancialSummaryService.calculate(
      bookings: [
        {
          'id': 1,
          'status': 'confirmed',
          'total_price': 1000.0,
          'security_deposit': 200.0,
          'deposit_status': 'pending',
          'start_date': '2026-08-10',
        },
        {
          'id': 2,
          'status': 'cancelled',
          'total_price': 500.0,
          'security_deposit': 0.0,
          'deposit_status': 'pending',
          'start_date': '2026-08-10',
        },
      ],
      expenses: [
        {'amount': 100.0, 'date': '2026-08-12'},
      ],
      payments: [
        {'booking_id': 1, 'amount': 400.0, 'paid_at': '2026-08-09'},
        {'booking_id': 2, 'amount': 500.0, 'paid_at': '2026-08-09'},
      ],
    );

    expect(summary.confirmedBookings, 1);
    expect(summary.bookingRevenue, 1000.0);
    expect(summary.receivedPayments, 400.0);
    expect(summary.outstandingBalance, 600.0);
    expect(summary.pendingDeposits, 200.0);
    expect(summary.expenses, 100.0);
    expect(summary.netCash, 300.0);
    expect(summary.monthlyRevenue['2026-08'], 1000.0);
  });
}
