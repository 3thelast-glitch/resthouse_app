from pathlib import Path

path = Path('lib/pages/ultimate_dashboard_page.dart')
text = path.read_text(encoding='utf-8')
old = '''              // أزرار العمليات السريعة (تلتف تلقائياً لتفادي الطفح)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  ElevatedButton.icon(
                    onPressed: _showQuickAddBooking,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('تسجيل حجز سريع'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _showQuickAddExpense,
                    icon: const Icon(Icons.money, size: 16),
                    label: const Text('تسجيل مصروف سريع'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _showQuickAddRenter,
                    icon: const Icon(Icons.person_add_outlined, size: 16),
                    label: const Text('عميل جديد'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),'''
new = '''              // أزرار العمليات السريعة: صف مرن على الشاشات الواسعة،
              // وعمود بعرض كامل على الهواتف أو عند تكبير النص.
              LayoutBuilder(
                builder: (context, constraints) {
                  final isLargeText =
                      MediaQuery.textScalerOf(context).scale(14) >= 20;
                  final stackActions = constraints.maxWidth < 520 || isLargeText;
                  final actions = <Widget>[
                    ElevatedButton.icon(
                      onPressed: _showQuickAddBooking,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('تسجيل حجز سريع'),
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
                    ),
                    OutlinedButton.icon(
                      onPressed: _showQuickAddExpense,
                      icon: const Icon(Icons.money, size: 18),
                      label: const Text('تسجيل مصروف سريع'),
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
                    ),
                    OutlinedButton.icon(
                      onPressed: _showQuickAddRenter,
                      icon: const Icon(Icons.person_add_outlined, size: 18),
                      label: const Text('عميل جديد'),
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
              ),'''
if old not in text:
    raise SystemExit('dashboard quick-actions block not found')
path.write_text(text.replace(old, new, 1), encoding='utf-8')
