import 'dart:convert';
import 'dart:io' as io;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart' as pp;

import '../database_helper.dart';
import '../ui/app_theme.dart';
import '../utils/responsive.dart';

class SettingsPage extends StatefulWidget {
  final VoidCallback onDatabaseRestored;

  const SettingsPage({super.key, required this.onDatabaseRestored});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isLoading = false;

  String _timestamp() {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
  }

  String _friendlyError(Object error) {
    if (error is FormatException) {
      return error.message.toString();
    }
    if (error is io.FileSystemException) {
      return 'تعذر الوصول إلى الملف أو حفظه. تحقق من صلاحية الموقع والمساحة المتاحة ثم أعد المحاولة.';
    }
    return 'تعذر إكمال العملية. أعد المحاولة وتأكد من صلاحية الملف أو موقع الحفظ.';
  }

  Future<void> _writeStructuredBackup(String outputPath) async {
    final backup = await DatabaseHelper.instance.exportBackupData();
    final encoded = const JsonEncoder.withIndent('  ').convert(backup);
    await io.File(outputPath).writeAsString(encoded, flush: true);
  }

  Future<String> _createRecoveryBackup() async {
    final databasePath = await DatabaseHelper.instance.getDatabasePath();
    final recoveryPath = p.join(
      p.dirname(databasePath),
      'resthouse_recovery_${_timestamp()}.json',
    );
    await _writeStructuredBackup(recoveryPath);
    return recoveryPath;
  }

  Future<Map<String, dynamic>> _readStructuredBackup(String sourcePath) async {
    final source = io.File(sourcePath);
    if (!await source.exists()) {
      throw const FormatException('تعذر الوصول إلى ملف النسخة الاحتياطية.');
    }
    final decoded = jsonDecode(await source.readAsString());
    if (decoded is! Map) {
      throw const FormatException('صيغة ملف النسخة الاحتياطية غير صالحة.');
    }
    return Map<String, dynamic>.from(decoded);
  }

