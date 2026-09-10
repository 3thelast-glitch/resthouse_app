import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../database_helper.dart';
import '../services/financial_summary_service.dart';
import '../ui/app_theme.dart';
import '../utils/responsive.dart';

class UltimateDashboardPage extends StatefulWidget {
  const UltimateDashboardPage({super.key});

  @override
  State<UltimateDashboardPage> createState() => _UltimateDashboardPageState();
}

class DashboardActivity {
  const DashboardActivity({
    required this.type,
    required this.title,
    required this.date,
    required this.amount,
  });

  final String type;
  final String title;
  final String date;
  final double amount;
}

class _UltimateDashboardPageState extends State<UltimateDashboardPage> {
  final dbHelper = DatabaseHelper.instance;

  double _bookingRevenue = 0;
  double _receivedPayments = 0;
  double _outstandingBalance = 0;
  double _pendingDeposits = 0;
  double _totalExpenses = 0;
  double _netCash = 0;

  int _bookingsCount = 0;
  int _rentersCount = 0;
  int _activeBookingsCount = 0;
  bool _hasRecordedData = false;
  bool _isRefreshing = false;

  List<DashboardActivity> _recentActivities = [];
  List<String> _sortedMonths = [];
  Map<String, double> _monthlyRevenue = {};
  Map<String, double> _monthlyExpenses = {};

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    try {
      final bookings = await dbHelper.queryAllBookings();
      final expenses = await dbHelper.queryAllExpenses();
      final payments = await dbHelper.queryAllPayments();
      final renters = await dbHelper.queryAllRenters();
      final summary = FinancialSummaryService.calculate(
        bookings: bookings,
        expenses: expenses,
        payments: payments,
      );

      final todayStr = DateTime.now().toString().split(' ')[0];
      var activeCount = 0;
      for (final booking in bookings) {
        if (booking['status'] == DatabaseHelper.statusConfirmed &&
            booking['end_date'].toString().compareTo(todayStr) >= 0) {
          activeCount++;
        }
      }

      final months = <String>{
        ...summary.monthlyRevenue.keys,
        ...summary.monthlyExpenses.keys,
      }.toList()
        ..sort();
      if (months.isEmpty) {
        final now = DateTime.now();
        months.add('${now.year}-${now.month.toString().padLeft(2, '0')}');
      }
      if (months.length > 5) {
        months.removeRange(0, months.length - 5);
      }

      final activities = <DashboardActivity>[];
      for (final booking in bookings) {
        final renter = renters.firstWhere(
          (row) => row['phone'] == booking['phone'],
          orElse: () => {'full_name': 'مستأجر غير معروف'},
        );
        activities.add(
          DashboardActivity(
            type: 'booking',
            title: 'حجز: ${renter['full_name']}',
            date: booking['start_date'].toString(),
            amount: (booking['total_price'] as num).toDouble(),
          ),
        );
      }
      for (final expense in expenses) {
        activities.add(
          DashboardActivity(
            type: 'expense',
            title: 'مصروف: ${expense['description']}',
            date: expense['date'].toString(),
            amount: (expense['amount'] as num).toDouble(),
          ),
        );
      }
      activities.sort((a, b) => b.date.compareTo(a.date));

      if (!mounted) return;
      setState(() {
        _bookingRevenue = summary.bookingRevenue;
        _receivedPayments = summary.receivedPayments;
        _outstandingBalance = summary.outstandingBalance;
        _pendingDeposits = summary.pendingDeposits;
        _totalExpenses = summary.expenses;
        _netCash = summary.netCash;
        _bookingsCount = bookings.length;
        _rentersCount = renters.length;
        _activeBookingsCount = activeCount;
        _hasRecordedData =
            bookings.isNotEmpty ||
            renters.isNotEmpty ||
            expenses.isNotEmpty ||
            payments.isNotEmpty;
        _sortedMonths = months;
        _monthlyRevenue = summary.monthlyRevenue;
        _monthlyExpenses = summary.monthlyExpenses;
        _recentActivities = activities.take(5).toList();
      });
    } finally {
      _isRefreshing = false;
    }
  }

  Future<void> _showQuickAddRenter() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var saving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('إضافة مستأجر سريع'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'الاسم الكامل'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'الرجاء إدخال الاسم الكامل';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.done,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      decoration: const InputDecoration(labelText: 'رقم الهاتف'),
                      validator: (value) {
                        final phone = value?.trim() ?? '';
                        if (phone.isEmpty) return 'الرجاء إدخال رقم الهاتف';
                        if (phone.length < 10) {
                          return 'رقم الهاتف يجب أن يتكون من 10 أرقام';
                        }
                        if (!phone.startsWith('05')) {
                          return 'رقم الهاتف يجب أن يبدأ بـ 05';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => saving = true);
                      try {
                        await dbHelper.insertRenter({
                          'full_name': nameController.text.trim(),
                          'phone': phoneController.text.trim(),
                          'notes': '',
                          'rating': 5,
                          'rental_count': 0,
                        });
                        await _loadDashboardData();
                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تمت إضافة المستأجر بنجاح')),
                        );
                      } catch (_) {
                        if (!dialogContext.mounted) return;
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(
                            content: Text('رقم الهاتف مسجل مسبقًا لمستأجر آخر.'),
                          ),
                        );
                      } finally {
                        if (dialogContext.mounted) {
                          setDialogState(() => saving = false);
                        }
                      }
                    },
              child: saving
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('إضافة'),
            ),
          ],
        ),
      ),
    );

    nameController.dispose();
    phoneController.dispose();
  }

  Future<void> _showRenterWarningDialog(String notes) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error),
            SizedBox(width: 10),
            Expanded(child: Text('تنبيه على المستأجر')),
          ],
        ),
        content: SingleChildScrollView(
          child: Text('هذا العميل لديه ملاحظات سابقة:\n\n$notes'),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('فهمت'),
          ),
        ],
      ),
    );
  }

  Future<void> _showQuickAddBooking() async {
    final renters = await dbHelper.queryAllRenters();
    if (renters.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أضف مستأجرًا أولًا قبل تسجيل الحجز.')),
      );
      return;
    }

    if (!mounted) return;

    String? selectedPhone;
    String? selectedRenterNotes;
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now();
    final priceController = TextEditingController();
    final securityDepositController = TextEditingController();
    var saving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('تسجيل حجز سريع'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'المستأجر'),
                    initialValue: selectedPhone,
                    items: renters.map((renter) {
                      return DropdownMenuItem<String>(
                        value: renter['phone'].toString(),
                        child: Text(
                          '${renter['full_name']} (${renter['phone']})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: saving
                        ? null
                        : (value) {
                            String? notes;
                            if (value != null) {
                              final renter = renters.firstWhere(
                                (row) => row['phone'].toString() == value,
                              );
                              notes = renter['notes'] as String?;
                            }
                            setDialogState(() {
                              selectedPhone = value;
                              selectedRenterNotes =
                                  (notes != null && notes.trim().isNotEmpty)
                                      ? notes
                                      : null;
                            });
                            if (selectedRenterNotes != null) {
                              _showRenterWarningDialog(selectedRenterNotes!);
                            }
                          },
                  ),
                  if (selectedRenterNotes != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsetsDirectional.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFF3C4C4)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: AppColors.error,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              selectedRenterNotes!,
                              style: Theme.of(dialogContext)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: AppColors.error,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: saving
                          ? null
                          : () async {
                              final date = await showDatePicker(
                                context: dialogContext,
                                initialDate: startDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2050),
                              );
                              if (!dialogContext.mounted || date == null) return;
                              setDialogState(() {
                                startDate = date;
                                if (endDate.isBefore(startDate)) endDate = startDate;
                              });
                            },
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text('البداية: ${startDate.toString().split(' ')[0]}'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: saving
                          ? null
                          : () async {
                              final date = await showDatePicker(
                                context: dialogContext,
                                initialDate:
                                    endDate.isBefore(startDate) ? startDate : endDate,
                                firstDate: startDate,
                                lastDate: DateTime(2050),
                              );
                              if (!dialogContext.mounted || date == null) return;
                              setDialogState(() => endDate = date);
                            },
                      icon: const Icon(Icons.event_available_outlined),
                      label: Text('النهاية: ${endDate.toString().split(' ')[0]}'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: priceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'سعر الحجز (ر.س)'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: securityDepositController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(labelText: 'قيمة التأمين (ر.س)'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      final price = double.tryParse(priceController.text.trim()) ?? 0;
                      final securityDeposit =
                          double.tryParse(securityDepositController.text.trim()) ?? 0;
                      if (selectedPhone == null || price <= 0) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(content: Text('الرجاء التحقق من بيانات الحجز.')),
                        );
                        return;
                      }

                      setDialogState(() => saving = true);
                      try {
                        final start = startDate.toString().split(' ')[0];
                        final end = endDate.toString().split(' ')[0];
                        final conflict = await dbHelper.hasBookingConflict(start, end);
                        if (conflict) {
                          if (!dialogContext.mounted) return;
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            const SnackBar(
                              content: Text('الاستراحة محجوزة بالفعل في هذه الفترة.'),
                            ),
                          );
                          return;
                        }

                        await dbHelper.insertBooking({
                          'phone': selectedPhone,
                          'start_date': start,
                          'end_date': end,
                          'total_price': price,
                          'security_deposit': securityDeposit,
                          'status': DatabaseHelper.statusConfirmed,
                        });
                        await _loadDashboardData();
                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تمت إضافة الحجز بنجاح')),
                        );
                      } on StateError catch (error) {
                        if (!dialogContext.mounted) return;
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(content: Text(error.message)),
                        );
                      } on ArgumentError catch (error) {
                        if (!dialogContext.mounted) return;
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(
                            content: Text(
                              error.message?.toString() ?? 'بيانات الحجز غير صالحة.',
                            ),
                          ),
                        );
                      } finally {
                        if (dialogContext.mounted) {
                          setDialogState(() => saving = false);
                        }
                      }
                    },
              child: saving
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('حفظ الحجز'),
            ),
          ],
        ),
      ),
    );

    priceController.dispose();
    securityDepositController.dispose();
  }

  Future<void> _showQuickAddExpense() async {
    final descController = TextEditingController();
    final amountController = TextEditingController();
    var saving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('تسجيل مصروف سريع'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: descController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'وصف المصروف'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(labelText: 'المبلغ (ر.س)'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      final description = descController.text.trim();
                      final amount = double.tryParse(amountController.text.trim());
                      if (description.isEmpty) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(content: Text('الرجاء إدخال وصف للمصروف.')),
                        );
                        return;
                      }
                      if (amount == null || amount <= 0) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(content: Text('أدخل مبلغ مصروف صحيحًا.')),
                        );
                        return;
                      }

                      setDialogState(() => saving = true);
                      try {
                        await dbHelper.insertExpense({
                          'description': description,
                          'amount': amount,
                          'date': DateTime.now().toString().split(' ')[0],
                        });
                        await _loadDashboardData();
                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تم تسجيل المصروف بنجاح')),
                        );
                      } finally {
                        if (dialogContext.mounted) {
                          setDialogState(() => saving = false);
                        }
                      }
                    },
              child: saving
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('حفظ'),
            ),
          ],
        ),
      ),
    );

    descController.dispose();
    amountController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: Responsive.pagePadding(context),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1260),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildDashboardHeader(context),
                      const SizedBox(height: 20),
                      if (!_hasRecordedData)
                        _buildDashboardEmptyState()
                      else ...[
                        _buildMetricsGrid(),
                        const SizedBox(height: 14),
                        _buildCountsStrip(),
                        const SizedBox(height: 20),
                        _buildLowerContent(constraints.maxWidth),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDashboardHeader(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 620;
        final intro = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('نظرة عامة', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(
              'تابع الحجوزات والتحصيل والمصروفات من مكان واحد.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        );

        final actions = Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: _showQuickAddBooking,
              icon: const Icon(Icons.add_rounded),
              label: const Text('حجز جديد'),
            ),
            OutlinedButton.icon(
              onPressed: _showQuickAddExpense,
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('مصروف'),
            ),
            OutlinedButton.icon(
              onPressed: _showQuickAddRenter,
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: const Text('مستأجر'),
            ),
          ],
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [intro, const SizedBox(height: 14), actions],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: intro),
            const SizedBox(width: 16),
            Flexible(child: actions),
          ],
        );
      },
    );
  }

  Widget _buildMetricsGrid() {
    final metrics = <_MetricData>[
      _MetricData(
        label: 'قيمة الحجوزات',
        value: _currency(_bookingRevenue),
        icon: Icons.event_available_outlined,
        tone: AppColors.primary,
        toneContainer: const Color(0xFFCCFBF1),
      ),
      _MetricData(
        label: 'المقبوض فعليًا',
        value: _currency(_receivedPayments),
        icon: Icons.payments_outlined,
        tone: AppColors.success,
        toneContainer: AppColors.successContainer,
      ),
      _MetricData(
        label: 'الرصيد المستحق',
        value: _currency(_outstandingBalance),
        icon: Icons.pending_actions_outlined,
        tone: AppColors.warning,
        toneContainer: AppColors.warningContainer,
      ),
      _MetricData(
        label: 'المصروفات',
        value: _currency(_totalExpenses),
        icon: Icons.receipt_long_outlined,
        tone: AppColors.error,
        toneContainer: AppColors.errorContainer,
      ),
      _MetricData(
        label: 'صافي النقد',
        value: _currency(_netCash),
        icon: Icons.account_balance_wallet_outlined,
        tone: _netCash >= 0 ? AppColors.success : AppColors.error,
        toneContainer: _netCash >= 0
            ? AppColors.successContainer
            : AppColors.errorContainer,
      ),
      _MetricData(
        label: 'تأمينات معلقة',
        value: _currency(_pendingDeposits),
        icon: Icons.security_outlined,
        tone: AppColors.warning,
        toneContainer: AppColors.warningContainer,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 340
            ? 1
            : constraints.maxWidth < 700
                ? 2
                : 3;
        const gap = 12.0;
        final width = (constraints.maxWidth - (gap * (columns - 1))) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final metric in metrics)
              SizedBox(width: width, child: _MetricCard(data: metric)),
          ],
        );
      },
    );
  }

  Widget _buildCountsStrip() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _CountPill(
          icon: Icons.calendar_month_outlined,
          label: 'إجمالي الحجوزات',
          value: '$_bookingsCount',
        ),
        _CountPill(
          icon: Icons.schedule_outlined,
          label: 'نشطة الآن',
          value: '$_activeBookingsCount',
        ),
        _CountPill(
          icon: Icons.groups_2_outlined,
          label: 'المستأجرون',
          value: '$_rentersCount',
        ),
      ],
    );
  }

  Widget _buildLowerContent(double availableWidth) {
    final chart = _Panel(
      title: 'الأداء المالي',
      subtitle: 'قيمة الحجوزات والمصروفات خلال آخر 5 أشهر',
      child: Column(
        children: [
          const Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              _LegendDot(color: AppColors.success, label: 'قيمة الحجوزات'),
              _LegendDot(color: AppColors.error, label: 'المصروفات'),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: availableWidth < 600 ? 230 : 280,
            child: BarChart(
              BarChartData(
                maxY: _chartMaxY(),
                barGroups: _buildBarChartGroups(),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: true, reservedSize: 44),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: _getBottomTitlesWidget,
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => const FlLine(
                    color: AppColors.border,
                    strokeWidth: 1,
                  ),
                ),
                barTouchData: const BarTouchData(enabled: true),
              ),
            ),
          ),
        ],
      ),
    );

    final activities = _Panel(
      title: 'آخر العمليات',
      subtitle: 'أحدث الحجوزات والمصروفات المسجلة',
      child: _buildActivitiesList(),
    );

    if (availableWidth < 900) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [chart, const SizedBox(height: 14), activities],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: chart),
        const SizedBox(width: 14),
        Expanded(flex: 2, child: activities),
      ],
    );
  }

  Widget _buildDashboardEmptyState() {
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 24, vertical: 44),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: Color(0xFFCCFBF1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.space_dashboard_outlined,
              size: 30,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد بيانات لعرض لوحة التحكم بعد',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'ابدأ بإضافة مستأجر أو تسجيل حجز أو مصروف، وستظهر المؤشرات هنا تلقائيًا.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _showQuickAddBooking,
            icon: const Icon(Icons.add_rounded),
            label: const Text('تسجيل أول حجز'),
          ),
        ],
      ),
    );
  }

  String _currency(double value) => '${value.toStringAsFixed(2)} ر.س';

  double _chartMaxY() {
    var highest = 0.0;
    for (final month in _sortedMonths) {
      highest = math.max(highest, _monthlyRevenue[month] ?? 0);
      highest = math.max(highest, _monthlyExpenses[month] ?? 0);
    }
    return highest <= 0 ? 1 : highest * 1.15;
  }

  List<BarChartGroupData> _buildBarChartGroups() {
    final groups = <BarChartGroupData>[];
    for (var i = 0; i < _sortedMonths.length; i++) {
      final month = _sortedMonths[i];
      groups.add(
        BarChartGroupData(
          x: i,
          barsSpace: 4,
          barRods: [
            BarChartRodData(
              toY: _monthlyRevenue[month] ?? 0,
              color: AppColors.success,
              width: 9,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
            BarChartRodData(
              toY: _monthlyExpenses[month] ?? 0,
              color: AppColors.error,
              width: 9,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ],
        ),
      );
    }
    return groups;
  }

  Widget _getBottomTitlesWidget(double value, TitleMeta meta) {
    final index = value.toInt();
    if (index < 0 || index >= _sortedMonths.length) {
      return SideTitleWidget(meta: meta, child: const SizedBox.shrink());
    }

    final parts = _sortedMonths[index].split('-');
    final label = parts.length == 2
        ? '${parts[1]}/${parts[0].substring(2)}'
        : _sortedMonths[index];

    return SideTitleWidget(
      meta: meta,
      child: Text(label, style: Theme.of(context).textTheme.labelSmall),
    );
  }

  Widget _buildActivitiesList() {
    if (_recentActivities.isEmpty) {
      return Padding(
        padding: const EdgeInsetsDirectional.symmetric(vertical: 28),
        child: Center(
          child: Text(
            'لا توجد أنشطة مسجلة بعد',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ),
      );
    }

    return Column(
      children: [
        for (var index = 0; index < _recentActivities.length; index++) ...[
          _ActivityRow(activity: _recentActivities[index]),
          if (index != _recentActivities.length - 1) const Divider(height: 20),
        ],
      ],
    );
  }
}

class _MetricData {
  const _MetricData({
    required this.label,
    required this.value,
    required this.icon,
    required this.tone,
    required this.toneContainer,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color tone;
  final Color toneContainer;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.data});
  final _MetricData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsetsDirectional.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: data.toneContainer,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(data.icon, color: data.tone, size: 21),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  data.label,
                  maxLines: 2,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Text(
            data.value,
            maxLines: 2,
            style: theme.textTheme.titleLarge?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 7),
          Text('$label: ', style: theme.textTheme.bodySmall),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.subtitle,
    required this.child,
  });
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsetsDirectional.all(Responsive.isCompact(context) ? 16 : 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.activity});
  final DashboardActivity activity;

  @override
  Widget build(BuildContext context) {
    final isBooking = activity.type == 'booking';
    final tone = isBooking ? AppColors.success : AppColors.error;
    final container =
        isBooking ? AppColors.successContainer : AppColors.errorContainer;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: container,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(
            isBooking ? Icons.event_available_outlined : Icons.receipt_outlined,
            color: tone,
            size: 19,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                activity.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 2),
              Text(activity.date, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${isBooking ? '+' : '-'}${activity.amount.toStringAsFixed(0)}',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(color: tone),
        ),
      ],
    );
  }
}
