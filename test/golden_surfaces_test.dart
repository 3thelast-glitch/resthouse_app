import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resthouse_app/pages/operations_tasks_page.dart';
import 'package:resthouse_app/services/operations_task_service.dart';
import 'package:resthouse_app/theme/app_theme.dart';

// Golden images are binary and cannot be authored by hand; generate
// them once on a developer machine, then commit the PNGs:
//
//   flutter test --update-goldens test/golden_surfaces_test.dart
//
// Until test/goldens/*.png exist, this suite skips itself so CI stays
// green; it activates automatically once the images are committed.
final _goldensReady = File('test/goldens/operations_tasks.png').existsSync();

const _tasks = [
  OperationsTask(
    id: 'arrival-1',
    type: OperationsTaskType.arrivalToday,
    bookingId: 1,
    title: 'حجز يبدأ اليوم #1',
    amount: 0,
  ),
  OperationsTask(
    id: 'departure-4',
    type: OperationsTaskType.departureToday,
    bookingId: 4,
    title: 'حجز ينتهي اليوم #4',
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

Widget _frame(Widget child, {double textScale = 1.0}) {
  return MaterialApp(
    theme: AppTheme.light,
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  void usePhoneSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('golden: مركز المهام بكل الأقسام', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(_frame(const OperationsTaskList(tasks: _tasks)));
    await expectLater(
      find.byType(OperationsTaskList),
      matchesGoldenFile('goldens/operations_tasks.png'),
    );
  }, skip: !_goldensReady);

  testWidgets('golden: مركز المهام بتكبير نص 200%', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(
      _frame(const OperationsTaskList(tasks: _tasks), textScale: 2.0),
    );
    await expectLater(
      find.byType(OperationsTaskList),
      matchesGoldenFile('goldens/operations_tasks_large_text.png'),
    );
  }, skip: !_goldensReady);

  testWidgets('golden: حالة فراغ مركز المهام', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(_frame(const OperationsTaskList(tasks: [])));
    await expectLater(
      find.byType(OperationsTaskList),
      matchesGoldenFile('goldens/operations_tasks_empty.png'),
    );
  }, skip: !_goldensReady);

  testWidgets('golden: شارات الحالة الأربع', (tester) async {
    tester.view.physicalSize = const Size(1170, 600);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _frame(
        const Padding(
          padding: EdgeInsets.all(16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusBadge.success(label: 'مؤكد'),
              StatusBadge.warning(label: 'قيد الانتظار'),
              StatusBadge.error(label: 'ملغي'),
              StatusBadge.neutral(label: 'غير محدد'),
            ],
          ),
        ),
      ),
    );
    await expectLater(
      find.byType(Wrap),
      matchesGoldenFile('goldens/status_badges.png'),
    );
  }, skip: !_goldensReady);
}
