import 'package:flutter_test/flutter_test.dart';
import 'package:resthouse_app/services/operations_task_service.dart';

void main() {
  test('ينشئ مهام الرصيد والتأمين والوصول للحجوزات المؤكدة فقط', () {
    final tasks = OperationsTaskService.calculate(
      now: DateTime(2026, 8, 10),
      bookings: [
        {
          'id': 1,
          'status': 'confirmed',
          'total_price': 1000.0,
          'security_deposit': 200.0,
          'deposit_status': 'pending',
          'start_date': '2026-08-10',
          'end_date': '2026-08-09',
        },
        {
          'id': 2,
          'status': 'cancelled',
          'total_price': 1000.0,
          'security_deposit': 500.0,
          'deposit_status': 'pending',
          'start_date': '2026-08-10',
          'end_date': '2026-08-09',
        },
      ],
      payments: [
        {'booking_id': 1, 'amount': 400.0},
      ],
    );

    expect(tasks, hasLength(3));
    expect(
      tasks
          .where((task) => task.type == OperationsTaskType.outstandingBalance)
          .single
          .amount,
      600.0,
    );
    expect(
      tasks
          .where((task) => task.type == OperationsTaskType.pendingDeposit)
          .single
          .amount,
      200.0,
    );
    expect(
      tasks.where((task) => task.type == OperationsTaskType.arrivalToday),
      hasLength(1),
    );
  });

  test('ينشئ مهمة مغادرة للحجوزات المؤكدة المنتهية اليوم فقط', () {
    final tasks = OperationsTaskService.calculate(
      now: DateTime(2026, 8, 10),
      bookings: [
        {
          'id': 10,
          'status': 'confirmed',
          'total_price': 0.0,
          'security_deposit': 0.0,
          'deposit_status': 'pending',
          'start_date': '2026-08-08',
          'end_date': '2026-08-10',
        },
        {
          'id': 11,
          'status': 'confirmed',
          'total_price': 0.0,
          'security_deposit': 0.0,
          'deposit_status': 'pending',
          'start_date': '2026-08-10',
          'end_date': '2026-08-11',
        },
        {
          'id': 12,
          'status': 'pending',
          'total_price': 0.0,
          'security_deposit': 0.0,
          'deposit_status': 'pending',
          'start_date': '2026-08-08',
          'end_date': '2026-08-10',
        },
        {
          'id': 13,
          'status': 'confirmed',
          'total_price': 0.0,
          'security_deposit': 0.0,
          'deposit_status': 'pending',
          'start_date': '2026-08-10',
          'end_date': '2026-08-10',
        },
      ],
      payments: const [],
    );

    final departures = tasks
        .where((task) => task.type == OperationsTaskType.departureToday)
        .toList();
    expect(departures, hasLength(2));
    expect(
      departures.map((task) => task.id),
      containsAll(['departure-10', 'departure-13']),
    );
    // The same-day booking (13) also arrives today; nothing else is due.
    expect(
      tasks.where((task) => task.type == OperationsTaskType.arrivalToday),
      hasLength(2),
    );
    expect(tasks, hasLength(4));
  });
}
