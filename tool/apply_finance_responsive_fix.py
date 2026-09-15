from pathlib import Path


def replace_between(text: str, start: str, end: str, replacement: str) -> str:
    a = text.index(start)
    b = text.index(end, a)
    return text[:a] + replacement + text[b:]

finance = Path('lib/pages/finance_page.dart')
text = finance.read_text(encoding='utf-8')

start = """        // Row 1: Title + Year dropdown + Comparison toggle\n        Row(\n"""
end = """        const SizedBox(height: 12),\n        // Row 2: Full Year chip + Month chips\n"""
replacement = r'''        LayoutBuilder(
          builder: (context, constraints) {
            final stacked =
                constraints.maxWidth < 680 || Responsive.hasLargeText(context);

            Widget yearDropdown({
              required int value,
              required Color color,
              required ValueChanged<int?> onChanged,
            }) {
              return Container(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: color.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withAlpha(60)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: value,
                    icon: Icon(Icons.keyboard_arrow_down, color: color, size: 20),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                    items: _getYearRange().map((year) {
                      return DropdownMenuItem<int>(
                        value: year,
                        child: Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text('$year'),
                        ),
                      );
                    }).toList(),
                    onChanged: onChanged,
                  ),
                ),
              );
            }

            final filterControls = Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                yearDropdown(
                  value: _selectedYear,
                  color: AppColors.primary,
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedYear = value;
                        _applyFilter();
                      });
                    }
                  },
                ),
                FilterChip(
                  label: Text(
                    'مقارنة مالية',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: _showComparison
                          ? Colors.white
                          : const Color(0xFF6366F1),
                    ),
                  ),
                  avatar: Icon(
                    Icons.compare_arrows,
                    size: 16,
                    color: _showComparison
                        ? Colors.white
                        : const Color(0xFF6366F1),
                  ),
                  selected: _showComparison,
                  selectedColor: const Color(0xFF6366F1),
                  backgroundColor: const Color(0xFF6366F1).withAlpha(20),
                  checkmarkColor: Colors.white,
                  onSelected: (value) => setState(() => _showComparison = value),
                ),
                if (_showComparison)
                  Text(
                    'مقابل',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.secondaryText,
                    ),
                  ),
                if (_showComparison)
                  yearDropdown(
                    value: _comparisonYear,
                    color: const Color(0xFF6366F1),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _comparisonYear = value);
                      }
                    },
                  ),
              ],
            );

            final title = Text(
              'التقرير المالي للعمليات',
              style: Theme.of(context).textTheme.titleMedium,
            );

            if (stacked) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  title,
                  const SizedBox(height: AppSpacing.xs),
                  filterControls,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: title),
                const SizedBox(width: AppSpacing.sm),
                Flexible(child: filterControls),
              ],
            );
          },
        ),
'''
text = replace_between(text, start, end, replacement)

text = text.replace(
    """        SizedBox(\n          height: 38,\n          child: ListView(\n""",
    """        SizedBox(\n          height: Responsive.hasLargeText(context) ? 64 : 48,\n          child: ListView(\n""",
    1,
)

text = text.replace(
    """          final isWide = constraints.maxWidth >= 950;\n""",
    """          final isWide =\n              constraints.maxWidth >= 950 && !Responsive.hasLargeText(context);\n""",
    1,
)

sub_start = """  Widget _buildSubTabSelector() {\n"""
sub_end = """  Widget _buildReportTabContent(bool isWide) {\n"""
sub_replacement = r'''  Widget _buildSubTabSelector() {
    Widget tab({required int index, required String label}) {
      final selected = _activeTab == index;
      return Material(
        color: selected ? AppColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => setState(() => _activeTab = index),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            alignment: Alignment.center,
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              softWrap: true,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: selected ? Colors.white : AppColors.secondaryText,
              ),
            ),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stacked =
                constraints.maxWidth < 520 || Responsive.hasLargeText(context);
            final report = tab(index: 0, label: 'التقرير والتحليل المالي العام');
            final comparison = tab(index: 1, label: 'المقارنة المالية المتقدمة');
            if (stacked) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  report,
                  const SizedBox(height: AppSpacing.xs),
                  comparison,
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: report),
                const SizedBox(width: AppSpacing.xs),
                Expanded(child: comparison),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildFinanceSummaryGrid(double netIncome) {
    final cards = <Widget>[
      _buildCard('إجمالي مبالغ الإيجار', _totalRevenue, const Color(0xFF10B981), Icons.monetization_on_outlined),
      _buildCard('التأمينات المعلقة', _totalSecurityDeposit, const Color(0xFF0284C7), Icons.security_outlined),
      _buildCard('إجمالي المصروفات', _totalExpenses, const Color(0xFFEF4444), Icons.arrow_downward),
      _buildCard('صافي الأرباح', netIncome, netIncome >= 0 ? AppColors.primary : AppColors.errorText, Icons.account_balance),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = Responsive.textScale(context);
        final minWidth = scale >= 1.5 ? 280.0 : scale >= 1.3 ? 220.0 : 180.0;
        final columns = Responsive.columnCountForWidth(
          constraints.maxWidth,
          minItemWidth: minWidth,
          maxColumns: 4,
        );
        final width = Responsive.itemWidthForColumns(
          constraints.maxWidth,
          columns: columns,
        );
        return Wrap(
          spacing: Responsive.gap,
          runSpacing: Responsive.gap,
          children: [for (final card in cards) SizedBox(width: width, child: card)],
        );
      },
    );
  }

'''
text = replace_between(text, sub_start, sub_end, sub_replacement)

