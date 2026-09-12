from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
PAGE_FILES = [
    ROOT / 'lib/pages/booking_manager_page.dart',
    ROOT / 'lib/pages/finance_page.dart',
    ROOT / 'lib/pages/ultimate_dashboard_page.dart',
    ROOT / 'lib/pages/settings_page.dart',
]

COLOR_MAP = {
    'F8FAFC': 'AppColors.background',
    'FFFFFF': 'AppColors.surface',
    '111827': 'AppColors.text',
    '0F172A': 'AppColors.heading',
    '1E293B': 'AppColors.heading',
    '334155': 'AppColors.secondaryText',
    '475569': 'AppColors.secondaryText',
    '0F766E': 'AppColors.primary',
    '0D9488': 'AppColors.primary',
    '115E59': 'AppColors.primaryPressed',
    'CCFBF1': 'AppColors.selectedSurface',
    'D1D9E0': 'AppColors.divider',
    '64748B': 'AppColors.fieldBorder',
    '166534': 'AppColors.successText',
    'DCFCE7': 'AppColors.successSurface',
    '059669': 'AppColors.successText',
    '92400E': 'AppColors.warningText',
    'FEF3C7': 'AppColors.warningSurface',
    'FFF7ED': 'AppColors.warningSurface',
    'D97706': 'AppColors.warningText',
    'FBBF24': 'AppColors.warningText',
    'B91C1C': 'AppColors.errorText',
    'FEE2E2': 'AppColors.errorSurface',
    'DC2626': 'AppColors.errorText',
    '991B1B': 'AppColors.primaryPressed',
    'E2E8F0': 'AppColors.neutralSurface',
    'F0FDFA': 'AppColors.selectedSurface',
    'F1F5F9': 'AppColors.background',
}

SHADE_REPLACEMENTS = {
    'Colors.grey.shade50': 'AppColors.background',
    'Colors.grey.shade100': 'AppColors.background',
    'Colors.grey.shade200': 'AppColors.divider',
    'Colors.grey.shade300': 'AppColors.divider',
    'Colors.grey.shade400': 'AppColors.fieldBorder',
    'Colors.grey.shade500': 'AppColors.secondaryText',
    'Colors.grey.shade600': 'AppColors.secondaryText',
    'Colors.grey.shade700': 'AppColors.secondaryText',
    'Colors.grey.shade800': 'AppColors.text',
    'Colors.grey.shade900': 'AppColors.heading',
    'Colors.red.shade50': 'AppColors.errorSurface',
    'Colors.red.shade100': 'AppColors.errorSurface',
    'Colors.red.shade200': 'AppColors.errorText',
    'Colors.red.shade600': 'AppColors.errorText',
    'Colors.red.shade700': 'AppColors.errorText',
    'Colors.red.shade800': 'AppColors.errorText',
    'Colors.red.shade900': 'AppColors.errorText',
    'Colors.green.shade50': 'AppColors.successSurface',
    'Colors.green.shade100': 'AppColors.successSurface',
    'Colors.green.shade600': 'AppColors.successText',
    'Colors.green.shade700': 'AppColors.successText',
    'Colors.green.shade800': 'AppColors.successText',
    'Colors.orange.shade50': 'AppColors.warningSurface',
    'Colors.orange.shade100': 'AppColors.warningSurface',
    'Colors.orange.shade600': 'AppColors.warningText',
    'Colors.orange.shade700': 'AppColors.warningText',
    'Colors.amber.shade50': 'AppColors.warningSurface',
    'Colors.amber.shade100': 'AppColors.warningSurface',
    'Colors.amber.shade600': 'AppColors.warningText',
    'Colors.amber.shade700': 'AppColors.warningText',
}

EXACT_COLOR_TOKENS = {
    'Colors.grey': 'AppColors.secondaryText',
    'Colors.red': 'AppColors.errorText',
    'Colors.green': 'AppColors.successText',
    'Colors.orange': 'AppColors.warningText',
    'Colors.amber': 'AppColors.warningText',
    'Colors.blue': 'AppColors.primaryPressed',
    'Colors.black54': 'AppColors.secondaryText',
    'Colors.white70': 'Colors.white',
}


def add_theme_import(text: str) -> str:
    line = "import '../theme/app_theme.dart';"
    if line in text:
        return text
    material = "import 'package:flutter/material.dart';"
    if material not in text:
        raise RuntimeError('material import not found')
    return text.replace(material, material + '\n\n' + line, 1)


