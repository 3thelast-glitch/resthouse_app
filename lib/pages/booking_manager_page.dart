import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/responsive.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:hijri/hijri_calendar.dart';
import '../database_helper.dart';

String toArabicDigits(int number) {
  const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  return number.toString().split('').map((char) {
    int? val = int.tryParse(char);
    return val != null ? arabicDigits[val] : char;
  }).join('');
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
    'ذو الحجة'
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
    final hijriStr = '${toArabicDigits(hijri.hDay)} ${getArabicHijriMonthName(hijri.hMonth)} ${toArabicDigits(hijri.hYear)}';
    return '$label: $gregorian\n$hijriStr';
  }

  String _formatDateString(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    final parsed = DateTime.tryParse(dateStr);
    if (parsed == null) return dateStr;

    const gMonths = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    const hMonths = [
      'Muharram', 'Safar', 'Rabi\' al-Awwal', 'Rabi\' al-Thani',
      'Jumada al-Awwal', 'Jumada al-Thani', 'Rajab', 'Sha\'ban',
      'Ramadan', 'Shawwal', 'Dhu al-Qi\'dah', 'Dhu al-Hijjah'
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

  Future<DateTime?> _selectDateDual(BuildContext context, DateTime initialDate) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'اختر نوع التقويم',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp(context)),
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
                    backgroundColor: const Color(0xFF0F766E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                    backgroundColor: const Color(0xFF991B1B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
    final pendingBookings = await dbHelper.queryEndedBookingsWithPendingDeposit();
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white,
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          title: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFFBBF24), width: 2),
                ),
                child: const Icon(Icons.account_balance_wallet, color: Color(0xFFD97706), size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                'انتهت فترة حجز $renterName',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17.sp(context)),
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
                  color: const Color(0xFFF0FDFA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF0D9488).withAlpha(51)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.security, color: Color(0xFF0F766E), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'قيمة التأمين: $depositAmount ر.س',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.sp(context), color: const Color(0xFF0F766E)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'من ${booking['start_date']} إلى ${booking['end_date']}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13.sp(context)),
              ),
              const SizedBox(height: 16),
              Text(
                'هل تم إعادة مبلغ التأمين للعميل، أم تم خصمه؟',
                style: TextStyle(fontSize: 14.sp(context), fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    await dbHelper.updateDepositStatus(booking['id'], 'returned');
                    if (!dialogContext.mounted) return;
                    Navigator.pop(dialogContext);
                  },
                  icon: const Icon(Icons.check_circle_outline, size: 20),
                  label: const Text('تم إرجاع التأمين'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () async {
                    await dbHelper.updateDepositStatus(booking['id'], 'deducted');
                    if (!dialogContext.mounted) return;
                    Navigator.pop(dialogContext);
                  },
                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                  label: const Text('تم خصم التأمين'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(dialogContext),
                  icon: const Icon(Icons.schedule, size: 20),
                  label: const Text('تذكيرني لاحقاً'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey.shade700,
                    side: BorderSide(color: Colors.grey.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
    final dateStr = "${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}";
    return _bookings.where((b) {
      final start = b['start_date'].toString();
      final end = b['end_date'].toString();
      return dateStr.compareTo(start) >= 0 && dateStr.compareTo(end) <= 0;
    }).toList();
  }

  void _showAddRenterDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إضافة مستأجر جديد', style: TextStyle(fontWeight: FontWeight.bold)),
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
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
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
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F766E), foregroundColor: Colors.white),
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
        title: const Text('تعديل بيانات المستأجر', style: TextStyle(fontWeight: FontWeight.bold)),
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
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
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
                  const SnackBar(content: Text('تم تحديث بيانات المستأجر بنجاح')),
                );
              } catch (e) {
                if (!dialogContext.mounted) return;
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text('خطأ: قد يكون الهاتف الجديد مستخدماً من عميل آخر'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F766E), foregroundColor: Colors.white),
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
        backgroundColor: Colors.red.shade50,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 28),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
          title: const Text('إضافة حجز جديد', style: TextStyle(fontWeight: FontWeight.bold)),
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
                      child: Text('${renter['full_name']} (${renter['phone']})'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    String? notes;
                    if (value != null) {
                      final renter = _renters.firstWhere((r) => r['phone'].toString() == value);
                      notes = renter['notes'] as String?;
                    }
                    setDialogState(() {
                      selectedPhone = value;
                      selectedRenterNotes = (notes != null && notes.trim().isNotEmpty) ? notes : null;
                    });
                    if (selectedRenterNotes != null) {
                      _showRenterWarningDialog(dialogContext, selectedRenterNotes!);
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
                            style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.bold, fontSize: 12.sp(context)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 20, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final date = await _selectDateDual(dialogContext, startDate ?? DateTime.now());
                          if (!dialogContext.mounted) return;
                          if (date != null) {
                            setDialogState(() {
                              startDate = date;
                              // إصلاح الخلل: تحديث تاريخ النهاية تلقائياً إذا كان يسبق البداية
                              if (endDate == null || endDate!.isBefore(startDate!)) {
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
                    const Icon(Icons.calendar_today, size: 20, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          // تحديد تاريخ البداية الحالي ليكون الحد الأدنى الآمن
                          final initialDate = (endDate != null && startDate != null && !endDate!.isBefore(startDate!))
                              ? endDate!
                              : (startDate ?? DateTime.now());

                          final date = await _selectDateDual(dialogContext, initialDate);
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
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                final price = double.tryParse(priceController.text) ?? 0.0;
                final securityDeposit = double.tryParse(securityDepositController.text) ?? 0.0;

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
                    const SnackBar(content: Text('تاريخ النهاية يجب أن يكون مساوياً أو بعد تاريخ البداية')),
                  );
                  return;
                }
                if (price <= 0) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('الرجاء إدخال سعر صحيح أكبر من الصفر')),
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
                      content: Text('عذراً، الاستراحة محجوزة بالفعل في هذه الفترة!'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                await dbHelper.insertBooking({
                  'phone': selectedPhone,
                  'start_date': startDate!.toString().split(' ')[0],
                  'end_date': endDate!.toString().split(' ')[0],
                  'total_price': price,
                  'security_deposit': securityDeposit,
                  'status': 'confirmed',
                });

                await _loadData();
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('تم تسجيل الحجز بنجاح')),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F766E), foregroundColor: Colors.white),
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
    final priceController = TextEditingController(text: booking['total_price'].toString());
    final securityDepositController = TextEditingController(text: (booking['security_deposit'] ?? 0.0).toString());
    String selectedStatus = booking['status'] ?? 'confirmed';

    final renter = _renters.firstWhere(
      (r) => r['phone'] == booking['phone'],
      orElse: () => {'full_name': 'مستأجر غير معروف'},
    );

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('تعديل الحجز الحالي', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person_outline, color: Color(0xFF0F766E)),
                  title: Text('المستأجر', style: TextStyle(fontSize: 12.sp(context), color: Colors.grey)),
                  subtitle: Text('${renter['full_name']} (${booking['phone']})', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 20, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final date = await _selectDateDual(dialogContext, startDate ?? DateTime.now());
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
                    const Icon(Icons.calendar_today, size: 20, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final initialDate = (endDate != null && startDate != null && !endDate!.isBefore(startDate!))
                              ? endDate!
                              : (startDate ?? DateTime.now());

                          final date = await _selectDateDual(dialogContext, initialDate);
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
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'سعر الحجز الإجمالي (ر.س)',
                    icon: Icon(Icons.attach_money),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: securityDepositController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                    DropdownMenuItem(value: 'pending', child: Text('قيد الانتظار')),
                    DropdownMenuItem(value: 'cancelled', child: Text('ملغي')),
                  ],
                  onChanged: (value) => setDialogState(() => selectedStatus = value ?? 'confirmed'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                final price = double.tryParse(priceController.text) ?? 0.0;
                final securityDeposit = double.tryParse(securityDepositController.text) ?? 0.0;

                if (startDate == null || endDate == null) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('الرجاء تحديد فترات الحجز')),
                  );
                  return;
                }
                if (endDate!.isBefore(startDate!)) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('تاريخ النهاية يجب أن يكون مساوياً أو بعد تاريخ البداية')),
                  );
                  return;
                }
                if (price <= 0) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('الرجاء إدخال سعر صحيح أكبر من الصفر')),
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
                        content: Text('عذراً، الاستراحة محجوزة بالفعل في هذه الفترة!'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                }

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
                  const SnackBar(content: Text('تم تعديل بيانات الحجز بنجاح')),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F766E), foregroundColor: Colors.white),
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
        title: const Text('تأكيد الحذف'),
        content: const Text('هل تريد حذف هذا الحجز نهائياً من قاعدة البيانات؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
          TextButton(
            onPressed: () async {
              await dbHelper.deleteBooking(id);
              await _loadData();
              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                const SnackBar(content: Text('تم حذف الحجز بنجاح')),
              );
            },
            child: const Text('حذف الحجز', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteRenter(String phone) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تأكيد حذف المستأجر'),
        content: const Text('تحذير: سيؤدي حذف المستأجر إلى إزالة بياناته فقط. إذا كان لديه حجوزات مرتبطة فقد تظهر كـ "غير معروف". هل تريد الاستمرار؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
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
                  const SnackBar(content: Text('تعذر الحذف لوجود قيود على البيانات')),
                );
              }
            },
            child: const Text('حذف المستأجر', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarDayCell(DateTime day, {required bool isSelected, required bool isToday, required bool isOutside}) {
    final hijri = HijriCalendar.fromDate(day);
    final hijriDayStr = toArabicDigits(hijri.hDay);
    final gregorianDayStr = day.day.toString();

    Color hijriColor = isSelected 
        ? Colors.white 
        : const Color(0xFF991B1B); // dark red
    Color gregorianColor = isSelected 
        ? Colors.white.withValues(alpha: 0.7) 
        : Colors.grey.shade500;
    
    BoxDecoration? decoration;
    if (isSelected) {
      decoration = const BoxDecoration(
        color: Color(0xFF0F766E), // Teal 700
        shape: BoxShape.circle,
      );
    } else if (isToday) {
      decoration = BoxDecoration(
        color: const Color(0xFF0F766E).withValues(alpha: 0.15),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF0F766E), width: 1.5),
      );
    }

    double opacity = isOutside ? 0.4 : 1.0;

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
              style: TextStyle(
                fontSize: 10.sp(context),
                color: gregorianColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final todayStr = DateTime.now().toString().split(' ')[0];
    final activeBookingsCount = _bookings.where((b) => b['end_date'].toString().compareTo(todayStr) >= 0).length;
    final archivedBookingsCount = _bookings.where((b) => b['end_date'].toString().compareTo(todayStr) < 0).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          // القسم الأيمن (تيل/سليت) - قائمة البيانات الإجمالية (الحجوزات أو المستأجرين)
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  // أزرار التبديل
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _showRentersTab = false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: !_showRentersTab ? const Color(0xFF0F766E) : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'الحجوزات (${_bookings.length})',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: !_showRentersTab ? Colors.white : Colors.grey.shade700,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13.sp(context),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _showRentersTab = true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: _showRentersTab ? const Color(0xFF0F766E) : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'قائمة المستأجرين (${_renters.length})',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _showRentersTab ? Colors.white : Colors.grey.shade700,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13.sp(context),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!_showRentersTab) ...[
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      padding: const EdgeInsets.all(2),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _bookingFilter = 'active'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                decoration: BoxDecoration(
                                  color: _bookingFilter == 'active'
                                      ? const Color(0xFF0D9488)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'الحجوزات النشطة ($activeBookingsCount)',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: _bookingFilter == 'active' ? Colors.white : Colors.grey.shade600,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11.sp(context),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _bookingFilter = 'archived'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                decoration: BoxDecoration(
                                  color: _bookingFilter == 'archived'
                                      ? const Color(0xFF0D9488)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'الأرشيف ($archivedBookingsCount)',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: _bookingFilter == 'archived' ? Colors.white : Colors.grey.shade600,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11.sp(context),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  // محتوى القائمة
                  Expanded(
                    child: _showRentersTab ? _buildRentersList() : _buildBookingsList(),
                  ),
                ],
              ),
            ),
          ),
          const VerticalDivider(width: 1, thickness: 1, color: Color(0xFFE2E8F0)),
          // القسم الأيسر - التقويم مع الحجوزات الخاصة باليوم المختار
          Expanded(
            flex: 3,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _showAddBookingDialog,
                          icon: const Icon(Icons.add, size: 20),
                          label: const Text('تسجيل حجز جديد'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F766E),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _showAddRenterDialog,
                          icon: const Icon(Icons.person_add_outlined, size: 20),
                          label: const Text('مستأجر جديد'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0F766E),
                            side: const BorderSide(color: Color(0xFF0F766E)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // حاوية التقويم
                  Card(
                    color: Colors.white,
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        children: [
                          // Custom dual date header
                          Builder(
                            builder: (context) {
                              final focusedHijri = HijriCalendar.fromDate(_focusedDay);
                              final lastDayNum = HijriCalendar().getDaysInMonth(focusedHijri.hYear, focusedHijri.hMonth);
                              final firstDayGregorian = HijriCalendar().hijriToGregorian(focusedHijri.hYear, focusedHijri.hMonth, 1);
                              final lastDayGregorian = HijriCalendar().hijriToGregorian(focusedHijri.hYear, focusedHijri.hMonth, lastDayNum);

                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                child: Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.chevron_left, color: Color(0xFF0F766E)),
                                      onPressed: () {
                                        setState(() {
                                          _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1);
                                        });
                                      },
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      "${firstDayGregorian.day}-${firstDayGregorian.month}-${firstDayGregorian.year} ➔ ${lastDayGregorian.day}-${lastDayGregorian.month}-${lastDayGregorian.year}",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF1E293B),
                                        fontSize: 14.sp(context),
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      "${getArabicHijriMonthName(focusedHijri.hMonth)} ${focusedHijri.hMonth}-${focusedHijri.hYear}",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF991B1B),
                                        fontSize: 16.sp(context),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: const Icon(Icons.chevron_right, color: Color(0xFF0F766E)),
                                      onPressed: () {
                                        setState(() {
                                          _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1);
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          const Divider(height: 16, thickness: 1),
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
                              setState(() {
                                _focusedDay = focusedDay;
                              });
                            },
                            calendarFormat: CalendarFormat.month,
                            locale: 'ar_AE',
                            startingDayOfWeek: StartingDayOfWeek.sunday,
                            headerVisible: false,
                            calendarBuilders: CalendarBuilders(
                              defaultBuilder: (context, day, focusedDay) {
                                return _buildCalendarDayCell(day, isSelected: false, isToday: false, isOutside: false);
                              },
                              selectedBuilder: (context, day, focusedDay) {
                                return _buildCalendarDayCell(day, isSelected: true, isToday: false, isOutside: false);
                              },
                              todayBuilder: (context, day, focusedDay) {
                                return _buildCalendarDayCell(day, isSelected: false, isToday: true, isOutside: false);
                              },
                              outsideBuilder: (context, day, focusedDay) {
                                return _buildCalendarDayCell(day, isSelected: false, isToday: false, isOutside: true);
                              },
                              markerBuilder: (context, date, events) {
                                if (events.isNotEmpty) {
                                  return Positioned(
                                    bottom: 4,
                                    child: Container(
                                      width: 5,
                                      height: 5,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFD97706),
                                        shape: BoxShape.circle,
                                      ),
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
                  ),
                  const SizedBox(height: 16),
                  // عنوان حجوزات اليوم المحدد
                  Row(
                    children: [
                      const Icon(Icons.bookmark_added_outlined, color: Color(0xFF0D9488)),
                      const SizedBox(width: 8),
                      Text(
                        _selectedDay == null
                            ? 'الحجوزات اليومية'
                            : 'الحجوزات في تاريخ ${_selectedDay.toString().split(' ')[0]}',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.sp(context), color: const Color(0xFF1E293B)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildDayBookingsListAdaptive(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // بناء قائمة الحجوزات العامة (مرتبة من الأحدث إلى الأقدم)
  Widget _buildBookingsList() {
    final todayStr = DateTime.now().toString().split(' ')[0];
    final filtered = _bookings.where((b) {
      final isArchived = b['end_date'].toString().compareTo(todayStr) < 0;
      return _bookingFilter == 'archived' ? isArchived : !isArchived;
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          _bookingFilter == 'archived'
              ? 'لا توجد حجوزات مؤرشفة'
              : 'لا توجد حجوزات نشطة حالياً',
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }

    final sorted = List<Map<String, dynamic>>.from(filtered)
      ..sort((a, b) => b['start_date'].toString().compareTo(a['start_date'].toString()));

    return ListView.builder(
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final booking = sorted[index];
        final renter = _renters.firstWhere(
          (r) => r['phone'] == booking['phone'],
          orElse: () => {'full_name': 'مستأجر غير معروف'},
        );

        final cardContent = Card(
          elevation: 0,
          color: const Color(0xFFF8FAFC),
          margin: const EdgeInsets.symmetric(vertical: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              renter['full_name'].toString(),
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp(context)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (_bookingFilter == 'archived') ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE2E8F0),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'مكتمل',
                                style: TextStyle(
                                  fontSize: 10.sp(context),
                                  color: const Color(0xFF475569),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          'من: ${_formatHijriDateOnlyArabic(booking['start_date'])}',
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 13.sp(context),
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          'إلى: ${_formatHijriDateOnlyArabic(booking['end_date'])}',
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 13.sp(context),
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${booking['total_price']} ر.س',
                        style: TextStyle(
                          fontWeight: FontWeight.bold, 
                          color: const Color(0xFF0F766E), 
                          fontSize: 12.sp(context),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 18),
                            onPressed: () => _showEditBookingDialog(booking),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                            onPressed: () => _confirmDeleteBooking(booking['id']),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

        if (_bookingFilter == 'archived') {
          return Opacity(
            opacity: 0.75,
            child: cardContent,
          );
        }
        return cardContent;
      },
    );
  }

  // بناء قائمة المستأجرين العامة (مرتبة حسب الأكثر نشاطاً)
  Widget _buildRentersList() {
    if (_renters.isEmpty) {
      return const Center(child: Text('لا توجد مستأجرين مسجلين بعد'));
    }
    final sorted = List<Map<String, dynamic>>.from(_renters)
      ..sort((a, b) {
        final countA = (a['rental_count'] as num?)?.toInt() ?? 0;
        final countB = (b['rental_count'] as num?)?.toInt() ?? 0;
        return countB.compareTo(countA);
      });
    return ListView.builder(
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final renter = sorted[index];
        return Card(
          elevation: 0,
          color: const Color(0xFFF8FAFC),
          margin: const EdgeInsets.symmetric(vertical: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFE0F2FE),
              foregroundColor: Color(0xFF0284C7),
              child: Icon(Icons.person, size: 18),
            ),
            title: Row(
              children: [
                Text(
                  renter['full_name'].toString(),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp(context)),
                ),
                const SizedBox(width: 8),
                if (renter['notes'] != null && renter['notes'].toString().trim().isNotEmpty)
                  const Tooltip(
                    message: 'توجد ملاحظات على العميل',
                    child: Icon(Icons.warning_amber_rounded, color: Colors.red, size: 16),
                  ),
                const SizedBox(width: 4),
                if ((renter['rating'] != null && (renter['rating'] as num) >= 4) ||
                    (renter['rental_count'] != null && (renter['rental_count'] as num) >= 3))
                  const Tooltip(
                    message: 'عميل مميز وموثوق',
                    child: Icon(Icons.verified, color: Colors.green, size: 16),
                  ),
              ],
            ),
            subtitle: Text(
              'هاتف: ${renter['phone']}\nمرات التأجير: ${renter['rental_count'] ?? 0}',
              style: TextStyle(fontSize: 11.sp(context)),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 18),
                  onPressed: () => _showEditRenterDialog(renter),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                  onPressed: () => _confirmDeleteRenter(renter['phone']),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
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
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: const Center(child: Text('يرجى تحديد يوم من التقويم', style: TextStyle(color: Colors.grey))),
      );
    }

    final bookingsOnDay = _getBookingsForDay(_selectedDay!)
      ..sort((a, b) => b['start_date'].toString().compareTo(a['start_date'].toString()));

    if (bookingsOnDay.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: const Center(
          child: Text(
            'لا توجد حجوزات في هذا اليوم',
            style: TextStyle(color: Colors.grey),
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

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF0D9488).withAlpha(51), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(13),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: Color(0xFF0F766E),
                        foregroundColor: Colors.white,
                        radius: 18,
                        child: Icon(Icons.vpn_key_outlined, size: 18),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: booking['status'] == 'cancelled'
                              ? const Color(0xFFFEF2F2)
                              : (booking['status'] == 'pending'
                                  ? const Color(0xFFFFFBEB)
                                  : const Color(0xFFECFDF5)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          booking['status'] == 'cancelled'
                              ? 'ملغي'
                              : (booking['status'] == 'pending' ? 'قيد الانتظار' : 'مؤكد'),
                          style: TextStyle(
                            color: booking['status'] == 'cancelled'
                                ? const Color(0xFFDC2626)
                                : (booking['status'] == 'pending'
                                    ? const Color(0xFFD97706)
                                    : const Color(0xFF059669)),
                            fontSize: 12.sp(context),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 20),
                        onPressed: () => _showEditBookingDialog(booking),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                        onPressed: () => _confirmDeleteBooking(booking['id']),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                children: [
                  Text(
                    'اسم المستأجر: ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16.sp(context),
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      renter['full_name'].toString(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18.sp(context),
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  if (renter['notes'] != null && renter['notes'].toString().trim().isNotEmpty)
                    const Tooltip(
                      message: 'توجد ملاحظات على العميل',
                      child: Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                    ),
                  const SizedBox(width: 4),
                  if ((renter['rating'] != null && (renter['rating'] as num) >= 4) ||
                      (renter['rental_count'] != null && (renter['rental_count'] as num) >= 3))
                    const Tooltip(
                      message: 'عميل مميز وموثوق',
                      child: Icon(Icons.verified, color: Colors.green, size: 20),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'رقم التواصل: ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16.sp(context),
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  Text(
                    booking['phone'].toString(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18.sp(context),
                      color: const Color(0xFF0F766E),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'فترة الحجز: ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16.sp(context),
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'من: ${_formatDateString(booking['start_date'])}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15.sp(context),
                            color: const Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'إلى: ${_formatDateString(booking['end_date'])}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15.sp(context),
                            color: const Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'المبلغ المدفوع: ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16.sp(context),
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  Text(
                    '${booking['total_price']} ر.س',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18.sp(context),
                      color: const Color(0xFF0F766E),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'قيمة التأمين: ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16.sp(context),
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  Text(
                    '${booking['security_deposit'] ?? 0.0} ر.س',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18.sp(context),
                      color: const Color(0xFF0F766E),
                    ),
                  ),
                ],
              ),
            ],
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
      final maxDays = HijriCalendar().getDaysInMonth(_selectedYear, _selectedMonth);
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
      final maxDays = HijriCalendar().getDaysInMonth(_selectedYear, _selectedMonth);
      if (_selectedDay > maxDays) {
        _selectedDay = maxDays;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth = HijriCalendar().getDaysInMonth(_selectedYear, _selectedMonth);
    final firstDayGregorian = HijriCalendar().hijriToGregorian(_selectedYear, _selectedMonth, 1);
    final startOffset = firstDayGregorian.weekday % 7;

    const weekdayNames = ['ح', 'ن', 'ث', 'ر', 'خ', 'ج', 'س'];

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      titlePadding: const EdgeInsets.all(16),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Color(0xFF0F766E)),
            onPressed: _previousMonth,
          ),
          Text(
            '${getArabicHijriMonthName(_selectedMonth)} ${toArabicDigits(_selectedYear)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16.sp(context),
              color: const Color(0xFF0F766E),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Color(0xFF0F766E)),
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
                        color: Colors.grey.shade600,
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
                            color: Color(0xFF0F766E),
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
          child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: () {
            final targetGregorian = HijriCalendar().hijriToGregorian(_selectedYear, _selectedMonth, _selectedDay);
            Navigator.pop(context, targetGregorian);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0F766E),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('تأكيد'),
        ),
      ],
    );
  }
}