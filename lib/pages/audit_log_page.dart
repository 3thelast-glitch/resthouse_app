import 'package:flutter/material.dart';

import '../database_helper.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';

/// Arabic labels for the raw values stored in the audit_events table.
/// Unknown values fall back to the stored string so nothing is hidden.
String auditEntityLabel(String? entityType) {
  switch (entityType) {
    case 'booking':
      return 'حجز';
    case 'payment':
      return 'دفعة';
    case 'deposit':
      return 'تأمين';
    case 'backup':
      return 'نسخة احتياطية';
    case 'demo_data':
      return 'بيانات تجريبية';
    default:
      return entityType ?? 'حدث';
  }
}

String auditActionLabel(String? action) {
  switch (action) {
    case 'created':
      return 'إنشاء';
    case 'updated':
      return 'تعديل';
    case 'deleted':
      return 'حذف';
    case 'voided':
      return 'إلغاء';
    case 'restored':
      return 'استعادة';
    case 'returned':
      return 'إرجاع التأمين';
    case 'deducted':
      return 'خصم التأمين';
    case 'pending':
      return 'تأمين معلّق';
    default:
      return action ?? '';
  }
}

IconData _entityIcon(String? entityType) {
  switch (entityType) {
    case 'booking':
      return Icons.calendar_month_outlined;
    case 'payment':
      return Icons.payments_outlined;
    case 'deposit':
      return Icons.shield_outlined;
    case 'backup':
      return Icons.backup_outlined;
    default:
      return Icons.history;
  }
}

({Color foreground, Color background}) _actionColors(String? action) {
  switch (action) {
    case 'created':
    case 'restored':
    case 'returned':
      return (
        foreground: AppColors.successText,
        background: AppColors.successSurface,
      );
    case 'deleted':
    case 'voided':
    case 'deducted':
      return (
        foreground: AppColors.errorText,
        background: AppColors.errorSurface,
      );
    case 'updated':
    case 'pending':
      return (
        foreground: AppColors.warningText,
        background: AppColors.warningSurface,
      );
    default:
      return (
        foreground: AppColors.neutralText,
        background: AppColors.neutralSurface,
      );
  }
}

String _formatTimestamp(String? raw) {
  if (raw == null) return '';
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;
  final local = parsed.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}

/// Renders audit events (rows from the audit_events table) as a list.
///
/// Pure presentation widget: [AuditLogPage] handles loading, this widget
/// only formats, so it can be tested without a database.
class AuditEventList extends StatelessWidget {
  const AuditEventList({super.key, required this.events});

  final List<Map<String, dynamic>> events;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const _AuditEmptyState();
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        final entityType = event['entity_type']?.toString();
        final action = event['action']?.toString();
        final colors = _actionColors(action);
        final details = event['details']?.toString();
        final timestamp = _formatTimestamp(event['created_at']?.toString());

        return Card(
          color: Colors.white,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: colors.background,
              foregroundColor: colors.foreground,
              child: Icon(_entityIcon(entityType), size: 20),
            ),
            title: Text(
              '${auditEntityLabel(entityType)} #${event['entity_id']} — '
              '${auditActionLabel(action)}',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14.sp(context),
                color: AppColors.text,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (timestamp.isNotEmpty)
                  Text(
                    timestamp,
                    style: TextStyle(
                      fontSize: 12.sp(context),
                      color: AppColors.secondaryText,
                    ),
                  ),
                if (details != null && details.isNotEmpty)
                  Text(
                    details,
                    style: TextStyle(
                      fontSize: 12.sp(context),
                      color: AppColors.secondaryText,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AuditEmptyState extends StatelessWidget {
  const _AuditEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Card(
          color: Colors.white,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 48),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.history,
                  size: 52,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'لا توجد أحداث مسجلة بعد',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18.sp(context),
                    color: AppColors.heading,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'ستظهر هنا عمليات إنشاء وتعديل وحذف الحجوزات والدفعات والتأمينات فور حدوثها.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    height: 1.5,
                    fontSize: 13.sp(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Read-only viewer for the audit_events table, which the database layer
/// has been recording all along. Reached from Settings.
class AuditLogPage extends StatefulWidget {
  const AuditLogPage({super.key});

  @override
  State<AuditLogPage> createState() => _AuditLogPageState();
}

class _AuditLogPageState extends State<AuditLogPage> {
  List<Map<String, dynamic>> _events = const [];
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _hasError = false;
      });
    }
    try {
      final events = await DatabaseHelper.instance.queryRecentAuditEvents(
        limit: 200,
      );
      if (!mounted) return;
      setState(() {
        _events = events;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('سجل التدقيق')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _hasError
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: AppColors.errorText,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'تعذر تحميل سجل التدقيق. حاول مرة أخرى.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14.sp(context),
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _loadEvents,
                      icon: const Icon(Icons.refresh),
                      label: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadEvents,
              child: AuditEventList(events: _events),
            ),
    );
  }
}