def normalize_page(path: Path) -> None:
    text = add_theme_import(path.read_text(encoding='utf-8'))

    # Replace both `const Color(...)` and `Color(...)` so values inside an
    # already-const parent are centralized too.
    for hex_value, replacement in COLOR_MAP.items():
        text = re.sub(
            rf'(?:const\s+)?Color\(0xFF{hex_value}\)',
            replacement,
            text,
        )

    for old, new in SHADE_REPLACEMENTS.items():
        text = text.replace(old, new)
    for old, new in EXACT_COLOR_TOKENS.items():
        text = re.sub(rf'{re.escape(old)}(?!\.)', new, text)

    text = text.replace('Alignment.centerLeft', 'AlignmentDirectional.centerStart')
    text = text.replace('Alignment.centerRight', 'AlignmentDirectional.centerEnd')
    text = text.replace('Alignment.topLeft', 'AlignmentDirectional.topStart')
    text = text.replace('Alignment.topRight', 'AlignmentDirectional.topEnd')
    text = text.replace('EdgeInsets.fromLTRB(', 'EdgeInsetsDirectional.fromSTEB(')

    # Direct legacy sizes below 13 are raised. Sizes using `.sp(context)` are
    # protected by Responsive.sp's readable floor and still honor TextScaler.
    text = re.sub(
        r'fontSize:\s*(?:8|9|10|11|12)(?:\.0)?\s*,',
        'fontSize: 13,',
        text,
    )

    # Allow dialogs to remain usable with the keyboard, short windows and 200%
    # accessibility text. Existing scrollable dialogs are left untouched.
    text = re.sub(
        r'AlertDialog\(\n(?!\s*scrollable:)',
        'AlertDialog(\n          scrollable: true,',
        text,
    )

    # Old icon buttons explicitly removed Material's minimum target size.
    text = text.replace(
        'constraints: const BoxConstraints(),',
        'constraints: const BoxConstraints(minWidth: 48, minHeight: 48),',
    )

    # Keep Saudi phone numbers visually LTR inside the Arabic UI.
    text = text.replace(
        'keyboardType: TextInputType.phone,',
        'keyboardType: TextInputType.phone,\n                textDirection: TextDirection.ltr,',
    )

    path.write_text(text, encoding='utf-8')


for page in PAGE_FILES:
    normalize_page(page)

booking = ROOT / 'lib/pages/booking_manager_page.dart'
text = booking.read_text(encoding='utf-8')

# The legacy booking screen is a two-pane desktop composition. On phones and
# 800dp tablets, make the whole composition pannable rather than letting Flex
# children overflow or clip. At 900dp+ it uses the full available width.
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

# Selected, current and booked days are visually distinct. Booked days also
# receive an event icon below, so color is not the only status cue.
calendar_pattern = re.compile(
    r'    Color hijriColor = isSelected.*?'
    r'    (?:double|final) opacity = isOutside \? 0\.4 : 1\.0;',
    re.S,
)
calendar_replacement = """    final hasBooking = _getBookingsForDay(day).isNotEmpty;\n    final hijriColor = isSelected ? Colors.white : AppColors.heading;\n    final gregorianColor = isSelected ? Colors.white : AppColors.secondaryText;\n\n    BoxDecoration? decoration;\n    if (isSelected) {\n      decoration = const BoxDecoration(\n        color: AppColors.primary,\n        shape: BoxShape.circle,\n      );\n    } else if (isToday) {\n      decoration = BoxDecoration(\n        color: AppColors.selectedSurface,\n        shape: BoxShape.circle,\n        border: Border.all(color: AppColors.primary, width: 2),\n      );\n    } else if (hasBooking) {\n      decoration = BoxDecoration(\n        color: AppColors.warningSurface,\n        shape: BoxShape.circle,\n        border: Border.all(color: AppColors.warningText, width: 1.5),\n      );\n    }\n\n    final opacity = isOutside ? 0.55 : 1.0;"""
text, calendar_count = calendar_pattern.subn(calendar_replacement, text, count=1)
if calendar_count != 1:
    raise RuntimeError('calendar color block not found')

marker_pattern = re.compile(
    r"markerBuilder: \(context, date, events\) \{\n"
    r"\s*if \(events\.isNotEmpty\) \{\n"
    r"\s*return Positioned\(.*?\n\s*\}\n"
    r"\s*return null;\n\s*\},",
    re.S,
)
marker_replacement = """markerBuilder: (context, date, events) {\n                                if (events.isNotEmpty) {\n                                  return const Positioned(\n                                    bottom: 1,\n                                    child: Icon(\n                                      Icons.event_available_outlined,\n                                      size: 12,\n                                      color: AppColors.warningText,\n                                    ),\n                                  );\n                                }\n                                return null;\n                              },"""
text, marker_count = marker_pattern.subn(marker_replacement, text, count=1)
if marker_count != 1:
    raise RuntimeError('calendar marker block not found')

