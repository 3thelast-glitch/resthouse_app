import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/adaptive_content.dart';
import '../widgets/responsive_bar_chart.dart';
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
  List<int> _availableYears = [DateTime.now().year];
  bool _isLoaded = false;

  List<int> _getYearRange() => _availableYears;

  bool _isConfirmedBooking(Map<String, dynamic> booking) {
    return booking['status'] == DatabaseHelper.statusConfirmed;
  }

  bool _hasPendingDeposit(Map<String, dynamic> booking) {
    return _isConfirmedBooking(booking) &&
        booking['deposit_status'] == DatabaseHelper.depositPending;
  }

  List<int> _collectAvailableYears(
    List<Map<String, dynamic>> bookings,
    List<Map<String, dynamic>> expenses,
  ) {
    final years = <int>{DateTime.now().year};
    for (final booking in bookings) {
      final date = DateTime.tryParse(booking['start_date']?.toString() ?? '');
      if (date != null) years.add(date.year);
    }
    for (final expense in expenses) {
      final date = DateTime.tryParse(expense['date']?.toString() ?? '');
      if (date != null) years.add(date.year);
    }
    final sortedYears = years.toList()..sort((a, b) => b.compareTo(a));
    return sortedYears;
  }

  void _normalizeSelectedYears() {
    final fallback = _availableYears.first;
    if (!_availableYears.contains(_selectedYear)) _selectedYear = fallback;
    if (!_availableYears.contains(_comparisonYear)) _comparisonYear = fallback;
    if (!_availableYears.contains(_compMonthYear)) _compMonthYear = fallback;
    if (!_availableYears.contains(_compYear1)) _compYear1 = fallback;
    if (!_availableYears.contains(_compYear2)) _compYear2 = fallback;
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
    _comparisonYear = DateTime.now().year;
    _compYear2 = DateTime.now().year;
    _loadFinance();
  }

  Future<void> _loadFinance() async {
    final bookings = await dbHelper.queryAllBookings();
    final expenses = await dbHelper.queryAllExpenses();
    final distinctDescs = await dbHelper.getDistinctExpenseDescriptions();

    if (!mounted) {
      return;
    }
    setState(() {
      _allBookings = bookings;
      _allExpenses = expenses;
      _distinctDescriptions = distinctDescs;
      _availableYears = _collectAvailableYears(bookings, expenses);
      _normalizeSelectedYears();
      _applyFilter();
      _isLoaded = true;
    });
  }

  void _applyFilter() {
    final months = _fullYearSelected
        ? <int>{1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12}
        : _selectedMonths;

    final filteredBookings = _allBookings.where((booking) {
      final date = DateTime.tryParse(booking['start_date']?.toString() ?? '');
      return date != null &&
          date.year == _selectedYear &&
          months.contains(date.month) &&
          _isConfirmedBooking(booking);
    }).toList();
    final filteredExpenses = _allExpenses.where((expense) {
      final date = DateTime.tryParse(expense['date']?.toString() ?? '');
      return date != null &&
          date.year == _selectedYear &&
          months.contains(date.month);
    }).toList();

    final revenue = filteredBookings.fold<double>(
      0.0,
      (sum, booking) => sum + (booking['total_price'] as num).toDouble(),
    );
    final pendingDeposits = filteredBookings
        .where(_hasPendingDeposit)
        .fold<double>(
          0.0,
          (sum, booking) =>
              sum + ((booking['security_deposit'] as num?)?.toDouble() ?? 0.0),
        );
    final expenses = filteredExpenses.fold<double>(
      0.0,
      (sum, expense) => sum + (expense['amount'] as num).toDouble(),
    );

    _filteredBookings = filteredBookings;
    _expenses = filteredExpenses;
    _totalRevenue = revenue;
    _totalSecurityDeposit = pendingDeposits;
    _totalExpenses = expenses;
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
          scrollable: true,
          title: const Text(
            'تسجيل مصروف جديد',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Autocomplete<String>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return const Iterable<String>.empty();
                  }
                  return _distinctDescriptions.where((String option) {
                    return option.toLowerCase().contains(
                      textEditingValue.text.toLowerCase(),
                    );
                  });
                },
                onSelected: (String selection) {
                  descController.text = selection;
                },
                fieldViewBuilder:
                    (
                      context,
                      textEditingController,
                      focusNode,
                      onFieldSubmitted,
                    ) {
                      if (textEditingController.text.isEmpty &&
                          descController.text.isNotEmpty) {
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
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'المبلغ (ر.س)',
                  icon: Icon(Icons.attach_money),
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                isDense: false,
                itemHeight: null,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'تصنيف المصروف',
                  icon: Icon(Icons.category_outlined),
                ),
                initialValue: selectedCategory,
                items: _categories.map((cat) {
                  return DropdownMenuItem<String>(value: cat, child: Text(cat));
                }).toList(),
                onChanged: (value) => setDialogState(
                  () => selectedCategory = value ?? 'مصاريف تشغيلية أخرى',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today,
                    size: 20,
                    color: AppColors.secondaryText,
                  ),
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
                        if (!dialogContext.mounted) {
                          return;
                        }
                        if (date != null) {
                          setDialogState(() => selectedDate = date);
                        }
                      },
                      child: Text(
                        'التاريخ: ${selectedDate.toString().split(' ')[0]}',
                      ),
                    ),
                  ),
                ],
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
                  'date': selectedDate.toString().split(' ')[0],
                  'category': selectedCategory,
                });

                await _loadFinance();
                if (!dialogContext.mounted) {
                  return;
                }
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('تم تسجيل المصروف بنجاح')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('إضافة'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditExpenseDialog(Map<String, dynamic> expense) {
    final descController = TextEditingController(text: expense['description']);
    final amountController = TextEditingController(
      text: expense['amount'].toString(),
    );
    DateTime selectedDate =
        DateTime.tryParse(expense['date']) ?? DateTime.now();
    String selectedCategory =
        expense['category']?.toString() ?? 'مصاريف تشغيلية أخرى';

    if (!_categories.contains(selectedCategory)) {
      selectedCategory = 'مصاريف تشغيلية أخرى';
    }

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          scrollable: true,
          title: const Text(
            'تعديل المصروف',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Autocomplete<String>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return const Iterable<String>.empty();
                  }
                  return _distinctDescriptions.where((String option) {
                    return option.toLowerCase().contains(
                      textEditingValue.text.toLowerCase(),
                    );
                  });
                },
                onSelected: (String selection) {
                  descController.text = selection;
                },
                fieldViewBuilder:
                    (
                      context,
                      textEditingController,
                      focusNode,
                      onFieldSubmitted,
                    ) {
                      if (textEditingController.text.isEmpty &&
                          descController.text.isNotEmpty) {
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
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'المبلغ (ر.س)',
                  icon: Icon(Icons.attach_money),
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                isDense: false,
                itemHeight: null,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'تصنيف المصروف',
                  icon: Icon(Icons.category_outlined),
                ),
                initialValue: selectedCategory,
                items: _categories.map((cat) {
                  return DropdownMenuItem<String>(value: cat, child: Text(cat));
                }).toList(),
                onChanged: (value) => setDialogState(
                  () => selectedCategory = value ?? 'مصاريف تشغيلية أخرى',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today,
                    size: 20,
                    color: AppColors.secondaryText,
                  ),
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
                        if (!dialogContext.mounted) {
                          return;
                        }
                        if (date != null) {
                          setDialogState(() => selectedDate = date);
                        }
                      },
                      child: Text(
                        'التاريخ: ${selectedDate.toString().split(' ')[0]}',
                      ),
                    ),
                  ),
                ],
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

                await dbHelper.updateExpense({
                  'id': expense['id'],
                  'description': desc,
                  'amount': amount,
                  'date': selectedDate.toString().split(' ')[0],
                  'category': selectedCategory,
                });

                await _loadFinance();
                if (!dialogContext.mounted) {
                  return;
                }
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('تم تحديث المصروف بنجاح')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
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
        scrollable: true,
        title: const Text('تأكيد حذف المصروف'),
        content: const Text('هل أنت متأكد من رغبتك في حذف هذا المصروف؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () async {
              await dbHelper.deleteExpense(id);
              await _loadFinance();
              if (!dialogContext.mounted) {
                return;
              }
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                const SnackBar(content: Text('تم حذف المصروف بنجاح')),
              );
            },
            child: const Text(
              'حذف',
              style: TextStyle(color: AppColors.errorText),
            ),
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
    if (catTotals.isEmpty) {
      return [];
    }

    final colorsMap = _getCategoryColors();

    return catTotals.entries.map((entry) {
      final color = colorsMap[entry.key] ?? AppColors.fieldBorder;
      return PieChartSectionData(
        color: color,
        value: entry.value,
        title: '',
        showTitle: false,
        radius: 35,
        titleStyle: TextStyle(
          fontSize: 10.sp(context),
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  Widget _buildPieLegend() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final entry in _getCategoryTotals().entries)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.only(top: 6, end: 8),
                child: Icon(
                  Icons.circle,
                  size: 10,
                  color: _getCategoryColors()[entry.key],
                ),
              ),
              Expanded(
                child: LabelledAmount(
                  '${entry.key} (${(_totalExpenses > 0 ? entry.value / _totalExpenses * 100 : 0).toStringAsFixed(0)}%)',
                  entry.value,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
        ),
    ],
  );

  List<BarChartGroupData> _buildComparativeBarGroups() {
    final Set<int> activeMonths = _fullYearSelected
        ? {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12}
        : _selectedMonths;
    final sortedMonths = activeMonths.toList()..sort();

    final Map<int, double> mRevenue = {};
    final Map<int, double> mExpenses = {};

    for (var b in _filteredBookings) {
      final date = DateTime.tryParse(b['start_date'] ?? '');
      if (date != null &&
          date.year == _selectedYear &&
          activeMonths.contains(date.month)) {
        mRevenue[date.month] =
            (mRevenue[date.month] ?? 0.0) +
            (b['total_price'] as num).toDouble();
      }
    }
    for (var e in _expenses) {
      final date = DateTime.tryParse(e['date'] ?? '');
      if (date != null &&
          date.year == _selectedYear &&
          activeMonths.contains(date.month)) {
        mExpenses[date.month] =
            (mExpenses[date.month] ?? 0.0) + (e['amount'] as num).toDouble();
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

    for (final booking in _allBookings) {
      final date = DateTime.tryParse(booking['start_date']?.toString() ?? '');
      if (date != null &&
          activeMonths.contains(date.month) &&
          _isConfirmedBooking(booking)) {
        if (date.year == _selectedYear) {
          rev1[date.month] =
              (rev1[date.month] ?? 0.0) +
              (booking['total_price'] as num).toDouble();
        } else if (date.year == _comparisonYear) {
          rev2[date.month] =
              (rev2[date.month] ?? 0.0) +
              (booking['total_price'] as num).toDouble();
        }
      }
    }
    for (var e in _allExpenses) {
      final date = DateTime.tryParse(e['date'] ?? '');
      if (date != null && activeMonths.contains(date.month)) {
        if (date.year == _selectedYear) {
          exp1[date.month] =
              (exp1[date.month] ?? 0.0) + (e['amount'] as num).toDouble();
        } else if (date.year == _comparisonYear) {
          exp2[date.month] =
              (exp2[date.month] ?? 0.0) + (e['amount'] as num).toDouble();
        }
      }
    }

    return List.generate(sortedMonths.length, (index) {
      final m = sortedMonths[index];
      return BarChartGroupData(
        x: m,
        barRods: [
          BarChartRodData(
            toY: rev1[m] ?? 0.0,
            color: const Color(0xFF10B981),
            width: 5,
            borderRadius: BorderRadius.circular(1),
          ),
          BarChartRodData(
            toY: exp1[m] ?? 0.0,
            color: const Color(0xFFEF4444),
            width: 5,
            borderRadius: BorderRadius.circular(1),
          ),
          BarChartRodData(
            toY: rev2[m] ?? 0.0,
            color: const Color(0xFF60A5FA),
            width: 5,
            borderRadius: BorderRadius.circular(1),
          ),
          BarChartRodData(
            toY: exp2[m] ?? 0.0,
            color: AppColors.warningText,
            width: 5,
            borderRadius: BorderRadius.circular(1),
          ),
        ],
      );
    });
  }

  // Build the advanced filter UI widget
  Widget _buildAdvancedFilterPanel() {
    const months = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'التقرير المالي للعمليات',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        AdaptiveItems(
          minItemWidth: 200,
          maxColumns: 3,
          children: [
            _labelledDropdown('السنة', _selectedYear, _getYearRange(), (value) {
              if (value != null) {
                setState(() {
                  _selectedYear = value;
                  _applyFilter();
                });
              }
            }),
            FilterChip(
              label: const Text('مقارنة مالية'),
              selected: _showComparison,
              onSelected: (value) => setState(() => _showComparison = value),
            ),
            if (_showComparison)
              _labelledDropdown('مقابل سنة', _comparisonYear, _getYearRange(), (
                value,
              ) {
                if (value != null) {
                  setState(() => _comparisonYear = value);
                }
              }),
          ],
        ),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('الأشهر والفترة'),
          subtitle: Text(
            _fullYearSelected
                ? 'السنة كاملة'
                : _selectedMonths.map((m) => months[m - 1]).join('، '),
          ),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: const Text('السنة كاملة'),
                  selected: _fullYearSelected,
                  onSelected: (value) => setState(() {
                    _fullYearSelected = value;
                    _selectedMonths = value
                        ? {for (var i = 1; i <= 12; i++) i}
                        : {DateTime.now().month};
                    _applyFilter();
                  }),
                ),
                for (var i = 1; i <= 12; i++)
                  FilterChip(
                    label: Text(months[i - 1]),
                    selected: _selectedMonths.contains(i),
                    onSelected: _fullYearSelected
                        ? null
                        : (value) => setState(() {
                            if (value) {
                              _selectedMonths.add(i);
                            } else if (_selectedMonths.length > 1) {
                              _selectedMonths.remove(i);
                            }
                            _applyFilter();
                          }),
                  ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _labelledDropdown(
    String label,
    int value,
    List<int> items,
    ValueChanged<int?> onChanged, {
    String Function(int)? itemToString,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall),
      _buildDropdown<int>(
        value: value,
        items: items,
        onChanged: onChanged,
        itemToString: itemToString,
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final hasFinancialData = _allBookings.isNotEmpty || _allExpenses.isNotEmpty;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: ContentWidth(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide =
                constraints.maxWidth >= 1024 * ContentLayout.textScale(context);
            return CustomScrollView(
              key: const PageStorageKey('finance-scroll'),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverMainAxisGroup(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (hasFinancialData) ...[
                              _buildSubTabSelector(),
                              const SizedBox(height: 16),
                              _activeTab == 0
                                  ? _buildReportTabContent(wide)
                                  : _buildComparisonTabContent(wide),
                              if (_activeTab == 0) ...[
                                const SizedBox(height: 24),
                                _buildExpensesHeader(),
                              ],
                            ] else
                              _buildFinancialEmptyState(),
                          ],
                        ),
                      ),
                      if (hasFinancialData && _activeTab == 0)
                        _buildExpensesList(),
                      const SliverToBoxAdapter(child: SizedBox(height: 16)),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildFinancialEmptyState() {
    return Card(
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 52),
        child: Column(
          children: [
            const Icon(
              Icons.account_balance_wallet_outlined,
              color: AppColors.primary,
              size: 52,
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد بيانات مالية لعرض تقرير بعد',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18.sp(context),
                color: AppColors.heading,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'أضف حجزًا من شاشة الحجوزات أو سجّل أول مصروف. ستظهر التقارير والمقارنات تلقائيًا بعد حفظ بياناتك.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.secondaryText,
                height: 1.5,
                fontSize: 13.sp(context),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _showAddExpenseDialog,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('تسجيل أول مصروف'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubTabSelector() => AdaptiveItems(
    minItemWidth: 250,
    maxColumns: 2,
    children: [
      ChoiceChip(
        key: const ValueKey('finance-report-tab'),
        label: const Text('التقرير والتحليل المالي العام'),
        selected: _activeTab == 0,
        onSelected: (_) => setState(() => _activeTab = 0),
      ),
      ChoiceChip(
        key: const ValueKey('finance-comparison-tab'),
        label: const Text('المقارنة المالية المتقدمة'),
        selected: _activeTab == 1,
        onSelected: (_) => setState(() => _activeTab = 1),
      ),
    ],
  );

  Widget _buildReportTabContent(bool isWide) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _buildAdvancedFilterPanel(),
      const SizedBox(height: 16),
      AdaptiveItems(
        minItemWidth: 210,
        children: [
          _buildCard(
            'إجمالي مبالغ الإيجار',
            _totalRevenue,
            AppColors.successText,
            Icons.monetization_on_outlined,
          ),
          _buildCard(
            'التأمينات المعلقة',
            _totalSecurityDeposit,
            AppColors.primary,
            Icons.security_outlined,
          ),
          _buildCard(
            'إجمالي المصروفات',
            _totalExpenses,
            AppColors.errorText,
            Icons.arrow_downward,
          ),
          _buildCard(
            'صافي الأرباح',
            _totalRevenue - _totalExpenses,
            AppColors.primary,
            Icons.account_balance,
          ),
        ],
      ),
      const SizedBox(height: 24),
      _buildChartsSection(),
    ],
  );

  Map<String, double> _getMonthFinancials(int year, int month) {
    double revenue = 0.0;
    double security = 0.0;
    double expenses = 0.0;
    int bookingsCount = 0;

    for (final booking in _allBookings) {
      final date = DateTime.tryParse(booking['start_date']?.toString() ?? '');
      if (date != null &&
          date.year == year &&
          date.month == month &&
          _isConfirmedBooking(booking)) {
        revenue += (booking['total_price'] as num).toDouble();
        if (_hasPendingDeposit(booking)) {
          security += (booking['security_deposit'] as num?)?.toDouble() ?? 0.0;
        }
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

    for (final booking in _allBookings) {
      final date = DateTime.tryParse(booking['start_date']?.toString() ?? '');
      if (date != null && date.year == year && _isConfirmedBooking(booking)) {
        revenue += (booking['total_price'] as num).toDouble();
        if (_hasPendingDeposit(booking)) {
          security += (booking['security_deposit'] as num?)?.toDouble() ?? 0.0;
        }
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
    const months = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];
    return SectionCard(
      title: 'تحديد خيارات المقارنة',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdaptiveItems(
            minItemWidth: 230,
            maxColumns: 2,
            children: [
              ChoiceChip(
                label: const Text('مقارنة بين الأشهر'),
                selected: _comparisonType == 'months',
                onSelected: (_) => setState(() => _comparisonType = 'months'),
              ),
              ChoiceChip(
                label: const Text('مقارنة بين السنوات'),
                selected: _comparisonType == 'years',
                onSelected: (_) => setState(() => _comparisonType = 'years'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AdaptiveItems(
            minItemWidth: 200,
            children: [
              if (_comparisonType == 'months') ...[
                _labelledDropdown('السنة', _compMonthYear, _getYearRange(), (
                  v,
                ) {
                  if (v != null) {
                    setState(() => _compMonthYear = v);
                  }
                }),
                _labelledDropdown(
                  'الشهر الأول',
                  _compMonth1,
                  List.generate(12, (i) => i + 1),
                  (v) {
                    if (v != null) {
                      setState(() => _compMonth1 = v);
                    }
                  },
                  itemToString: (v) => months[v - 1],
                ),
                _labelledDropdown(
                  'الشهر الثاني',
                  _compMonth2,
                  List.generate(12, (i) => i + 1),
                  (v) {
                    if (v != null) {
                      setState(() => _compMonth2 = v);
                    }
                  },
                  itemToString: (v) => months[v - 1],
                ),
              ] else ...[
                _labelledDropdown('السنة الأولى', _compYear1, _getYearRange(), (
                  v,
                ) {
                  if (v != null) {
                    setState(() => _compYear1 = v);
                  }
                }),
                _labelledDropdown(
                  'السنة الثانية',
                  _compYear2,
                  _getYearRange(),
                  (v) {
                    if (v != null) {
                      setState(() => _compYear2 = v);
                    }
                  },
                ),
              ],
            ],
          ),
        ],
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
        color: AppColors.primary.withAlpha(15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withAlpha(40)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          itemHeight: null,
          value: value,
          icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
            fontSize: 13.sp(context),
          ),
          items: items.map((item) {
            return DropdownMenuItem<T>(
              value: item,
              child: Text(
                itemToString != null ? itemToString(item) : item.toString(),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildComparisonChart(
    Map<String, double> dataA,
    Map<String, double> dataB,
    String labelA,
    String labelB,
  ) {
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

    return ResponsiveBarChart(groups: groups, labels: {0: labelA, 1: labelB});
  }

  Widget _buildComparisonStats(
    Map<String, double> dataA,
    Map<String, double> dataB,
    String labelA,
    String labelB,
  ) {
    return Column(
      children: [
        _buildComparisonRow(
          'إجمالي مبالغ الإيجار',
          dataA['revenue']!,
          dataB['revenue']!,
          AppColors.successText,
          Icons.monetization_on_outlined,
        ),
        const SizedBox(height: 12),
        _buildComparisonRow(
          'إجمالي مبالغ التأمين',
          dataA['security'] ?? 0.0,
          dataB['security'] ?? 0.0,
          AppColors.primaryPressed,
          Icons.security_outlined,
        ),
        const SizedBox(height: 12),
        _buildComparisonRow(
          'إجمالي المصروفات',
          dataA['expenses']!,
          dataB['expenses']!,
          AppColors.errorText,
          Icons.arrow_downward,
        ),
        const SizedBox(height: 12),
        _buildComparisonRow(
          'صافي الأرباح',
          dataA['net']!,
          dataB['net']!,
          AppColors.primary,
          Icons.account_balance,
        ),
        const SizedBox(height: 12),
        _buildComparisonRow(
          'عدد الحجوزات',
          dataA['bookings']!,
          dataB['bookings']!,
          Colors.indigo,
          Icons.calendar_month,
          isCurrency: false,
        ),
      ],
    );
  }

  Widget _buildComparisonRow(
    String title,
    double valA,
    double valB,
    Color color,
    IconData icon, {
    bool isCurrency = true,
  }) {
    final diff = valB - valA;
    final percentDiff = valA > 0 ? (diff / valA) * 100 : 0.0;

    String diffText = '';
    Color diffColor = AppColors.secondaryText;
    IconData diffIcon = Icons.remove;

    if (diff > 0) {
      diffText =
          '+${diff.toStringAsFixed(0)}${isCurrency ? " ر.س" : ""} (${percentDiff.toStringAsFixed(1)}%)';
      diffColor = AppColors.successText;
      diffIcon = Icons.trending_up;
    } else if (diff < 0) {
      diffText =
          '${diff.toStringAsFixed(0)}${isCurrency ? " ر.س" : ""} (${percentDiff.toStringAsFixed(1)}%)';
      diffColor = AppColors.errorText;
      diffIcon = Icons.trending_down;
    } else {
      diffText = 'لا يوجد اختلاف (0%)';
      diffColor = AppColors.secondaryText;
      diffIcon = Icons.trending_flat;
    }

    return SectionCard(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdaptiveItems(
            minItemWidth: 210,
            maxColumns: 2,
            children: [
              if (isCurrency)
                LabelledAmount('الفترة الأولى', valA)
              else
                Text('الفترة الأولى: ${valA.toInt()}'),
              if (isCurrency)
                LabelledAmount('الفترة الثانية', valB)
              else
                Text('الفترة الثانية: ${valB.toInt()}'),
            ],
          ),
          const SizedBox(height: 12),
          Icon(diffIcon, size: 20, color: diffColor),
          Text(
            diffText,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: diffColor),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonInsights(
    Map<String, double> dataA,
    Map<String, double> dataB,
    String labelA,
    String labelB,
  ) {
    final netDiff = dataB['net']! - dataA['net']!;
    final revDiff = dataB['revenue']! - dataA['revenue']!;
    final expDiff = dataB['expenses']! - dataA['expenses']!;

    String title = '';
    String description = '';
    Color highlightColor = AppColors.secondaryText;

    if (netDiff > 0) {
      title = 'أداء مالي أفضل لـ $labelB';
      description =
          'حقق $labelB صافي أرباح أعلى بقيمة ${netDiff.toStringAsFixed(0)} ر.س مقارنة بـ $labelA. ';
      if (revDiff > 0) {
        description +=
            'وكان هذا الارتفاع مدفوعاً بزيادة الإيرادات بقيمة ${revDiff.toStringAsFixed(0)} ر.س. ';
      }
      if (expDiff < 0) {
        description +=
            'بالإضافة إلى نجاحك في خفض المصروفات التشغيلية بقيمة ${(-expDiff).toStringAsFixed(0)} ر.س. ';
      }
      highlightColor = AppColors.primary;
    } else if (netDiff < 0) {
      title = 'أداء مالي أفضل لـ $labelA';
      description =
          'حقق $labelA صافي أرباح أعلى بقيمة ${(-netDiff).toStringAsFixed(0)} ر.س مقارنة بـ $labelB. ';
      if (revDiff < 0) {
        description +=
            'حيث انخفضت الإيرادات في $labelB بقيمة ${(-revDiff).toStringAsFixed(0)} ر.س. ';
      }
      if (expDiff > 0) {
        description +=
            'بالإضافة إلى ارتفاع المصاريف التشغيلية في $labelB بقيمة ${expDiff.toStringAsFixed(0)} ر.س. ';
      }
      highlightColor = AppColors.errorText;
    } else {
      title = 'أداء مالي متطابق';
      description = 'لا يوجد اختلاف في صافي الأرباح بين الفترتين المحددتين. ';
      highlightColor = AppColors.secondaryText;
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
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15.sp(context),
                      color: highlightColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                fontSize: 13.sp(context),
                color: AppColors.text,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonTabContent(bool isWide) {
    const monthNames = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];

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
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15.sp(context),
                color: AppColors.heading,
              ),
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
            _buildComparisonChart(dataA, dataB, labelA, labelB),
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
                Expanded(flex: 2, child: stats),
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

  Widget _buildCard(String title, double amount, Color color, IconData icon) =>
      MetricCard(title: title, value: amount, color: color, icon: icon);

  Widget _buildExpensesHeader() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'سجل المصروفات التشغيلية',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 12),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: FilledButton(
          key: const ValueKey('add-expense'),
          onPressed: _showAddExpenseDialog,
          child: const ActionLabel(
            Icons.add_circle_outline,
            'تسجيل مصروف جديد',
          ),
        ),
      ),
      const SizedBox(height: 12),
    ],
  );

  Widget _buildChartsSection() {
    if (_expenses.isEmpty && _filteredBookings.isEmpty) {
      return const SectionCard(
        title: 'التحليل البياني المالي',
        child: Text('لا توجد عمليات مالية مسجلة للفترة المحددة'),
      );
    }
    final groups = _showComparison
        ? _buildComparisonBarGroups()
        : _buildComparativeBarGroups();
    return AdaptiveItems(
      minItemWidth: 460,
      maxColumns: 2,
      children: [
        SectionCard(
          title: _showComparison
              ? 'مقارنة مالية: $_selectedYear مقابل $_comparisonYear'
              : 'مقارنة الإيرادات والمصروفات',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ResponsiveBarChart(
                groups: groups,
                labels: {for (final g in groups) g.x: '${g.x}/$_selectedYear'},
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  _buildLegendItem(
                    AppColors.successText,
                    'إيرادات $_selectedYear',
                  ),
                  _buildLegendItem(
                    AppColors.errorText,
                    'مصروفات $_selectedYear',
                  ),
                  if (_showComparison) ...[
                    _buildLegendItem(
                      const Color(0xFF60A5FA),
                      'إيرادات $_comparisonYear',
                    ),
                    _buildLegendItem(
                      AppColors.warningText,
                      'مصروفات $_comparisonYear',
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        SectionCard(
          title: 'توزيع المصاريف حسب التصنيف',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_expenses.isEmpty)
                const Text(
                  'لا توجد مصروفات مسجلة لعرض تصنيفاتها للفترة المحددة',
                )
              else ...[
                SizedBox(
                  height: 200,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 44,
                      sections: _buildPieSections(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildPieLegend(),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    );
  }

  Widget _buildExpensesList() {
    if (_expenses.isEmpty) {
      return const SliverToBoxAdapter(child: Text('لا توجد مصروفات مسجلة بعد'));
    }
    final sorted = List<Map<String, dynamic>>.from(_expenses)
      ..sort((a, b) => b['date'].toString().compareTo(a['date'].toString()));
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final expense = sorted[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  expense['description'].toString(),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  expense['category']?.toString() ?? 'مصاريف تشغيلية أخرى',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  expense['date'].toString(),
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.end,
                ),
                AmountText(
                  expense['amount'] as num,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(color: AppColors.errorText),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      onPressed: () => _showEditExpenseDialog(expense),
                      child: const ActionLabel(Icons.edit_outlined, 'تعديل'),
                    ),
                    TextButton(
                      onPressed: () => _confirmDeleteExpense(expense['id']),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.errorText,
                      ),
                      child: const ActionLabel(Icons.delete_outline, 'حذف'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }, childCount: sorted.length),
    );
  }
}
