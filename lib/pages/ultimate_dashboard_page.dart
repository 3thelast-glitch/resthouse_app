import 'package:flutter/material.dart';
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
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
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
        backgroundColor: Colors.red.shade50,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.red.shade700,
              size: 28,
            ),
            const SizedBox(width: 8),
            Text(
              'تنبيه هام!',
              style: TextStyle(
                color: Colors.red.shade900,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          'تنبيه: هذا العميل لديه ملاحظات سابقة:\n\n$notes',
          style: TextStyle(
            color: Colors.red.shade900,
            fontSize: 16.sp(context),
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
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
                      color: Colors.red.shade50,
                      border: Border.all(color: Colors.red.shade200),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning, color: Colors.red.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'تنبيه: هذا العميل لديه ملاحظات سابقة: $selectedRenterNotes',
                            style: TextStyle(
                              color: Colors.red.shade900,
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
                      backgroundColor: Colors.red,
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
                      backgroundColor: Colors.red,
                    ),
                  );
                } on ArgumentError catch (error) {
                  if (!dialogContext.mounted) return;
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: Text(
                        error.message?.toString() ?? 'بيانات الحجز غير صالحة.',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
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
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              if (amountText.isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text('الرجاء إدخال مبلغ المصروف'),
                    backgroundColor: Colors.red,
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
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              if (amount <= 0) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text('المبلغ يجب أن يكون أكبر من الصفر'),
                    backgroundColor: Colors.red,
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
              backgroundColor: const Color(0xFF0F766E),
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
    final netProfit = _totalRevenue - _totalExpenses;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // أزرار العمليات السريعة (تلتف تلقائياً لتفادي الطفح)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  ElevatedButton.icon(
                    onPressed: _showQuickAddBooking,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('تسجيل حجز سريع'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _showQuickAddExpense,
                    icon: const Icon(Icons.money, size: 16),
                    label: const Text('تسجيل مصروف سريع'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0F766E),
                      side: const BorderSide(color: Color(0xFF0F766E)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _showQuickAddRenter,
                    icon: const Icon(Icons.person_add_outlined, size: 16),
                    label: const Text('عميل جديد'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0D9488),
                      side: const BorderSide(color: Color(0xFF0D9488)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // بطاقات الإحصائيات الفوقية الملونة
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      title: 'إجمالي الإيرادات',
                      value: '${_totalRevenue.toStringAsFixed(0)} ر.س',
                      icon: Icons.monetization_on,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      title: 'إجمالي المصاريف',
                      value: '${_totalExpenses.toStringAsFixed(0)} ر.س',
                      icon: Icons.payment,
                      color: const Color(0xFFEF4444),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      title: 'صافي الأرباح',
                      value: '${netProfit.toStringAsFixed(0)} ر.س',
                      icon: Icons.account_balance_wallet,
                      color: netProfit >= 0
                          ? const Color(0xFF0D9488)
                          : const Color(0xFFDC2626),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      title: 'عدد الحجوزات الكلي',
                      value: '$_bookingsCount حجز',
                      icon: Icons.calendar_month,
                      color: Colors.indigo,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      title: 'الحجوزات النشطة حالياً',
                      value: '$_activeBookingsCount حجز نشط',
                      icon: Icons.timer,
                      color: const Color(0xFFD97706),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      title: 'العملاء المسجلين',
                      value: '$_rentersCount مستأجر',
                      icon: Icons.people,
                      color: Colors.blueGrey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // القسم السفلي: الرسم البياني على اليمين والأنشطة الأخيرة على اليسار
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // الرسم البياني (الإيرادات والمصروفات شهرياً)
                  Expanded(
                    flex: 3,
                    child: Card(
                      color: Colors.white,
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'تقرير الأداء المالي (آخر 5 أشهر)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15.sp(context),
                                color: const Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 16,
                              runSpacing: 4,
                              children: [
                                _buildLegendIndicator(
                                  const Color(0xFF10B981),
                                  'الإيرادات',
                                ),
                                _buildLegendIndicator(
                                  const Color(0xFFEF4444),
                                  'المصروفات',
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              height: 250,
                              child: BarChart(
                                BarChartData(
                                  barGroups: _buildBarChartGroups(),
                                  titlesData: FlTitlesData(
                                    topTitles: const AxisTitles(
                                      sideTitles: SideTitles(showTitles: false),
                                    ),
                                    rightTitles: const AxisTitles(
                                      sideTitles: SideTitles(showTitles: false),
                                    ),
                                    leftTitles: const AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 40,
                                      ),
                                    ),
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        getTitlesWidget: _getBottomTitlesWidget,
                                      ),
                                    ),
                                  ),
                                  borderData: FlBorderData(show: false),
                                  gridData: const FlGridData(
                                    show: true,
                                    drawVerticalLine: false,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // قائمة الأنشطة الأخيرة
                  Expanded(
                    flex: 2,
                    child: Card(
                      color: Colors.white,
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'الأنشطة والعمليات الأخيرة',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15.sp(context),
                                color: const Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildActivitiesList(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.1),
              foregroundColor: color,
              radius: 20,
              child: Icon(icon, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 11.sp(context),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 15.sp(context),
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
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
            color: Colors.grey,
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

  Widget _getBottomTitlesWidget(double value, TitleMeta meta) {
    int index = value.toInt();
    if (index >= 0 && index < _sortedMonths.length) {
      final monthStr = _sortedMonths[index];
      final parts = monthStr.split('-');
      if (parts.length > 1) {
        return SideTitleWidget(
          meta: meta,
          child: Text(
            '${parts[1]}/${parts[0].substring(2)}',
            style: TextStyle(
              fontSize: 10.sp(context),
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        );
      }
      return SideTitleWidget(meta: meta, child: Text(monthStr));
    }
    return SideTitleWidget(meta: meta, child: const Text(''));
  }

  Widget _buildActivitiesList() {
    if (_recentActivities.isEmpty) {
      return const SizedBox(
        height: 180,
        child: Center(
          child: Text(
            'لا توجد أنشطة مسجلة بعد',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _recentActivities.length,
      separatorBuilder: (context, index) =>
          const Divider(height: 12, color: Color(0xFFF1F5F9)),
      itemBuilder: (context, index) {
        final act = _recentActivities[index];
        final isBooking = act.type == 'booking';

        return Row(
          children: [
            CircleAvatar(
              backgroundColor: isBooking
                  ? const Color(0xFFECFDF5)
                  : const Color(0xFFFEF2F2),
              foregroundColor: isBooking
                  ? const Color(0xFF10B981)
                  : const Color(0xFFEF4444),
              radius: 18,
              child: Icon(
                isBooking ? Icons.vpn_key_outlined : Icons.receipt_long,
                size: 16,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    act.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.sp(context),
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    act.date,
                    style: TextStyle(
                      fontSize: 10.sp(context),
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              isBooking
                  ? '+${act.amount.toStringAsFixed(0)}'
                  : '-${act.amount.toStringAsFixed(0)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13.sp(context),
                color: isBooking
                    ? const Color(0xFF10B981)
                    : const Color(0xFFEF4444),
              ),
            ),
          ],
        );
      },
    );
  }
}