sum_start = """        if (isWide)\n          Row(\n"""
sum_end = """        const SizedBox(height: 24),\n"""
a = text.index(sum_start, text.index("Widget _buildReportTabContent"))
b = text.index(sum_end, a)
text = text[:a] + "        _buildFinanceSummaryGrid(netIncome),\n" + text[b:]

header_start = """            Row(\n              children: [\n                const Icon(Icons.compare_arrows, color: AppColors.primary),\n"""
header_end = """            const Divider(height: 24),\n"""
header_replacement = r'''            LayoutBuilder(
              builder: (context, constraints) {
                final stacked =
                    constraints.maxWidth < 620 || Responsive.hasLargeText(context);
                final heading = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.compare_arrows, color: AppColors.primary),
                    const SizedBox(width: AppSpacing.xs),
                    Flexible(
                      child: Text(
                        'تحديد خيارات المقارنة',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                  ],
                );
                final types = Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    _buildComparisonTypeButton('months', 'مقارنة بين الأشهر'),
                    _buildComparisonTypeButton('years', 'مقارنة بين السنوات'),
                  ],
                );
                if (stacked) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      heading,
                      const SizedBox(height: AppSpacing.xs),
                      types,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: heading),
                    const SizedBox(width: AppSpacing.sm),
                    types,
                  ],
                );
              },
            ),
'''
text = replace_between(text, header_start, header_end, header_replacement)

years_old = r'''              Row(
                children: [
                  const Text(
                    'السنة الأولى: ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.secondaryText,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildDropdown<int>(
                    value: _compYear1,
                    items: _getYearRange(),
                    onChanged: (val) {
                      if (val != null) setState(() => _compYear1 = val);
                    },
                  ),
                  const SizedBox(width: 32),
                  const Text(
                    'السنة الثانية: ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.secondaryText,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildDropdown<int>(
                    value: _compYear2,
                    items: _getYearRange(),
                    onChanged: (val) {
                      if (val != null) setState(() => _compYear2 = val);
                    },
                  ),
                ],
              ),
'''
years_new = r'''              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('السنة الأولى:', style: Theme.of(context).textTheme.labelMedium),
                  _buildDropdown<int>(
                    value: _compYear1,
                    items: _getYearRange(),
                    onChanged: (val) {
                      if (val != null) setState(() => _compYear1 = val);
                    },
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text('السنة الثانية:', style: Theme.of(context).textTheme.labelMedium),
                  _buildDropdown<int>(
                    value: _compYear2,
                    items: _getYearRange(),
                    onChanged: (val) {
                      if (val != null) setState(() => _compYear2 = val);
                    },
                  ),
                ],
              ),
'''
if years_old not in text:
    raise RuntimeError('year comparison Row marker not found')
text = text.replace(years_old, years_new, 1)
finance.write_text(text, encoding='utf-8')

test = Path('test/responsive_layout_test.dart')
t = test.read_text(encoding='utf-8')
t = t.replace(
    "import 'package:resthouse_app/pages/booking_manager_page.dart';\n",
    "import 'package:resthouse_app/pages/booking_manager_page.dart';\n"
    "import 'package:resthouse_app/pages/finance_page.dart';\n"
    "import 'package:resthouse_app/pages/settings_page.dart';\n",
    1,
)
insert_marker = """Widget bookingTestApp() {\n"""
apps = r'''Widget financeTestApp() {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    locale: const Locale('ar', 'SA'),
    supportedLocales: const [Locale('ar', 'SA')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: const FinancePage(),
  );
}

Widget settingsTestApp() {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    locale: const Locale('ar', 'SA'),
    supportedLocales: const [Locale('ar', 'SA')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: SettingsPage(onDatabaseRestored: () {}),
  );
}

'''
t = t.replace(insert_marker, apps + insert_marker, 1)
end_marker = """  testWidgets('booking page reaches content below calendar on short phone', (\n"""
extra_tests = r'''  testWidgets('finance remains usable with seeded data and large text', (
    tester,
  ) async {
    const cases = <(Size, double)>[
      (Size(320, 800), 1.0),
      (Size(390, 844), 2.0),
      (Size(600, 850), 1.5),
      (Size(1024, 900), 1.0),
    ];
    for (final entry in cases) {
      final (size, scale) = entry;
      await tester.binding.setSurfaceSize(size);
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      await tester.pumpWidget(financeTestApp());
      await settleDatabaseUi(tester);
      expect(find.text('التقرير والتحليل المالي العام'), findsOneWidget);
      expect(find.text('إجمالي مبالغ الإيجار'), findsOneWidget);
      expectNoLayoutException(
        tester,
        'Finance overflow at ${size.width}x${size.height}, text scale $scale',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('settings remains readable at 320px and 200% text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 600));
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(() async {
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      await tester.binding.setSurfaceSize(null);
    });
    await tester.pumpWidget(settingsTestApp());
    await tester.pump();
    expect(find.text('إدارة البيانات والنسخ الاحتياطي'), findsOneWidget);
    expectNoLayoutException(
      tester,
      'Settings overflowed at 320x600 with 200% text scaling.',
    );
  });

'''
t = t.replace(end_marker, extra_tests + end_marker, 1)
test.write_text(t, encoding='utf-8')
