import 'package:flutter/material.dart';

abstract final class AppColors {
  static const background = Color(0xFFF8FAFC);
  static const surface = Color(0xFFFFFFFF);
  static const text = Color(0xFF111827);
  static const heading = Color(0xFF0F172A);
  static const secondaryText = Color(0xFF475569);
  static const primary = Color(0xFF0F766E);
  static const primaryPressed = Color(0xFF115E59);
  static const selectedSurface = Color(0xFFCCFBF1);
  static const divider = Color(0xFFD1D9E0);
  static const fieldBorder = Color(0xFF64748B);

  static const successText = Color(0xFF166534);
  static const successSurface = Color(0xFFDCFCE7);
  static const warningText = Color(0xFF92400E);
  static const warningSurface = Color(0xFFFEF3C7);
  static const errorText = Color(0xFFB91C1C);
  static const errorSurface = Color(0xFFFEE2E2);
  static const neutralText = secondaryText;
  static const neutralSurface = Color(0xFFE2E8F0);
}

abstract final class AppSpacing {
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

abstract final class AppRadius {
  static const medium = 12.0;
  static const large = 16.0;
}

abstract final class AppTheme {
  static const fontFamily = 'IBMPlexSansArabic';

  static ThemeData get light {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.primary,
          onPrimary: Colors.white,
          primaryContainer: AppColors.selectedSurface,
          onPrimaryContainer: AppColors.primaryPressed,
          secondary: AppColors.primaryPressed,
          onSecondary: Colors.white,
          secondaryContainer: AppColors.selectedSurface,
          onSecondaryContainer: AppColors.primaryPressed,
          error: AppColors.errorText,
          onError: Colors.white,
          errorContainer: AppColors.errorSurface,
          onErrorContainer: AppColors.errorText,
          surface: AppColors.surface,
          onSurface: AppColors.text,
          onSurfaceVariant: AppColors.secondaryText,
          outline: AppColors.fieldBorder,
          outlineVariant: AppColors.divider,
        );

