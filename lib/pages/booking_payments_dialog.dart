import 'package:flutter/material.dart';

import '../database_helper.dart';

/// Shows the complete receipt history, including corrections, for one booking.
class BookingPaymentsDialog extends StatefulWidget {
  const BookingPaymentsDialog({super.key, required this.bookingId});

  final int bookingId;

  @override
  State<BookingPaymentsDialog> createState() => _BookingPaymentsDialogState();
}

class _BookingPaymentsDialogState extends State<BookingPaymentsDialog> {
  List<Map<String, dynamic>> _payments = [];
  Map<String, double>? _summary;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final helper = DatabaseHelper.instance;
      final rows = await helper.queryPaymentsForBooking(
        widget.bookingId,
        includeVoided: true,
      );
      final summary = await helper.queryPaymentSummary(widget.bookingId);
      if (!mounted) return;
      setState(() {
        _payments = rows;
        _summary = summary;
        _error = null;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر تحميل سجل الدفعات.');
    }
  }

  Future<void> _voidPayment(Map<String, dynamic> payment) async {
    if (_busy) return;
    setState(() => _busy = true);
    var reasonText = '';
    final formKey = GlobalKey<FormState>();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إلغاء دفعة خاطئة'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'سيُحتفظ بالدفعة وسبب إلغائها في السجل. هذه العملية تصحح التسجيل ولا تنفذ استرداداً مالياً للعميل.',
              ),
              const SizedBox(height: 12),
              TextFormField(
                onChanged: (value) => reasonText = value,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'سبب الإلغاء'),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'اكتب سبب إلغاء الدفعة.'
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('رجوع'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, reasonText.trim());
              }
            },
            child: const Text('تأكيد إلغاء الدفعة'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (reason == null) {
      setState(() => _busy = false);
      return;
    }
    try {
      await DatabaseHelper.instance.voidPayment(
        payment['id'] as int,
        reason: reason,
      );
      await _load();
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر إلغاء الدفعة. حاول مرة أخرى.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('دفعات الحجز #${widget.bookingId}'),
      content: SizedBox(
        width: 480,
        child: _summary == null && _error == null
            ? const SizedBox(
                height: 80,
                child: Center(child: CircularProgressIndicator()),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null)
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                    if (_summary != null) ...[
                      Text(
                        'المسدد: ${_summary!['paid']!.toStringAsFixed(2)} ر.س',
                      ),
                      Text(
                        'المتبقي: ${_summary!['remaining']!.toStringAsFixed(2)} ر.س',
                      ),
                      const Divider(),
                      if (_payments.isEmpty)
                        const Text('لا توجد دفعات لهذا الحجز.'),
                      for (final payment in _payments)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${(payment['amount'] as num).toStringAsFixed(2)} ر.س — ${payment['status'] == 'voided' ? 'ملغاة' : 'مؤكدة'}',
                                ),
                                Text(
                                  '${payment['paid_at']} — ${const {'cash': 'نقدي', 'transfer': 'تحويل بنكي', 'card': 'بطاقة'}[payment['method']] ?? payment['method']}',
                                ),
                                if ((payment['note'] ?? '')
                                    .toString()
                                    .isNotEmpty)
                                  Text(payment['note'].toString()),
                                if (payment['status'] == 'voided') ...[
                                  Text('السبب: ${payment['void_reason']}'),
                                  Text(
                                    'تاريخ الإلغاء: ${payment['voided_at']}',
                                  ),
                                ] else
                                  TextButton.icon(
                                    onPressed: _busy
                                        ? null
                                        : () => _voidPayment(payment),
                                    icon: const Icon(Icons.undo),
                                    label: const Text('إلغاء الدفعة'),
                                  ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('إغلاق'),
        ),
      ],
    );
  }
}
