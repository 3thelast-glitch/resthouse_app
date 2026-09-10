import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const primary = Color(0xFF0F766E);
  static const secondary = Color(0xFF2B8C85);
  static const canvas = Color(0xFFF5F7FA);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceSubtle = Color(0xFFF1F5F9);
  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF475569);
  static const border = Color(0xFFD7E0E7);

  static const success = Color(0xFF166534);
  static const successContainer = Color(0xFFECFDF5);
  static const warning = Color(0xFF92400E);
  static const warningContainer = Color(0xFFFFF7E6);
  static const error = Color(0xFFB91C1C);
  static const errorContainer = Color(0xFFFEF2F2);
  static const info = Color(0xFF1D4ED8);
  static const infoContainer = Color(0xFFEFF6FF);
}

class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    final scheme = const ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFCCFBF1),
      onPrimaryContainer: Color(0xFF134E4A),
      secondary: AppColors.secondary,
      onSecondary: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      error: AppColors.error,
      onError: Colors.white,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.canvas,
      visualDensity: VisualDensity.standard,
    );

    final textTheme = _buildArabicFriendlyTextTheme(base.textTheme);

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsetsDirectional.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        hintStyle: const TextStyle(color: AppColors.textSecondary),
        errorMaxLines: 3,
        border: _outlineBorder(AppColors.border),
        enabledBorder: _outlineBorder(AppColors.border),
        focusedBorder: _outlineBorder(AppColors.primary, width: 1.6),
        errorBorder: _outlineBorder(AppColors.error),
        focusedErrorBorder: _outlineBorder(AppColors.error, width: 1.6),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 52),
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: 20,
            vertical: 14,
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: 20,
            vertical: 14,
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: 20,
            vertical: 14,
          ),
          side: const BorderSide(color: AppColors.border),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(48, 44),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: Color(0xFFCCFBF1),
        elevation: 0,
        height: 72,
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: Color(0xFFCCFBF1),
        selectedIconTheme: IconThemeData(color: AppColors.primary),
        unselectedIconTheme: IconThemeData(color: AppColors.textSecondary),
        selectedLabelTextStyle: TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.textPrimary,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(color: Colors.white),
      ),
    );
  }

  static OutlineInputBorder _outlineBorder(
    Color color, {
    double width = 1,
  }) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  static TextTheme _buildArabicFriendlyTextTheme(TextTheme base) {
    TextStyle? style(
      TextStyle? source, {
      required double size,
      required FontWeight weight,
      double height = 1.45,
      Color color = AppColors.textPrimary,
    }) {
      return source?.copyWith(
        fontSize: size,
        fontWeight: weight,
        height: height,
        color: color,
        letterSpacing: 0,
      );
    }

    return base.copyWith(
      displayLarge: style(
        base.displayLarge,
        size: 40,
        weight: FontWeight.w700,
        height: 1.25,
      ),
      displayMedium: style(
        base.displayMedium,
        size: 34,
        weight: FontWeight.w700,
        height: 1.25,
      ),
      displaySmall: style(
        base.displaySmall,
        size: 30,
        weight: FontWeight.w700,
        height: 1.25,
      ),
      headlineLarge: style(
        base.headlineLarge,
        size: 26,
        weight: FontWeight.w700,
        height: 1.3,
      ),
      headlineMedium: style(
        base.headlineMedium,
        size: 22,
        weight: FontWeight.w700,
        height: 1.3,
      ),
      headlineSmall: style(
        base.headlineSmall,
        size: 20,
        weight: FontWeight.w700,
        height: 1.35,
      ),
      titleLarge: style(
        base.titleLarge,
        size: 20,
        weight: FontWeight.w700,
        height: 1.35,
      ),
      titleMedium: style(
        base.titleMedium,
        size: 16,
        weight: FontWeight.w700,
      ),
      titleSmall: style(
        base.titleSmall,
        size: 14,
        weight: FontWeight.w700,
      ),
      bodyLarge: style(
        base.bodyLarge,
        size: 16,
        weight: FontWeight.w400,
      ),
      bodyMedium: style(
        base.bodyMedium,
        size: 14,
        weight: FontWeight.w400,
      ),
      bodySmall: style(
        base.bodySmall,
        size: 12,
        weight: FontWeight.w400,
        color: AppColors.textSecondary,
      ),
      labelLarge: style(
        base.labelLarge,
        size: 14,
        weight: FontWeight.w700,
      ),
      labelMedium: style(
        base.labelMedium,
        size: 12,
        weight: FontWeight.w600,
      ),
      labelSmall: style(
        base.labelSmall,
        size: 11,
        weight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    );
  }
}
