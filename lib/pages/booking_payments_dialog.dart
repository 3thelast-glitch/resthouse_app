import 'package:flutter/material.dart';

import '../database_helper.dart';
import '../theme/app_theme.dart';

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

  String _money(num value) => '${value.toStringAsFixed(2)} ر.س';

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
        scrollable: true,
        title: const Text('إلغاء دفعة خاطئة'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const StatusBadge.warning(label: 'تصحيح سجل دفعة'),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'سيُحتفظ بالدفعة وسبب إلغائها في السجل. هذه العملية تصحح التسجيل ولا تنفذ استرداداً مالياً للعميل.',
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                onChanged: (value) => reasonText = value,
                maxLines: 3,
                minLines: 2,
                decoration: const InputDecoration(
                  labelText: 'سبب الإلغاء',
                  hintText: 'اكتب سبب تصحيح هذه الدفعة',
                ),
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
          FilledButton.icon(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, reasonText.trim());
              }
            },
            icon: const Icon(Icons.undo),
            label: const Text('تأكيد إلغاء الدفعة'),
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
      scrollable: true,
      title: Text('دفعات الحجز #${widget.bookingId}'),
      content: SizedBox(
        width: 520,
        child: _summary == null && _error == null
            ? const SizedBox(
                height: 96,
                child: Center(child: CircularProgressIndicator()),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null) ...[
                    StatusBadge.error(label: _error!),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  if (_summary != null) ...[
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        _SummaryAmount(
                          label: 'المسدد',
                          value: _money(_summary!['paid']!),
                          foreground: AppColors.successText,
                          background: AppColors.successSurface,
                        ),
                        _SummaryAmount(
                          label: 'المتبقي',
                          value: _money(_summary!['remaining']!),
                          foreground: _summary!['remaining']! > 0
                              ? AppColors.warningText
                              : AppColors.successText,
                          background: _summary!['remaining']! > 0
                              ? AppColors.warningSurface
                              : AppColors.successSurface,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const Divider(),
                    const SizedBox(height: AppSpacing.md),
                    if (_payments.isEmpty)
                      const StatusBadge.neutral(
                        label: 'لا توجد دفعات لهذا الحجز.',
                      ),
                    for (final payment in _payments) ...[
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _PaymentAmount(amount: payment['amount'] as num),
                              const SizedBox(height: 8),
                              Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: payment['status'] == 'voided'
                                    ? const StatusBadge.error(label: 'ملغاة')
                                    : const StatusBadge.success(label: 'مؤكدة'),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Directionality(
                                textDirection: TextDirection.ltr,
                                child: Align(
                                  alignment: AlignmentDirectional.centerEnd,
                                  child: Text(
                                    '${payment['paid_at']}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                'طريقة الدفع: ${const {'cash': 'نقدي', 'transfer': 'تحويل بنكي', 'card': 'بطاقة'}[payment['method']] ?? payment['method']}',
                              ),
                              if ((payment['note'] ?? '')
                                  .toString()
                                  .isNotEmpty) ...[
                                const SizedBox(height: AppSpacing.xs),
                                Text('ملاحظة: ${payment['note']}'),
                              ],
                              if (payment['status'] == 'voided') ...[
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  'السبب: ${payment['void_reason']}',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(color: AppColors.errorText),
                                ),
                                Directionality(
                                  textDirection: TextDirection.ltr,
                                  child: Align(
                                    alignment: AlignmentDirectional.centerEnd,
                                    child: Text(
                                      'تاريخ الإلغاء: ${payment['voided_at']}',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ),
                                ),
                              ] else ...[
                                const SizedBox(height: AppSpacing.sm),
                                Align(
                                  alignment: AlignmentDirectional.centerStart,
                                  child: TextButton.icon(
                                    onPressed: _busy
                                        ? null
                                        : () => _voidPayment(payment),
                                    icon: const Icon(Icons.undo),
                                    label: const Text('إلغاء الدفعة'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppColors.errorText,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                  ],
                ],
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

class _PaymentAmount extends StatelessWidget {
  const _PaymentAmount({required this.amount});

  final num amount;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleLarge;
    return Wrap(
      spacing: 6,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          amount.toStringAsFixed(2),
          textDirection: TextDirection.ltr,
          softWrap: false,
          style: style,
        ),
        Text(
          'ر.س',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: style?.color),
        ),
      ],
    );
  }
}

class _SummaryAmount extends StatelessWidget {
  const _SummaryAmount({
    required this.label,
    required this.value,
    required this.foreground,
    required this.background,
  });

  final String label;
  final String value;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(color: foreground.withValues(alpha: 0.35)),
      ),
      child: Text(
        '$label: $value',
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: foreground,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
