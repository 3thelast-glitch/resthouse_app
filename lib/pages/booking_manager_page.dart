import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
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

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _loadData();
  }

  Future<void> _loadData() async {
    final bookings = await dbHelper.queryAllBookings();
    final renters = await dbHelper.queryAllRenters();
    if (!mounted) return;
    setState(() {
      _bookings = bookings;
      _renters = renters;
    });
    // Feature 3: Check for ended bookings with pending deposits
    _checkPendingDeposits();
  }

  /// Formats a date showing both Gregorian and Hijri side-by-side
  /// Example: "البداية: 2026-06-13 | ١٩ ذو الحجة ١٤٤٧"
  String _formatDualDate(DateTime? date, String label) {
    if (date == null) return label;
    final gregorian = date.toString().split(' ')[0];
    final hijri = HijriCalendar.fromDate(date);
    final hijriStr =
        '${toArabicDigits(hijri.hDay)} ${getArabicHijriMonthName(hijri.hMonth)} ${toArabicDigits(hijri.hYear)}';
    return '$label: $gregorian\n$hijriStr';
  }

  String _formatDateString(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    final parsed = DateTime.tryParse(dateStr);
    if (parsed == null) return dateStr;

    const gMonths = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    const hMonths = [
      'Muharram',
      'Safar',
      'Rabi\' al-Awwal',
      'Rabi\' al-Thani',
      'Jumada al-Awwal',
      'Jumada al-Thani',
      'Rajab',
      'Sha\'ban',
      'Ramadan',
      'Shawwal',
      'Dhu al-Qi\'dah',
      'Dhu al-Hijjah',
    ];

    final gDay = parsed.day;
    final gMonth = gMonths[parsed.month - 1];
    final gYear = parsed.year;

    final hijri = HijriCalendar.fromDate(parsed);
    final hDay = hijri.hDay;
    final hMonthName = hMonths[hijri.hMonth - 1];
    final hYear = hijri.hYear;

    return '$gDay $gMonth $gYear | $hDay $hMonthName $hYear';
  }

  String _formatHijriDateOnlyArabic(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    final parsed = DateTime.tryParse(dateStr);
    if (parsed == null) return dateStr;

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
      if (!context.mounted) return null;
      return await showDatePicker(
        context: context,
        initialDate: initialDate,
        firstDate: DateTime(2020),
        lastDate: DateTime(2050),
      );
    } else if (choice == 'hijri') {
      if (!context.mounted) return null;
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
    if (pendingBookings.isEmpty || !mounted) return;

    for (final booking in pendingBookings) {
      if (!mounted) return;
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
                    if (!dialogContext.mounted) return;
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
                    if (!dialogContext.mounted) return;
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
      if (!mounted) return;
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
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text('تم تحديث بيانات المستأجر بنجاح'),
                  ),
                );
              } catch (e) {
                if (!dialogContext.mounted) return;
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
                          if (!dialogContext.mounted) return;
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
                          if (!dialogContext.mounted) return;
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

                  await _loadData();
                  if (!dialogContext.mounted) return;
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('تم تسجيل الحجز بنجاح')),
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
                          if (!dialogContext.mounted) return;
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
                          if (!dialogContext.mounted) return;
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
                  if (!dialogContext.mounted) return;
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('تم تعديل بيانات الحجز بنجاح'),
                    ),
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
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                await _loadData();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم حذف الحجز بنجاح')),
                );
              } on StateError catch (error) {
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                if (!mounted) return;
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
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('تم حذف المستأجر بنجاح')),
                );
              } catch (e) {
                if (!dialogContext.mounted) return;
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
    final hijriDayStr = toArabicDigits(hijri.hDay);
    final gregorianDayStr = day.day.toString();

    final hasBooking = _getBookingsForDay(day).isNotEmpty;
    final hijriColor = isSelected ? Colors.white : AppColors.heading;
    final gregorianColor = isSelected ? Colors.white : AppColors.secondaryText;

    BoxDecoration? decoration;
    if (isSelected) {
      decoration = const BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
      );
    } else if (isToday) {
      decoration = BoxDecoration(
        color: AppColors.selectedSurface,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primary, width: 2),
      );
    } else if (hasBooking) {
      decoration = BoxDecoration(
        color: AppColors.warningSurface,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.warningText, width: 1.5),
      );
    }

    final opacity = isOutside ? 0.55 : 1.0;

    return Opacity(
      opacity: opacity,
      child: Container(
        margin: const EdgeInsets.all(3.0),
        alignment: Alignment.center,
        decoration: decoration,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              hijriDayStr,
              style: TextStyle(
                fontSize: 16.sp(context),
                fontWeight: FontWeight.bold,
                color: hijriColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              gregorianDayStr,
              style: TextStyle(fontSize: 10.sp(context), color: gregorianColor),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final todayStr = DateTime.now().toString().split(' ')[0];
    final activeBookingsCount = _bookings
        .where((b) => BookingStatusService.isActive(b, todayStr))
        .length;
    final archivedBookingsCount = _bookings
        .where((b) => !BookingStatusService.isActive(b, todayStr))
        .length;
    final hasDirectoryData = _bookings.isNotEmpty || _renters.isNotEmpty;
    final textScale = Responsive.textScale(context);
    final calendarRowHeight = (64.0 * textScale).clamp(52.0, 150.0).toDouble();
    final calendarDowHeight = (32.0 * textScale).clamp(28.0, 72.0).toDouble();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final canUseTwoPanes =
                constraints.maxWidth >= Responsive.wide &&
                !Responsive.hasLargeText(context, threshold: 1.5);

            if (canUseTwoPanes) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildDirectoryPanel(
                      activeBookingsCount: activeBookingsCount,
                      archivedBookingsCount: archivedBookingsCount,
                      hasDirectoryData: hasDirectoryData,
                      embedded: false,
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    flex: 3,
                    child: SingleChildScrollView(
                      key: const ValueKey('bookingCalendarScrollWide'),
                      padding: const EdgeInsets.all(Responsive.pagePadding),
                      child: _buildCalendarSection(
                        calendarRowHeight: calendarRowHeight,
                        calendarDowHeight: calendarDowHeight,
                        includeActions: true,
                      ),
                    ),
                  ),
                ],
              );
            }

            return SingleChildScrollView(
              key: const ValueKey('bookingPageScroll'),
              padding: const EdgeInsets.all(Responsive.pagePadding),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: Responsive.maxContentWidth,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildBookingActions(),
                      const SizedBox(height: AppSpacing.sm),
                      _buildDirectoryControls(
                        activeBookingsCount: activeBookingsCount,
                        archivedBookingsCount: archivedBookingsCount,
                        hasDirectoryData: hasDirectoryData,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _buildCalendarSection(
                        calendarRowHeight: calendarRowHeight,
                        calendarDowHeight: calendarDowHeight,
                        includeActions: false,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        _showRentersTab ? 'قائمة المستأجرين' : 'قائمة الحجوزات',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      if (hasDirectoryData)
                        _showRentersTab
                            ? _buildRentersList(embedded: true)
                            : _buildBookingsList(embedded: true)
                      else
                        _buildDirectoryEmptyState(),
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

  Widget _buildDirectoryPanel({
    required int activeBookingsCount,
    required int archivedBookingsCount,
    required bool hasDirectoryData,
    required bool embedded,
  }) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildDirectoryControls(
            activeBookingsCount: activeBookingsCount,
            archivedBookingsCount: archivedBookingsCount,
            hasDirectoryData: hasDirectoryData,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (hasDirectoryData)
            Expanded(
              child: _showRentersTab
                  ? _buildRentersList(embedded: embedded)
                  : _buildBookingsList(embedded: embedded),
            )
          else
            Expanded(child: _buildDirectoryEmptyState()),
        ],
      ),
    );
  }

  Widget _buildDirectoryControls({
    required int activeBookingsCount,
    required int archivedBookingsCount,
    required bool hasDirectoryData,
  }) {
    Widget selector({
      required String label,
      required bool selected,
      required VoidCallback onTap,
    }) {
      return Material(
        color: selected ? AppColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            alignment: Alignment.center,
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              softWrap: true,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: selected ? Colors.white : AppColors.secondaryText,
              ),
            ),
          ),
        ),
      );
    }

    Widget adaptivePair(List<Widget> children) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final stacked =
              constraints.maxWidth < 350 || Responsive.hasLargeText(context);
          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: double.infinity, child: children[0]),
                const SizedBox(height: AppSpacing.xs),
                SizedBox(width: double.infinity, child: children[1]),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: children[0]),
              const SizedBox(width: AppSpacing.xs),
              Expanded(child: children[1]),
            ],
          );
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(10),
          ),
          child: adaptivePair([
            selector(
              label: 'الحجوزات (${_bookings.length})',
              selected: !_showRentersTab,
              onTap: () => setState(() => _showRentersTab = false),
            ),
            selector(
              label: 'قائمة المستأجرين (${_renters.length})',
              selected: _showRentersTab,
              onTap: () => setState(() => _showRentersTab = true),
            ),
          ]),
        ),
        if (!_showRentersTab && _bookings.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.divider),
            ),
            child: adaptivePair([
              selector(
                label: 'المؤكدة القادمة ($activeBookingsCount)',
                selected: _bookingFilter == 'active',
                onTap: () => setState(() => _bookingFilter = 'active'),
              ),
              selector(
                label: 'السجل ($archivedBookingsCount)',
                selected: _bookingFilter == 'archived',
                onTap: () => setState(() => _bookingFilter = 'archived'),
              ),
            ]),
          ),
        ],
        if (hasDirectoryData) ...[
          const SizedBox(height: AppSpacing.sm),
          TextField(
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              labelText: 'بحث',
              hintText: _showRentersTab
                  ? 'بالاسم أو رقم الهاتف'
                  : 'عن حجز بالاسم أو رقم الهاتف',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'مسح البحث',
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _searchQuery = ''),
                    ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBookingActions() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked =
            constraints.maxWidth < 480 || Responsive.hasLargeText(context);
        final addBooking = ElevatedButton.icon(
          onPressed: _showAddBookingDialog,
          icon: const Icon(Icons.add, size: 20),
          label: const Text('تسجيل حجز جديد'),
        );
        final addRenter = OutlinedButton.icon(
          onPressed: _showAddRenterDialog,
          icon: const Icon(Icons.person_add_outlined, size: 20),
          label: const Text('مستأجر جديد'),
        );

        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: double.infinity, child: addBooking),
              const SizedBox(height: AppSpacing.xs),
              SizedBox(width: double.infinity, child: addRenter),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: addBooking),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: addRenter),
          ],
        );
      },
    );
  }

  Widget _buildCalendarSection({
    required double calendarRowHeight,
    required double calendarDowHeight,
    required bool includeActions,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (includeActions) ...[
          _buildBookingActions(),
          const SizedBox(height: AppSpacing.md),
        ],
        _buildCalendarCard(
          calendarRowHeight: calendarRowHeight,
          calendarDowHeight: calendarDowHeight,
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.bookmark_added_outlined, color: AppColors.primary),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                _selectedDay == null
                    ? 'الحجوزات اليومية'
                    : 'الحجوزات في تاريخ ${_selectedDay.toString().split(' ')[0]}',
                softWrap: true,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        _buildDayBookingsListAdaptive(),
      ],
    );
  }

  Widget _buildCalendarCard({
    required double calendarRowHeight,
    required double calendarDowHeight,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          children: [
            Builder(
              builder: (context) {
                final focusedHijri = HijriCalendar.fromDate(_focusedDay);
                final lastDayNum = HijriCalendar().getDaysInMonth(
                  focusedHijri.hYear,
                  focusedHijri.hMonth,
                );
                final firstDayGregorian = HijriCalendar().hijriToGregorian(
                  focusedHijri.hYear,
                  focusedHijri.hMonth,
                  1,
                );
                final lastDayGregorian = HijriCalendar().hijriToGregorian(
                  focusedHijri.hYear,
                  focusedHijri.hMonth,
                  lastDayNum,
                );
                final gregorianRange =
                    '${firstDayGregorian.day}-${firstDayGregorian.month}-${firstDayGregorian.year} '
                    '➔ ${lastDayGregorian.day}-${lastDayGregorian.month}-${lastDayGregorian.year}';
                final hijriTitle =
                    '${getArabicHijriMonthName(focusedHijri.hMonth)} '
                    '${toArabicDigits(focusedHijri.hYear)}';

                void previousMonth() {
                  setState(() {
                    _focusedDay = DateTime(
                      _focusedDay.year,
                      _focusedDay.month - 1,
                    );
                  });
                }

                void nextMonth() {
                  setState(() {
                    _focusedDay = DateTime(
                      _focusedDay.year,
                      _focusedDay.month + 1,
                    );
                  });
                }

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final stacked =
                        constraints.maxWidth < 520 ||
                        Responsive.hasLargeText(context);
                    final navigation = Row(
                      children: [
                        IconButton(
                          tooltip: 'الشهر السابق',
                          icon: const Icon(
                            Icons.chevron_left,
                            color: AppColors.primary,
                          ),
                          onPressed: previousMonth,
                        ),
                        Expanded(
                          child: Text(
                            hijriTitle,
                            textAlign: TextAlign.center,
                            softWrap: true,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(color: AppColors.primaryPressed),
                          ),
                        ),
                        IconButton(
                          tooltip: 'الشهر التالي',
                          icon: const Icon(
                            Icons.chevron_right,
                            color: AppColors.primary,
                          ),
                          onPressed: nextMonth,
                        ),
                      ],
                    );
                    final range = Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        gregorianRange,
                        textAlign: TextAlign.center,
                        softWrap: true,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    );

                    if (stacked) {
                      return Column(
                        children: [
                          navigation,
                          const SizedBox(height: 4),
                          range,
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(flex: 2, child: navigation),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(flex: 3, child: range),
                      ],
                    );
                  },
                );
              },
            ),
            const Divider(height: AppSpacing.md),
            TableCalendar(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2050, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              eventLoader: _getBookingsForDay,
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              onPageChanged: (focusedDay) {
                setState(() => _focusedDay = focusedDay);
              },
              calendarFormat: CalendarFormat.month,
              locale: 'ar_AE',
              startingDayOfWeek: StartingDayOfWeek.sunday,
              headerVisible: false,
              rowHeight: calendarRowHeight,
              daysOfWeekHeight: calendarDowHeight,
              calendarBuilders: CalendarBuilders(
                defaultBuilder: (context, day, focusedDay) =>
                    _buildCalendarDayCell(
                      day,
                      isSelected: false,
                      isToday: false,
                      isOutside: false,
                    ),
                selectedBuilder: (context, day, focusedDay) =>
                    _buildCalendarDayCell(
                      day,
                      isSelected: true,
                      isToday: false,
                      isOutside: false,
                    ),
                todayBuilder: (context, day, focusedDay) =>
                    _buildCalendarDayCell(
                      day,
                      isSelected: false,
                      isToday: true,
                      isOutside: false,
                    ),
                outsideBuilder: (context, day, focusedDay) =>
                    _buildCalendarDayCell(
                      day,
                      isSelected: false,
                      isToday: false,
                      isOutside: true,
                    ),
                markerBuilder: (context, date, events) {
                  if (events.isNotEmpty) {
                    return const Positioned(
                      bottom: 1,
                      child: Icon(
                        Icons.event_available_outlined,
                        size: 12,
                        color: AppColors.warningText,
                      ),
                    );
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDirectoryEmptyState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.people_outline,
              size: 44,
              color: AppColors.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'لا توجد حجوزات أو مستأجرون بعد',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15.sp(context),
                color: AppColors.heading,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'استخدم أزرار الإضافة لإدخال بياناتك. ستظهر القوائم هنا بعد حفظ أول مستأجر أو حجز.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.secondaryText,
                height: 1.45,
                fontSize: 12.sp(context),
              ),
            ),
          ],
        ),
      ),
    );
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
    if (!mounted) return;
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
    if (!mounted) return;
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
                  if (!dialogContext.mounted) return;
                  Navigator.pop(dialogContext);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم تسجيل الدفعة بنجاح.')),
                  );
                } on ArgumentError catch (error) {
                  if (!dialogContext.mounted) return;
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: Text(
                        error.message?.toString() ?? 'تعذر تسجيل الدفعة.',
                      ),
                      backgroundColor: AppColors.errorText,
                    ),
                  );
                } on StateError catch (error) {
                  if (!dialogContext.mounted) return;
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

  // بناء قائمة الحجوزات العامة (مرتبة من الأحدث إلى الأقدم)
  Widget _buildBookingsList({bool embedded = false}) {
    final todayStr = DateTime.now().toString().split(' ')[0];
    final normalizedQuery = _searchQuery.trim().toLowerCase();
    final filtered = _bookings.where((b) {
      final renter = _renters.firstWhere(
        (r) => r['phone'] == b['phone'],
        orElse: () => const <String, dynamic>{},
      );
      final matchesSearch =
          normalizedQuery.isEmpty ||
          b['phone'].toString().contains(normalizedQuery) ||
          renter['full_name'].toString().toLowerCase().contains(
            normalizedQuery,
          );
      final isActive = BookingStatusService.isActive(b, todayStr);
      return (_bookingFilter == 'archived' ? !isActive : isActive) &&
          matchesSearch;
    }).toList();

    if (filtered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Center(
          child: Text(
            _bookingFilter == 'archived'
                ? 'لا توجد حجوزات مؤرشفة'
                : 'لا توجد حجوزات نشطة حالياً',
            style: const TextStyle(color: AppColors.secondaryText),
          ),
        ),
      );
    }

    final sorted = List<Map<String, dynamic>>.from(filtered)
      ..sort(
        (a, b) =>
            b['start_date'].toString().compareTo(a['start_date'].toString()),
      );

    return ListView.builder(
      shrinkWrap: embedded,
      physics: embedded
          ? const NeverScrollableScrollPhysics()
          : const ClampingScrollPhysics(),
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final booking = sorted[index];
        final renter = _renters.firstWhere(
          (r) => r['phone'] == booking['phone'],
          orElse: () => {'full_name': 'مستأجر غير معروف'},
        );

        final cardContent = Card(
          elevation: 0,
          color: AppColors.background,
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      renter['full_name'].toString(),
                      softWrap: true,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.heading,
                      ),
                    ),
                    _bookingStatusBadge(booking['status']?.toString()),
                    if (_bookingFilter == 'archived')
                      const StatusBadge.neutral(label: 'مكتمل'),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'من: ${_formatHijriDateOnlyArabic(booking['start_date'])}',
                  softWrap: true,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  'إلى: ${_formatHijriDateOnlyArabic(booking['end_date'])}',
                  softWrap: true,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const Divider(height: AppSpacing.md),
                FutureBuilder<Map<String, double>>(
                  future: dbHelper.queryPaymentSummary(booking['id'] as int),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    }
                    final summary = snapshot.data!;
                    final remaining = summary['remaining']!;
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final minWidth = Responsive.hasLargeText(context)
                            ? 200.0
                            : 150.0;
                        final columns = Responsive.columnCountForWidth(
                          constraints.maxWidth,
                          minItemWidth: minWidth,
                          maxColumns: 3,
                          spacing: AppSpacing.xs,
                        );
                        final width = Responsive.itemWidthForColumns(
                          constraints.maxWidth,
                          columns: columns,
                          spacing: AppSpacing.xs,
                        );
                        return Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: AppSpacing.xs,
                          children: [
                            SizedBox(
                              width: width,
                              child: _buildFinancialValue(
                                'الإجمالي',
                                summary['total']!,
                                AppColors.text,
                              ),
                            ),
                            SizedBox(
                              width: width,
                              child: _buildFinancialValue(
                                'المسدد',
                                summary['paid']!,
                                AppColors.successText,
                              ),
                            ),
                            SizedBox(
                              width: width,
                              child: _buildFinancialValue(
                                'المتبقي',
                                remaining,
                                remaining > 0
                                    ? AppColors.warningText
                                    : AppColors.successText,
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  alignment: WrapAlignment.end,
                  children: [
                    IconButton(
                      tooltip: 'الدفعات',
                      icon: const Icon(
                        Icons.payments_outlined,
                        color: AppColors.primary,
                      ),
                      onPressed: () => _showPaymentActions(booking),
                    ),
                    IconButton(
                      tooltip: 'تعديل الحجز',
                      icon: const Icon(
                        Icons.edit_outlined,
                        color: AppColors.primaryPressed,
                      ),
                      onPressed: () => _showEditBookingDialog(booking),
                    ),
                    IconButton(
                      tooltip: 'حذف الحجز',
                      icon: const Icon(
                        Icons.delete_outline,
                        color: AppColors.errorText,
                      ),
                      onPressed: () => _confirmDeleteBooking(booking['id']),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );

        if (_bookingFilter == 'archived') {
          return Opacity(opacity: 0.75, child: cardContent);
        }
        return cardContent;
      },
    );
  }

  Widget _buildFinancialValue(String label, double value, Color color) {
    final display = '${value.toStringAsFixed(2)} ر.س'.replaceAll(
      ' ر.س',
      '\u00A0ر.س',
    );
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 2),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              display,
              softWrap: true,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }

  // بناء قائمة المستأجرين العامة (مرتبة حسب الأكثر نشاطاً)
  Widget _buildRentersList({bool embedded = false}) {
    if (_renters.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Center(child: Text('لا توجد مستأجرين مسجلين بعد')),
      );
    }
    final normalizedQuery = _searchQuery.trim().toLowerCase();
    final matchingRenters = _renters.where((renter) {
      return normalizedQuery.isEmpty ||
          renter['full_name'].toString().toLowerCase().contains(
            normalizedQuery,
          ) ||
          renter['phone'].toString().contains(normalizedQuery);
    }).toList();
    final sorted = List<Map<String, dynamic>>.from(matchingRenters)
      ..sort((a, b) {
        final countA = (a['rental_count'] as num?)?.toInt() ?? 0;
        final countB = (b['rental_count'] as num?)?.toInt() ?? 0;
        return countB.compareTo(countA);
      });

    return ListView.builder(
      shrinkWrap: embedded,
      physics: embedded
          ? const NeverScrollableScrollPhysics()
          : const ClampingScrollPhysics(),
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final renter = sorted[index];
        final hasNotes =
            renter['notes'] != null &&
            renter['notes'].toString().trim().isNotEmpty;
        final isTrusted =
            (renter['rating'] != null && (renter['rating'] as num) >= 4) ||
            (renter['rental_count'] != null &&
                (renter['rental_count'] as num) >= 3);

        return Card(
          elevation: 0,
          color: AppColors.background,
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CircleAvatar(
                      backgroundColor: Color(0xFFE0F2FE),
                      foregroundColor: Color(0xFF0284C7),
                      child: Icon(Icons.person, size: 18),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        renter['full_name'].toString(),
                        softWrap: true,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                    if (hasNotes)
                      const Tooltip(
                        message: 'توجد ملاحظات على العميل',
                        child: Icon(
                          Icons.warning_amber_rounded,
                          color: AppColors.errorText,
                          size: 20,
                        ),
                      ),
                    if (hasNotes && isTrusted) const SizedBox(width: 4),
                    if (isTrusted)
                      const Tooltip(
                        message: 'عميل مميز وموثوق',
                        child: Icon(
                          Icons.verified,
                          color: AppColors.successText,
                          size: 20,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    renter['phone'].toString(),
                    textAlign: TextAlign.end,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                Text(
                  'مرات التأجير: ${renter['rental_count'] ?? 0}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  alignment: WrapAlignment.end,
                  children: [
                    IconButton(
                      tooltip: 'تعديل المستأجر',
                      icon: const Icon(
                        Icons.edit_outlined,
                        color: AppColors.primaryPressed,
                      ),
                      onPressed: () => _showEditRenterDialog(renter),
                    ),
                    IconButton(
                      tooltip: 'حذف المستأجر',
                      icon: const Icon(
                        Icons.delete_outline,
                        color: AppColors.errorText,
                      ),
                      onPressed: () => _confirmDeleteRenter(renter['phone']),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDayBookingsListAdaptive() {
    if (_selectedDay == null) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.medium),
          border: Border.all(color: AppColors.divider),
        ),
        child: const Center(
          child: Text(
            'يرجى تحديد يوم من التقويم',
            style: TextStyle(color: AppColors.secondaryText),
          ),
        ),
      );
    }

    final bookingsOnDay = _getBookingsForDay(_selectedDay!)
      ..sort(
        (a, b) =>
            b['start_date'].toString().compareTo(a['start_date'].toString()),
      );

    if (bookingsOnDay.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.medium),
          border: Border.all(color: AppColors.divider),
        ),
        child: const Center(
          child: Text(
            'لا توجد حجوزات في هذا اليوم',
            style: TextStyle(color: AppColors.secondaryText),
          ),
        ),
      );
    }

    return Column(
      children: bookingsOnDay.map((booking) {
        final renter = _renters.firstWhere(
          (r) => r['phone'] == booking['phone'],
          orElse: () => {'full_name': 'مستأجر غير معروف'},
        );

        Widget detail(String label, String value, {bool ltr = false}) {
          final valueWidget = Text(
            value,
            softWrap: true,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.heading,
            ),
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 2),
              if (ltr)
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: valueWidget,
                )
              else
                valueWidget,
            ],
          );
        }

        return Card(
          margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const CircleAvatar(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      radius: 18,
                      child: Icon(Icons.vpn_key_outlined, size: 18),
                    ),
                    _bookingStatusBadge(booking['status']?.toString()),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  renter['full_name'].toString(),
                  softWrap: true,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final minFieldWidth = Responsive.hasLargeText(context)
                        ? 260.0
                        : 220.0;
                    final columns = Responsive.columnCountForWidth(
                      constraints.maxWidth,
                      minItemWidth: minFieldWidth,
                      maxColumns: 2,
                      spacing: AppSpacing.sm,
                    );
                    final width = Responsive.itemWidthForColumns(
                      constraints.maxWidth,
                      columns: columns,
                      spacing: AppSpacing.sm,
                    );
                    final fields = <Widget>[
                      detail(
                        'رقم التواصل',
                        booking['phone'].toString(),
                        ltr: true,
                      ),
                      detail(
                        'فترة الحجز',
                        'من: ${_formatDateString(booking['start_date'])}\n'
                            'إلى: ${_formatDateString(booking['end_date'])}',
                      ),
                      detail(
                        'قيمة الحجز',
                        '${booking['total_price']} ر.س'.replaceAll(
                          ' ر.س',
                          '\u00A0ر.س',
                        ),
                        ltr: true,
                      ),
                      detail(
                        'قيمة التأمين',
                        '${booking['security_deposit'] ?? 0.0} ر.س'.replaceAll(
                          ' ر.س',
                          '\u00A0ر.س',
                        ),
                        ltr: true,
                      ),
                    ];
                    return Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        for (final field in fields)
                          SizedBox(width: width, child: field),
                      ],
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  alignment: WrapAlignment.end,
                  children: [
                    IconButton(
                      tooltip: 'الدفعات',
                      icon: const Icon(
                        Icons.payments_outlined,
                        color: AppColors.primary,
                      ),
                      onPressed: () => _showPaymentActions(booking),
                    ),
                    IconButton(
                      tooltip: 'تعديل الحجز',
                      icon: const Icon(
                        Icons.edit_outlined,
                        color: AppColors.primaryPressed,
                      ),
                      onPressed: () => _showEditBookingDialog(booking),
                    ),
                    IconButton(
                      tooltip: 'حذف الحجز',
                      icon: const Icon(
                        Icons.delete_outline,
                        color: AppColors.errorText,
                      ),
                      onPressed: () => _confirmDeleteBooking(booking['id']),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
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
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
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
