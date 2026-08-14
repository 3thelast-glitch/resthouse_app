import '../database_helper.dart';

enum OperationsTaskType { pendingDeposit, outstandingBalance, arrivalToday }

class OperationsTask {
  const OperationsTask({
    required this.id,
    required this.type,
    required this.bookingId,
    required this.title,
    required this.amount,
  });

  final String id;
  final OperationsTaskType type;
  final int bookingId;
  final String title;
  final double amount;
}

class OperationsTaskService {
  const OperationsTaskService._();

  static List<OperationsTask> calculate({
    required Iterable<Map<String, dynamic>> bookings,
    required Iterable<Map<String, dynamic>> payments,
    DateTime? now,
  }) {
    final referenceDate = now ?? DateTime.now();
    final today = _dateKey(referenceDate);
    final paymentsByBooking = <int, double>{};
    for (final payment in payments) {
      final bookingId = payment['booking_id'];
      if (bookingId is! int) continue;
      paymentsByBooking[bookingId] =
          (paymentsByBooking[bookingId] ?? 0) +
          ((payment['amount'] as num?)?.toDouble() ?? 0);
    }

    final tasks = <OperationsTask>[];
    for (final booking in bookings) {
      if (booking['status'] != DatabaseHelper.statusConfirmed) continue;
      final bookingId = booking['id'];
      if (bookingId is! int) continue;
      final total = (booking['total_price'] as num?)?.toDouble() ?? 0;
      final paid = paymentsByBooking[bookingId] ?? 0;
      final remaining = total - paid;
      final endDate = booking['end_date']?.toString() ?? '';
      final startDate = booking['start_date']?.toString() ?? '';
      final deposit = (booking['security_deposit'] as num?)?.toDouble() ?? 0;

      if (remaining > 0) {
        tasks.add(
          OperationsTask(
            id: 'balance-$bookingId',
            type: OperationsTaskType.outstandingBalance,
            bookingId: bookingId,
            title: 'رصيد مستحق للحجز #$bookingId',
            amount: remaining,
          ),
        );
      }
      if (endDate.compareTo(today) < 0 &&
          deposit > 0 &&
          booking['deposit_status'] == DatabaseHelper.depositPending) {
        tasks.add(
          OperationsTask(
            id: 'deposit-$bookingId',
            type: OperationsTaskType.pendingDeposit,
            bookingId: bookingId,
            title: 'تأمين بانتظار التسوية للحجز #$bookingId',
            amount: deposit,
          ),
        );
      }
      if (startDate == today) {
        tasks.add(
          OperationsTask(
            id: 'arrival-$bookingId',
            type: OperationsTaskType.arrivalToday,
            bookingId: bookingId,
            title: 'حجز يبدأ اليوم #$bookingId',
            amount: 0,
          ),
        );
      }
    }

    return tasks;
  }

  static String _dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
