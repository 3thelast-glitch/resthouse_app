from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
PAGE_FILES = [
    ROOT / 'lib/pages/booking_manager_page.dart',
    ROOT / 'lib/pages/finance_page.dart',
    ROOT / 'lib/pages/ultimate_dashboard_page.dart',
    ROOT / 'lib/pages/settings_page.dart',
]


def add_theme_import(text: str) -> str:
    line = "import '../theme/app_theme.dart';"
    if line in text:
        return text
    material = "import 'package:flutter/material.dart';"
    if material not in text:
        raise RuntimeError('material import not found')
    return text.replace(material, material + '\n\n' + line, 1)


COMMON_REPLACEMENTS = {
    'const Color(0xFFF8FAFC)': 'AppColors.background',
    'const Color(0xFFFFFFFF)': 'AppColors.surface',
    'const Color(0xFF111827)': 'AppColors.text',
    'const Color(0xFF0F172A)': 'AppColors.heading',
    'const Color(0xFF1E293B)': 'AppColors.heading',
    'const Color(0xFF334155)': 'AppColors.secondaryText',
    'const Color(0xFF475569)': 'AppColors.secondaryText',
    'const Color(0xFF0F766E)': 'AppColors.primary',
    'const Color(0xFF0D9488)': 'AppColors.primary',
    'const Color(0xFF115E59)': 'AppColors.primaryPressed',
    'const Color(0xFFCCFBF1)': 'AppColors.selectedSurface',
    'const Color(0xFFD1D9E0)': 'AppColors.divider',
    'const Color(0xFF64748B)': 'AppColors.fieldBorder',
    'const Color(0xFF166534)': 'AppColors.successText',
    'const Color(0xFFDCFCE7)': 'AppColors.successSurface',
    'const Color(0xFF059669)': 'AppColors.successText',
    'const Color(0xFF92400E)': 'AppColors.warningText',
    'const Color(0xFFFEF3C7)': 'AppColors.warningSurface',
    'const Color(0xFFFFF7ED)': 'AppColors.warningSurface',
    'const Color(0xFFD97706)': 'AppColors.warningText',
    'const Color(0xFFFBBF24)': 'AppColors.warningText',
    'const Color(0xFFB91C1C)': 'AppColors.errorText',
    'const Color(0xFFFEE2E2)': 'AppColors.errorSurface',
    'const Color(0xFFDC2626)': 'AppColors.errorText',
    # Red was also used as a decorative Hijri accent; use the calm brand dark teal instead.
    'const Color(0xFF991B1B)': 'AppColors.primaryPressed',
    'const Color(0xFFE2E8F0)': 'AppColors.neutralSurface',
    'const Color(0xFFF0FDFA)': 'AppColors.selectedSurface',
    'const Color(0xFFF1F5F9)': 'AppColors.background',
    'Colors.grey.shade50': 'AppColors.background',
    'Colors.grey.shade100': 'AppColors.background',
    'Colors.grey.shade200': 'AppColors.divider',
    'Colors.grey.shade300': 'AppColors.divider',
    'Colors.grey.shade400': 'AppColors.fieldBorder',
    'Colors.grey.shade500': 'AppColors.secondaryText',
    'Colors.grey.shade600': 'AppColors.secondaryText',
    'Colors.grey.shade700': 'AppColors.secondaryText',
    'Colors.grey.shade800': 'AppColors.text',
    'Colors.grey': 'AppColors.secondaryText',
    'Colors.red.shade50': 'AppColors.errorSurface',
    'Colors.red.shade100': 'AppColors.errorSurface',
    'Colors.red.shade200': 'AppColors.errorText',
    'Colors.red.shade700': 'AppColors.errorText',
    'Colors.red.shade900': 'AppColors.errorText',
    'Colors.red': 'AppColors.errorText',
    'Colors.green.shade50': 'AppColors.successSurface',
    'Colors.green.shade700': 'AppColors.successText',
    'Colors.green': 'AppColors.successText',
    'Colors.orange.shade50': 'AppColors.warningSurface',
    'Colors.orange.shade700': 'AppColors.warningText',
    'Colors.orange': 'AppColors.warningText',
    'Colors.blue': 'AppColors.primaryPressed',
    'Colors.white70': 'Colors.white',
    'Colors.black54': 'AppColors.secondaryText',
    'Alignment.centerLeft': 'AlignmentDirectional.centerStart',
    'Alignment.centerRight': 'AlignmentDirectional.centerEnd',
    'Alignment.topLeft': 'AlignmentDirectional.topStart',
    'Alignment.topRight': 'AlignmentDirectional.topEnd',
    'EdgeInsets.fromLTRB(': 'EdgeInsetsDirectional.fromSTEB(',
}


