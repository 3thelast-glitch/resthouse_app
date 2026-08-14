import 'package:flutter/material.dart';
import '../utils/responsive.dart';
import 'package:fl_chart/fl_chart.dart';
import '../database_helper.dart';

class FinancePage extends StatefulWidget {
  const FinancePage({super.key});

  @override
  State<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends State<FinancePage> {
  final dbHelper = DatabaseHelper.instance;
  double _totalRevenue = 0.0;
  double _totalSecurityDeposit = 0.0;
  double _totalExpenses = 0.0;
  List<Map<String, dynamic>> _expenses = []; // Filtered expenses
  List<Map<String, dynamic>> _filteredBookings = []; // Filtered bookings
  List<Map<String, dynamic>> _allBookings = [];
  List<Map<String, dynamic>> _allExpenses = [];

  // Dynamic year range
  List<int> _getYearRange() {
    int currentYear = DateTime.now().year;
    if (currentYear > 2050) {
      return [currentYear];
    }
    return List.generate(2050 - currentYear + 1, (i) => currentYear + i);
  }

  // Advanced filter state
  int _selectedYear = DateTime.now().year;
  Set<int> _selectedMonths = {DateTime.now().month};
  bool _fullYearSelected = false;

  // Comparison state
  bool _showComparison = false;
  late int _comparisonYear;

  // Comparison tab state
  int _activeTab = 0; // 0 for report, 1 for comparison
  String _comparisonType = 'months'; // 'months' or 'years'
  int _compMonthYear = DateTime.now().year;
  int _compMonth1 = DateTime.now().month;
  int _compMonth2 = (DateTime.now().month == 1) ? 12 : DateTime.now().month - 1;
  int _compYear1 = DateTime.now().year;
  late int _compYear2;

  final List<String> _categories = [
    'راتب عامل',
    'فواتير كهرباء وماء',
    'صيانة',
    'مصاريف تشغيلية أخرى',
  ];

  Map<String, Color> _getCategoryColors() {
    return {
      'راتب عامل': const Color(0xFF3B82F6), // Blue
      'فواتير كهرباء وماء': const Color(0xFFF59E0B), // Orange
      'صيانة': const Color(0xFFEF4444), // Red
      'مصاريف تشغيلية أخرى': const Color(0xFF10B981), // Green
    };
  }

  List<String> _distinctDescriptions = [];

  @override
  void initState() {
    super.initState();
    _comparisonYear = DateTime.now().year < 2050 ? DateTime.now().year + 1 : DateTime.now().year;
    _compYear2 = DateTime.now().year < 2050 ? DateTime.now().year + 1 : DateTime.now().year;
    _loadFinance();
  }

  Future<void> _loadFinance() async {
    final bookings = await dbHelper.queryAllBookings();
    final expenses = await dbHelper.queryAllExpenses();
    final distinctDescs = await dbHelper.getDistinctExpenseDescriptions();

    if (!mounted) return;
    setState(() {
      _allBookings = bookings;
      _allExpenses = expenses;
      _distinctDescriptions = distinctDescs;
      _applyFilter();
    });
  }

  void _applyFilter() {
    List<Map<String, dynamic>> fBookings = [];
    List<Map<String, dynamic>> fExpenses = [];

    final Set<int> months = _fullYearSelected
        ? {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12}
        : _selectedMonths;

    fBookings = _allBookings.where((b) {
      final date = DateTime.tryParse(b['start_date'] ?? '') ?? DateTime(1970);
      return date.year == _selectedYear && months.contains(date.month);
    }).toList();
    fExpenses = _allExpenses.where((e) {
      final date = DateTime.tryParse(e['date'] ?? '') ?? DateTime(1970);
      return date.year == _selectedYear && months.contains(date.month);
    }).toList();

    double revenue = 0.0;
    double securitySum = 0.0;
    double expenseSum = 0.0;

    for (var b in fBookings) {
      revenue += (b['total_price'] as num).toDouble();
      securitySum += (b['security_deposit'] as num?)?.toDouble() ?? 0.0;
    }
    for (var e in fExpenses) {
      expenseSum += (e['amount'] as num).toDouble();
    }

    _filteredBookings = fBookings;
    _expenses = fExpenses;
    _totalRevenue = revenue;
    _totalSecurityDeposit = securitySum;
    _totalExpenses = expenseSum;
  }

  void _showAddExpenseDialog() {
    final descController = TextEditingController();
    final amountController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    String selectedCategory = 'مصاريف تشغيلية أخرى';

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('تسجيل مصروف جديد', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Autocomplete<String>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return const Iterable<String>.empty();
                  }
                  return _distinctDescriptions.where((String option) {
                    return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                  });
                },
                onSelected: (String selection) {
                  descController.text = selection;
                },
                fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                  if (textEditingController.text.isEmpty && descController.text.isNotEmpty) {
                    textEditingController.text = descController.text;
                  }
                  return TextField(
                    controller: textEditingController,
                    focusNode: focusNode,
                    onChanged: (value) {
                      descController.text = value;
                    },
                    onSubmitted: (value) => onFieldSubmitted(),
                    decoration: const InputDecoration(
                      labelText: 'وصف المصروف',
                      icon: Icon(Icons.description_outlined),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'المبلغ (ر.س)',
                  icon: Icon(Icons.attach_money),
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'تصنيف المصروف',
                  icon: Icon(Icons.category_outlined),
                ),
                initialValue: selectedCategory,
                items: _categories.map((cat) {
                  return DropdownMenuItem<String>(
                    value: cat,
                    child: Text(cat),
                  );
                }).toList(),
                onChanged: (value) => setDialogState(() => selectedCategory = value ?? 'مصاريف تشغيلية أخرى'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 20, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: dialogContext,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2050),
                        );
                        if (!dialogContext.mounted) return;
                        if (date != null) {
                          setDialogState(() => selectedDate = date);
                        }
                      },
                      child: Text('التاريخ: ${selectedDate.toString().split(' ')[0]}'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
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
                      content: Text('الرجاء إدخال أرقام صالحة فقط في حقل المبلغ!'),
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
                  'date': selectedDate.toString().split(' ')[0],
                  'category': selectedCategory,
                });

                await _loadFinance();
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('تم تسجيل المصروف بنجاح')),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F766E), foregroundColor: Colors.white),
              child: const Text('إضافة'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditExpenseDialog(Map<String, dynamic> expense) {
    final descController = TextEditingController(text: expense['description']);
    final amountController = TextEditingController(text: expense['amount'].toString());
    DateTime selectedDate = DateTime.tryParse(expense['date']) ?? DateTime.now();
    String selectedCategory = expense['category']?.toString() ?? 'مصاريف تشغيلية أخرى';

    if (!_categories.contains(selectedCategory)) {
      selectedCategory = 'مصاريف تشغيلية أخرى';
    }

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('تعديل المصروف', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Autocomplete<String>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return const Iterable<String>.empty();
                  }
                  return _distinctDescriptions.where((String option) {
                    return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                  });
                },
                onSelected: (String selection) {
                  descController.text = selection;
                },
                fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                  if (textEditingController.text.isEmpty && descController.text.isNotEmpty) {
                    textEditingController.text = descController.text;
                  }
                  return TextField(
                    controller: textEditingController,
                    focusNode: focusNode,
                    onChanged: (value) {
                      descController.text = value;
                    },
                    onSubmitted: (value) => onFieldSubmitted(),
                    decoration: const InputDecoration(
                      labelText: 'وصف المصروف',
                      icon: Icon(Icons.description_outlined),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'المبلغ (ر.س)',
                  icon: Icon(Icons.attach_money),
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'تصنيف المصروف',
                  icon: Icon(Icons.category_outlined),
                ),
                initialValue: selectedCategory,
                items: _categories.map((cat) {
                  return DropdownMenuItem<String>(
                    value: cat,
                    child: Text(cat),
                  );
                }).toList(),
                onChanged: (value) => setDialogState(() => selectedCategory = value ?? 'مصاريف تشغيلية أخرى'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 20, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: dialogContext,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2050),
                        );
                        if (!dialogContext.mounted) return;
                        if (date != null) {
                          setDialogState(() => selectedDate = date);
                        }
                      },
                      child: Text('التاريخ: ${selectedDate.toString().split(' ')[0]}'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
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
                      content: Text('الرجاء إدخال أرقام صالحة فقط في حقل المبلغ!'),
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

                await dbHelper.updateExpense({
                  'id': expense['id'],
                  'description': desc,
                  'amount': amount,
                  'date': selectedDate.toString().split(' ')[0],
                  'category': selectedCategory,
                });

                await _loadFinance();
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('تم تحديث المصروف بنجاح')),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F766E), foregroundColor: Colors.white),
              child: const Text('حفظ التعديلات'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteExpense(int id) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تأكيد حذف المصروف'),
        content: const Text('هل أنت متأكد من رغبتك في حذف هذا المصروف؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
          TextButton(
            onPressed: () async {
              await dbHelper.deleteExpense(id);
              await _loadFinance();
              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                const SnackBar(content: Text('تم حذف المصروف بنجاح')),
              );
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Map<String, double> _getCategoryTotals() {
    final Map<String, double> totals = {};
    for (var e in _expenses) {
      final cat = e['category']?.toString() ?? 'مصاريف تشغيلية أخرى';
      final amt = (e['amount'] as num).toDouble();
      totals[cat] = (totals[cat] ?? 0.0) + amt;
    }
    return totals;
  }

  List<PieChartSectionData> _buildPieSections() {
    final catTotals = _getCategoryTotals();
    if (catTotals.isEmpty) return [];

    final totalExp = catTotals.values.fold(0.0, (sum, val) => sum + val);
    final colorsMap = _getCategoryColors();

    return catTotals.entries.map((entry) {
      final percentage = totalExp > 0 ? (entry.value / totalExp) * 100 : 0.0;
      final color = colorsMap[entry.key] ?? const Color(0xFF64748B);
      return PieChartSectionData(
        color: color,
        value: entry.value,
        title: '${percentage.toStringAsFixed(0)}%',
        radius: 35,
        titleStyle: TextStyle(fontSize: 10.sp(context), fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();
  }

  Widget _buildPieLegend() {
    final catTotals = _getCategoryTotals();
    final colorsMap = _getCategoryColors();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: catTotals.entries.map((entry) {
        final color = colorsMap[entry.key] ?? const Color(0xFF64748B);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${entry.key}: ${entry.value.toStringAsFixed(0)} ر.س',
                  style: TextStyle(fontSize: 11.sp(context), fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  List<BarChartGroupData> _buildComparativeBarGroups() {
    final Set<int> activeMonths = _fullYearSelected
        ? {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12}
        : _selectedMonths;
    final sortedMonths = activeMonths.toList()..sort();

    final Map<int, double> mRevenue = {};
    final Map<int, double> mExpenses = {};

    for (var b in _filteredBookings) {
      final date = DateTime.tryParse(b['start_date'] ?? '');
      if (date != null && date.year == _selectedYear && activeMonths.contains(date.month)) {
        mRevenue[date.month] = (mRevenue[date.month] ?? 0.0) + (b['total_price'] as num).toDouble();
      }
    }
    for (var e in _expenses) {
      final date = DateTime.tryParse(e['date'] ?? '');
      if (date != null && date.year == _selectedYear && activeMonths.contains(date.month)) {
        mExpenses[date.month] = (mExpenses[date.month] ?? 0.0) + (e['amount'] as num).toDouble();
      }
    }

    return List.generate(sortedMonths.length, (index) {
      final monthNum = sortedMonths[index];
      final rev = mRevenue[monthNum] ?? 0.0;
      final exp = mExpenses[monthNum] ?? 0.0;

      return BarChartGroupData(
        x: monthNum,
        barRods: [
          BarChartRodData(
            toY: rev,
            color: const Color(0xFF10B981),
            width: sortedMonths.length > 6 ? 6 : 12,
            borderRadius: BorderRadius.circular(2),
          ),
          BarChartRodData(
            toY: exp,
            color: const Color(0xFFEF4444),
            width: sortedMonths.length > 6 ? 6 : 12,
            borderRadius: BorderRadius.circular(2),
          ),
        ],
      );
    });
  }

  // Financial comparison: build grouped bar chart data for two years
  List<BarChartGroupData> _buildComparisonBarGroups() {
    final Set<int> activeMonths = _fullYearSelected
        ? {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12}
        : _selectedMonths;
    final sortedMonths = activeMonths.toList()..sort();

    final Map<int, double> rev1 = {};
    final Map<int, double> exp1 = {};
    final Map<int, double> rev2 = {};
    final Map<int, double> exp2 = {};

    for (var b in _allBookings) {
      final date = DateTime.tryParse(b['start_date'] ?? '');
      if (date != null && activeMonths.contains(date.month)) {
        if (date.year == _selectedYear) {
          rev1[date.month] = (rev1[date.month] ?? 0.0) + (b['total_price'] as num).toDouble();
        } else if (date.year == _comparisonYear) {
          rev2[date.month] = (rev2[date.month] ?? 0.0) + (b['total_price'] as num).toDouble();
        }
      }
    }
    for (var e in _allExpenses) {
      final date = DateTime.tryParse(e['date'] ?? '');
      if (date != null && activeMonths.contains(date.month)) {
        if (date.year == _selectedYear) {
          exp1[date.month] = (exp1[date.month] ?? 0.0) + (e['amount'] as num).toDouble();
        } else if (date.year == _comparisonYear) {
          exp2[date.month] = (exp2[date.month] ?? 0.0) + (e['amount'] as num).toDouble();
        }
      }
    }

    return List.generate(sortedMonths.length, (index) {
      final m = sortedMonths[index];
      return BarChartGroupData(
        x: m,
        barRods: [
          BarChartRodData(toY: rev1[m] ?? 0.0, color: const Color(0xFF10B981), width: 5, borderRadius: BorderRadius.circular(1)),
          BarChartRodData(toY: exp1[m] ?? 0.0, color: const Color(0xFFEF4444), width: 5, borderRadius: BorderRadius.circular(1)),
          BarChartRodData(toY: rev2[m] ?? 0.0, color: const Color(0xFF60A5FA), width: 5, borderRadius: BorderRadius.circular(1)),
          BarChartRodData(toY: exp2[m] ?? 0.0, color: const Color(0xFFFBBF24), width: 5, borderRadius: BorderRadius.circular(1)),
        ],
      );
    });
  }

  Widget _getBarBottomTitles(double value, TitleMeta meta) {
    const months = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
    int monthNum = value.toInt(); // 1-indexed month number
    if (monthNum >= 1 && monthNum <= 12) {
      return SideTitleWidget(
        meta: meta,
        child: Text(months[monthNum - 1], style: TextStyle(fontSize: 9.sp(context), fontWeight: FontWeight.bold, color: Colors.grey)),
      );
    }
    return SideTitleWidget(meta: meta, child: const Text(''));
  }

  // Build the advanced filter UI widget
  Widget _buildAdvancedFilterPanel() {
    const monthNames = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Row 1: Title + Year dropdown + Comparison toggle
        Row(
          children: [
            Expanded(
              child: Text(
                'التقرير المالي للعمليات',
                style: TextStyle(fontSize: 18.sp(context), fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
              ),
            ),
            // Year dropdown
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF0F766E).withAlpha(20),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF0F766E).withAlpha(60)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _selectedYear,
                  icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF0F766E), size: 20),
                  style: TextStyle(fontWeight: FontWeight.bold, color: const Color(0xFF0F766E), fontSize: 14.sp(context)),
                  items: _getYearRange().map((year) {
                    return DropdownMenuItem<int>(value: year, child: Text('$year'));
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedYear = value;
                        _applyFilter();
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Comparison toggle
            FilterChip(
              label: Text(
                'مقارنة مالية',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12.sp(context),
                  color: _showComparison ? Colors.white : const Color(0xFF6366F1),
                ),
              ),
              avatar: Icon(
                Icons.compare_arrows,
                size: 16,
                color: _showComparison ? Colors.white : const Color(0xFF6366F1),
              ),
              selected: _showComparison,
              selectedColor: const Color(0xFF6366F1),
              backgroundColor: const Color(0xFF6366F1).withAlpha(20),
              checkmarkColor: Colors.white,
              onSelected: (val) {
                setState(() {
                  _showComparison = val;
                });
              },
            ),
            if (_showComparison) ...[
              const SizedBox(width: 8),
              Text('مقابل', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12.sp(context))),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF6366F1).withAlpha(60)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _comparisonYear,
                    icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF6366F1), size: 20),
                    style: TextStyle(fontWeight: FontWeight.bold, color: const Color(0xFF6366F1), fontSize: 14.sp(context)),
                    items: _getYearRange().map((year) {
                      return DropdownMenuItem<int>(value: year, child: Text('$year'));
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _comparisonYear = value;
                        });
                      }
                    },
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        // Row 2: Full Year chip + Month chips
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              // Full year chip
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: FilterChip(
                  label: Text(
                    'السنة كاملة',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12.sp(context),
                      color: _fullYearSelected ? Colors.white : const Color(0xFF0F766E),
                    ),
                  ),
                  selected: _fullYearSelected,
                  selectedColor: const Color(0xFF0F766E),
                  backgroundColor: const Color(0xFF0F766E).withAlpha(15),
                  checkmarkColor: Colors.white,
                  onSelected: (val) {
                    setState(() {
                      _fullYearSelected = val;
                      if (val) {
                        _selectedMonths = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12};
                      } else {
                        _selectedMonths = {DateTime.now().month};
                      }
                      _applyFilter();
                    });
                  },
                ),
              ),
              const SizedBox(width: 6),
              const VerticalDivider(width: 16, thickness: 1, indent: 6, endIndent: 6),
              // Month chips
              ...List.generate(12, (i) {
                final monthNum = i + 1;
                final isSelected = _selectedMonths.contains(monthNum);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: FilterChip(
                    label: Text(
                      monthNames[i],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11.sp(context),
                        color: isSelected ? Colors.white : Colors.grey.shade700,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: const Color(0xFF0F766E),
                    backgroundColor: Colors.grey.shade100,
                    checkmarkColor: Colors.white,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    onSelected: _fullYearSelected ? null : (val) {
                      setState(() {
                        if (val) {
                          _selectedMonths.add(monthNum);
                        } else {
                          if (_selectedMonths.length > 1) {
                            _selectedMonths.remove(monthNum);
                          }
                        }
                        _applyFilter();
                      });
                    },
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      // [تعديل] تم تغليف المحتوى الرئيسي بـ SingleChildScrollView للسماح بالتمرير على الشاشات الصغيرة
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 950;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSubTabSelector(),
                const SizedBox(height: 16),
                // [تعديل] تم إزالة Expanded لأنه غير متوافق مع SingleChildScrollView
                _activeTab == 0
                    ? _buildReportTabContent(isWide)
                    : _buildComparisonTabContent(isWide),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSubTabSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _activeTab = 0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _activeTab == 0 ? const Color(0xFF0F766E) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'التقرير والتحليل المالي العام',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _activeTab == 0 ? Colors.white : Colors.grey.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 14.sp(context),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _activeTab = 1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _activeTab == 1 ? const Color(0xFF0F766E) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'المقارنة المالية المتقدمة',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _activeTab == 1 ? Colors.white : Colors.grey.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 14.sp(context),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportTabContent(bool isWide) {
    final netIncome = _totalRevenue - _totalExpenses;
    // [تعديل] تم إزالة Expanded من Column لأن المحتوى الآن داخل SingleChildScrollView
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildAdvancedFilterPanel(),
        const SizedBox(height: 16),
        if (isWide)
          Row(
            children: [
              Expanded(child: _buildCard('إجمالي مبالغ الإيجار', _totalRevenue, const Color(0xFF10B981), Icons.monetization_on_outlined)),
              const SizedBox(width: 12),
              Expanded(child: _buildCard('إجمالي مبالغ التأمين', _totalSecurityDeposit, const Color(0xFF0284C7), Icons.security_outlined)),
              const SizedBox(width: 12),
              Expanded(child: _buildCard('إجمالي المصروفات', _totalExpenses, const Color(0xFFEF4444), Icons.arrow_downward)),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCard(
                  'صافي الأرباح', 
                  netIncome, 
                  netIncome >= 0 ? const Color(0xFF0D9488) : const Color(0xFFDC2626), 
                  Icons.account_balance,
                ),
              ),
            ],
          )
        else
          Column(
            children: [
              Row(
                children: [
                  Expanded(child: _buildCard('إجمالي مبالغ الإيجار', _totalRevenue, const Color(0xFF10B981), Icons.monetization_on_outlined)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildCard('إجمالي مبالغ التأمين', _totalSecurityDeposit, const Color(0xFF0284C7), Icons.security_outlined)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildCard('إجمالي المصروفات', _totalExpenses, const Color(0xFFEF4444), Icons.arrow_downward)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildCard(
                      'صافي الأرباح', 
                      netIncome, 
                      netIncome >= 0 ? const Color(0xFF0D9488) : const Color(0xFFDC2626), 
                      Icons.account_balance,
                    ),
                  ),
                ],
              ),
            ],
          ),
        const SizedBox(height: 24),
        // [تعديل] تم إزالة Expanded واستخدام isScrollable: true لعرض المحتوى بارتفاع ثابت
        // بدلاً من الاعتماد على Expanded الذي لا يعمل مع SingleChildScrollView
        if (isWide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: _buildExpensesSection(isScrollable: true),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: _buildChartsSection(isScrollable: true),
              ),
            ],
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildChartsSection(isScrollable: true),
              const SizedBox(height: 24),
              _buildExpensesSection(isScrollable: true),
            ],
          ),
      ],
    );
  }

  Map<String, double> _getMonthFinancials(int year, int month) {
    double revenue = 0.0;
    double security = 0.0;
    double expenses = 0.0;
    int bookingsCount = 0;

    for (var b in _allBookings) {
      final date = DateTime.tryParse(b['start_date'] ?? '');
      if (date != null && date.year == year && date.month == month) {
        revenue += (b['total_price'] as num).toDouble();
        security += (b['security_deposit'] as num?)?.toDouble() ?? 0.0;
        bookingsCount++;
      }
    }

    for (var e in _allExpenses) {
      final date = DateTime.tryParse(e['date'] ?? '');
      if (date != null && date.year == year && date.month == month) {
        expenses += (e['amount'] as num).toDouble();
      }
    }

    return {
      'revenue': revenue,
      'security': security,
      'expenses': expenses,
      'net': revenue - expenses,
      'bookings': bookingsCount.toDouble(),
    };
  }

  Map<String, double> _getYearFinancials(int year) {
    double revenue = 0.0;
    double security = 0.0;
    double expenses = 0.0;
    int bookingsCount = 0;

    for (var b in _allBookings) {
      final date = DateTime.tryParse(b['start_date'] ?? '');
      if (date != null && date.year == year) {
        revenue += (b['total_price'] as num).toDouble();
        security += (b['security_deposit'] as num?)?.toDouble() ?? 0.0;
        bookingsCount++;
      }
    }

    for (var e in _allExpenses) {
      final date = DateTime.tryParse(e['date'] ?? '');
      if (date != null && date.year == year) {
        expenses += (e['amount'] as num).toDouble();
      }
    }

    return {
      'revenue': revenue,
      'security': security,
      'expenses': expenses,
      'net': revenue - expenses,
      'bookings': bookingsCount.toDouble(),
    };
  }

  Widget _buildComparisonControls() {
    const monthNames = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
    return Card(
      color: Colors.white,
      elevation: 2,
      shadowColor: Colors.black.withAlpha(13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.compare_arrows, color: Color(0xFF0F766E)),
                const SizedBox(width: 8),
                Text(
                  'تحديد خيارات المقارنة',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp(context), color: const Color(0xFF1E293B)),
                ),
                const Spacer(),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.all(2),
                  child: Row(
                    children: [
                      _buildComparisonTypeButton('months', 'مقارنة بين الأشهر'),
                      _buildComparisonTypeButton('years', 'مقارنة بين السنوات'),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            if (_comparisonType == 'months') ...[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    const Text('السنة: ', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                    const SizedBox(width: 8),
                    _buildDropdown<int>(
                      value: _compMonthYear,
                      items: _getYearRange(),
                      onChanged: (val) {
                        if (val != null) setState(() => _compMonthYear = val);
                      },
                    ),
                    const SizedBox(width: 24),
                    const Text('الشهر الأول: ', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                    const SizedBox(width: 8),
                    _buildDropdown<int>(
                      value: _compMonth1,
                      items: List.generate(12, (i) => i + 1),
                      itemToString: (m) => monthNames[m - 1],
                      onChanged: (val) {
                        if (val != null) setState(() => _compMonth1 = val);
                      },
                    ),
                    const SizedBox(width: 24),
                    const Text('الشهر الثاني: ', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                    const SizedBox(width: 8),
                    _buildDropdown<int>(
                      value: _compMonth2,
                      items: List.generate(12, (i) => i + 1),
                      itemToString: (m) => monthNames[m - 1],
                      onChanged: (val) {
                        if (val != null) setState(() => _compMonth2 = val);
                      },
                    ),
                  ],
                ),
              ),
            ] else ...[
              Row(
                children: [
                  const Text('السنة الأولى: ', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                  const SizedBox(width: 8),
                  _buildDropdown<int>(
                    value: _compYear1,
                    items: _getYearRange(),
                    onChanged: (val) {
                      if (val != null) setState(() => _compYear1 = val);
                    },
                  ),
                  const SizedBox(width: 32),
                  const Text('السنة الثانية: ', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                  const SizedBox(width: 8),
                  _buildDropdown<int>(
                    value: _compYear2,
                    items: _getYearRange(),
                    onChanged: (val) {
                      if (val != null) setState(() => _compYear2 = val);
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonTypeButton(String type, String label) {
    final isSelected = _comparisonType == type;
    return InkWell(
      onTap: () => setState(() => _comparisonType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F766E) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontWeight: FontWeight.bold,
            fontSize: 12.sp(context),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T value,
    required List<T> items,
    String Function(T)? itemToString,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF0F766E).withAlpha(15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF0F766E).withAlpha(40)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF0F766E)),
          style: TextStyle(fontWeight: FontWeight.bold, color: const Color(0xFF0F766E), fontSize: 13.sp(context)),
          items: items.map((item) {
            return DropdownMenuItem<T>(
              value: item,
              child: Text(itemToString != null ? itemToString(item) : item.toString()),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildComparisonChart(Map<String, double> dataA, Map<String, double> dataB, String labelA, String labelB) {
    final double maxVal = [
      dataA['revenue']!,
      dataA['expenses']!,
      dataB['revenue']!,
      dataB['expenses']!
    ].reduce((curr, next) => curr > next ? curr : next);

    final double maxBarHeight = maxVal > 0 ? maxVal * 1.25 : 100.0;

    final groups = [
      BarChartGroupData(
        x: 0,
        barRods: [
          BarChartRodData(
            toY: dataA['revenue']!,
            color: const Color(0xFF10B981),
            width: 14,
            borderRadius: BorderRadius.circular(3),
          ),
          BarChartRodData(
            toY: dataA['expenses']!,
            color: const Color(0xFFEF4444),
            width: 14,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      ),
      BarChartGroupData(
        x: 1,
        barRods: [
          BarChartRodData(
            toY: dataB['revenue']!,
            color: const Color(0xFF3B82F6),
            width: 14,
            borderRadius: BorderRadius.circular(3),
          ),
          BarChartRodData(
            toY: dataB['expenses']!,
            color: const Color(0xFFF59E0B),
            width: 14,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      ),
    ];

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxBarHeight,
        barTouchData: const BarTouchData(enabled: true),
        titlesData: FlTitlesData(
          show: true,
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 45,
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (val, meta) {
                if (val.toInt() == 0) {
                  return SideTitleWidget(meta: meta, child: Text(labelA, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10.sp(context))));
                } else if (val.toInt() == 1) {
                  return SideTitleWidget(meta: meta, child: Text(labelB, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10.sp(context))));
                }
                return SideTitleWidget(meta: meta, child: const Text(''));
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        barGroups: groups,
      ),
    );
  }

  Widget _buildComparisonStats(Map<String, double> dataA, Map<String, double> dataB, String labelA, String labelB) {
    return Column(
      children: [
        _buildComparisonRow('إجمالي مبالغ الإيجار', dataA['revenue']!, dataB['revenue']!, Colors.green, Icons.monetization_on_outlined),
        const SizedBox(height: 12),
        _buildComparisonRow('إجمالي مبالغ التأمين', dataA['security'] ?? 0.0, dataB['security'] ?? 0.0, Colors.blue, Icons.security_outlined),
        const SizedBox(height: 12),
        _buildComparisonRow('إجمالي المصروفات', dataA['expenses']!, dataB['expenses']!, Colors.red, Icons.arrow_downward),
        const SizedBox(height: 12),
        _buildComparisonRow('صافي الأرباح', dataA['net']!, dataB['net']!, const Color(0xFF0F766E), Icons.account_balance),
        const SizedBox(height: 12),
        _buildComparisonRow('عدد الحجوزات', dataA['bookings']!, dataB['bookings']!, Colors.indigo, Icons.calendar_month, isCurrency: false),
      ],
    );
  }

  Widget _buildComparisonRow(String title, double valA, double valB, Color color, IconData icon, {bool isCurrency = true}) {
    final diff = valB - valA;
    final percentDiff = valA > 0 ? (diff / valA) * 100 : 0.0;
    
    String diffText = '';
    Color diffColor = Colors.grey;
    IconData diffIcon = Icons.remove;

    if (diff > 0) {
      diffText = '+${diff.toStringAsFixed(0)}${isCurrency ? " ر.س" : ""} (${percentDiff.toStringAsFixed(1)}%)';
      diffColor = Colors.green.shade700;
      diffIcon = Icons.trending_up;
    } else if (diff < 0) {
      diffText = '${diff.toStringAsFixed(0)}${isCurrency ? " ر.س" : ""} (${percentDiff.toStringAsFixed(1)}%)';
      diffColor = Colors.red.shade700;
      diffIcon = Icons.trending_down;
    } else {
      diffText = 'لا يوجد اختلاف (0%)';
      diffColor = Colors.grey.shade600;
      diffIcon = Icons.trending_flat;
    }

    return Card(
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withAlpha(20),
              foregroundColor: color,
              radius: 18,
              child: Icon(icon, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: Colors.grey.shade500, fontSize: 11.sp(context), fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        '${valA.toStringAsFixed(0)}${isCurrency ? " ر.س" : ""}',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp(context)),
                      ),
                      const SizedBox(width: 8),
                      const Text('➔', style: TextStyle(color: Colors.grey)),
                      const SizedBox(width: 8),
                      Text(
                        '${valB.toStringAsFixed(0)}${isCurrency ? " ر.س" : ""}',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp(context)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: diffColor.withAlpha(15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(diffIcon, size: 14, color: diffColor),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        diffText,
                        style: TextStyle(color: diffColor, fontWeight: FontWeight.bold, fontSize: 11.sp(context)),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonInsights(Map<String, double> dataA, Map<String, double> dataB, String labelA, String labelB) {
    final netDiff = dataB['net']! - dataA['net']!;
    final revDiff = dataB['revenue']! - dataA['revenue']!;
    final expDiff = dataB['expenses']! - dataA['expenses']!;

    String title = '';
    String description = '';
    Color highlightColor = Colors.grey;

    if (netDiff > 0) {
      title = 'أداء مالي أفضل لـ $labelB';
      description = 'حقق $labelB صافي أرباح أعلى بقيمة ${netDiff.toStringAsFixed(0)} ر.س مقارنة بـ $labelA. ';
      if (revDiff > 0) {
        description += 'وكان هذا الارتفاع مدفوعاً بزيادة الإيرادات بقيمة ${revDiff.toStringAsFixed(0)} ر.س. ';
      }
      if (expDiff < 0) {
        description += 'بالإضافة إلى نجاحك في خفض المصروفات التشغيلية بقيمة ${(-expDiff).toStringAsFixed(0)} ر.س. ';
      }
      highlightColor = const Color(0xFF0F766E);
    } else if (netDiff < 0) {
      title = 'أداء مالي أفضل لـ $labelA';
      description = 'حقق $labelA صافي أرباح أعلى بقيمة ${(-netDiff).toStringAsFixed(0)} ر.س مقارنة بـ $labelB. ';
      if (revDiff < 0) {
        description += 'حيث انخفضت الإيرادات في $labelB بقيمة ${(-revDiff).toStringAsFixed(0)} ر.س. ';
      }
      if (expDiff > 0) {
        description += 'بالإضافة إلى ارتفاع المصاريف التشغيلية في $labelB بقيمة ${expDiff.toStringAsFixed(0)} ر.س. ';
      }
      highlightColor = const Color(0xFFB91C1C);
    } else {
      title = 'أداء مالي متطابق';
      description = 'لا يوجد اختلاف في صافي الأرباح بين الفترتين المحددتين. ';
      highlightColor = Colors.grey.shade700;
    }

    return Card(
      color: highlightColor.withAlpha(15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: highlightColor.withAlpha(51), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb_outline, color: highlightColor, size: 24),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.sp(context), color: highlightColor),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(fontSize: 13.sp(context), color: Colors.grey.shade800, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonTabContent(bool isWide) {
    const monthNames = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
    
    String labelA = '';
    String labelB = '';
    Map<String, double> dataA = {};
    Map<String, double> dataB = {};

    if (_comparisonType == 'months') {
      labelA = monthNames[_compMonth1 - 1];
      labelB = monthNames[_compMonth2 - 1];
      dataA = _getMonthFinancials(_compMonthYear, _compMonth1);
      dataB = _getMonthFinancials(_compMonthYear, _compMonth2);
      labelA += ' $_compMonthYear';
      labelB += ' $_compMonthYear';
    } else {
      labelA = 'سنة $_compYear1';
      labelB = 'سنة $_compYear2';
      dataA = _getYearFinancials(_compYear1);
      dataB = _getYearFinancials(_compYear2);
    }

    final controls = _buildComparisonControls();
    final stats = _buildComparisonStats(dataA, dataB, labelA, labelB);
    final insights = _buildComparisonInsights(dataA, dataB, labelA, labelB);

    final chartWidget = Card(
      color: Colors.white,
      elevation: 2,
      shadowColor: Colors.black.withAlpha(13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'التحليل المقارن للمبيعات والمصاريف',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.sp(context), color: const Color(0xFF1E293B)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              runSpacing: 4,
              children: [
                _buildLegendItem(const Color(0xFF10B981), 'إيرادات $labelA'),
                _buildLegendItem(const Color(0xFFEF4444), 'مصاريف $labelA'),
                _buildLegendItem(const Color(0xFF3B82F6), 'إيرادات $labelB'),
                _buildLegendItem(const Color(0xFFF59E0B), 'مصاريف $labelB'),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 220,
              child: _buildComparisonChart(dataA, dataB, labelA, labelB),
            ),
          ],
        ),
      ),
    );

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          controls,
          const SizedBox(height: 16),
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      chartWidget,
                      const SizedBox(height: 16),
                      insights,
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: stats,
                ),
              ],
            )
          else
            Column(
              children: [
                chartWidget,
                const SizedBox(height: 16),
                stats,
                const SizedBox(height: 16),
                insights,
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildCard(String title, double amount, Color color, IconData icon) {
    return Card(
      color: Colors.white,
      elevation: 2,
      shadowColor: Colors.black.withAlpha(13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withAlpha(26),
              foregroundColor: color,
              radius: 24,
              child: Icon(icon, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13.sp(context), fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${amount.toStringAsFixed(0)} ر.س',
                    style: TextStyle(
                      fontSize: 20.sp(context),
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

  Widget _buildExpensesSection({bool isScrollable = false}) {
    // [تعديل] تم استخدام SizedBox بارتفاع ثابت دائماً لأن الصفحة كلها أصبحت قابلة للتمرير
    final listWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.list_alt, color: Color(0xFF0F766E)),
                const SizedBox(width: 8),
                Text(
                  'سجل المصروفات التشغيلية',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp(context), color: const Color(0xFF1E293B)),
                ),
              ],
            ),
            ElevatedButton.icon(
              onPressed: _showAddExpenseDialog,
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: const Text('تسجيل مصروف جديد'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 400,
          child: _buildExpensesList(),
        ),
      ],
    );
    return listWidget;
  }

  Widget _buildChartsSection({bool isScrollable = false}) {
    if (_expenses.isEmpty && _filteredBookings.isEmpty) {
      return Card(
        color: Colors.white,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.pie_chart_outline, size: 48, color: Colors.grey),
                const SizedBox(height: 12),
                Text(
                  'لا توجد عمليات مالية مسجلة للفترة المحددة',
                  style: TextStyle(color: Colors.grey, fontSize: 13.sp(context)),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    double maxRod = 0.0;
    final groups = _showComparison ? _buildComparisonBarGroups() : _buildComparativeBarGroups();
    for (var g in groups) {
      for (var r in g.barRods) {
        if (r.toY > maxRod) {
          maxRod = r.toY;
        }
      }
    }
    final double maxBarHeight = maxRod > 0 ? maxRod * 1.25 : 100.0;

    final mainContent = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.analytics_outlined, color: Color(0xFF0F766E)),
            const SizedBox(width: 8),
            Text(
              'التحليل البياني المالي',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp(context), color: const Color(0xFF1E293B)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          color: Colors.white,
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _showComparison
                      ? 'مقارنة مالية: $_selectedYear مقابل $_comparisonYear'
                      : 'مقارنة الإيرادات والمصروفات',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp(context), color: const Color(0xFF475569)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 160,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: maxBarHeight > 0 ? maxBarHeight : 100,
                      barTouchData: const BarTouchData(enabled: true),
                      titlesData: FlTitlesData(
                        show: true,
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: _getBarBottomTitles,
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      gridData: const FlGridData(show: false),
                      barGroups: groups,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (_showComparison)
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 16,
                    runSpacing: 4,
                    children: [
                      _buildLegendItem(const Color(0xFF10B981), 'إيرادات $_selectedYear'),
                      _buildLegendItem(const Color(0xFFEF4444), 'مصروفات $_selectedYear'),
                      _buildLegendItem(const Color(0xFF60A5FA), 'إيرادات $_comparisonYear'),
                      _buildLegendItem(const Color(0xFFFBBF24), 'مصروفات $_comparisonYear'),
                    ],
                  )
                else
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 16,
                    children: [
                      _buildLegendItem(const Color(0xFF10B981), 'الإيرادات'),
                      _buildLegendItem(const Color(0xFFEF4444), 'المصروفات'),
                    ],
                  ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 12),
                Text(
                  'توزيع المصاريف حسب التصنيف',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp(context), color: const Color(0xFF475569)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                if (_expenses.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        'لا توجد مصروفات مسجلة لعرض تصنيفاتها للفترة المحددة',
                        style: TextStyle(color: Colors.grey, fontSize: 12.sp(context)),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: SizedBox(
                          height: 110,
                          child: PieChart(
                            PieChartData(
                              sectionsSpace: 2,
                              centerSpaceRadius: 18,
                              sections: _buildPieSections(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 6,
                        child: _buildPieLegend(),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );

    // [تعديل] تم إزالة الشرط وإرجاع المحتوى مباشرة لأن الصفحة كلها أصبحت قابلة للتمرير
    return mainContent;
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11.sp(context), fontWeight: FontWeight.bold, color: const Color(0xFF475569))),
      ],
    );
  }

  Widget _buildExpensesList() {
    if (_expenses.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Center(
          child: Text(
            'لا توجد مصروفات مسجلة بعد',
            style: TextStyle(color: Colors.grey, fontSize: 14.sp(context)),
          ),
        ),
      );
    }

    final colorsMap = _getCategoryColors();
    final sorted = List<Map<String, dynamic>>.from(_expenses)
      ..sort((a, b) => b['date'].toString().compareTo(a['date'].toString()));

    return Card(
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListView.separated(
        itemCount: sorted.length,
        separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
        itemBuilder: (context, index) {
          final expense = sorted[index];
          final category = expense['category']?.toString() ?? 'مصاريف تشغيلية أخرى';
          final categoryColor = colorsMap[category] ?? const Color(0xFF64748B);

          return ListTile(
            leading: CircleAvatar(
              backgroundColor: categoryColor.withAlpha(26),
              foregroundColor: categoryColor,
              child: const Icon(Icons.receipt, size: 18),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    expense['description'].toString(),
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp(context), color: const Color(0xFF1E293B)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: categoryColor.withAlpha(26),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: categoryColor.withAlpha(51)),
                  ),
                  child: Text(
                    category,
                    style: TextStyle(fontSize: 10.sp(context), color: categoryColor, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            subtitle: Text(
              expense['date'].toString(),
              style: TextStyle(fontSize: 12.sp(context), color: Colors.grey),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '-${expense['amount']} ر.س',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFEF4444),
                    fontSize: 14.sp(context),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 20),
                  onPressed: () => _showEditExpenseDialog(expense),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  onPressed: () => _confirmDeleteExpense(expense['id']),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
