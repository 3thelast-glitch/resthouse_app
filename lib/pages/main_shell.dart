import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'booking_manager_page.dart';
import 'finance_page.dart';
import 'settings_page.dart';
import 'ultimate_dashboard_page.dart';

class MainShellPage extends StatefulWidget {
  const MainShellPage({super.key});

  @override
  State<MainShellPage> createState() => _MainShellPageState();
}

class _MainShellPageState extends State<MainShellPage> {
  int _selectedIndex = 0;
  int _dbSessionId = 0;

  void _handleDatabaseRestored() {
    setState(() => _dbSessionId++);
  }

  List<Widget> get _pages => [
        UltimateDashboardPage(key: ValueKey('dashboard_$_dbSessionId')),
        BookingManagerPage(key: ValueKey('bookings_$_dbSessionId')),
        FinancePage(key: ValueKey('finance_$_dbSessionId')),
        SettingsPage(
          key: ValueKey('settings_$_dbSessionId'),
          onDatabaseRestored: _handleDatabaseRestored,
        ),
      ];

  static const _titles = [
    'لوحة التحكم الإحصائية',
    'إدارة الحجوزات والتقويم',
    'الملخص المالي والمصروفات',
    'الإعدادات والنسخ الاحتياطي',
  ];

  static const _compactTitles = [
    'لوحة التحكم',
    'الحجوزات',
    'المالية',
    'الإعدادات',
  ];

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final textScaler = MediaQuery.textScalerOf(context);
    final isWide = width >= 900;
    final isCompact = width < 600;
    final isLargeText = textScaler.scale(14) >= 20;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: isLargeText ? 88 : 68,
        titleSpacing: 16,
        title: Text(
          isCompact ? _compactTitles[_selectedIndex] : _titles[_selectedIndex],
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (!isCompact)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.holiday_village_outlined, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    'استراحة نوره',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              ),
            )
          else
            const Padding(
              padding: EdgeInsetsDirectional.only(end: 8),
              child: Tooltip(
                message: 'استراحة نوره',
                child: Icon(Icons.holiday_village_outlined, color: Colors.white),
              ),
            ),
        ],
      ),
      body: isWide
          ? Row(
              children: [
                _buildSidebar(isLargeText: isLargeText),
                const VerticalDivider(width: 1),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _pages[_selectedIndex],
                  ),
                ),
              ],
            )
          : AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _pages[_selectedIndex],
            ),
      bottomNavigationBar: isWide
          ? null
          : NavigationBar(
              height: isLargeText ? 84 : 72,
              selectedIndex: _selectedIndex,
              labelBehavior: isLargeText
                  ? NavigationDestinationLabelBehavior.onlyShowSelected
                  : NavigationDestinationLabelBehavior.alwaysShow,
              onDestinationSelected: (index) {
                setState(() => _selectedIndex = index);
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: 'لوحة التحكم',
                ),
                NavigationDestination(
                  icon: Icon(Icons.calendar_month_outlined),
                  selectedIcon: Icon(Icons.calendar_month),
                  label: 'الحجوزات',
                ),
                NavigationDestination(
                  icon: Icon(Icons.account_balance_wallet_outlined),
                  selectedIcon: Icon(Icons.account_balance_wallet),
                  label: 'المالية',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: 'الإعدادات',
                ),
              ],
            ),
    );
  }

  Widget _buildSidebar({required bool isLargeText}) {
    return Container(
      width: isLargeText ? 290 : 260,
      color: AppColors.surface,
      padding: const EdgeInsetsDirectional.fromSTEB(12, 24, 12, 16),
      child: ListView(
        key: const ValueKey('mainSidebar'),
        primary: false,
        padding: EdgeInsets.zero,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(AppRadius.large),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'لوحة الإدارة',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'التحكم والمتابعة الفورية',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSidebarItem(
            index: 0,
            icon: Icons.dashboard_outlined,
            activeIcon: Icons.dashboard,
            label: 'لوحة التحكم العامة',
          ),
          const SizedBox(height: 8),
          _buildSidebarItem(
            index: 1,
            icon: Icons.calendar_month_outlined,
            activeIcon: Icons.calendar_month,
            label: 'إدارة الحجوزات والتقويم',
          ),
          const SizedBox(height: 8),
          _buildSidebarItem(
            index: 2,
            icon: Icons.account_balance_wallet_outlined,
            activeIcon: Icons.account_balance_wallet,
            label: 'الحسابات والمصروفات',
          ),
          const SizedBox(height: 8),
          _buildSidebarItem(
            index: 3,
            icon: Icons.settings_outlined,
            activeIcon: Icons.settings,
            label: 'إعدادات النظام والنسخ',
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(AppRadius.medium),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 20,
                  color: AppColors.primaryPressed,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'الإصدار 1.0.0 (تجريبي)',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    final isSelected = _selectedIndex == index;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _selectedIndex = index),
        borderRadius: BorderRadius.circular(AppRadius.medium),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsetsDirectional.symmetric(
            vertical: 12,
            horizontal: 16,
          ),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.selectedSurface : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.medium),
            border: Border.all(
              color: isSelected ? AppColors.primaryPressed : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? activeIcon : icon,
                color: isSelected
                    ? AppColors.primaryPressed
                    : AppColors.secondaryText,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: isSelected
                            ? AppColors.primaryPressed
                            : AppColors.text,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
