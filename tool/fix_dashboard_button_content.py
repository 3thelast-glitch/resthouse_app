from pathlib import Path

path = Path('lib/pages/ultimate_dashboard_page.dart')
text = path.read_text(encoding='utf-8')
start_marker = "              // أزرار العمليات السريعة: صف مرن على الشاشات الواسعة،\n"
end_marker = "              const SizedBox(height: 16),\n"
start = text.find(start_marker)
if start < 0:
    raise SystemExit('quick action start marker not found')
end = text.find(end_marker, start)
if end < 0:
    raise SystemExit('quick action end marker not found')
replacement = '''              // أزرار العمليات السريعة: صف مرن على الشاشات الواسعة،
              // وعمود بعرض كامل على الهواتف أو عند تكبير النص.
              LayoutBuilder(
                builder: (context, constraints) {
                  final isLargeText =
                      MediaQuery.textScalerOf(context).scale(14) >= 20;
                  final stackActions = constraints.maxWidth < 520 || isLargeText;

                  Widget actionContent(IconData icon, String label) {
                    if (stackActions) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: 20),
                          const SizedBox(height: 4),
                          Text(label, textAlign: TextAlign.center),
                        ],
                      );
                    }
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 18),
                        const SizedBox(width: 8),
                        Text(label),
                      ],
                    );
                  }

                  final actions = <Widget>[
                    ElevatedButton(
                      onPressed: _showQuickAddBooking,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsetsDirectional.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: actionContent(Icons.add, 'تسجيل حجز سريع'),
                    ),
                    OutlinedButton(
                      onPressed: _showQuickAddExpense,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryPressed,
                        side: const BorderSide(color: AppColors.fieldBorder),
                        padding: const EdgeInsetsDirectional.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: actionContent(Icons.money, 'تسجيل مصروف سريع'),
                    ),
                    OutlinedButton(
                      onPressed: _showQuickAddRenter,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryPressed,
                        side: const BorderSide(color: AppColors.fieldBorder),
                        padding: const EdgeInsetsDirectional.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: actionContent(Icons.person_add_outlined, 'عميل جديد'),
                    ),
                  ];

                  if (stackActions) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var index = 0; index < actions.length; index++) ...[
                          if (index > 0) const SizedBox(height: 8),
                          SizedBox(width: double.infinity, child: actions[index]),
                        ],
                      ],
                    );
                  }

                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    children: actions,
                  );
                },
              ),
'''
path.write_text(text[:start] + replacement + text[end:], encoding='utf-8')
