import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:resthouse_app/pages/operations_tasks_page.dart';
import 'package:resthouse_app/services/operations_task_service.dart';

const _tasks = [
  OperationsTask(
    id: 'arrival-1',
    type: OperationsTaskType.arrivalToday,
    bookingId: 1,
    title: 'حجز يبدأ اليوم #1',
    amount: 0,
  ),
  OperationsTask(
    id: 'balance-2',
    type: OperationsTaskType.outstandingBalance,
    bookingId: 2,
    title: 'رصيد مستحق للحجز #2',
    amount: 600,
  ),
  OperationsTask(
    id: 'deposit-3',
    type: OperationsTaskType.pendingDeposit,
    bookingId: 3,
    title: 'تأمين بانتظار التسوية للحجز #3',
    amount: 200,
  ),
];

void main() {
  testWidgets('يعرض المهام مجمعة حسب النوع مع المبالغ', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: OperationsTaskList(tasks: _tasks)),
      ),
    );

    // Section headers in display order.
    expect(find.text('حجوزات تبدأ اليوم'), findsOneWidget);
    expect(find.text('أرصدة مستحقة'), findsOneWidget);
    expect(find.text('تأمينات بانتظار التسوية'), findsOneWidget);

    // Task titles.
    expect(find.text('حجز يبدأ اليوم #1'), findsOneWidget);
    expect(find.text('رصيد مستحق للحجز #2'), findsOneWidget);
    expect(find.text('تأمين بانتظار التسوية للحجز #3'), findsOneWidget);

    // Amounts are shown for money tasks only.
    expect(find.text('600.00 ر.س'), findsOneWidget);
    expect(find.text('200.00 ر.س'), findsOneWidget);
    expect(find.text('0.00 ر.س'), findsNothing);

    expect(tester.takeException(), isNull);
  });

  testWidgets('يعرض حالة فراغ عند عدم وجود مهام', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: OperationsTaskList(tasks: [])),
      ),
    );

    expect(find.text('لا توجد تنبيهات حالياً'), findsOneWidget);
    expect(find.text('حجوزات تبدأ اليوم'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
