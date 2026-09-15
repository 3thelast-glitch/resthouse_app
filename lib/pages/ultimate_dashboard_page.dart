import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/adaptive_content.dart';
import '../widgets/responsive_bar_chart.dart';
import 'package:flutter/services.dart';

import '../utils/responsive.dart';

import 'package:fl_chart/fl_chart.dart';

import '../database_helper.dart';
import '../services/financial_summary_service.dart';

class UltimateDashboardPage extends StatefulWidget {
  const UltimateDashboardPage({super.key});

  @override
  State<UltimateDashboardPage> createState() => _UltimateDashboardPageState();
}

class DashboardActivity {
  final String type; // 'booking' or 'expense'
  final String title;
  final String date;
  final double amount;

  DashboardActivity({
    required this.type,
    required this.title,
    required this.date,
    required this.amount,
  });
}

class _UltimateDashboardPageState extends State<UltimateDashboardPage> {
  final dbHelper = DatabaseHelper.instance;
  double _totalRevenue = 0.0;
  double _totalExpenses = 0.0;
  int _bookingsCount = 0;
  int _rentersCount = 0;
  int _activeBookingsCount = 0;
  bool _hasRecordedData = false;
  bool _isLoading = true;
  String? _loadError;

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
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      await _readDashboardData();
    } catch (_) {
      if (mounted) {
        setState(() => _loadError = 'تعذر تحميل بيانات لوحة التحكم.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _readDashboardData() async {
    final bookings = await dbHelper.queryAllBookings();
    final expenses = await dbHelper.queryAllExpenses();
    final payments = await dbHelper.queryAllPayments();
    final renters = await dbHelper.queryAllRenters();
    final summary = FinancialSummaryService.calculate(
      bookings: bookings,
      expenses: expenses,
      payments: payments,
    );

    // حساب الحجوزات النشطة (التي تنتهي اليوم أو مستقبلاً)
    final todayStr = DateTime.now().toString().split(' ')[0];
    int activeCount = 0;
    for (var b in bookings) {
      if (b['status'] == DatabaseHelper.statusConfirmed &&
          b['end_date'].toString().compareTo(todayStr) >= 0) {
        activeCount++;
      }
    }

    // تجميع الإحصائيات الشهرية للرسم البياني
    final mRevenue = summary.monthlyRevenue;
    final mExpenses = summary.monthlyExpenses;

    List<String> months = {...mRevenue.keys, ...mExpenses.keys}.toList()
      ..sort();
    if (months.isEmpty) {
      final now = DateTime.now();
      months.add("${now.year}-${now.month.toString().padLeft(2, '0')}");
    }
    if (months.length > 5) {
      months = months.sublist(months.length - 5);
    }

    // تجميع الأنشطة الأخيرة
    final List<DashboardActivity> acts = [];
    for (var b in bookings) {
      final renter = renters.firstWhere(
        (r) => r['phone'] == b['phone'],
        orElse: () => {'full_name': 'مستأجر غير معروف'},
      );
      acts.add(
        DashboardActivity(
          type: 'booking',
          title: 'حجز جديد: ${renter['full_name']}',
          date: b['start_date'].toString(),
          amount: (b['total_price'] as num).toDouble(),
        ),
      );
    }
    for (var e in expenses) {
      acts.add(
        DashboardActivity(
          type: 'expense',
          title: 'مصروف: ${e['description']}',
          date: e['date'].toString(),
          amount: (e['amount'] as num).toDouble(),
        ),
      );
    }

    acts.sort((a, b) => b.date.compareTo(a.date));

    if (!mounted) return;
    setState(() {
      _totalRevenue = summary.bookingRevenue;
      _totalExpenses = summary.expenses;
      _bookingsCount = bookings.length;
      _rentersCount = renters.length;
      _activeBookingsCount = activeCount;
      _hasRecordedData =
          bookings.isNotEmpty ||
          renters.isNotEmpty ||
          expenses.isNotEmpty ||
          payments.isNotEmpty;
      _sortedMonths = months;
      _monthlyRevenue = mRevenue;
      _monthlyExpenses = mExpenses;
      _recentActivities = acts.take(4).toList();
    });
  }

  void _showQuickAddRenter() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: const Text(
          'إضافة مستأجر سريع',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'الاسم الكامل'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'الرجاء إدخال الاسم الكامل';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                textDirection: TextDirection.ltr,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: const InputDecoration(labelText: 'رقم الهاتف'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'الرجاء إدخال رقم الهاتف';
                  }
                  if (value.trim().length < 10) {
                    return 'رقم الهاتف يجب أن يتكون من 10 أرقام';
                  }
                  if (!value.trim().startsWith('05')) {
                    return 'رقم الهاتف يجب أن يبدأ بـ 05';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) {
                return;
              }
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
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('تمت إضافة المستأجر بنجاح')),
                );
              } catch (e) {
                if (!dialogContext.mounted) return;
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text('خطأ: رقم الهاتف مسجل مسبقاً لمستأجر آخر!'),
                    backgroundColor: AppColors.errorText,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  void _showRenterWarningDialog(BuildContext context, String notes) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        backgroundColor: AppColors.errorSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: AppColors.errorText,
              size: 28,
            ),
            SizedBox(width: 8),
            Text(
              'تنبيه هام!',
              style: TextStyle(
                color: AppColors.errorText,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          'تنبيه: هذا العميل لديه ملاحظات سابقة:\n\n$notes',
          style: TextStyle(
            color: AppColors.errorText,
            fontSize: 16.sp(context),
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorText,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('فهمت ذلك'),
          ),
        ],
      ),
    );
  }

  void _showQuickAddBooking() async {
    final renters = await dbHelper.queryAllRenters();
    if (renters.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرجاء إضافة مستأجر أولاً قبل حجز الاستراحة'),
        ),
      );
      return;
    }

    if (!mounted) return;
    String? selectedPhone;
    String? selectedRenterNotes;
    DateTime? startDate = DateTime.now();
    DateTime? endDate = DateTime.now();
    final priceController = TextEditingController();
    final securityDepositController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          scrollable: true,
          title: const Text(
            'تسجيل حجز سريع',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'المستأجر'),
                  initialValue: selectedPhone,
                  items: renters.map((renter) {
                    return DropdownMenuItem<String>(
                      value: renter['phone'].toString(),
                      child: Text(
                        '${renter['full_name']} (${renter['phone']})',
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    String? notes;
                    if (value != null) {
                      final renter = renters.firstWhere(
                        (r) => r['phone'].toString() == value,
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
                      _showRenterWarningDialog(
                        dialogContext,
                        selectedRenterNotes!,
                      );
                    }
                  },
                ),
                if (selectedRenterNotes != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.errorSurface,
                      border: Border.all(color: AppColors.errorText),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning, color: AppColors.errorText),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'تنبيه: هذا العميل لديه ملاحظات سابقة: $selectedRenterNotes',
                            style: TextStyle(
                              color: AppColors.errorText,
                              fontWeight: FontWeight.bold,
                              fontSize: 12.sp(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: dialogContext,
                      initialDate: startDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2050),
                    );
                    if (!dialogContext.mounted) return;
                    if (date != null) {
                      setDialogState(() {
                        startDate = date;
                        if (endDate == null || endDate!.isBefore(startDate!)) {
                          endDate = startDate;
                        }
                      });
                    }
                  },
                  child: Text('البداية: ${startDate.toString().split(' ')[0]}'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () async {
                    final initialDate =
                        (endDate != null &&
                            startDate != null &&
                            !endDate!.isBefore(startDate!))
                        ? endDate!
                        : (startDate ?? DateTime.now());
                    final firstDate = startDate ?? DateTime(2020);

                    final date = await showDatePicker(
                      context: dialogContext,
                      initialDate: initialDate,
                      firstDate: firstDate,
                      lastDate: DateTime(2050),
                    );
                    if (!dialogContext.mounted) return;
                    if (date != null) {
                      setDialogState(() {
                        endDate = date;
                      });
                    }
                  },
                  child: Text('النهاية: ${endDate.toString().split(' ')[0]}'),
                ),
                TextField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'سعر الحجز (ر.س)',
                  ),
                ),
                TextField(
                  controller: securityDepositController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'قيمة التأمين (ر.س)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                final price = double.tryParse(priceController.text) ?? 0.0;
                final securityDeposit =
                    double.tryParse(securityDepositController.text) ?? 0.0;
                if (selectedPhone == null ||
                    startDate == null ||
                    endDate == null ||
                    price <= 0) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('الرجاء التحقق من المدخلات')),
                  );
                  return;
                }

                // فحص تعارض المواعيد
                final conflict = await dbHelper.hasBookingConflict(
                  startDate!.toString().split(' ')[0],
                  endDate!.toString().split(' ')[0],
                );
                if (conflict) {
                  if (!dialogContext.mounted) return;
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'عذراً، الاستراحة محجوزة بالفعل في هذه الفترة!',
                      ),
                      backgroundColor: AppColors.errorText,
                    ),
                  );
                  return;
                }

                try {
                  await dbHelper.insertBooking({
                    'phone': selectedPhone,
                    'start_date': startDate!.toString().split(' ')[0],
                    'end_date': endDate!.toString().split(' ')[0],
                    'total_price': price,
                    'security_deposit': securityDeposit,
                    'status': DatabaseHelper.statusConfirmed,
                  });
                  await _loadDashboardData();
                  if (!dialogContext.mounted) return;
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('تمت إضافة الحجز بنجاح')),
                  );
                } on StateError catch (error) {
                  if (!dialogContext.mounted) return;
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: Text(error.message),
                      backgroundColor: AppColors.errorText,
                    ),
                  );
                } on ArgumentError catch (error) {
                  if (!dialogContext.mounted) return;
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: Text(
                        error.message?.toString() ?? 'بيانات الحجز غير صالحة.',
                      ),
                      backgroundColor: AppColors.errorText,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('حفظ الحجز'),
            ),
          ],
        ),
      ),
    );
  }

  void _showQuickAddExpense() {
    final descController = TextEditingController();
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: const Text(
          'تسجيل مصروف سريع',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: 'وصف المصروف'),
            ),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'المبلغ'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              final desc = descController.text.trim();
              final amountText = amountController.text.trim();

              if (desc.isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text('الرجاء إدخال وصف للمصروف'),
                    backgroundColor: AppColors.errorText,
                  ),
                );
                return;
              }
              if (amountText.isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text('الرجاء إدخال مبلغ المصروف'),
                    backgroundColor: AppColors.errorText,
                  ),
                );
                return;
              }

              final amount = double.tryParse(amountText);
              if (amount == null) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'الرجاء إدخال أرقام صالحة فقط في حقل المبلغ!',
                    ),
                    backgroundColor: AppColors.errorText,
                  ),
                );
                return;
              }

              if (amount <= 0) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text('المبلغ يجب أن يكون أكبر من الصفر'),
                    backgroundColor: AppColors.errorText,
                  ),
                );
                return;
              }

              await dbHelper.insertExpense({
                'description': desc,
                'amount': amount,
                'date': DateTime.now().toString().split(' ')[0],
              });
              await _loadDashboardData();
              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                const SnackBar(content: Text('تم تسجيل المصروف بنجاح')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_loadError!),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _loadDashboardData,
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }
    final netProfit = _totalRevenue - _totalExpenses;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: ContentWidth(
        child: SingleChildScrollView(
          key: const PageStorageKey('dashboard-scroll'),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AdaptiveItems(
                minItemWidth: 220,
                children: [
                  FilledButton(onPressed: _showQuickAddBooking,
                    child: const ActionLabel(Icons.add, 'تسجيل حجز سريع')),
                  OutlinedButton(onPressed: _showQuickAddExpense,
                    child: const ActionLabel(Icons.money, 'تسجيل مصروف سريع')),
                  OutlinedButton(onPressed: _showQuickAddRenter,
                    child: const ActionLabel(Icons.person_add_outlined, 'عميل جديد')),
                ],
              ),
              const SizedBox(height: 16),
              if (!_hasRecordedData) _buildDashboardEmptyState() else ...[
                AdaptiveItems(
                  key: const ValueKey('dashboard-metrics'),
                  minItemWidth: 210,
                  children: [
                    MetricCard(title: 'إجمالي الإيرادات', value: _totalRevenue,
                      icon: Icons.monetization_on, color: AppColors.successText),
                    MetricCard(title: 'إجمالي المصاريف', value: _totalExpenses,
                      icon: Icons.payment, color: AppColors.errorText),
                    MetricCard(title: 'صافي الأرباح', value: netProfit,
                      icon: Icons.account_balance_wallet,
                      color: netProfit >= 0 ? AppColors.primary : AppColors.errorText),
                    MetricCard(title: 'عدد الحجوزات الكلي', value: _bookingsCount,
                      icon: Icons.calendar_month, color: Colors.indigo, isMoney: false, unit: 'حجز'),
                    MetricCard(title: 'الحجوزات النشطة حالياً', value: _activeBookingsCount,
                      icon: Icons.timer, color: AppColors.warningText, isMoney: false, unit: 'حجز نشط'),
                    MetricCard(title: 'العملاء المسجلين', value: _rentersCount,
                      icon: Icons.people, color: AppColors.secondaryText, isMoney: false, unit: 'مستأجر'),
                  ],
                ),
                const SizedBox(height: 24),
                AdaptiveItems(
                  minItemWidth: 480,
                  maxColumns: 2,
                  children: [
                    SectionCard(title: 'تقرير الأداء المالي', child: _buildDashboardChart()),
                    SectionCard(title: 'الأنشطة والعمليات الأخيرة', child: _buildActivitiesList()),
                  ],
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardChart() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Text('آخر 5 أشهر', style: Theme.of(context).textTheme.bodySmall),
    const SizedBox(height: 8),
    Wrap(spacing: 16, runSpacing: 8, children: [
      _buildLegendIndicator(AppColors.successText, 'الإيرادات'),
      _buildLegendIndicator(AppColors.errorText, 'المصروفات'),
    ]),
    const SizedBox(height: 24),
    ResponsiveBarChart(groups: _buildBarChartGroups(), labels: {
      for (var i = 0; i < _sortedMonths.length; i++) i: _sortedMonths[i],
    }),
  ]);

  Widget _buildDashboardEmptyState() {
    return Card(
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 48),
        child: Column(
          children: [
            const Icon(
              Icons.space_dashboard_outlined,
              size: 52,
              color: AppColors.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد بيانات لعرض لوحة التحكم بعد',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18.sp(context),
                color: AppColors.heading,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'ابدأ بإضافة مستأجر أو تسجيل حجز أو مصروف. ستظهر التقارير والأرقام تلقائيًا بعد إدخال بياناتك الفعلية.',
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
    );
  }

  Widget _buildLegendIndicator(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 12.sp(context),
            color: AppColors.secondaryText,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  List<BarChartGroupData> _buildBarChartGroups() {
    final List<BarChartGroupData> groups = [];
    for (int i = 0; i < _sortedMonths.length; i++) {
      final month = _sortedMonths[i];
      final rev = _monthlyRevenue[month] ?? 0.0;
      final exp = _monthlyExpenses[month] ?? 0.0;

      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: rev,
              color: const Color(0xFF10B981),
              width: 10,
              borderRadius: BorderRadius.circular(2),
            ),
            BarChartRodData(
              toY: exp,
              color: const Color(0xFFEF4444),
              width: 10,
              borderRadius: BorderRadius.circular(2),
            ),
          ],
        ),
      );
    }
    return groups;
  }

  Widget _buildActivitiesList() {
    if (_recentActivities.isEmpty) {
      return const Padding(padding: EdgeInsets.all(16), child: Text('لا توجد أنشطة حديثة'));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < _recentActivities.length; index++) ...[
          if (index > 0) const Divider(height: 24),
          _buildActivity(_recentActivities[index]),
        ],
      ],
    );
  }

  Widget _buildActivity(DashboardActivity activity) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(activity.type == 'booking' ? Icons.calendar_month : Icons.payments_outlined,
          color: activity.type == 'booking' ? AppColors.primary : AppColors.errorText, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text(activity.title, style: Theme.of(context).textTheme.titleSmall)),
      ]),
      const SizedBox(height: 4),
      Text(activity.date, textDirection: TextDirection.ltr, textAlign: TextAlign.end,
        style: Theme.of(context).textTheme.bodySmall),
      AmountText(activity.amount),
    ],
  );
}
