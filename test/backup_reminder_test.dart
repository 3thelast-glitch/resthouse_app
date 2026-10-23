import 'package:flutter_test/flutter_test.dart';
import 'package:resthouse_app/services/operations_task_service.dart';

void main() {
  final now = DateTime(2026, 8, 10);

  test('لا تذكير بدون بيانات', () {
    expect(
      OperationsTaskService.backupReminder(
        lastBackupAt: null,
        hasData: false,
        now: now,
      ),
      isNull,
    );
  });

  test('تذكير عند عدم وجود أي نسخة مع وجود بيانات', () {
    final task = OperationsTaskService.backupReminder(
      lastBackupAt: null,
      hasData: true,
      now: now,
    );
    expect(task, isNotNull);
    expect(task!.type, OperationsTaskType.backupReminder);
    expect(task.amount, 0);
  });

  test('لا تذكير مع نسخة حديثة، وتذكير مع نسخة قديمة', () {
    expect(
      OperationsTaskService.backupReminder(
        lastBackupAt: DateTime(2026, 8, 1),
        hasData: true,
        now: now,
      ),
      isNull,
    );
    expect(
      OperationsTaskService.backupReminder(
        lastBackupAt: DateTime(2026, 6, 1),
        hasData: true,
        now: now,
      ),
      isNotNull,
    );
  });
}