def normalize_page(path: Path) -> None:
    text = path.read_text(encoding='utf-8')
    text = add_theme_import(text)
    for old, new in COMMON_REPLACEMENTS.items():
        text = text.replace(old, new)

    # Never allow tiny direct text sizes. Existing .sp(context) values are
    # protected by Responsive.sp's readable floor.
    text = re.sub(
        r'fontSize:\s*(?:8|9|10|11|12)(?:\.0)?\s*,',
        'fontSize: 13,',
        text,
    )

    # AlertDialog can scroll its title/content/actions together when a short
    # window or software keyboard leaves little vertical room.
    text = re.sub(
        r'AlertDialog\(\n(?!\s*scrollable:)',
        'AlertDialog(\n          scrollable: true,',
        text,
    )

    # Preserve readable touch targets even where old code explicitly removed
    # IconButton constraints.
    text = text.replace(
        'constraints: const BoxConstraints(),',
        'constraints: const BoxConstraints(minWidth: 48, minHeight: 48),',
    )

    # Phone input must not be visually reversed by the app-wide RTL direction.
    text = text.replace(
        'keyboardType: TextInputType.phone,',
        'keyboardType: TextInputType.phone,\n                textDirection: TextDirection.ltr,',
    )

    path.write_text(text, encoding='utf-8')


for page in PAGE_FILES:
    normalize_page(page)

booking = ROOT / 'lib/pages/booking_manager_page.dart'
text = booking.read_text(encoding='utf-8')

# Keep the two-pane workflow usable on narrow phones without RenderFlex
# overflow. The business UI remains unchanged and can be horizontally panned;
# at 900dp+ it uses the full available width with no extra scroll.
old_body = """      body: Row(\n        children: ["""
new_body = """      body: SingleChildScrollView(\n        scrollDirection: Axis.horizontal,\n        child: SizedBox(\n          width: MediaQuery.sizeOf(context).width < 900\n              ? 900\n              : MediaQuery.sizeOf(context).width,\n          child: Row(\n            children: ["""
if old_body not in text:
    raise RuntimeError('booking main Row marker not found')
text = text.replace(old_body, new_body, 1)
old_tail = """        ],\n      ),\n    );\n  }\n\n  Widget _buildDirectoryEmptyState()"""
new_tail = """            ],\n          ),\n        ),\n      ),\n    );\n  }\n\n  Widget _buildDirectoryEmptyState()"""
if old_tail not in text:
    raise RuntimeError('booking main Row closing marker not found')
text = text.replace(old_tail, new_tail, 1)

# Calendar cells: selected, today and booked are distinct while both Hijri and
# Gregorian day numbers keep high-contrast foregrounds.
old_calendar_colors = """    Color hijriColor = isSelected\n        ? Colors.white\n        : AppColors.primaryPressed; // dark red\n    Color gregorianColor = isSelected\n        ? Colors.white.withValues(alpha: 0.7)\n        : AppColors.secondaryText;\n\n    BoxDecoration? decoration;\n    if (isSelected) {\n      decoration = const BoxDecoration(\n        color: AppColors.primary, // Teal 700\n        shape: BoxShape.circle,\n      );\n    } else if (isToday) {\n      decoration = BoxDecoration(\n        color: AppColors.primary.withValues(alpha: 0.15),\n        shape: BoxShape.circle,\n        border: Border.all(color: AppColors.primary, width: 1.5),\n      );\n    }\n\n    double opacity = isOutside ? 0.4 : 1.0;"""
new_calendar_colors = """    final hasBooking = _getBookingsForDay(day).isNotEmpty;\n    final hijriColor = isSelected ? Colors.white : AppColors.heading;\n    final gregorianColor = isSelected ? Colors.white : AppColors.secondaryText;\n\n    BoxDecoration? decoration;\n    if (isSelected) {\n      decoration = const BoxDecoration(\n        color: AppColors.primary,\n        shape: BoxShape.circle,\n      );\n    } else if (isToday) {\n      decoration = BoxDecoration(\n        color: AppColors.selectedSurface,\n        shape: BoxShape.circle,\n        border: Border.all(color: AppColors.primary, width: 2),\n      );\n    } else if (hasBooking) {\n      decoration = BoxDecoration(\n        color: AppColors.warningSurface,\n        shape: BoxShape.circle,\n        border: Border.all(color: AppColors.warningText, width: 1.5),\n      );\n    }\n\n    final opacity = isOutside ? 0.55 : 1.0;"""
if old_calendar_colors in text:
    text = text.replace(old_calendar_colors, new_calendar_colors, 1)
else:
    raise RuntimeError('calendar color block not found')