    final textTheme = _textTheme();
    final radius = BorderRadius.circular(AppRadius.medium);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: fontFamily,
      textTheme: textTheme,
      visualDensity: VisualDensity.standard,
      dividerColor: AppColors.divider,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        toolbarHeight: 68,
        titleTextStyle: textTheme.headlineSmall?.copyWith(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 1,
        shadowColor: const Color(0x1A0F172A),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.large),
          side: const BorderSide(color: AppColors.divider),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        errorMaxLines: 5,
        helperMaxLines: 5,
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 14),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.secondaryText,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: textTheme.labelLarge?.copyWith(
          color: AppColors.primaryPressed,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.secondaryText,
        ),
        helperStyle: textTheme.bodySmall?.copyWith(
          color: AppColors.secondaryText,
        ),
        errorStyle: textTheme.bodySmall?.copyWith(color: AppColors.errorText),
        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(color: AppColors.fieldBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(color: AppColors.fieldBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(color: AppColors.errorText, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(color: AppColors.errorText, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: _primaryButtonStyle(radius),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: _primaryButtonStyle(
          radius,
        ).copyWith(elevation: const WidgetStatePropertyAll(0)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
          padding: const WidgetStatePropertyAll(
            EdgeInsetsDirectional.symmetric(horizontal: 20, vertical: 12),
          ),
          textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
          foregroundColor: const WidgetStatePropertyAll(
            AppColors.primaryPressed,
          ),
          side: const WidgetStatePropertyAll(
            BorderSide(color: AppColors.fieldBorder),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: radius),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
          padding: const WidgetStatePropertyAll(
            EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 12),
          ),
          textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
          foregroundColor: const WidgetStatePropertyAll(
            AppColors.primaryPressed,
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: radius),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyLarge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.large),
          side: const BorderSide(color: AppColors.divider),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.neutralSurface,
        selectedColor: AppColors.selectedSurface,
        disabledColor: AppColors.neutralSurface,
        labelStyle: textTheme.labelMedium?.copyWith(
          color: AppColors.neutralText,
        ),
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(
          color: AppColors.primaryPressed,
        ),
        side: const BorderSide(color: AppColors.divider),
        shape: RoundedRectangleBorder(borderRadius: radius),
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 10,
          vertical: 6,
        ),
      ),
      dataTableTheme: DataTableThemeData(
        headingTextStyle: textTheme.labelLarge?.copyWith(
          color: AppColors.heading,
        ),
        dataTextStyle: textTheme.bodyMedium,
        headingRowColor: const WidgetStatePropertyAll(AppColors.neutralSurface),
        dividerThickness: 1,
        horizontalMargin: 16,
        columnSpacing: 24,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primaryPressed,
        unselectedItemColor: AppColors.secondaryText,
        selectedLabelStyle: textTheme.labelMedium,
        unselectedLabelStyle: textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w500,
        ),
        type: BottomNavigationBarType.fixed,
        elevation: 4,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.selectedSurface,
        surfaceTintColor: Colors.transparent,
        height: 72,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return textTheme.labelMedium?.copyWith(
            color: states.contains(WidgetState.selected)
                ? AppColors.primaryPressed
                : AppColors.secondaryText,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.primaryPressed
                : AppColors.secondaryText,
          );
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.heading,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
      iconTheme: const IconThemeData(color: AppColors.secondaryText),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
      ),
    );
  }

  static ButtonStyle _primaryButtonStyle(BorderRadius radius) {
    return ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
      padding: const WidgetStatePropertyAll(
        EdgeInsetsDirectional.symmetric(horizontal: 20, vertical: 12),
      ),
      textStyle: WidgetStatePropertyAll(_textTheme().labelLarge),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: radius),
      ),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return AppColors.neutralSurface;
        }
        if (states.contains(WidgetState.pressed)) {
          return AppColors.primaryPressed;
        }
        return AppColors.primary;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return AppColors.secondaryText;
        }
        return Colors.white;
      }),
    );
  }

  static TextTheme _textTheme() {
    TextStyle style(
      double size,
      FontWeight weight, {
      Color color = AppColors.text,
      double height = 1.5,
    }) {
      return TextStyle(
        fontFamily: fontFamily,
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: 0,
      );
    }

    return TextTheme(
      displayLarge: style(
        32,
        FontWeight.w700,
        color: AppColors.heading,
        height: 1.4,
      ),
      displayMedium: style(
        30,
        FontWeight.w700,
        color: AppColors.heading,
        height: 1.4,
      ),
      displaySmall: style(
        28,
        FontWeight.w700,
        color: AppColors.heading,
        height: 1.4,
      ),
      headlineLarge: style(
        28,
        FontWeight.w700,
        color: AppColors.heading,
        height: 1.4,
      ),
      headlineMedium: style(
        26,
        FontWeight.w700,
        color: AppColors.heading,
        height: 1.4,
      ),
      headlineSmall: style(
        24,
        FontWeight.w700,
        color: AppColors.heading,
        height: 1.4,
      ),
      titleLarge: style(
        20,
        FontWeight.w600,
        color: AppColors.heading,
        height: 1.45,
      ),
      titleMedium: style(
        18,
        FontWeight.w600,
        color: AppColors.heading,
        height: 1.45,
      ),
      titleSmall: style(
        16,
        FontWeight.w600,
        color: AppColors.heading,
        height: 1.45,
      ),
      bodyLarge: style(16, FontWeight.w400, height: 1.55),
      bodyMedium: style(16, FontWeight.w400, height: 1.55),
      bodySmall: style(
        14,
        FontWeight.w400,
        color: AppColors.secondaryText,
        height: 1.5,
      ),
      labelLarge: style(15, FontWeight.w600, height: 1.4),
      labelMedium: style(14, FontWeight.w600, height: 1.4),
      labelSmall: style(
        13,
        FontWeight.w500,
        color: AppColors.secondaryText,
        height: 1.4,
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    required this.icon,
    required this.foreground,
    required this.background,
  });

  final String label;
  final IconData icon;
  final Color foreground;
  final Color background;

  const StatusBadge.success({super.key, required this.label})
    : icon = Icons.check_circle_outline,
      foreground = AppColors.successText,
      background = AppColors.successSurface;

  const StatusBadge.warning({super.key, required this.label})
    : icon = Icons.schedule_outlined,
      foreground = AppColors.warningText,
      background = AppColors.warningSurface;

  const StatusBadge.error({super.key, required this.label})
    : icon = Icons.error_outline,
      foreground = AppColors.errorText,
      background = AppColors.errorSurface;

  const StatusBadge.neutral({super.key, required this.label})
    : icon = Icons.info_outline,
      foreground = AppColors.neutralText,
      background = AppColors.neutralSurface;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: Container(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 10,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: foreground.withValues(alpha: 0.28)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: foreground),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: foreground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
