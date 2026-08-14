import 'package:flutter/material.dart';
import '../utils/responsive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart' as pp;
import 'package:path/path.dart' as p;
import 'dart:io' as io;
import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';

class SettingsPage extends StatefulWidget {
  final VoidCallback onDatabaseRestored;

  const SettingsPage({
    super.key,
    required this.onDatabaseRestored,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isLoading = false;

  Future<bool> _validateAndImportBackup(String sourcePath) async {
    final dbPath = await DatabaseHelper.instance.getDatabasePath();
    final tempPath = '$dbPath.temp';

    // 1. نسخ الملف مؤقتاً للتحقق من صحته
    final sourceFile = io.File(sourcePath);
    final tempFile = await sourceFile.copy(tempPath);

    Database? testDb;
    bool isValid = false;
    try {
      testDb = await openDatabase(tempPath);
      // الاستعلام عن وجود الجداول المطلوبة لإدارة الاستراحة
      final tables = await testDb.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
      final tableNames = tables.map((t) => t['name'] as String).toList();
      if (tableNames.contains('bookings') && tableNames.contains('renters')) {
        isValid = true;
      }
    } catch (e) {
      isValid = false;
    } finally {
      if (testDb != null) {
        await testDb.close();
      }
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    }

    if (!isValid) {
      throw Exception('الملف المختار ليس قاعدة بيانات صالحة لتطبيق إدارة الاستراحات.');
    }

    // 2. إذا كان الملف سليماً، نقوم باستبدال قاعدة البيانات الحالية
    await DatabaseHelper.instance.closeDatabase();
    await sourceFile.copy(dbPath);
    await DatabaseHelper.instance.resetDatabase();
    return true;
  }

  Future<void> _exportBackup() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final dbPath = await DatabaseHelper.instance.getDatabasePath();
      final dbFile = io.File(dbPath);
      if (!await dbFile.exists()) {
        throw Exception('ملف قاعدة البيانات غير موجود في المسار الافتراضي.');
      }

      final now = DateTime.now();
      final timestamp = "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}";
      final fileName = 'resthouse_backup_$timestamp.db';

      String? outputPath;

      if (io.Platform.isWindows || io.Platform.isMacOS || io.Platform.isLinux) {
        // أنظمة التشغيل لسطح المكتب (ويندوز)
        outputPath = await FilePicker.platform.saveFile(
          dialogTitle: 'اختر موقع حفظ النسخة الاحتياطية',
          fileName: fileName,
          type: FileType.any,
        );
        if (outputPath != null) {
          await dbFile.copy(outputPath);
        }
      } else if (io.Platform.isIOS) {
        // iOS لا يسمح باختيار مجلد حفظ عام؛ نستخدم مستندات التطبيق.
        // تم تفعيل File Sharing في Info.plist للوصول إلى النسخ عبر Finder أو تطبيق الملفات.
        final documentsDirectory = await pp.getApplicationDocumentsDirectory();
        outputPath = p.join(documentsDirectory.path, fileName);
        await dbFile.copy(outputPath);
      } else {
        // Android: محاولة اختيار مجلد مخصص باستخدام SAF.
        final selectedDir = await FilePicker.platform.getDirectoryPath(
          dialogTitle: 'اختر مجلد حفظ النسخة الاحتياطية',
        );
        if (selectedDir != null) {
          outputPath = p.join(selectedDir, fileName);
          await dbFile.copy(outputPath);
        } else {
          final externalDir = await pp.getExternalStorageDirectory() ?? await pp.getApplicationDocumentsDirectory();
          outputPath = p.join(externalDir.path, fileName);
          await dbFile.copy(outputPath);
        }
      }

      if (outputPath != null) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.check_circle, color: Color(0xFF10B981), size: 28),
                  SizedBox(width: 8),
                  Text('تم التصدير بنجاح'),
                ],
              ),
              content: Text(
                io.Platform.isIOS
                    ? 'تم حفظ النسخة الاحتياطية في مستندات التطبيق. يمكنك الوصول إليها عبر Finder أو تطبيق الملفات عند توصيل iPhone.\n\n$outputPath'
                    : 'تم حفظ نسخة من البيانات بأمان في المسار التالي:\n\n$outputPath',
                style: const TextStyle(height: 1.4),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('حسناً'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ أثناء تصدير البيانات: $e'),
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
          'تحذير: استيراد نسخة احتياطية سيقوم باستبدال كافة البيانات الحالية ولا يمكن التراجع عن هذا الإجراء. هل تريد الاستمرار بالفعل؟',
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('استمرار واستبدال'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result != null && result.files.single.path != null) {
        final sourcePath = result.files.single.path!;
        await _validateAndImportBackup(sourcePath);

        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.check_circle, color: Color(0xFF10B981), size: 28),
                  SizedBox(width: 8),
                  Text('تمت الاستعادة بنجاح'),
                ],
              ),
              content: const Text(
                'تمت استعادة قاعدة البيانات بنجاح وسنقوم بتحديث جميع واجهات التطبيق في الخلفية فوراً.',
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('موافق'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red, size: 28),
                SizedBox(width: 8),
                Text('فشل استيراد البيانات'),
              ],
            ),
            content: Text(
              'تعذر قراءة قاعدة البيانات المحددة.\n\nالسبب: ${e.toString().replaceAll('Exception: ', '')}',
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
      setState(() {
        _isLoading = false;
      });
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0F766E)),
                          ),
                        ),
                      )
                    else ...[
                      // زر تصدير البيانات
                      ElevatedButton.icon(
                        onPressed: _exportBackup,
                        icon: const Icon(Icons.cloud_upload_outlined, size: 22),
                        label: const Text(
                          'تصدير نسخة احتياطية (Export)',
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
                        icon: const Icon(Icons.cloud_download_outlined, size: 22),
                        label: const Text(
                          'استيراد نسخة احتياطية (Import)',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0D9488),
                          side: const BorderSide(color: Color(0xFF0D9488), width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // زر بذر البيانات الأولية
                      OutlinedButton.icon(
                        onPressed: _seedData,
                        icon: const Icon(Icons.playlist_add_check_rounded, size: 22),
                        label: const Text(
                          'بذر بيانات تجريبية (Seed Initial Data)',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0F766E),
                          side: const BorderSide(color: Color(0xFF0F766E), width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // زر بذر المستأجرين فقط
                      OutlinedButton.icon(
                        onPressed: _seedTenantsOnlyData,
                        icon: const Icon(Icons.people_outline, size: 22),
                        label: const Text(
                          'بذر المستأجرين فقط (Seed Tenants Only)',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0F766E),
                          side: const BorderSide(color: Color(0xFF0F766E), width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
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
                          Icon(Icons.info_outline, color: Colors.amber.shade800, size: 20),
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
