import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:table_calendar/table_calendar.dart';

import '../database_helper.dart';
import '../ui/app_theme.dart';
import '../utils/responsive.dart';
import 'booking_manager_page.dart' as legacy;

class BookingWorkspacePage extends StatefulWidget {
  const BookingWorkspacePage({super.key});

  @override
  State<BookingWorkspacePage> createState() => _BookingWorkspacePageState();
}

enum _DirectoryMode { bookings, renters }

class _BookingWorkspacePageState extends State<BookingWorkspacePage> {
  final _db = DatabaseHelper.instance;
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _bookings = [];
  List<Map<String, dynamic>> _renters = [];
  List<Map<String, dynamic>> _payments = [];

  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  _DirectoryMode _directoryMode = _DirectoryMode.bookings;
  String _bookingFilter = 'active';
  int _compactPane = 0;
  bool _loading = true;
  bool _writing = false;
  final Set<int> _shownDepositReminders = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final bookings = await _db.queryAllBookings();
    final renters = await _db.queryAllRenters();
    final payments = await _db.queryAllPayments();
    if (!mounted) return;
    setState(() {
      _bookings = bookings;
      _renters = renters;
      _payments = payments;
      _loading = false;
    });
    _checkPendingDeposits();
  }

  Future<void> _checkPendingDeposits() async {
    final pending = await _db.queryEndedBookingsWithPendingDeposit();
    if (!mounted) return;
    for (final booking in pending) {
      final id = booking['id'];
      if (id is! int || _shownDepositReminders.contains(id) || !mounted) {
        continue;
      }
      _shownDepositReminders.add(id);
      final renter = _renterFor(booking['phone']?.toString());
      final action = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.security_outlined, color: AppColors.warning),
              SizedBox(width: 10),
              Expanded(child: Text('تأمين بانتظار التسوية')),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  renter?['full_name']?.toString() ?? 'مستأجر غير معروف',
                  style: Theme.of(dialogContext).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'قيمة التأمين: ${_money((booking['security_deposit'] as num?)?.toDouble() ?? 0)}',
                ),
                Text('انتهى الحجز في ${booking['end_date']}'),
                const SizedBox(height: 8),
                const Text('اختر الإجراء الذي تم على مبلغ التأمين.'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, 'later'),
              child: const Text('لاحقًا'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.pop(dialogContext, 'deducted'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
              ),
              child: const Text('تم الخصم'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, 'returned'),
              child: const Text('تم الإرجاع'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (action == 'returned' || action == 'deducted') {
        await _db.updateDepositStatus(id, action!);
        await _loadData();
      }
    }
  }

  Map<String, dynamic>? _renterFor(String? phone) {
    if (phone == null) return null;
    for (final renter in _renters) {
      if (renter['phone']?.toString() == phone) return renter;
    }
    return null;
  }

  double _paidForBooking(int? bookingId) {
    if (bookingId == null) return 0;
    return _payments
        .where(
          (payment) =>
              payment['booking_id'] == bookingId &&
              (payment['status'] ?? 'confirmed') == 'confirmed',
        )
        .fold<double>(
          0,
          (sum, payment) =>
              sum + ((payment['amount'] as num?)?.toDouble() ?? 0),
        );
  }

  String _money(double value) => '${value.toStringAsFixed(2)} ر.س';

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  List<Map<String, dynamic>> _bookingsForDay(DateTime day) {
    final key = _dateKey(day);
    return _bookings.where((booking) {
      final start = booking['start_date']?.toString() ?? '';
      final end = booking['end_date']?.toString() ?? '';
      return key.compareTo(start) >= 0 && key.compareTo(end) <= 0;
    }).toList();
  }

  Color _statusColor(String? status) {
    switch (status) {
      case DatabaseHelper.statusCancelled:
        return AppColors.error;
      case DatabaseHelper.statusPending:
        return AppColors.warning;
      default:
        return AppColors.success;
    }
  }

  String _statusLabel(String? status) {
    switch (status) {
      case DatabaseHelper.statusCancelled:
        return 'ملغي';
      case DatabaseHelper.statusPending:
        return 'قيد الانتظار';
      default:
        return 'مؤكد';
    }
  }

  Color _statusBackground(String? status) {
    switch (status) {
      case DatabaseHelper.statusCancelled:
        return AppColors.errorContainer;
      case DatabaseHelper.statusPending:
        return AppColors.warningContainer;
      default:
        return AppColors.successContainer;
    }
  }

  Future<DateTime?> _selectDateDual(
    BuildContext dialogContext,
    DateTime initialDate,
  ) async {
    final choice = await showDialog<String>(
      context: dialogContext,
      builder: (context) => AlertDialog(
        title: const Text('اختر نوع التقويم'),
        content: const Text('يمكن تحديد التاريخ بالميلادي أو الهجري.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(context, 'hijri'),
            icon: const Icon(Icons.mosque_outlined),
            label: const Text('هجري'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, 'gregorian'),
            icon: const Icon(Icons.calendar_month_outlined),
            label: const Text('ميلادي'),
          ),
        ],
      ),
    );
    if (choice == null || !dialogContext.mounted) return null;
    if (choice == 'hijri') {
      return showDialog<DateTime>(
        context: dialogContext,
        builder: (_) => legacy.HijriDatePickerDialog(
          initialDate: initialDate,
          firstDate: DateTime(2020),
          lastDate: DateTime(2050),
        ),
      );
    }
    return showDatePicker(
      context: dialogContext,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2050),
    );
  }

  Future<void> _addRenter() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var busy = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('إضافة مستأجر جديد'),
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
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'أدخل الاسم الكامل.'
                              : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      textDirection: TextDirection.ltr,
                      textAlign: TextAlign.end,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      decoration: const InputDecoration(labelText: 'رقم الهاتف'),
                      validator: (value) {
                        final phone = value?.trim() ?? '';
                        if (phone.length != 10) {
                          return 'رقم الهاتف يجب أن يتكون من 10 أرقام.';
                        }
                        if (!phone.startsWith('05')) {
                          return 'رقم الهاتف يجب أن يبدأ بـ 05.';
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
              onPressed: busy ? null : () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => busy = true);
                      try {
                        await _db.insertRenter({
                          'full_name': nameController.text.trim(),
                          'phone': phoneController.text.trim(),
                          'notes': '',
                          'rating': 5,
                          'rental_count': 0,
                        });
                        await _loadData();
                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext);
                      } catch (_) {
                        if (!dialogContext.mounted) return;
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(
                            content: Text('رقم الهاتف مستخدم لمستأجر آخر.'),
                          ),
                        );
                      } finally {
                        if (dialogContext.mounted) {
                          setDialogState(() => busy = false);
                        }
                      }
                    },
              child: busy
                  ? const SizedBox.square(
                      dimension: 18,
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

  Future<void> _editRenter(Map<String, dynamic> renter) async {
    final nameController = TextEditingController(
      text: renter['full_name']?.toString() ?? '',
    );
    final phoneController = TextEditingController(
      text: renter['phone']?.toString() ?? '',
    );
    final notesController = TextEditingController(
      text: renter['notes']?.toString() ?? '',
    );
    final formKey = GlobalKey<FormState>();
    var busy = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('تعديل بيانات المستأجر'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'الاسم الكامل'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'أدخل الاسم الكامل.'
                              : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      textDirection: TextDirection.ltr,
                      textAlign: TextAlign.end,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      decoration: const InputDecoration(labelText: 'رقم الهاتف'),
                      validator: (value) {
                        final phone = value?.trim() ?? '';
                        if (phone.length != 10) return 'أدخل رقمًا من 10 أرقام.';
                        if (!phone.startsWith('05')) return 'يجب أن يبدأ الرقم بـ 05.';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: notesController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(labelText: 'الملاحظات'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => busy = true);
                      try {
                        await _db.updateRenter(
                          {
                            'phone': phoneController.text.trim(),
                            'full_name': nameController.text.trim(),
                            'notes': notesController.text.trim(),
                            'rating': renter['rating'] ?? 5,
                            'rental_count': renter['rental_count'] ?? 0,
                          },
                          oldPhone: renter['phone']?.toString(),
                        );
                        await _loadData();
                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext);
                      } catch (_) {
                        if (!dialogContext.mounted) return;
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(
                            content: Text('تعذر حفظ التعديل. تحقق من رقم الهاتف.'),
                          ),
                        );
                      } finally {
                        if (dialogContext.mounted) {
                          setDialogState(() => busy = false);
                        }
                      }
                    },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
    phoneController.dispose();
    notesController.dispose();
  }

  Future<void> _deleteRenter(Map<String, dynamic> renter) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف المستأجر'),
        content: Text(
          'هل تريد حذف ${renter['full_name']}؟ لا يمكن حذف مستأجر لديه حجوزات مرتبطة.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _db.deleteRenter(renter['phone'].toString());
      await _loadData();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يمكن حذف المستأجر لوجود حجوزات مرتبطة.')),
      );
    }
  }

  Future<void> _showRenterNotes(String notes) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ملاحظات على المستأجر'),
        content: SingleChildScrollView(child: Text(notes)),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('موافق'),
          ),
        ],
      ),
    );
  }

  Future<void> _addBooking({DateTime? initialDate}) async {
    if (_renters.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أضف مستأجرًا أولًا قبل تسجيل الحجز.')),
      );
      return;
    }

    String? selectedPhone;
    String? notes;
    DateTime startDate = initialDate ?? _selectedDay;
    DateTime endDate = initialDate ?? _selectedDay;
    final priceController = TextEditingController();
    final depositController = TextEditingController();
    var busy = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('تسجيل حجز جديد'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: selectedPhone,
                    decoration: const InputDecoration(labelText: 'المستأجر'),
                    items: _renters
                        .map(
                          (renter) => DropdownMenuItem<String>(
                            value: renter['phone'].toString(),
                            child: Text(
                              '${renter['full_name']} (${renter['phone']})',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: busy
                        ? null
                        : (value) {
                            setDialogState(() {
                              selectedPhone = value;
                              final renter = _renterFor(value);
                              final raw = renter?['notes']?.toString().trim() ?? '';
                              notes = raw.isEmpty ? null : raw;
                            });
                            if (notes != null) _showRenterNotes(notes!);
                          },
                  ),
                  if (notes != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsetsDirectional.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'تنبيه: $notes',
                        style: const TextStyle(color: AppColors.error),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: busy
                          ? null
                          : () async {
                              final date = await _selectDateDual(
                                dialogContext,
                                startDate,
                              );
                              if (date == null || !dialogContext.mounted) return;
                              setDialogState(() {
                                startDate = date;
                                if (endDate.isBefore(startDate)) endDate = startDate;
                              });
                            },
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text('البداية: ${_dateKey(startDate)}'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: busy
                          ? null
                          : () async {
                              final date = await _selectDateDual(
                                dialogContext,
                                endDate.isBefore(startDate) ? startDate : endDate,
                              );
                              if (date == null || !dialogContext.mounted) return;
                              if (date.isBefore(startDate)) {
                                ScaffoldMessenger.of(dialogContext).showSnackBar(
                                  const SnackBar(
                                    content: Text('تاريخ النهاية لا يسبق البداية.'),
                                  ),
                                );
                                return;
                              }
                              setDialogState(() => endDate = date);
                            },
                      icon: const Icon(Icons.event_available_outlined),
                      label: Text('النهاية: ${_dateKey(endDate)}'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: priceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'سعر الحجز (ر.س)'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: depositController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'قيمة التأمين (ر.س)'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      final price = double.tryParse(priceController.text.trim());
                      final deposit =
                          double.tryParse(depositController.text.trim()) ?? 0;
                      if (selectedPhone == null || price == null || price <= 0) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(content: Text('تحقق من المستأجر وسعر الحجز.')),
                        );
                        return;
                      }
                      setDialogState(() => busy = true);
                      try {
                        final conflict = await _db.hasBookingConflict(
                          _dateKey(startDate),
                          _dateKey(endDate),
                        );
                        if (conflict) {
                          if (!dialogContext.mounted) return;
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            const SnackBar(
                              content: Text('يوجد حجز مؤكد في هذه الفترة.'),
                            ),
                          );
                          return;
                        }
                        await _db.insertBooking({
                          'phone': selectedPhone,
                          'start_date': _dateKey(startDate),
                          'end_date': _dateKey(endDate),
                          'total_price': price,
                          'security_deposit': deposit,
                          'status': DatabaseHelper.statusConfirmed,
                        });
                        await _loadData();
                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext);
                      } on ArgumentError catch (error) {
                        if (!dialogContext.mounted) return;
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(content: Text(error.message?.toString() ?? 'بيانات غير صالحة.')),
                        );
                      } on StateError catch (error) {
                        if (!dialogContext.mounted) return;
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(content: Text(error.message)),
                        );
                      } finally {
                        if (dialogContext.mounted) {
                          setDialogState(() => busy = false);
                        }
                      }
                    },
              child: const Text('حفظ الحجز'),
            ),
          ],
        ),
      ),
    );
    priceController.dispose();
    depositController.dispose();
  }

  Future<void> _editBooking(Map<String, dynamic> booking) async {
    DateTime startDate = DateTime.parse(booking['start_date'].toString());
    DateTime endDate = DateTime.parse(booking['end_date'].toString());
    final priceController = TextEditingController(text: booking['total_price'].toString());
    final depositController = TextEditingController(
      text: (booking['security_deposit'] ?? 0).toString(),
    );
    String status = booking['status']?.toString() ?? DatabaseHelper.statusConfirmed;
    var busy = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('تعديل الحجز'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFCCFBF1),
                      foregroundColor: AppColors.primary,
                      child: Icon(Icons.person_outline),
                    ),
                    title: Text(_renterFor(booking['phone']?.toString())?['full_name']?.toString() ?? 'مستأجر غير معروف'),
                    subtitle: Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(booking['phone']?.toString() ?? ''),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: busy
                          ? null
                          : () async {
                              final value = await _selectDateDual(dialogContext, startDate);
                              if (value == null || !dialogContext.mounted) return;
                              setDialogState(() {
                                startDate = value;
                                if (endDate.isBefore(startDate)) endDate = startDate;
                              });
                            },
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text('البداية: ${_dateKey(startDate)}'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: busy
                          ? null
                          : () async {
                              final value = await _selectDateDual(dialogContext, endDate);
                              if (value == null || !dialogContext.mounted) return;
                              if (value.isBefore(startDate)) return;
                              setDialogState(() => endDate = value);
                            },
                      icon: const Icon(Icons.event_available_outlined),
                      label: Text('النهاية: ${_dateKey(endDate)}'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: priceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'سعر الحجز (ر.س)'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: depositController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'قيمة التأمين (ر.س)'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(labelText: 'حالة الحجز'),
                    items: const [
                      DropdownMenuItem(value: 'confirmed', child: Text('مؤكد')),
                      DropdownMenuItem(value: 'pending', child: Text('قيد الانتظار')),
                      DropdownMenuItem(value: 'cancelled', child: Text('ملغي')),
                    ],
                    onChanged: busy ? null : (value) => setDialogState(() => status = value ?? status),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      final price = double.tryParse(priceController.text.trim());
                      final deposit = double.tryParse(depositController.text.trim()) ?? 0;
                      if (price == null || price <= 0) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(content: Text('أدخل سعر حجز صحيحًا.')),
                        );
                        return;
                      }
                      setDialogState(() => busy = true);
                      try {
                        if (status == DatabaseHelper.statusConfirmed) {
                          final conflict = await _db.hasBookingConflict(
                            _dateKey(startDate),
                            _dateKey(endDate),
                            excludeId: booking['id'] as int,
                          );
                          if (conflict) {
                            if (!dialogContext.mounted) return;
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              const SnackBar(content: Text('يوجد حجز مؤكد آخر في هذه الفترة.')),
                            );
                            return;
                          }
                        }
                        await _db.updateBooking({
                          'id': booking['id'],
                          'phone': booking['phone'],
                          'start_date': _dateKey(startDate),
                          'end_date': _dateKey(endDate),
                          'total_price': price,
                          'security_deposit': deposit,
                          'status': status,
                          'deposit_status': booking['deposit_status'] ?? DatabaseHelper.depositPending,
                        });
                        await _loadData();
                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext);
                      } on ArgumentError catch (error) {
                        if (!dialogContext.mounted) return;
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(content: Text(error.message?.toString() ?? 'بيانات غير صالحة.')),
                        );
                      } on StateError catch (error) {
                        if (!dialogContext.mounted) return;
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(content: Text(error.message)),
                        );
                      } finally {
                        if (dialogContext.mounted) setDialogState(() => busy = false);
                      }
                    },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    priceController.dispose();
    depositController.dispose();
  }

  Future<void> _deleteBooking(Map<String, dynamic> booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف الحجز'),
        content: const Text('هل تريد حذف هذا الحجز نهائيًا؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حذف الحجز'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _db.deleteBooking(booking['id'] as int);
      await _loadData();
    } on StateError catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  Future<void> _addPayment(Map<String, dynamic> booking) async {
    final bookingId = booking['id'] as int;
    final summary = await _db.queryPaymentSummary(bookingId);
    if (!mounted) return;
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    String method = 'cash';
    var busy = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('تسجيل دفعة'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _paymentSummaryBox(summary),
                  const SizedBox(height: 14),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'قيمة الدفعة (ر.س)'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: method,
                    decoration: const InputDecoration(labelText: 'طريقة السداد'),
                    items: const [
                      DropdownMenuItem(value: 'cash', child: Text('نقدي')),
                      DropdownMenuItem(value: 'transfer', child: Text('تحويل بنكي')),
                      DropdownMenuItem(value: 'card', child: Text('بطاقة')),
                    ],
                    onChanged: busy ? null : (value) => setDialogState(() => method = value ?? 'cash'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'ملاحظة (اختياري)'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      final amount = double.tryParse(amountController.text.trim());
                      if (amount == null || amount <= 0) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(content: Text('أدخل قيمة دفعة صحيحة.')),
                        );
                        return;
                      }
                      setDialogState(() => busy = true);
                      try {
                        await _db.insertPayment({
                          'booking_id': bookingId,
                          'amount': amount,
                          'paid_at': _dateKey(DateTime.now()),
                          'method': method,
                          'note': noteController.text.trim(),
                        });
                        await _loadData();
                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext);
                      } on ArgumentError catch (error) {
                        if (!dialogContext.mounted) return;
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(content: Text(error.message?.toString() ?? 'تعذر تسجيل الدفعة.')),
                        );
                      } on StateError catch (error) {
                        if (!dialogContext.mounted) return;
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(content: Text(error.message)),
                        );
                      } finally {
                        if (dialogContext.mounted) setDialogState(() => busy = false);
                      }
                    },
              child: const Text('حفظ الدفعة'),
            ),
          ],
        ),
      ),
    );
    amountController.dispose();
    noteController.dispose();
  }

  Widget _paymentSummaryBox(Map<String, double> summary) {
    return Container(
      padding: const EdgeInsetsDirectional.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFCCFBF1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Wrap(
        spacing: 18,
        runSpacing: 8,
        children: [
          _miniValue('الإجمالي', _money(summary['total'] ?? 0)),
          _miniValue('المسدد', _money(summary['paid'] ?? 0)),
          _miniValue('المتبقي', _money(summary['remaining'] ?? 0)),
        ],
      ),
    );
  }

  Widget _miniValue(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(value, style: Theme.of(context).textTheme.labelLarge),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 900;
        if (compact) return _buildCompactWorkspace();
        return _buildExpandedWorkspace(constraints.maxWidth);
      },
    );
  }

  Widget _buildCompactWorkspace() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildActions(),
              const SizedBox(height: 12),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(
                    value: 0,
                    icon: Icon(Icons.calendar_month_outlined),
                    label: Text('التقويم'),
                  ),
                  ButtonSegment(
                    value: 1,
                    icon: Icon(Icons.view_list_outlined),
                    label: Text('القوائم'),
                  ),
                ],
                selected: {_compactPane},
                showSelectedIcon: false,
                onSelectionChanged: (selection) {
                  setState(() => _compactPane = selection.first);
                },
              ),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: IndexedStack(
            index: _compactPane,
            children: [
              _buildCalendarPane(compact: true),
              _buildDirectoryPane(compact: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExpandedWorkspace(double availableWidth) {
    final directoryWidth = (availableWidth * 0.34).clamp(340.0, 430.0);
    return Row(
      children: [
        SizedBox(
          width: directoryWidth,
          child: _buildDirectoryPane(compact: false),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 0),
                child: _buildActions(),
              ),
              Expanded(child: _buildCalendarPane(compact: false)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActions() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 430) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                onPressed: _writing ? null : () => _addBooking(),
                icon: const Icon(Icons.add_rounded),
                label: const Text('تسجيل حجز جديد'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _writing ? null : _addRenter,
                icon: const Icon(Icons.person_add_alt_1_outlined),
                label: const Text('مستأجر جديد'),
              ),
            ],
          );
        }
        return Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _writing ? null : () => _addBooking(),
                icon: const Icon(Icons.add_rounded),
                label: const Text('تسجيل حجز جديد'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _writing ? null : _addRenter,
                icon: const Icon(Icons.person_add_alt_1_outlined),
                label: const Text('مستأجر جديد'),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDirectoryPane({required bool compact}) {
    final query = _searchController.text.trim().toLowerCase();
    return Container(
      color: AppColors.surface,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              compact ? 16 : 14,
              14,
              compact ? 16 : 14,
              10,
            ),
            child: Column(
              children: [
                SegmentedButton<_DirectoryMode>(
                  segments: const [
                    ButtonSegment(
                      value: _DirectoryMode.bookings,
                      icon: Icon(Icons.event_note_outlined),
                      label: Text('الحجوزات'),
                    ),
                    ButtonSegment(
                      value: _DirectoryMode.renters,
                      icon: Icon(Icons.groups_2_outlined),
                      label: Text('المستأجرون'),
                    ),
                  ],
                  selected: {_directoryMode},
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) {
                    setState(() => _directoryMode = selection.first);
                  },
                ),
                if (_directoryMode == _DirectoryMode.bookings &&
                    _bookings.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'active', label: Text('النشطة')),
                      ButtonSegment(value: 'archived', label: Text('الأرشيف')),
                    ],
                    selected: {_bookingFilter},
                    showSelectedIcon: false,
                    onSelectionChanged: (selection) {
                      setState(() => _bookingFilter = selection.first);
                    },
                  ),
                ],
                const SizedBox(height: 10),
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: _directoryMode == _DirectoryMode.bookings
                        ? 'ابحث باسم المستأجر أو الهاتف'
                        : 'ابحث عن مستأجر',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'مسح البحث',
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: _directoryMode == _DirectoryMode.bookings
                ? _buildBookingList(query)
                : _buildRenterList(query),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingList(String query) {
    final today = _dateKey(DateTime.now());
    final filtered = _bookings.where((booking) {
      final archived = booking['end_date'].toString().compareTo(today) < 0;
      final renter = _renterFor(booking['phone']?.toString());
      final matches = query.isEmpty ||
          booking['phone'].toString().contains(query) ||
          (renter?['full_name']?.toString().toLowerCase() ?? '').contains(query);
      return (_bookingFilter == 'archived' ? archived : !archived) && matches;
    }).toList()
      ..sort(
        (a, b) => b['start_date'].toString().compareTo(a['start_date'].toString()),
      );

    if (filtered.isEmpty) {
      return _emptyState(
        icon: Icons.event_busy_outlined,
        title: query.isEmpty ? 'لا توجد حجوزات في هذا القسم' : 'لا توجد نتائج',
        subtitle: query.isEmpty
            ? 'ستظهر الحجوزات هنا بعد تسجيلها.'
            : 'غيّر عبارة البحث أو امسحها لعرض السجلات.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 20),
      itemCount: filtered.length,
      separatorBuilder: (_, _) => const SizedBox(height: 9),
      itemBuilder: (context, index) => _bookingCard(filtered[index]),
    );
  }

  Widget _bookingCard(Map<String, dynamic> booking) {
    final renter = _renterFor(booking['phone']?.toString());
    final bookingId = booking['id'] as int?;
    final total = (booking['total_price'] as num?)?.toDouble() ?? 0;
    final paid = _paidForBooking(bookingId);
    final remaining = total - paid;
    final status = booking['status']?.toString();

    return Container(
      padding: const EdgeInsetsDirectional.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      renter?['full_name']?.toString() ?? 'مستأجر غير معروف',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        booking['phone']?.toString() ?? '',
                        textAlign: TextAlign.end,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _statusChip(status),
              PopupMenuButton<String>(
                tooltip: 'إجراءات الحجز',
                onSelected: (value) {
                  if (value == 'payment') _addPayment(booking);
                  if (value == 'edit') _editBooking(booking);
                  if (value == 'delete') _deleteBooking(booking);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'payment',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.payments_outlined),
                      title: Text('تسجيل دفعة'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.edit_outlined),
                      title: Text('تعديل الحجز'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.delete_outline, color: AppColors.error),
                      title: Text('حذف الحجز'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _infoPill(Icons.login_rounded, 'من ${booking['start_date']}'),
              _infoPill(Icons.logout_rounded, 'إلى ${booking['end_date']}'),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsetsDirectional.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceSubtle,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Wrap(
              spacing: 18,
              runSpacing: 8,
              children: [
                _miniValue('الإجمالي', _money(total)),
                _miniValue('المسدد', _money(paid)),
                _miniValue('المتبقي', _money(remaining)),
                if (((booking['security_deposit'] as num?)?.toDouble() ?? 0) > 0)
                  _miniValue(
                    'التأمين',
                    _money((booking['security_deposit'] as num).toDouble()),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRenterList(String query) {
    final filtered = _renters.where((renter) {
      return query.isEmpty ||
          renter['full_name'].toString().toLowerCase().contains(query) ||
          renter['phone'].toString().contains(query);
    }).toList()
      ..sort((a, b) {
        final countA = (a['rental_count'] as num?)?.toInt() ?? 0;
        final countB = (b['rental_count'] as num?)?.toInt() ?? 0;
        return countB.compareTo(countA);
      });

    if (filtered.isEmpty) {
      return _emptyState(
        icon: Icons.person_search_outlined,
        title: query.isEmpty ? 'لا يوجد مستأجرون بعد' : 'لا توجد نتائج',
        subtitle: query.isEmpty
            ? 'أضف أول مستأجر لبدء تسجيل الحجوزات.'
            : 'غيّر عبارة البحث أو امسحها.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 20),
      itemCount: filtered.length,
      separatorBuilder: (_, _) => const SizedBox(height: 9),
      itemBuilder: (context, index) {
        final renter = filtered[index];
        final notes = renter['notes']?.toString().trim() ?? '';
        return Container(
          padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 8, 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xFFCCFBF1),
                foregroundColor: AppColors.primary,
                child: Icon(Icons.person_outline),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            renter['full_name'].toString(),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        if (notes.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Tooltip(
                            message: notes,
                            child: const Icon(
                              Icons.warning_amber_rounded,
                              color: AppColors.warning,
                              size: 18,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        renter['phone'].toString(),
                        textAlign: TextAlign.end,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    Text(
                      'مرات التأجير: ${renter['rental_count'] ?? 0}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'إجراءات المستأجر',
                onSelected: (value) {
                  if (value == 'edit') _editRenter(renter);
                  if (value == 'delete') _deleteRenter(renter);
                  if (value == 'notes' && notes.isNotEmpty) _showRenterNotes(notes);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('تعديل البيانات')),
                  if (notes.isNotEmpty)
                    const PopupMenuItem(value: 'notes', child: Text('عرض الملاحظات')),
                  const PopupMenuItem(value: 'delete', child: Text('حذف المستأجر')),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCalendarPane({required bool compact}) {
    final dayBookings = _bookingsForDay(_selectedDay)
      ..sort(
        (a, b) => a['start_date'].toString().compareTo(b['start_date'].toString()),
      );

    return SingleChildScrollView(
      padding: EdgeInsetsDirectional.fromSTEB(
        compact ? 16 : 20,
        14,
        compact ? 16 : 20,
        28,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _calendarCard(),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.event_note_outlined, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'حجوزات ${_dateKey(_selectedDay)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                '${dayBookings.length}',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.primary,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (dayBookings.isEmpty)
            _emptyState(
              icon: Icons.event_available_outlined,
              title: 'لا توجد حجوزات في هذا اليوم',
              subtitle: 'يمكنك تسجيل حجز جديد لهذا التاريخ.',
              action: FilledButton.icon(
                onPressed: () => _addBooking(initialDate: _selectedDay),
                icon: const Icon(Icons.add_rounded),
                label: const Text('حجز لهذا اليوم'),
              ),
            )
          else
            ...[
              for (final booking in dayBookings) ...[
                _bookingCard(booking),
                const SizedBox(height: 10),
              ],
            ],
        ],
      ),
    );
  }

  Widget _calendarCard() {
    final hijri = HijriCalendar.fromDate(_focusedDay);
    final month = legacy.getArabicHijriMonthName(hijri.hMonth);

    return Container(
      padding: const EdgeInsetsDirectional.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'الشهر السابق',
                onPressed: () {
                  setState(() {
                    _focusedDay = DateTime(
                      _focusedDay.year,
                      _focusedDay.month - 1,
                    );
                  });
                },
                icon: const Icon(Icons.chevron_right_rounded),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '$month ${legacy.toArabicDigits(hijri.hYear)}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.primary,
                          ),
                    ),
                    Text(
                      '${_focusedDay.month.toString().padLeft(2, '0')} / ${_focusedDay.year}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'الشهر التالي',
                onPressed: () {
                  setState(() {
                    _focusedDay = DateTime(
                      _focusedDay.year,
                      _focusedDay.month + 1,
                    );
                  });
                },
                icon: const Icon(Icons.chevron_left_rounded),
              ),
            ],
          ),
          const Divider(height: 16),
          TableCalendar<Map<String, dynamic>>(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2050, 12, 31),
            focusedDay: _focusedDay,
            locale: 'ar_AE',
            startingDayOfWeek: StartingDayOfWeek.sunday,
            headerVisible: false,
            rowHeight: 54,
            daysOfWeekHeight: 30,
            selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
            eventLoader: _bookingsForDay,
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onPageChanged: (focusedDay) {
              setState(() => _focusedDay = focusedDay);
            },
            calendarBuilders: CalendarBuilders<Map<String, dynamic>>(
              defaultBuilder: (_, day, _) => _dayCell(day),
              outsideBuilder: (_, day, _) => _dayCell(day, outside: true),
              todayBuilder: (_, day, _) => _dayCell(day, today: true),
              selectedBuilder: (_, day, _) => _dayCell(day, selected: true),
              markerBuilder: (_, _, events) {
                if (events.isEmpty) return null;
                final colors = events
                    .map((booking) => _statusColor(booking['status']?.toString()))
                    .toSet()
                    .take(3)
                    .toList();
                return PositionedDirectional(
                  bottom: 3,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final color in colors)
                        Container(
                          width: 5,
                          height: 5,
                          margin: const EdgeInsetsDirectional.symmetric(horizontal: 1),
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          const Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 6,
            children: [
              _CalendarLegend(color: AppColors.success, label: 'مؤكد'),
              _CalendarLegend(color: AppColors.warning, label: 'قيد الانتظار'),
              _CalendarLegend(color: AppColors.error, label: 'ملغي'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dayCell(
    DateTime day, {
    bool selected = false,
    bool today = false,
    bool outside = false,
  }) {
    final hijri = HijriCalendar.fromDate(day);
    final foreground = selected ? Colors.white : AppColors.textPrimary;
    return Opacity(
      opacity: outside ? 0.38 : 1,
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : today
                  ? const Color(0xFFCCFBF1)
                  : null,
          border: today && !selected
              ? Border.all(color: AppColors.primary)
              : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              legacy.toArabicDigits(hijri.hDay),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: foreground,
              ),
            ),
            Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 10,
                color: selected ? Colors.white70 : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String? status) {
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: _statusBackground(status),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: _statusColor(status),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            _statusLabel(status),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: _statusColor(status),
                ),
          ),
        ],
      ),
    );
  }

  Widget _infoPill(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 5),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 20,
          vertical: 36,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: const BoxDecoration(
                color: Color(0xFFCCFBF1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (action != null) ...[
              const SizedBox(height: 14),
              action,
            ],
          ],
        ),
      ),
    );
  }
}

class _CalendarLegend extends StatelessWidget {
  const _CalendarLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
