import 'package:flutter/material.dart';
import 'package:hijri/hijri_calendar.dart';

import '../theme/app_theme.dart';
import '../utils/hijri_date_helpers.dart';
import '../utils/responsive.dart';

class HijriDatePickerDialog extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  const HijriDatePickerDialog({
    super.key,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  @override
  State<HijriDatePickerDialog> createState() => _HijriDatePickerDialogState();
}

class _HijriDatePickerDialogState extends State<HijriDatePickerDialog> {
  late int _selectedYear;
  late int _selectedMonth;
  late int _selectedDay;

  @override
  void initState() {
    super.initState();
    final hijri = HijriCalendar.fromDate(widget.initialDate);
    _selectedYear = hijri.hYear;
    _selectedMonth = hijri.hMonth;
    _selectedDay = hijri.hDay;
  }

  void _nextMonth() {
    setState(() {
      if (_selectedMonth == 12) {
        _selectedMonth = 1;
        _selectedYear++;
      } else {
        _selectedMonth++;
      }
      final maxDays = HijriCalendar().getDaysInMonth(
        _selectedYear,
        _selectedMonth,
      );
      if (_selectedDay > maxDays) {
        _selectedDay = maxDays;
      }
    });
  }

  void _previousMonth() {
    setState(() {
      if (_selectedMonth == 1) {
        _selectedMonth = 12;
        _selectedYear--;
      } else {
        _selectedMonth--;
      }
      final maxDays = HijriCalendar().getDaysInMonth(
        _selectedYear,
        _selectedMonth,
      );
      if (_selectedDay > maxDays) {
        _selectedDay = maxDays;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth = HijriCalendar().getDaysInMonth(
      _selectedYear,
      _selectedMonth,
    );
    final firstDayGregorian = HijriCalendar().hijriToGregorian(
      _selectedYear,
      _selectedMonth,
      1,
    );
    final startOffset = firstDayGregorian.weekday % 7;

    const weekdayNames = ['ح', 'ن', 'ث', 'ر', 'خ', 'ج', 'س'];

    return AlertDialog(
      scrollable: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      titlePadding: const EdgeInsets.all(16),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: AppColors.primary),
            onPressed: _previousMonth,
          ),
          Text(
            '${getArabicHijriMonthName(_selectedMonth)} ${toArabicDigits(_selectedYear)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16.sp(context),
              color: AppColors.primary,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: AppColors.primary),
            onPressed: _nextMonth,
          ),
        ],
      ),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: weekdayNames.map((day) {
                return Expanded(
                  child: Center(
                    child: Text(
                      day,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12.sp(context),
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const Divider(height: 12, thickness: 1),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
              ),
              itemCount: startOffset + daysInMonth,
              itemBuilder: (context, index) {
                if (index < startOffset) {
                  return const SizedBox.shrink();
                }
                final dayNum = index - startOffset + 1;
                final isSelected = dayNum == _selectedDay;

                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedDay = dayNum;
                    });
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: isSelected
                        ? const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          )
                        : null,
                    child: Text(
                      toArabicDigits(dayNum),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.sp(context),
                        color: isSelected ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text(
            'إلغاء',
            style: TextStyle(color: AppColors.secondaryText),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            final targetGregorian = HijriCalendar().hijriToGregorian(
              _selectedYear,
              _selectedMonth,
              _selectedDay,
            );
            Navigator.pop(context, targetGregorian);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('تأكيد'),
        ),
      ],
    );
  }
}