# Never shrink booking dates with FittedBox; let the user pan the long date at
# the requested accessibility size.
for label, prefix in (('start_date', 'من'), ('end_date', 'إلى')):
    old = f"""FittedBox(\n                        fit: BoxFit.scaleDown,\n                        alignment: AlignmentDirectional.centerStart,\n                        child: Text(\n                          '{prefix}: ${{_formatHijriDateOnlyArabic(booking['{label}'])}}',\n                          maxLines: 1,"""
    new = f"""SingleChildScrollView(\n                        scrollDirection: Axis.horizontal,\n                        child: Text(\n                          '{prefix}: ${{_formatHijriDateOnlyArabic(booking['{label}'])}}',\n                          maxLines: 1,\n                          softWrap: false,"""
    if old not in text:
        raise RuntimeError(f'{label} FittedBox not found')
    text = text.replace(old, new, 1)

status_helper_marker = """  // بناء قائمة الحجوزات العامة (مرتبة من الأحدث إلى الأقدم)\n  Widget _buildBookingsList()"""
status_helper = """  Widget _bookingStatusBadge(String? status) {\n    switch (status) {\n      case DatabaseHelper.statusConfirmed:\n        return const StatusBadge.success(label: 'مؤكد');\n      case DatabaseHelper.statusPending:\n        return const StatusBadge.warning(label: 'قيد الانتظار');\n      case DatabaseHelper.statusCancelled:\n        return const StatusBadge.error(label: 'ملغي');\n      default:\n        return const StatusBadge.neutral(label: 'غير محدد');\n    }\n  }\n\n  // بناء قائمة الحجوزات العامة (مرتبة من الأحدث إلى الأقدم)\n  Widget _buildBookingsList()"""
if status_helper_marker not in text:
    raise RuntimeError('booking status helper marker not found')
text = text.replace(status_helper_marker, status_helper, 1)

# Expose total/paid/remaining on every booking card through the existing,
# cent-safe payment summary API. This changes presentation only.
old_total = """                      Text(\n                        '${booking['total_price']} ر.س',\n                        style: TextStyle(\n                          fontWeight: FontWeight.bold,\n                          color: AppColors.primary,\n                          fontSize: 12.sp(context),\n                        ),\n                      ),"""
new_total = """                      Align(\n                        alignment: AlignmentDirectional.centerEnd,\n                        child: _bookingStatusBadge(booking['status']?.toString()),\n                      ),\n                      const SizedBox(height: 8),\n                      FutureBuilder<Map<String, double>>(\n                        future: dbHelper.queryPaymentSummary(booking['id'] as int),\n                        builder: (context, snapshot) {\n                          if (!snapshot.hasData) {\n                            return const SizedBox(\n                              width: 24,\n                              height: 24,\n                              child: CircularProgressIndicator(strokeWidth: 2),\n                            );\n                          }\n                          final summary = snapshot.data!;\n                          final remaining = summary['remaining']!;\n                          return Column(\n                            crossAxisAlignment: CrossAxisAlignment.end,\n                            children: [\n                              Text(\n                                'الإجمالي: ${summary['total']!.toStringAsFixed(2)} ر.س',\n                                style: Theme.of(context).textTheme.labelMedium,\n                              ),\n                              Text(\n                                'المسدد: ${summary['paid']!.toStringAsFixed(2)} ر.س',\n                                style: Theme.of(context).textTheme.labelMedium?.copyWith(\n                                      color: AppColors.successText,\n                                    ),\n                              ),\n                              Text(\n                                'المتبقي: ${remaining.toStringAsFixed(2)} ر.س',\n                                style: Theme.of(context).textTheme.labelMedium?.copyWith(\n                                      color: remaining > 0\n                                          ? AppColors.warningText\n                                          : AppColors.successText,\n                                    ),\n                              ),\n                            ],\n                          );\n                        },\n                      ),"""
if old_total not in text:
    raise RuntimeError('booking card total block not found')
text = text.replace(old_total, new_total, 1)

# Search is not a data-entry form, but a persistent label still makes its
# purpose clear after the user types a query.
text = text.replace(
    "hintText: _showRentersTab\n                            ? 'ابحث بالاسم أو رقم الهاتف'\n                            : 'ابحث عن حجز بالاسم أو رقم الهاتف',",
    "labelText: 'بحث',\n                        hintText: _showRentersTab\n                            ? 'بالاسم أو رقم الهاتف'\n                            : 'عن حجز بالاسم أو رقم الهاتف',",
    1,
)

booking.write_text(text, encoding='utf-8')

print('Applied Arabic UI consistency migration to:')
for page in PAGE_FILES:
    print(' -', page.relative_to(ROOT))
