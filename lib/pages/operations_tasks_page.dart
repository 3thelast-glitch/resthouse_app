import 'package:flutter/material.dart';

import '../database_helper.dart';
import '../services/operations_task_service.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';

/// Visual metadata for each operations task type, kept in one place so the
/// notifications center stays consistent with the app theme.
class _TaskTypeStyle {
  const _TaskTypeStyle({
    required this.sectionTitle,
    required this.icon,
    required this.foreground,
    required this.background,
  });

  final String sectionTitle;
  final IconData icon;
  final Color foreground;
  final Color background;
}

const _taskTypeStyles = <OperationsTaskType, _TaskTypeStyle>{
  OperationsTaskType.arrivalToday: _TaskTypeStyle(
    sectionTitle: 'حجوزات تبدأ اليوم',
    icon: Icons.event_available_outlined,
    foreground: AppColors.successText,
    background: AppColors.successSurface,
  ),
  OperationsTaskType.departureToday: _TaskTypeStyle(
    sectionTitle: 'حجوزات تنتهي اليوم',
    icon: Icons.logout,
    foreground: AppColors.primaryPressed,
    background: AppColors.selectedSurface,
  ),
  OperationsTaskType.outstandingBalance: _TaskTypeStyle(
    sectionTitle: 'أرصدة مستحقة',
    icon: Icons.account_balance_wallet_outlined,
    foreground: AppColors.warningText,
    background: AppColors.warningSurface,
  ),
  OperationsTaskType.backupReminder: _TaskTypeStyle(
    sectionTitle: 'النسخ الاحتياطي',
    icon: Icons.backup_outlined,
    foreground: AppColors.neutralText,
    background: AppColors.neutralSurface,
  ),
  OperationsTaskType.pendingDeposit: _TaskTypeStyle(
    sectionTitle: 'تأمينات بانتظار التسوية',
    icon: Icons.shield_outlined,
    foreground: AppColors.errorText,
    background: AppColors.errorSurface,
  ),
};

/// Display order for the sections: today's arrivals and departures
/// first (the operating day), then money owed, then deposits waiting
/// for settlement.
const _sectionOrder = <OperationsTaskType>[
  OperationsTaskType.arrivalToday,
  OperationsTaskType.departureToday,
  OperationsTaskType.outstandingBalance,
  OperationsTaskType.pendingDeposit,
  OperationsTaskType.backupReminder,
];

String _formatAmount(double amount) => '${amount.toStringAsFixed(2)} ر.س';

/// Notifications center: renders the tasks produced by
/// [OperationsTaskService] grouped by type.
///
/// The list itself is a pure presentation widget so it can be tested and
/// reused without a database. [OperationsTasksPage] handles loading.
class OperationsTaskList extends StatelessWidget {
  const OperationsTaskList({super.key, required this.tasks});

  final List<OperationsTask> tasks;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return const _OperationsEmptyState();
    }

    final children = <Widget>[];
    for (final type in _sectionOrder) {
      final sectionTasks = tasks.where((task) => task.type == type).toList();
      if (sectionTasks.isEmpty) continue;
      final style = _taskTypeStyles[type]!;
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
          child: Row(
            children: [
              Icon(style.icon, size: 20, color: style.foreground),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  style.sectionTitle,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15.sp(context),
                    color: AppColors.heading,
                  ),
                ),
              ),
              Text(
                '${sectionTasks.length}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13.sp(context),
                  color: AppColors.secondaryText,
                ),
              ),
            ],
          ),
        ),
      );
      for (final task in sectionTasks) {
        children.add(_OperationsTaskTile(task: task, style: style));
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: children,
    );
  }
}

class _OperationsTaskTile extends StatelessWidget {
  const _OperationsTaskTile({required this.task, required this.style});

  final OperationsTask task;
  final _TaskTypeStyle style;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: style.background,
          foregroundColor: style.foreground,
          child: Icon(style.icon, size: 20),
        ),
        title: Text(
          task.title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14.sp(context),
            color: AppColors.text,
          ),
        ),
        trailing: task.amount > 0
            ? Text(
                _formatAmount(task.amount),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13.sp(context),
                  color: style.foreground,
                ),
              )
            : null,
      ),
    );
  }
}

class _OperationsEmptyState extends StatelessWidget {
  const _OperationsEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Card(
          color: Colors.white,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 48),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.notifications_none_outlined,
                  size: 52,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'لا توجد تنبيهات حالياً',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18.sp(context),
                    color: AppColors.heading,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'كل شيء مسوّى: لا أرصدة مستحقة، ولا تأمينات بانتظار التسوية، ولا حجوزات تبدأ اليوم.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    height: 1.5,
                    fontSize: 13.sp(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Page that loads bookings and payments, runs them through
/// [OperationsTaskService] and shows the resulting notifications center.
class OperationsTasksPage extends StatefulWidget {
  const OperationsTasksPage({super.key});

  @override
  State<OperationsTasksPage> createState() => _OperationsTasksPageState();
}

class _OperationsTasksPageState extends State<OperationsTasksPage> {
  final _dbHelper = DatabaseHelper.instance;
  List<OperationsTask> _tasks = const [];
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _hasError = false;
      });
    }
    try {
      final bookings = await _dbHelper.queryAllBookings();
      final payments = await _dbHelper.queryAllPayments();
      final tasks = OperationsTaskService.calculate(
        bookings: bookings,
        payments: payments,
      );
      final reminder = OperationsTaskService.backupReminder(
        lastBackupAt: await _dbHelper.lastBackupAt(),
        hasData: bookings.isNotEmpty || payments.isNotEmpty,
      );
      if (reminder != null) tasks.add(reminder);
      if (!mounted) return;
      setState(() {
        _tasks = tasks;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('مركز التنبيهات')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _hasError
          ? _OperationsErrorState(onRetry: _loadTasks)
          : RefreshIndicator(
              onRefresh: _loadTasks,
              child: OperationsTaskList(tasks: _tasks),
            ),
    );
  }
}

class _OperationsErrorState extends StatelessWidget {
  const _OperationsErrorState({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: AppColors.errorText,
            ),
            const SizedBox(height: 12),
            Text(
              'تعذر تحميل التنبيهات. حاول مرة أخرى.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.sp(context),
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}