# Replace scale-down date text with horizontal scrolling so accessibility text
# stays at its requested size rather than being silently shrunk.
for label in ('start_date', 'end_date'):
    prefix = 'من' if label == 'start_date' else 'إلى'
    old = f"""FittedBox(\n                        fit: BoxFit.scaleDown,\n                        alignment: AlignmentDirectional.centerStart,\n                        child: Text(\n                          '{prefix}: ${{_formatHijriDateOnlyArabic(booking['{label}'])}}',\n                          maxLines: 1,"""
    new = f"""SingleChildScrollView(\n                        scrollDirection: Axis.horizontal,\n                        child: Text(\n                          '{prefix}: ${{_formatHijriDateOnlyArabic(booking['{label}'])}}',\n                          maxLines: 1,\n                          softWrap: false,"""
    if old in text:
        text = text.replace(old, new, 1)
    # FittedBox and SingleChildScrollView both close with the same final child
    # parenthesis shape, so no closing-delimiter change is needed.

# Replace the archived-only color chip with a status that is always textual.
archived_block = """                          if (_bookingFilter == 'archived') ...[\n                            const SizedBox(width: 8),\n                            Container(\n                              padding: const EdgeInsets.symmetric(\n                                horizontal: 6,\n                                vertical: 2,\n                              ),\n                              decoration: BoxDecoration(\n                                color: AppColors.neutralSurface,\n                                borderRadius: BorderRadius.circular(6),\n                              ),\n                              child: Text(\n                                'مكتمل',\n                                style: TextStyle(\n                                  fontSize: 10.sp(context),\n                                  color: AppColors.secondaryText,\n                                  fontWeight: FontWeight.bold,\n                                ),\n                              ),\n                            ),\n                          ],"""
status_block = """                          const SizedBox(width: 8),\n                          _bookingStatusBadge(booking['status']?.toString()),"""
if archived_block in text:
    text = text.replace(archived_block, status_block, 1)
else:
    # The readable-floor migration may already have changed the 10.sp source;
    # handle that form too.
    alt = archived_block.replace('fontSize: 10.sp(context)', 'fontSize: 10.sp(context)')

status_helper_marker = """  // بناء قائمة الحجوزات العامة (مرتبة من الأحدث إلى الأقدم)\n  Widget _buildBookingsList()"""
status_helper = """  Widget _bookingStatusBadge(String? status) {\n    switch (status) {\n      case DatabaseHelper.statusConfirmed:\n        return const StatusBadge.success(label: 'مؤكد');\n      case DatabaseHelper.statusPending:\n        return const StatusBadge.warning(label: 'قيد الانتظار');\n      case DatabaseHelper.statusCancelled:\n        return const StatusBadge.error(label: 'ملغي');\n      default:\n        return const StatusBadge.neutral(label: 'غير محدد');\n    }\n  }\n\n  // بناء قائمة الحجوزات العامة (مرتبة من الأحدث إلى الأقدم)\n  Widget _buildBookingsList()"""
if status_helper_marker not in text:
    raise RuntimeError('booking status helper marker not found')
text = text.replace(status_helper_marker, status_helper, 1)

# Show total, paid and remaining values from the existing payment summary API.
old_total = """                      Text(\n                        '${booking['total_price']} ر.س',\n                        style: TextStyle(\n                          fontWeight: FontWeight.bold,\n                          color: AppColors.primary,\n                          fontSize: 12.sp(context),\n                        ),\n                      ),"""
new_total = """                      FutureBuilder<Map<String, double>>(\n                        future: dbHelper.queryPaymentSummary(booking['id'] as int),\n                        builder: (context, snapshot) {\n                          if (!snapshot.hasData) {\n                            return const SizedBox(\n                              width: 24,\n                              height: 24,\n                              child: CircularProgressIndicator(strokeWidth: 2),\n                            );\n                          }\n                          final summary = snapshot.data!;\n                          final remaining = summary['remaining']!;\n                          return Column(\n                            crossAxisAlignment: CrossAxisAlignment.end,\n                            children: [\n                              Text(\n                                'الإجمالي: ${summary['total']!.toStringAsFixed(2)} ر.س',\n                                style: Theme.of(context).textTheme.labelMedium,\n                              ),\n                              Text(\n                                'المسدد: ${summary['paid']!.toStringAsFixed(2)} ر.س',\n                                style: Theme.of(context).textTheme.labelMedium?.copyWith(\n                                      color: AppColors.successText,\n                                    ),\n                              ),\n                              Text(\n                                'المتبقي: ${remaining.toStringAsFixed(2)} ر.س',\n                                style: Theme.of(context).textTheme.labelMedium?.copyWith(\n                                      color: remaining > 0\n                                          ? AppColors.warningText\n                                          : AppColors.successText,\n                                    ),\n                              ),\n                            ],\n                          );\n                        },\n                      ),"""
if old_total in text:
    text = text.replace(old_total, new_total, 1)
else:
    raise RuntimeError('booking card total block not found')

booking.write_text(text, encoding='utf-8')

print('Applied Arabic UI consistency migration to:')
for page in PAGE_FILES:
    print(' -', page.relative_to(ROOT))