  Future<void> _showResultDialog({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
    String actionLabel = 'موافق',
    VoidCallback? onConfirmed,
  }) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(icon, color: iconColor),
            const SizedBox(width: 10),
            Expanded(child: Text(title)),
          ],
        ),
        content: SingleChildScrollView(
          child: SelectableText(
            message,
            style: Theme.of(dialogContext).textTheme.bodyMedium,
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              onConfirmed?.call();
            },
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }

  Future<void> _exportBackup() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final fileName = 'resthouse_backup_${_timestamp()}.json';
      String? outputPath;

      if (io.Platform.isWindows || io.Platform.isMacOS || io.Platform.isLinux) {
        outputPath = await FilePicker.platform.saveFile(
          dialogTitle: 'اختر موقع حفظ النسخة الاحتياطية',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['json'],
        );
      } else if (io.Platform.isIOS) {
        final documentsDirectory = await pp.getApplicationDocumentsDirectory();
        outputPath = p.join(documentsDirectory.path, fileName);
      } else {
        final selectedDir = await FilePicker.platform.getDirectoryPath(
          dialogTitle: 'اختر مجلد حفظ النسخة الاحتياطية',
        );
        if (selectedDir == null) return;
        outputPath = p.join(selectedDir, fileName);
      }

      if (outputPath == null) return;
      final normalizedPath = outputPath.endsWith('.json')
          ? outputPath
          : '$outputPath.json';
      await _writeStructuredBackup(normalizedPath);

      await _showResultDialog(
        icon: Icons.check_circle_outline_rounded,
        iconColor: AppColors.success,
        title: 'تم التصدير بنجاح',
        message: io.Platform.isIOS
            ? 'تم حفظ نسخة JSON في مجلد مستندات التطبيق. يمكنك الوصول إليها من تطبيق الملفات أو Finder عند توصيل iPhone.\n\n$normalizedPath'
            : 'تم حفظ نسخة JSON مهيكلة من البيانات في المسار التالي:\n\n$normalizedPath',
      );
    } catch (error) {
      await _showResultDialog(
        icon: Icons.error_outline_rounded,
        iconColor: AppColors.error,
        title: 'تعذر تصدير البيانات',
        message: _friendlyError(error),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _importBackup() async {
    if (_isLoading) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.restore_rounded, color: AppColors.warning),
            SizedBox(width: 10),
            Expanded(child: Text('استعادة نسخة احتياطية')),
          ],
        ),
        content: const SingleChildScrollView(
          child: Text(
            'سيتم التحقق من ملف JSON واستبدال البيانات داخل معاملة آمنة. قبل الاستبدال ستُنشأ نسخة استرجاع تلقائية من بياناتك الحالية.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.folder_open_rounded),
            label: const Text('اختيار النسخة'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.single.path == null || !mounted) return;

    setState(() => _isLoading = true);
    try {
      final backup = await _readStructuredBackup(result.files.single.path!);
      final recoveryPath = await _createRecoveryBackup();
      await DatabaseHelper.instance.restoreBackupData(backup);

      await _showResultDialog(
        icon: Icons.check_circle_outline_rounded,
        iconColor: AppColors.success,
        title: 'تمت الاستعادة بنجاح',
        message:
            'تمت استعادة البيانات وتحديث واجهات التطبيق. احتُفظ بنسخة استرجاع تلقائية من بياناتك السابقة في:\n\n$recoveryPath',
        onConfirmed: widget.onDatabaseRestored,
      );
    } catch (error) {
      await _showResultDialog(
        icon: Icons.error_outline_rounded,
        iconColor: AppColors.error,
        title: 'فشل استيراد البيانات',
        message:
            'لم تُستبدل البيانات عند فشل عملية الاستعادة.\n\n${_friendlyError(error)}',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _clearLocalData() async {
    if (_isLoading) return;
    final shouldClear =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.delete_forever_rounded, color: AppColors.error),
                SizedBox(width: 10),
                Expanded(child: Text('مسح جميع البيانات المحلية')),
              ],
            ),
            content: const SingleChildScrollView(
              child: Text(
                'سيُمسح جميع المستأجرين والحجوزات والدفعات والمصروفات وسجل التدقيق من هذا الجهاز. لا يمكن التراجع عن المسح من داخل التطبيق، لكن سيُنشئ التطبيق نسخة استعادة JSON تلقائية قبل التنفيذ.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('مسح جميع البيانات'),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldClear || !mounted) return;

    setState(() => _isLoading = true);
    try {
      final recoveryPath = await _createRecoveryBackup();
      final result = await DatabaseHelper.instance.clearLocalData();

      await _showResultDialog(
        icon: Icons.check_circle_outline_rounded,
        iconColor: AppColors.success,
        title: 'أصبحت القوائم فارغة',
        message: result.totalDeleted == 0
            ? 'لا توجد سجلات محلية لمسحها.\n\nأُنشئت نسخة الاستعادة هنا:\n$recoveryPath'
            : 'مُسح ${result.totalDeleted} سجلًا محليًا، وأصبحت قوائم الحجوزات والمستأجرين والتقارير المالية فارغة.\n\nأُنشئت نسخة الاستعادة هنا:\n$recoveryPath',
        onConfirmed: widget.onDatabaseRestored,
      );
    } catch (error) {
      await _showResultDialog(
        icon: Icons.error_outline_rounded,
        iconColor: AppColors.error,
        title: 'تعذر مسح البيانات',
        message: _friendlyError(error),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: Responsive.pagePadding(context),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 860),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildIntro(context),
                      const SizedBox(height: 20),
                      if (_isLoading) ...[
                        const LinearProgressIndicator(minHeight: 3),
                        const SizedBox(height: 16),
                      ],
                      _SettingsSection(
                        icon: Icons.cloud_sync_outlined,
                        title: 'النسخ الاحتياطي',
                        description:
                            'احفظ نسخة JSON كاملة من بيانات الاستراحة أو استعد نسخة محفوظة سابقًا.',
                        children: [
                          FilledButton.icon(
                            onPressed: _isLoading ? null : _exportBackup,
                            icon: const Icon(Icons.upload_file_rounded),
                            label: const Text('تصدير نسخة احتياطية JSON'),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: _isLoading ? null : _importBackup,
                            icon: const Icon(Icons.restore_page_rounded),
                            label: const Text('استيراد نسخة احتياطية JSON'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _SettingsSection(
                        icon: Icons.admin_panel_settings_outlined,
                        title: 'إدارة البيانات',
                        description:
                            'العمليات الحساسة مفصولة بوضوح عن إجراءات النسخ والاستعادة العادية.',
                        tone: _SectionTone.danger,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _isLoading ? null : _clearLocalData,
                            icon: const Icon(Icons.delete_forever_rounded),
                            label: const Text('مسح جميع البيانات المحلية'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              side: const BorderSide(color: Color(0xFFF3B4B4)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const _SettingsSection(
                        icon: Icons.info_outline_rounded,
                        title: 'حول التطبيق',
                        description:
                            'نظام محلي لإدارة حجوزات الاستراحة والدفعات والمصروفات والنسخ الاحتياطي.',
                        children: [
                          _InfoRow(
                            label: 'الإصدار',
                            value: '1.0.0',
                          ),
                          SizedBox(height: 10),
                          _InfoRow(
                            label: 'طريقة التخزين',
                            value: 'محلي على الجهاز',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsetsDirectional.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.warningContainer,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFFF4D7A6),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.lightbulb_outline_rounded,
                              color: AppColors.warning,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'ينصح بعمل نسخة احتياطية دورية وحفظها في مكان آمن خارج الجهاز.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: AppColors.warning,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
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

  Widget _buildIntro(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsetsDirectional.all(
        Responsive.isCompact(context) ? 18 : 24,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFCCFBF1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF99E7DD)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.settings_backup_restore_rounded,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'إدارة البيانات والنسخ الاحتياطي',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  'احمِ بيانات الاستراحة، واستعدها عند الحاجة، وأبقِ العمليات الحساسة منفصلة وواضحة.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _SectionTone { normal, danger }

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.icon,
    required this.title,
    required this.description,
    required this.children,
    this.tone = _SectionTone.normal,
  });

  final IconData icon;
  final String title;
  final String description;
  final List<Widget> children;
  final _SectionTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final danger = tone == _SectionTone.danger;

    return Container(
      padding: EdgeInsetsDirectional.all(
        Responsive.isCompact(context) ? 16 : 20,
      ),
      decoration: BoxDecoration(
        color: danger ? AppColors.errorContainer : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: danger ? const Color(0xFFF3C4C4) : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: danger
                      ? const Color(0xFFFDE2E2)
                      : AppColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: danger ? AppColors.error : AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (children.isNotEmpty) ...[
            const SizedBox(height: 18),
            ...children,
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
