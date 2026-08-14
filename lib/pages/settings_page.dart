import 'dart:convert';
import 'dart:io' as io;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart' as pp;

import '../database_helper.dart';
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

  Future<void> _exportBackup() async {
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
        // iOS لا يقدم اختيار مجلد موثوقًا للحفظ؛ نستخدم مستندات التطبيق
        // ونفعّل File Sharing في Info.plist للوصول إليها عبر تطبيق الملفات أو Finder.
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

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Color(0xFF10B981), size: 28),
              SizedBox(width: 8),
              Text('تم التصدير بنجاح'),
            ],
          ),
          content: Text(
            io.Platform.isIOS
                ? 'تم حفظ نسخة JSON في مجلد مستندات التطبيق. يمكنك الوصول إليها من تطبيق الملفات أو Finder عند توصيل iPhone.\n\n$normalizedPath'
                : 'تم حفظ نسخة JSON مهيكلة من البيانات في المسار التالي:\n\n$normalizedPath',
            style: const TextStyle(height: 1.4),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('حسناً'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ أثناء تصدير البيانات: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _importBackup() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 28),
            SizedBox(width: 8),
            Text('تأكيد استيراد البيانات'),
          ],
        ),
        content: const Text(
          'سيتم التحقق من ملف JSON واستبدال البيانات داخل معاملة آمنة. قبل الاستبدال ستُنشأ نسخة استرجاع تلقائية من بياناتك الحالية.',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade800,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('اختيار النسخة والاستعادة'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.single.path == null) return;

    setState(() => _isLoading = true);
    try {
      final backup = await _readStructuredBackup(result.files.single.path!);
      final recoveryPath = await _createRecoveryBackup();
      await DatabaseHelper.instance.restoreBackupData(backup);

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Color(0xFF10B981), size: 28),
              SizedBox(width: 8),
              Text('تمت الاستعادة بنجاح'),
            ],
          ),
          content: Text(
            'تمت استعادة البيانات وتحديث واجهات التطبيق. احتُفظ بنسخة استرجاع تلقائية من بياناتك السابقة في:\n\n$recoveryPath',
            style: const TextStyle(height: 1.4),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                widget.onDatabaseRestored();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('موافق'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red, size: 28),
                SizedBox(width: 8),
                Text('فشل استيراد البيانات'),
              ],
            ),
            content: Text(
              'تعذر التحقق من النسخة أو استعادتها. لم تُستبدل البيانات عند فشل المعاملة.\n\nالسبب: $error',
              style: const TextStyle(height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('حسنًا'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _seedData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await DatabaseHelper.instance.seedInitialData();
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Color(0xFF10B981), size: 28),
                SizedBox(width: 8),
                Text('تم تهيئة البيانات'),
              ],
            ),
            content: const Text(
              'تم إدخال الحجوزات والمستأجرين التجريبيين بنجاح وتحديث كافة شاشات التطبيق.',
              style: TextStyle(height: 1.4),
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  widget.onDatabaseRestored();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('موافق'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ أثناء تهيئة البيانات: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _seedTenantsOnlyData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await DatabaseHelper.instance.seedTenantsOnly();
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Color(0xFF10B981), size: 28),
                SizedBox(width: 8),
                Text('تم تهيئة المستأجرين'),
              ],
            ),
            content: const Text(
              'تم إدخال المستأجرين التجريبيين بنجاح وتحديث كافة شاشات التطبيق.',
              style: TextStyle(height: 1.4),
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  widget.onDatabaseRestored();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('موافق'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ أثناء تهيئة المستأجرين: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _removeDemoData() async {
    final shouldDelete =
        await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.deepOrange),
                SizedBox(width: 8),
                Expanded(child: Text('حذف البيانات التجريبية فقط')),
              ],
            ),
            content: const Text(
              'سيُحذف فقط ما وُسِم داخليًا كبيانات تجريبية. لن تُحذف الحجوزات أو الدفعات أو المستأجرون الذين أُضيفوا أو عُدّلوا للاستخدام الفعلي.\n\nسيُنشئ التطبيق نسخة استعادة تلقائية قبل الحذف.',
              style: TextStyle(height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                ),
                child: const Text('حذف البيانات التجريبية'),
              ),
            ],
          ),
        ) ??
        false;
    if (!shouldDelete) return;

    setState(() => _isLoading = true);
    try {
      final recoveryPath = await _createRecoveryBackup();
      final result = await DatabaseHelper.instance.deleteDemoData();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Color(0xFF10B981), size: 28),
              SizedBox(width: 8),
              Text('اكتمل الحذف الانتقائي'),
            ],
          ),
          content: Text(
            result.totalDeleted == 0
                ? 'لم يُعثر على بيانات تجريبية موسومة للحذف.\n\nأُنشئت نسخة الاستعادة هنا:\n$recoveryPath'
                : 'حُذف ${result.totalDeleted} سجلًا تجريبيًا فقط، مع الحفاظ على البيانات الفعلية.\n\nأُنشئت نسخة الاستعادة هنا:\n$recoveryPath',
            style: const TextStyle(height: 1.5),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                foregroundColor: Colors.white,
              ),
              child: const Text('موافق'),
            ),
          ],
        ),
      );
      if (mounted) widget.onDatabaseRestored();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر حذف البيانات التجريبية: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _clearLocalData() async {
    final shouldClear =
        await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Row(
              children: [
                Icon(Icons.delete_forever, color: Colors.red),
                SizedBox(width: 8),
                Expanded(child: Text('مسح جميع البيانات المحلية')),
              ],
            ),
            content: const Text(
              'سيُمسح جميع المستأجرين والحجوزات والدفعات والمصروفات وسجل التدقيق من هذا الجهاز. لا يمكن التراجع عن المسح من داخل التطبيق، لكن سيُنشئ التطبيق نسخة استعادة JSON تلقائية قبل التنفيذ.',
              style: TextStyle(height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('مسح جميع البيانات'),
              ),
            ],
          ),
        ) ??
        false;
    if (!shouldClear) return;

    setState(() => _isLoading = true);
    try {
      final recoveryPath = await _createRecoveryBackup();
      final result = await DatabaseHelper.instance.clearLocalData();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Color(0xFF10B981), size: 28),
              SizedBox(width: 8),
              Text('أصبحت القوائم فارغة'),
            ],
          ),
          content: Text(
            result.totalDeleted == 0
                ? 'لا توجد سجلات محلية لمسحها.\n\nأُنشئت نسخة الاستعادة هنا:\n$recoveryPath'
                : 'مُسح ${result.totalDeleted} سجلًا محليًا، وأصبحت قوائم الحجوزات والمستأجرين والتقارير المالية فارغة.\n\nأُنشئت نسخة الاستعادة هنا:\n$recoveryPath',
            style: const TextStyle(height: 1.5),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                foregroundColor: Colors.white,
              ),
              child: const Text('موافق'),
            ),
          ],
        ),
      );
      if (mounted) widget.onDatabaseRestored();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر مسح البيانات المحلية: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Card(
              color: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // أيقونة إعدادات عليا مع خلفية خفيفة
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          color: Color(0xFFECFDF5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.settings_backup_restore_outlined,
                          size: 48,
                          color: Color(0xFF0F766E),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'إدارة البيانات والنسخ الاحتياطي',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20.sp(context),
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'احمِ بيانات استراحتك من الضياع. يمكنك عمل نسخة احتياطية كاملة للملفات وحفظها على حاسوبك أو هاتفك واستعادتها في أي وقت.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.sp(context),
                        color: Colors.grey,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Divider(height: 1),
                    const SizedBox(height: 32),
                    if (_isLoading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFF0F766E),
                            ),
                          ),
                        ),
                      )
                    else ...[
                      // زر تصدير البيانات
                      ElevatedButton.icon(
                        onPressed: _exportBackup,
                        icon: const Icon(Icons.cloud_upload_outlined, size: 22),
                        label: const Text(
                          'تصدير نسخة احتياطية JSON',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F766E),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 1,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // زر استيراد البيانات
                      OutlinedButton.icon(
                        onPressed: _importBackup,
                        icon: const Icon(
                          Icons.cloud_download_outlined,
                          size: 22,
                        ),
                        label: const Text(
                          'استيراد نسخة احتياطية JSON',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0D9488),
                          side: const BorderSide(
                            color: Color(0xFF0D9488),
                            width: 1.5,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _removeDemoData,
                        icon: const Icon(Icons.delete_sweep_outlined, size: 22),
                        label: const Text(
                          'حذف البيانات التجريبية فقط',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.deepOrange,
                          side: const BorderSide(
                            color: Colors.deepOrange,
                            width: 1.5,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _clearLocalData,
                        icon: const Icon(Icons.delete_forever, size: 22),
                        label: const Text(
                          'مسح جميع البيانات المحلية',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      if (kDebugMode) ...[
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _seedData,
                          icon: const Icon(
                            Icons.playlist_add_check_rounded,
                            size: 22,
                          ),
                          label: const Text(
                            'بذر بيانات تجريبية',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0F766E),
                            side: const BorderSide(
                              color: Color(0xFF0F766E),
                              width: 1.5,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _seedTenantsOnlyData,
                          icon: const Icon(Icons.people_outline, size: 22),
                          label: const Text(
                            'بذر المستأجرين فقط',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0F766E),
                            side: const BorderSide(
                              color: Color(0xFF0F766E),
                              width: 1.5,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ],
                    const SizedBox(height: 32),
                    // ملاحظة تحذيرية في الأسفل
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        border: Border.all(color: Colors.amber.shade200),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.amber.shade800,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'نصيحة: ينصح بعمل نسخة احتياطية دورياً وحفظها في مكان آمن خارج الجهاز.',
                              style: TextStyle(
                                fontSize: 11.sp(context),
                                color: const Color(0xFF78350F),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
