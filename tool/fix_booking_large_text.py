from pathlib import Path

path = Path('lib/pages/booking_manager_page.dart')
text = path.read_text(encoding='utf-8')

# Give calendar cells enough physical height when the system font is enlarged.
old = """                              TableCalendar(\n                                firstDay: DateTime.utc(2020, 1, 1),"""
new = """                              TableCalendar(\n                                rowHeight:\n                                    MediaQuery.textScalerOf(context).scale(16) >= 20\n                                    ? 144\n                                    : 52,\n                                daysOfWeekHeight:\n                                    MediaQuery.textScalerOf(context).scale(14) >= 20\n                                    ? 64\n                                    : 32,\n                                firstDay: DateTime.utc(2020, 1, 1),"""
if old not in text:
    raise SystemExit('TableCalendar marker not found')
text = text.replace(old, new, 1)

# The selected-day heading must wrap instead of forcing a single wide Row.
old = """                      Row(\n                        children: [\n                          const Icon(\n                            Icons.bookmark_added_outlined,\n                            color: AppColors.primary,\n                          ),\n                          const SizedBox(width: 8),\n                          Text(\n                            _selectedDay == null\n                                ? 'الحجوزات اليومية'\n                                : 'الحجوزات في تاريخ ${_selectedDay.toString().split(' ')[0]}',\n                            style: TextStyle(\n                              fontWeight: FontWeight.bold,\n                              fontSize: 15.sp(context),\n                              color: AppColors.heading,\n                            ),\n                          ),\n                        ],\n                      ),"""
new = """                      Row(\n                        crossAxisAlignment: CrossAxisAlignment.start,\n                        children: [\n                          const Padding(\n                            padding: EdgeInsets.only(top: 4),\n                            child: Icon(\n                              Icons.bookmark_added_outlined,\n                              color: AppColors.primary,\n                            ),\n                          ),\n                          const SizedBox(width: 8),\n                          Expanded(\n                            child: Text(\n                              _selectedDay == null\n                                  ? 'الحجوزات اليومية'\n                                  : 'الحجوزات في تاريخ ${_selectedDay.toString().split(' ')[0]}',\n                              style: TextStyle(\n                                fontWeight: FontWeight.bold,\n                                fontSize: 15.sp(context),\n                                color: AppColors.heading,\n                              ),\n                            ),\n                          ),\n                        ],\n                      ),"""
if old not in text:
    raise SystemExit('selected-day heading block not found')
text = text.replace(old, new, 1)

# Empty-state content must remain reachable on short windows and large text.
start = text.find('  Widget _buildDirectoryEmptyState() {')
end = text.find('\n  Future<void> _showPaymentActions', start)
if start < 0 or end < 0:
    raise SystemExit('directory empty-state markers not found')
replacement = '''  Widget _buildDirectoryEmptyState() {\n    return SingleChildScrollView(\n      padding: const EdgeInsets.all(24),\n      child: Center(\n        child: Column(\n          mainAxisSize: MainAxisSize.min,\n          children: [\n            const Icon(\n              Icons.people_outline,\n              size: 44,\n              color: AppColors.primary,\n            ),\n            const SizedBox(height: 12),\n            Text(\n              'لا توجد حجوزات أو مستأجرون بعد',\n              textAlign: TextAlign.center,\n              style: TextStyle(\n                fontWeight: FontWeight.bold,\n                fontSize: 15.sp(context),\n                color: AppColors.heading,\n              ),\n            ),\n            const SizedBox(height: 8),\n            Text(\n              'استخدم أزرار الإضافة لإدخال بياناتك. ستظهر القوائم هنا بعد حفظ أول مستأجر أو حجز.',\n              textAlign: TextAlign.center,\n              style: TextStyle(\n                color: AppColors.secondaryText,\n                height: 1.45,\n                fontSize: 12.sp(context),\n              ),\n            ),\n          ],\n        ),\n      ),\n    );\n  }\n'''
text = text[:start] + replacement + text[end:]

path.write_text(text, encoding='utf-8')
