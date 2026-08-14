import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io' as io;

// استدعاء واجهة الملاحة الرئيسية
import 'pages/main_shell.dart';

void main() {
  // 1. التأكد من تهيئة بيئة فلاتر قبل تشغيل أي شيء
  WidgetsFlutterBinding.ensureInitialized();

  // 2. تفعيل قاعدة البيانات للعمل على الويندوز (أو أنظمة سطح المكتب)
  if (io.Platform.isWindows || io.Platform.isLinux || io.Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // 3. تشغيل التطبيق
  runApp(const ResthouseApp());
}

TextTheme _makeBold(TextTheme base) {
  return TextTheme(
    displayLarge: base.displayLarge?.copyWith(fontWeight: FontWeight.bold),
    displayMedium: base.displayMedium?.copyWith(fontWeight: FontWeight.bold),
    displaySmall: base.displaySmall?.copyWith(fontWeight: FontWeight.bold),
    headlineLarge: base.headlineLarge?.copyWith(fontWeight: FontWeight.bold),
    headlineMedium: base.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
    headlineSmall: base.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
    titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.bold),
    titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.bold),
    titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.bold),
    bodyLarge: base.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
    bodyMedium: base.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
    bodySmall: base.bodySmall?.copyWith(fontWeight: FontWeight.bold),
    labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.bold),
    labelMedium: base.labelMedium?.copyWith(fontWeight: FontWeight.bold),
    labelSmall: base.labelSmall?.copyWith(fontWeight: FontWeight.bold),
  );
}

class ResthouseApp extends StatelessWidget {
  const ResthouseApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF0F766E), // لون رئيسي: تيل (Teal)
        primary: const Color(0xFF0F766E),
        secondary: const Color(0xFF0D9488),
      ),
      useMaterial3: true,
      fontFamily: 'Inter', // خط موحد
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false, // إخفاء شريط الـ Debug
      title: 'إدارة الاستراحة',
      theme: baseTheme.copyWith(
        textTheme: _makeBold(baseTheme.textTheme),
      ),
      // دعم اللغة العربية
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ar', 'AE'), // لغة عربية
      ],
      locale: const Locale('ar', 'AE'), // إجبار التطبيق على الاتجاه واللغة العربية
      home: const MainShellPage(),
    );
  }
}