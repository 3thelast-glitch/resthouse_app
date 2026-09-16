import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/adaptive_content.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:flutter/services.dart';

import '../utils/responsive.dart';

import 'package:table_calendar/table_calendar.dart';
import 'package:hijri/hijri_calendar.dart';

import '../database_helper.dart';
import '../services/booking_status_service.dart';
import 'booking_payments_dialog.dart';

String toArabicDigits(int number) {
  const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  return number
      .toString()
      .split('')
      .map((char) {
        int? val = int.tryParse(char);
        return val != null ? arabicDigits[val] : char;
      })
      .join('');
}

String getArabicHijriMonthName(int hMonth) {
  const months = [
    'محرم',
    'صفر',
    'ربيع الأول',
    'ربيع الآخر',
    'جمادى الأولى',
    'جمادى الآخرة',
    'رجب',
    'شعبان',
    'رمضان',
    'شوال',
    'ذو القعدة',
    'ذو الحجة',
  ];
  if (hMonth >= 1 && hMonth <= 12) {
    return months[hMonth - 1];
  }
  return '';
}

class BookingManagerPage extends StatefulWidget {
  const BookingManagerPage({super.key});

  @override
  State<BookingManagerPage> createState() => _BookingManagerPageState();
}

class _BookingManagerPageState extends State<BookingManagerPage> {
  final dbHelper = DatabaseHelper.instance;
  List<Map<String, dynamic>> _bookings = [];
  List<Map<String, dynamic>> _renters = [];
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // للتبديل في القائمة الجانبية بين الحجوزات والمستأجرين
  bool _showRentersTab = false;
  String _bookingFilter = 'active'; // 'active' or 'archived'
  String _searchQuery = '';
  final _searchController = TextEditingController();
  final _paymentSummaries = <int, Future<Map<String, double>>>{};
  bool _calendarExpanded = true;
  bool _loading = true;
  String? _loadError;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final bookings = await dbHelper.queryAllBookings();
      final renters = await dbHelper.queryAllRenters();
      if (!mounted) {
        return;
      }
      setState(() {
        _bookings = bookings;
        _renters = renters;
        _paymentSummaries.clear();
        _loading = false;
        _loadError = null;
      });
      _checkPendingDeposits();
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = 'تعذر تحميل الحجوزات. حاول مرة أخرى.';
        });
      }
    }
  }

  /// Formats a date showing both Gregorian and Hijri side-by-side
  /// Example: "البداية: 2026-06-13 | ١٩ ذو الحجة ١٤٤٧"
  String _formatDualDate(DateTime? date, String label) {
    if (date == null) {
      return label;
    }
    final gregorian = date.toString().split(' ')[0];
    final hijri = HijriCalendar.fromDate(date);
    final hijriStr =
        '${toArabicDigits(hijri.hDay)} ${getArabicHijriMonthName(hijri.hMonth)} ${toArabicDigits(hijri.hYear)}';
    return '$label: $gregorian\n$hijriStr';
  }

  String _formatHijriDateOnlyArabic(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) {
      return '';
    }
    final parsed = DateTime.tryParse(dateStr);
    if (parsed == null) {
      return dateStr;
    }

    final hijri = HijriCalendar.fromDate(parsed);
    final hDay = hijri.hDay;
    final hMonthName = getArabicHijriMonthName(hijri.hMonth);
    final hYear = hijri.hYear;

    return '$hDay $hMonthName $hYear';
  }

  Future<DateTime?> _selectDateDual(
    BuildContext context,
    DateTime initialDate,
  ) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'اختر نوع التقويم',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16.sp(context),
          ),
          textAlign: TextAlign.center,
        ),
        content: Text(
          'هل ترغب في تحديد التاريخ بالتقويم الميلادي أم الهجري؟',
          style: TextStyle(fontSize: 13.sp(context)),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(ctx, 'gregorian'),
                  icon: const Icon(Icons.calendar_month, size: 18),
                  label: const Text('ميلادي'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(ctx, 'hijri'),
                  icon: const Icon(Icons.mosque, size: 18),
                  label: const Text('هجري'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryPressed,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (choice == 'gregorian') {
      if (!context.mounted) {
        return null;
      }
      return await showDatePicker(
        context: context,
        initialDate: initialDate,
        firstDate: DateTime(2020),
        lastDate: DateTime(2050),
      );
    } else if (choice == 'hijri') {
      if (!context.mounted) {
        return null;
      }
      return await showDialog<DateTime>(
        context: context,
        builder: (ctx) => HijriDatePickerDialog(
          initialDate: initialDate,
          firstDate: DateTime(2020),
          lastDate: DateTime(2050),
        ),
      );
    }
    return null;
  }

  /// Feature 3: Checks for ended bookings whose deposit is still pending
  /// and shows sequential alert dialogs to the admin.
  Future<void> _checkPendingDeposits() async {
    final pendingBookings = await dbHelper
        .queryEndedBookingsWithPendingDeposit();
    if (pendingBookings.isEmpty || !mounted) {
      return;
    }

    for (final booking in pendingBookings) {
      if (!mounted) {
        return;
      }
      final renter = _renters.firstWhere(
        (r) => r['phone'] == booking['phone'],
        orElse: () => {'full_name': 'مستأجر غير معروف'},
      );
      final depositAmount = booking['security_deposit'] ?? 0.0;
      final renterName = renter['full_name'].toString();

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          scrollable: true,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Colors.white,
          titlePadding: const EdgeInsetsDirectional.fromSTEB(24, 24, 24, 0),
          title: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.warningSurface,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.warningText, width: 2),
                ),
                child: const Icon(
                  Icons.account_balance_wallet,
                  color: AppColors.warningText,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'انتهت فترة حجز $renterName',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17.sp(context),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.selectedSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withAlpha(51)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.security,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'قيمة التأمين: $depositAmount ر.س',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15.sp(context),
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'من ${booking['start_date']} إلى ${booking['end_date']}',
                style: TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 13.sp(context),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'هل تم إعادة مبلغ التأمين للعميل، أم تم خصمه؟',
                style: TextStyle(
                  fontSize: 14.sp(context),
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actionsPadding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 16),
          actions: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    await dbHelper.updateDepositStatus(
                      booking['id'],
                      'returned',
                    );
                    if (!dialogContext.mounted) {
                      return;
                    }
                    Navigator.pop(dialogContext);
                  },
                  icon: const Icon(Icons.check_circle_outline, size: 20),
                  label: const Text('تم إرجاع التأمين'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.successText,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () async {
                    await dbHelper.updateDepositStatus(
                      booking['id'],
                      'deducted',
                    );
                    if (!dialogContext.mounted) {
                      return;
                    }
                    Navigator.pop(dialogContext);
                  },
                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                  label: const Text('تم خصم التأمين'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.errorText,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(dialogContext),
                  icon: const Icon(Icons.schedule, size: 20),
                  label: const Text('تذكيرني لاحقاً'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.secondaryText,
                    side: const BorderSide(color: AppColors.divider),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }
    // Reload data after handling deposits
    if (mounted) {
      final bookings = await dbHelper.queryAllBookings();
      final renters = await dbHelper.queryAllRenters();
      if (!mounted) {
        return;
      }
      setState(() {
        _bookings = bookings;
        _renters = renters;
      });
    }
  }

  // الحصول على الحجوزات المتقاطعة مع يوم معين (start_date <= day <= end_date)
  List<Map<String, dynamic>> _getBookingsForDay(DateTime day) {
    final dateStr =
        "${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}";
    return _bookings
        .where((b) => BookingStatusService.occupiesDay(b, dateStr))
        .toList();
  }

  void _showAddRenterDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: const Text(
          'إضافة مستأجر جديد',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'الاسم الكامل',
                  icon: Icon(Icons.person_outline),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'الرجاء إدخال الاسم الكامل';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                textDirection: TextDirection.ltr,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: const InputDecoration(
                  labelText: 'الهاتف (مهم جداً فريد)',
                  icon: Icon(Icons.phone_outlined),
                ),
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

              final name = nameController.text.trim();
              final phone = phoneController.text.trim();

              try {
                await dbHelper.insertRenter({
                  'full_name': name,
                  'phone': phone,
                  'notes': '',
                  'rating': 5,
                  'rental_count': 0,
                });
                await _loadData();
                if (!dialogContext.mounted) {
                  return;
                }
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('تمت إضافة المستأجر بنجاح')),
                );
              } catch (e) {
                if (!dialogContext.mounted) {
                  return;
                }
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

  void _showEditRenterDialog(Map<String, dynamic> renter) {
    final nameController = TextEditingController(text: renter['full_name']);
    final phoneController = TextEditingController(text: renter['phone']);
    final notesController = TextEditingController(text: renter['notes'] ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: const Text(
          'تعديل بيانات المستأجر',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'الاسم الكامل',
                  icon: Icon(Icons.person_outline),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'الرجاء إدخال الاسم الكامل';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                textDirection: TextDirection.ltr,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: const InputDecoration(
                  labelText: 'رقم الهاتف',
                  icon: Icon(Icons.phone_outlined),
                ),
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
              const SizedBox(height: 8),
              TextFormField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'الملاحظات',
                  icon: Icon(Icons.notes),
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
              if (!formKey.currentState!.validate()) {
                return;
              }

              final name = nameController.text.trim();
              final phone = phoneController.text.trim();
              final notes = notesController.text.trim();

              try {
                await dbHelper.updateRenter({
                  'phone': phone,
                  'full_name': name,
                  'notes': notes,
                  'rating': renter['rating'] ?? 5,
                  'rental_count': renter['rental_count'] ?? 0,
                }, oldPhone: renter['phone']);
                await _loadData();
                if (!dialogContext.mounted) {
                  return;
                }
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text('تم تحديث بيانات المستأجر بنجاح'),
                  ),
                );
              } catch (e) {
                if (!dialogContext.mounted) {
                  return;
                }
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'خطأ: قد يكون الهاتف الجديد مستخدماً من عميل آخر',
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
            child: const Text('حفظ التعديلات'),
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

  void _showAddBookingDialog() {
    String? selectedPhone;
    String? selectedRenterNotes;
    DateTime? startDate = _selectedDay;
    DateTime? endDate = _selectedDay;
    final priceController = TextEditingController();
    final securityDepositController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          scrollable: true,
          title: const Text(
            'إضافة حجز جديد',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  isDense: false,
                  itemHeight: null,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'اختر المستأجر',
                    icon: Icon(Icons.person_outline),
                  ),
                  initialValue: selectedPhone,
                  items: _renters.map((renter) {
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
                      final renter = _renters.firstWhere(
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
                          final date = await _selectDateDual(
                            dialogContext,
                            startDate ?? DateTime.now(),
                          );
                          if (!dialogContext.mounted) {
                            return;
                          }
                          if (date != null) {
                            setDialogState(() {
                              startDate = date;
                              // إصلاح الخلل: تحديث تاريخ النهاية تلقائياً إذا كان يسبق البداية
                              if (endDate == null ||
                                  endDate!.isBefore(startDate!)) {
                                endDate = startDate;
                              }
                            });
                          }
                        },
                        child: Text(
                          _formatDualDate(startDate, 'البداية'),
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12.sp(context)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
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
                          // تحديد تاريخ البداية الحالي ليكون الحد الأدنى الآمن
                          final initialDate =
                              (endDate != null &&
                                  startDate != null &&
                                  !endDate!.isBefore(startDate!))
                              ? endDate!
                              : (startDate ?? DateTime.now());

                          final date = await _selectDateDual(
                            dialogContext,
                            initialDate,
                          );
                          if (!dialogContext.mounted) {
                            return;
                          }
                          if (date != null) {
                            setDialogState(() {
                              endDate = date;
                            });
                          }
                        },
                        child: Text(
                          _formatDualDate(endDate, 'النهاية'),
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12.sp(context)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: priceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'سعر الحجز الإجمالي (ر.س)',
                    icon: Icon(Icons.attach_money),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: securityDepositController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'سعر التأمين (ر.س)',
                    icon: Icon(Icons.security),
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

                if (selectedPhone == null) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('الرجاء اختيار مستأجر')),
                  );
                  return;
                }
                if (startDate == null || endDate == null) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('الرجاء تحديد فترات الحجز')),
                  );
                  return;
                }
                if (endDate!.isBefore(startDate!)) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'تاريخ النهاية يجب أن يكون مساوياً أو بعد تاريخ البداية',
                      ),
                    ),
                  );
                  return;
                }
                if (price <= 0) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('الرجاء إدخال سعر صحيح أكبر من الصفر'),
                    ),
                  );
                  return;
                }

                // فحص تعارض المواعيد
                final conflict = await dbHelper.hasBookingConflict(
                  startDate!.toString().split(' ')[0],
                  endDate!.toString().split(' ')[0],
                );
                if (conflict) {
                  if (!dialogContext.mounted) {
                    return;
                  }
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

                  await _loadData();
                  if (!dialogContext.mounted) {
                    return;
                  }
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('تم تسجيل الحجز بنجاح')),
                  );
                } on StateError catch (error) {
                  if (!dialogContext.mounted) {
                    return;
                  }
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: Text(error.message),
                      backgroundColor: AppColors.errorText,
                    ),
                  );
                } on ArgumentError catch (error) {
                  if (!dialogContext.mounted) {
                    return;
                  }
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

  void _showEditBookingDialog(Map<String, dynamic> booking) {
    DateTime? startDate = DateTime.tryParse(booking['start_date']);
    DateTime? endDate = DateTime.tryParse(booking['end_date']);
    final priceController = TextEditingController(
      text: booking['total_price'].toString(),
    );
    final securityDepositController = TextEditingController(
      text: (booking['security_deposit'] ?? 0.0).toString(),
    );
    String selectedStatus = booking['status'] ?? 'confirmed';

    final renter = _renters.firstWhere(
      (r) => r['phone'] == booking['phone'],
      orElse: () => {'full_name': 'مستأجر غير معروف'},
    );

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          scrollable: true,
          title: const Text(
            'تعديل الحجز الحالي',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.person_outline,
                    color: AppColors.primary,
                  ),
                  title: Text(
                    'المستأجر',
                    style: TextStyle(
                      fontSize: 12.sp(context),
                      color: AppColors.secondaryText,
                    ),
                  ),
                  subtitle: Text(
                    '${renter['full_name']} (${booking['phone']})',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const Divider(),
                const SizedBox(height: 8),
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
                          final date = await _selectDateDual(
                            dialogContext,
                            startDate ?? DateTime.now(),
                          );
                          if (!dialogContext.mounted) {
                            return;
                          }
                          if (date != null) {
                            setDialogState(() {
                              startDate = date;
                              if (endDate == null ||
                                  endDate!.isBefore(startDate!)) {
                                endDate = startDate;
                              }
                            });
                          }
                        },
                        child: Text(
                          _formatDualDate(startDate, 'البداية'),
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12.sp(context)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
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
                          final initialDate =
                              (endDate != null &&
                                  startDate != null &&
                                  !endDate!.isBefore(startDate!))
                              ? endDate!
                              : (startDate ?? DateTime.now());

                          final date = await _selectDateDual(
                            dialogContext,
                            initialDate,
                          );
                          if (!dialogContext.mounted) {
                            return;
                          }
                          if (date != null) {
                            setDialogState(() {
                              endDate = date;
                            });
                          }
                        },
                        child: Text(
                          _formatDualDate(endDate, 'النهاية'),
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12.sp(context)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: priceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'سعر الحجز الإجمالي (ر.س)',
                    icon: Icon(Icons.attach_money),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: securityDepositController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'قيمة التأمين (ر.س)',
                    icon: Icon(Icons.security),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  isDense: false,
                  itemHeight: null,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'حالة الحجز',
                    icon: Icon(Icons.info_outline),
                  ),
                  initialValue: selectedStatus,
                  items: const [
                    DropdownMenuItem(value: 'confirmed', child: Text('مؤكد')),
                    DropdownMenuItem(
                      value: 'pending',
                      child: Text('قيد الانتظار'),
                    ),
                    DropdownMenuItem(value: 'cancelled', child: Text('ملغي')),
                  ],
                  onChanged: (value) => setDialogState(
                    () => selectedStatus = value ?? 'confirmed',
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

                if (startDate == null || endDate == null) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('الرجاء تحديد فترات الحجز')),
                  );
                  return;
                }
                if (endDate!.isBefore(startDate!)) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'تاريخ النهاية يجب أن يكون مساوياً أو بعد تاريخ البداية',
                      ),
                    ),
                  );
                  return;
                }
                if (price <= 0) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('الرجاء إدخال سعر صحيح أكبر من الصفر'),
                    ),
                  );
                  return;
                }

                // فحص تعارض المواعيد فقط للحجوزات المؤكدة
                if (selectedStatus == 'confirmed') {
                  final conflict = await dbHelper.hasBookingConflict(
                    startDate!.toString().split(' ')[0],
                    endDate!.toString().split(' ')[0],
                    excludeId: booking['id'],
                  );
                  if (conflict) {
                    if (!dialogContext.mounted) {
                      return;
                    }
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
                }

                try {
                  await dbHelper.updateBooking({
                    'id': booking['id'],
                    'phone': booking['phone'],
                    'start_date': startDate!.toString().split(' ')[0],
                    'end_date': endDate!.toString().split(' ')[0],
                    'total_price': price,
                    'security_deposit': securityDeposit,
                    'status': selectedStatus,
                  });

                  await _loadData();
                  if (!dialogContext.mounted) {
                    return;
                  }
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('تم تعديل بيانات الحجز بنجاح'),
                    ),
                  );
                } on StateError catch (error) {
                  if (!dialogContext.mounted) {
                    return;
                  }
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: Text(error.message),
                      backgroundColor: AppColors.errorText,
                    ),
                  );
                } on ArgumentError catch (error) {
                  if (!dialogContext.mounted) {
                    return;
                  }
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
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteBooking(int id) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: const Text('تأكيد الحذف'),
        content: const Text('هل تريد حذف هذا الحجز نهائياً من قاعدة البيانات؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await dbHelper.deleteBooking(id);
                if (!dialogContext.mounted) {
                  return;
                }
                Navigator.pop(dialogContext);
                await _loadData();
                if (!mounted) {
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم حذف الحجز بنجاح')),
                );
              } on StateError catch (error) {
                if (!dialogContext.mounted) {
                  return;
                }
                Navigator.pop(dialogContext);
                if (!mounted) {
                  return;
                }
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(error.message)));
              }
            },
            child: const Text(
              'حذف الحجز',
              style: TextStyle(color: AppColors.errorText),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteRenter(String phone) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: const Text('تأكيد حذف المستأجر'),
        content: const Text(
          'تحذير: سيؤدي حذف المستأجر إلى إزالة بياناته فقط. إذا كان لديه حجوزات مرتبطة فقد تظهر كـ "غير معروف". هل تريد الاستمرار؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await dbHelper.deleteRenter(phone);
                await _loadData();
                if (!dialogContext.mounted) {
                  return;
                }
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('تم حذف المستأجر بنجاح')),
                );
              } catch (e) {
                if (!dialogContext.mounted) {
                  return;
                }
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text('تعذر الحذف لوجود قيود على البيانات'),
                  ),
                );
              }
            },
            child: const Text(
              'حذف المستأجر',
              style: TextStyle(color: AppColors.errorText),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarDayCell(
    DateTime day, {
    required bool isSelected,
    required bool isToday,
    required bool isOutside,
  }) {
    final hijri = HijriCalendar.fromDate(day);
    final color = isSelected ? Colors.white : AppColors.heading;
    return Semantics(
      label:
          '${DateFormat('yyyy-MM-dd').format(day)}، ${hijri.hDay} ${getArabicHijriMonthName(hijri.hMonth)} ${hijri.hYear}',
      selected: isSelected,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : isToday
              ? AppColors.selectedSurface
              : null,
          borderRadius: BorderRadius.circular(8),
          border: isToday ? Border.all(color: AppColors.primary) : null,
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              toArabicDigits(hijri.hDay),
              textDirection: TextDirection.ltr,
              style: TextStyle(
                fontSize: 14,
                height: 1.25,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${day.day}',
              textDirection: TextDirection.ltr,
              style: TextStyle(
                fontSize: 12,
                height: 1.25,
                color: isSelected ? Colors.white : AppColors.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_loadError!),
              TextButton(
                onPressed: _loadData,
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }
    final rows = _showRentersTab ? _matchingRenters() : _matchingBookings();
    Widget directorySliver() => rows.isEmpty
        ? SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                _showRentersTab
                    ? 'لا توجد مستأجرين مسجلين بعد'
                    : 'لا توجد حجوزات مطابقة',
              ),
            ),
          )
        : SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _showRentersTab
                  ? _buildRenterCard(rows[index])
                  : _buildBookingCard(rows[index]),
              childCount: rows.length,
            ),
          );
    Widget scroller(List<Widget> slivers, String name) => CustomScrollView(
      key: PageStorageKey(name),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverMainAxisGroup(slivers: slivers),
        ),
      ],
    );
    return Scaffold(
      backgroundColor: AppColors.background,
      body: ContentWidth(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide =
                constraints.maxWidth >= 1024 * ContentLayout.textScale(context);
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: scroller([
                      SliverToBoxAdapter(child: _buildDirectoryControls()),
                      directorySliver(),
                    ], 'booking-directory-wide'),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: scroller([
                      SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildBookingActions(),
                            const SizedBox(height: 16),
                            _buildCalendar(),
                            const SizedBox(height: 16),
                            _buildDayBookingsListAdaptive(),
                          ],
                        ),
                      ),
                    ], 'booking-calendar-wide'),
                  ),
                ],
              );
            }
            return scroller([
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildBookingActions(),
                    const SizedBox(height: 16),
                    _buildDirectoryControls(),
                    if (!_showRentersTab) ...[
                      _buildCalendar(),
                      const SizedBox(height: 16),
                      _buildDayBookingsListAdaptive(),
                      const SizedBox(height: 16),
                    ],
                    Text(
                      _showRentersTab ? 'قائمة المستأجرين' : 'قائمة الحجوزات',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
              directorySliver(),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
            ], 'booking-page-scroll');
          },
        ),
      ),
    );
  }

  Widget _buildBookingActions() => AdaptiveItems(
    minItemWidth: 230,
    maxColumns: 2,
    children: [
      FilledButton(
        key: const ValueKey('add-booking'),
        onPressed: _showAddBookingDialog,
        child: const ActionLabel(Icons.add, 'تسجيل حجز جديد'),
      ),
      OutlinedButton(
        onPressed: _showAddRenterDialog,
        child: const ActionLabel(Icons.person_add_outlined, 'مستأجر جديد'),
      ),
    ],
  );

  Widget _buildDirectoryControls() {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final active = _bookings
        .where((b) => BookingStatusService.isActive(b, today))
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdaptiveItems(
          minItemWidth: 200,
          maxColumns: 2,
          children: [
            ChoiceChip(
              label: Text('الحجوزات (${_bookings.length})'),
              selected: !_showRentersTab,
              onSelected: (_) => setState(() => _showRentersTab = false),
            ),
            ChoiceChip(
              label: Text('قائمة المستأجرين (${_renters.length})'),
              selected: _showRentersTab,
              onSelected: (_) => setState(() => _showRentersTab = true),
            ),
          ],
        ),
        if (!_showRentersTab) ...[
          const SizedBox(height: 8),
          AdaptiveItems(
            minItemWidth: 200,
            maxColumns: 2,
            children: [
              ChoiceChip(
                key: const ValueKey('filter-active'),
                label: Text('المؤكدة القادمة ($active)'),
                selected: _bookingFilter == 'active',
                onSelected: (_) => setState(() => _bookingFilter = 'active'),
              ),
              ChoiceChip(
                key: const ValueKey('filter-archived'),
                label: Text('السجل (${_bookings.length - active})'),
                selected: _bookingFilter == 'archived',
                onSelected: (_) => setState(() => _bookingFilter = 'archived'),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('booking-search'),
          controller: _searchController,
          onChanged: (value) => setState(() => _searchQuery = value),
          decoration: InputDecoration(
            labelText: 'بحث',
            helperText: 'الاسم أو رقم الهاتف',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchQuery.isEmpty
                ? null
                : IconButton(
                    tooltip: 'مسح البحث',
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildCalendar() {
    final scale = ContentLayout.textScale(context);
    final first = HijriCalendar.fromDate(
      DateTime(_focusedDay.year, _focusedDay.month),
    );
    final last = HijriCalendar.fromDate(
      DateTime(_focusedDay.year, _focusedDay.month + 1, 0),
    );
    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        key: const PageStorageKey('booking-calendar-expanded'),
        initiallyExpanded: _calendarExpanded,
        onExpansionChanged: (value) =>
            setState(() => _calendarExpanded = value),
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        title: Text('التقويم', style: Theme.of(context).textTheme.titleMedium),
        subtitle: Text(
          'المحدد: \u2066${DateFormat('yyyy-MM-dd').format(_selectedDay ?? _focusedDay)}\u2069',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'الشهر السابق',
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _changeCalendarMonth(-1),
              ),
              Expanded(
                child: Text(
                  DateFormat.yMMMM('ar_SA').format(_focusedDay),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              IconButton(
                tooltip: 'الشهر التالي',
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _changeCalendarMonth(1),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '${getArabicHijriMonthName(first.hMonth)} ${first.hYear} — ${getArabicHijriMonthName(last.hMonth)} ${last.hYear}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 8),
          TableCalendar(
            key: const ValueKey('booking-calendar'),
            firstDay: DateTime.utc(2020),
            lastDay: DateTime.utc(2050, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            eventLoader: _getBookingsForDay,
            onDaySelected: (selectedDay, focusedDay) => setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            }),
            onPageChanged: (focusedDay) =>
                setState(() => _focusedDay = focusedDay),
            calendarFormat: CalendarFormat.month,
            locale: 'ar_SA',
            startingDayOfWeek: StartingDayOfWeek.sunday,
            headerVisible: false,
            rowHeight: 56 * scale + 28,
            daysOfWeekHeight: 24 * scale + 12,
            calendarStyle: const CalendarStyle(cellMargin: EdgeInsets.zero),
            calendarBuilders: CalendarBuilders(
              dowBuilder: (context, day) => LayoutBuilder(
                builder: (context, constraints) {
                  const names = [
                    'الاثنين',
                    'الثلاثاء',
                    'الأربعاء',
                    'الخميس',
                    'الجمعة',
                    'السبت',
                    'الأحد',
                  ];
                  const short = ['ن', 'ث', 'ر', 'خ', 'ج', 'س', 'ح'];
                  final name = names[day.weekday - 1];
                  final style = Theme.of(context).textTheme.labelSmall!;
                  return Tooltip(
                    message: name,
                    child: Center(
                      child: Text(
                        ContentLayout.textWidth(context, name, style) + 4 <=
                                constraints.maxWidth
                            ? name
                            : short[day.weekday - 1],
                        style: style,
                      ),
                    ),
                  );
                },
              ),
              defaultBuilder: (context, day, _) => _buildCalendarDayCell(
                day,
                isSelected: false,
                isToday: false,
                isOutside: false,
              ),
              selectedBuilder: (context, day, _) => _buildCalendarDayCell(
                day,
                isSelected: true,
                isToday: false,
                isOutside: false,
              ),
              todayBuilder: (context, day, _) => _buildCalendarDayCell(
                day,
                isSelected: false,
                isToday: true,
                isOutside: false,
              ),
              outsideBuilder: (context, day, _) => _buildCalendarDayCell(
                day,
                isSelected: false,
                isToday: false,
                isOutside: true,
              ),
              markerBuilder: (context, date, events) => events.isEmpty
                  ? null
                  : const Positioned(
                      bottom: 2,
                      child: Icon(
                        Icons.event_available_outlined,
                        size: 12,
                        color: AppColors.warningText,
                      ),
                    ),
            ),
          ),
          Text(
            'الأعلى: هجري • الأسفل: ميلادي',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  void _changeCalendarMonth(int delta) {
    final day = DateTime(_focusedDay.year, _focusedDay.month + delta);
    if (day.year >= 2020 && day.year <= 2050) {
      setState(() => _focusedDay = day);
    }
  }

  Future<void> _showPaymentActions(Map<String, dynamic> booking) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.receipt_long),
              title: const Text('سجل الدفعات وتصحيحها'),
              onTap: () => Navigator.pop(sheetContext, 'history'),
            ),
            ListTile(
              leading: const Icon(Icons.add_card),
              title: const Text('تسجيل دفعة'),
              onTap: () => Navigator.pop(sheetContext, 'add'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    if (action == 'add') {
      await _showAddPaymentDialog(booking);
    } else if (action == 'history') {
      await showDialog<void>(
        context: context,
        builder: (_) => BookingPaymentsDialog(bookingId: booking['id'] as int),
      );
    }
  }

  Future<void> _showAddPaymentDialog(Map<String, dynamic> booking) async {
    final bookingId = booking['id'] as int;
    final summary = await dbHelper.queryPaymentSummary(bookingId);
    if (!mounted) {
      return;
    }
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    String method = 'cash';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          scrollable: true,
          title: const Text('تسجيل دفعة'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'إجمالي الحجز: ${summary['total']!.toStringAsFixed(2)} ر.س',
                ),
                Text('المسدد: ${summary['paid']!.toStringAsFixed(2)} ر.س'),
                Text(
                  'المتبقي: ${summary['remaining']!.toStringAsFixed(2)} ر.س',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'قيمة الدفعة (ر.س)',
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  isDense: false,
                  itemHeight: null,
                  initialValue: method,
                  decoration: const InputDecoration(labelText: 'طريقة السداد'),
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('نقدي')),
                    DropdownMenuItem(
                      value: 'transfer',
                      child: Text('تحويل بنكي'),
                    ),
                    DropdownMenuItem(value: 'card', child: Text('بطاقة')),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => method = value ?? 'cash'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: noteController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظة (اختياري)',
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
                final amount = double.tryParse(amountController.text.trim());
                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('أدخل قيمة دفعة صحيحة.'),
                      backgroundColor: AppColors.errorText,
                    ),
                  );
                  return;
                }
                try {
                  await dbHelper.insertPayment({
                    'booking_id': bookingId,
                    'amount': amount,
                    'paid_at': DateTime.now()
                        .toIso8601String()
                        .split('T')
                        .first,
                    'method': method,
                    'note': noteController.text.trim(),
                  });
                  if (!dialogContext.mounted) {
                    return;
                  }
                  Navigator.pop(dialogContext);
                  if (!mounted) {
                    return;
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم تسجيل الدفعة بنجاح.')),
                  );
                } on ArgumentError catch (error) {
                  if (!dialogContext.mounted) {
                    return;
                  }
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: Text(
                        error.message?.toString() ?? 'تعذر تسجيل الدفعة.',
                      ),
                      backgroundColor: AppColors.errorText,
                    ),
                  );
                } on StateError catch (error) {
                  if (!dialogContext.mounted) {
                    return;
                  }
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: Text(error.message),
                      backgroundColor: AppColors.errorText,
                    ),
                  );
                }
              },
              child: const Text('حفظ الدفعة'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bookingStatusBadge(String? status) {
    switch (status) {
      case DatabaseHelper.statusConfirmed:
        return const StatusBadge.success(label: 'مؤكد');
      case DatabaseHelper.statusPending:
        return const StatusBadge.warning(label: 'قيد الانتظار');
      case DatabaseHelper.statusCancelled:
        return const StatusBadge.error(label: 'ملغي');
      default:
        return const StatusBadge.neutral(label: 'غير محدد');
    }
  }

  List<Map<String, dynamic>> _matchingBookings() {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final query = _searchQuery.trim().toLowerCase();
    return _bookings.where((booking) {
      final renter = _renterFor(booking);
      final matches =
          query.isEmpty ||
          booking['phone'].toString().contains(query) ||
          renter['full_name'].toString().toLowerCase().contains(query);
      final active = BookingStatusService.isActive(booking, today);
      return matches && (_bookingFilter == 'archived' ? !active : active);
    }).toList()..sort(
      (a, b) =>
          b['start_date'].toString().compareTo(a['start_date'].toString()),
    );
  }

  Map<String, dynamic> _renterFor(Map<String, dynamic> booking) =>
      _renters.firstWhere(
        (r) => r['phone'] == booking['phone'],
        orElse: () => {'full_name': 'مستأجر غير معروف'},
      );

  List<Map<String, dynamic>> _matchingRenters() {
    final query = _searchQuery.trim().toLowerCase();
    return _renters
        .where(
          (r) =>
              query.isEmpty ||
              r['full_name'].toString().toLowerCase().contains(query) ||
              r['phone'].toString().contains(query),
        )
        .toList()
      ..sort(
        (a, b) => ((b['rental_count'] as num?) ?? 0).compareTo(
          (a['rental_count'] as num?) ?? 0,
        ),
      );
  }

  Widget _buildBookingCard(
    Map<String, dynamic> booking, {
    bool details = false,
  }) {
    final id = booking['id'] as int;
    final renter = _renterFor(booking);
    return Card(
      key: ValueKey('${details ? 'day' : 'directory'}-booking-$id'),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              renter['full_name'].toString(),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: _bookingStatusBadge(booking['status']?.toString()),
            ),
            const SizedBox(height: 12),
            _bookingDate(booking['start_date'].toString(), 'من'),
            _bookingDate(booking['end_date'].toString(), 'إلى'),
            if (details) ...[
              const SizedBox(height: 8),
              Text('رقم التواصل', style: Theme.of(context).textTheme.bodySmall),
              Text(
                booking['phone'].toString(),
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.end,
              ),
              if ((renter['notes'] ?? '').toString().trim().isNotEmpty)
                Text('ملاحظات العميل: ${renter['notes']}'),
              LabelledAmount(
                'قيمة التأمين',
                (booking['security_deposit'] as num?) ?? 0,
              ),
            ],
            const Divider(height: 24),
            FutureBuilder<Map<String, double>>(
              future: _paymentSummaries.putIfAbsent(
                id,
                () => dbHelper.queryPaymentSummary(id),
              ),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Text('تعذر تحميل ملخص الدفعات.');
                }
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(8),
                    child: LinearProgressIndicator(),
                  );
                }
                final summary = snapshot.data!;
                return AdaptiveItems(
                  minItemWidth: 180,
                  children: [
                    LabelledAmount('الإجمالي', summary['total']!),
                    LabelledAmount(
                      'المسدد',
                      summary['paid']!,
                      color: AppColors.successText,
                    ),
                    LabelledAmount(
                      'المتبقي',
                      summary['remaining']!,
                      color: AppColors.warningText,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton(
                  onPressed: () => _showPaymentActions(booking),
                  child: const ActionLabel(Icons.payments_outlined, 'الدفعات'),
                ),
                TextButton(
                  onPressed: () => _showEditBookingDialog(booking),
                  child: const ActionLabel(Icons.edit_outlined, 'تعديل'),
                ),
                TextButton(
                  onPressed: () => _confirmDeleteBooking(id),
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
  }

  Widget _bookingDate(String date, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '$label: ${_formatHijriDateOnlyArabic(date)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Text(date, textDirection: TextDirection.ltr, textAlign: TextAlign.end),
      ],
    ),
  );

  Widget _buildRenterCard(Map<String, dynamic> renter) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            renter['full_name'].toString(),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            renter['phone'].toString(),
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.end,
          ),
          Text('مرات التأجير: ${renter['rental_count'] ?? 0}'),
          if ((renter['notes'] ?? '').toString().trim().isNotEmpty)
            Text(
              'ملاحظات: ${renter['notes']}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (((renter['rating'] as num?) ?? 0) >= 4 ||
              ((renter['rental_count'] as num?) ?? 0) >= 3)
            const StatusBadge.success(label: 'عميل مميز وموثوق'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton(
                onPressed: () => _showEditRenterDialog(renter),
                child: const ActionLabel(Icons.edit_outlined, 'تعديل'),
              ),
              TextButton(
                onPressed: () => _confirmDeleteRenter(renter['phone']),
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

  Widget _buildDayBookingsListAdaptive() {
    final selected = _selectedDay;
    if (selected == null) {
      return const Text('يرجى تحديد يوم من التقويم');
    }
    final bookings = _getBookingsForDay(selected)
      ..sort(
        (a, b) =>
            b['start_date'].toString().compareTo(a['start_date'].toString()),
      );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'حجوزات اليوم المحدد',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (bookings.isEmpty) const Text('لا توجد حجوزات في هذا اليوم'),
        for (final booking in bookings)
          _buildBookingCard(booking, details: true),
      ],
    );
  }
}

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
          Expanded(
            child: Text(
              '${getArabicHijriMonthName(_selectedMonth)} ${toArabicDigits(_selectedYear)}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16.sp(context),
                color: AppColors.primary,
              ),
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
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                mainAxisExtent: 48 * ContentLayout.textScale(context),
                crossAxisCount: 7,
                mainAxisSpacing: 4,
                crossAxisSpacing: 2,
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
