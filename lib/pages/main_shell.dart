import 'package:flutter/material.dart';

import '../ui/app_theme.dart';
import '../utils/responsive.dart';
import 'booking_manager_page.dart';
import 'finance_page.dart';
import 'settings_page.dart';
import 'ultimate_dashboard_page.dart';

class MainShellPage extends StatefulWidget {
  const MainShellPage({super.key});

  @override
  State<MainShellPage> createState() => _MainShellPageState();
}

class _Destination {
  const _Destination({
    required this.label,
    required this.title,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final String title;
  final IconData icon;
  final IconData selectedIcon;
}

class _MainShellPageState extends State<MainShellPage> {
  static const _destinations = <_Destination>[
    _Destination(
      label: 'لوحة التحكم',
      title: 'لوحة التحكم',
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard_rounded,
    ),
    _Destination(
      label: 'الحجوزات',
      title: 'إدارة الحجوزات والتقويم',
      icon: Icons.calendar_month_outlined,
      selectedIcon: Icons.calendar_month_rounded,
    ),
    _Destination(
      label: 'المالية',
      title: 'الملخص المالي والمصروفات',
      icon: Icons.account_balance_wallet_outlined,
      selectedIcon: Icons.account_balance_wallet_rounded,
    ),
    _Destination(
      label: 'الإعدادات',
      title: 'الإعدادات والنسخ الاحتياطي',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings_rounded,
    ),
  ];

  int _selectedIndex = 0;
  int _dbSessionId = 0;
  final Set<int> _visitedIndexes = {0};

  void _handleDatabaseRestored() {
    setState(() {
      _dbSessionId++;
    });
  }

  void _selectDestination(int index) {
    if (_selectedIndex == index) return;
    setState(() {
      _selectedIndex = index;
      _visitedIndexes.add(index);
    });
  }

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return UltimateDashboardPage(
          key: ValueKey('dashboard_$_dbSessionId'),
        );
      case 1:
        return BookingManagerPage(
          key: ValueKey('bookings_$_dbSessionId'),
        );
      case 2:
        return FinancePage(
          key: ValueKey('finance_$_dbSessionId'),
        );
      case 3:
        return SettingsPage(
          key: ValueKey('settings_$_dbSessionId'),
          onDatabaseRestored: _handleDatabaseRestored,
        );
      default:
        throw StateError('Unknown destination index: $index');
    }
  }

  Widget _buildPersistentPageStack() {
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var index = 0; index < _destinations.length; index++)
          if (_visitedIndexes.contains(index))
            Offstage(
              key: ValueKey('shell-destination-$index'),
              offstage: index != _selectedIndex,
              child: TickerMode(
                enabled: index == _selectedIndex,
                child: _buildPage(index),
              ),
            ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < Responsive.compactBreakpoint;
        final extendedRail = constraints.maxWidth >= 1180;

        return Scaffold(
          backgroundColor: AppColors.canvas,
          appBar: _buildAppBar(context, constraints.maxWidth),
          body: SafeArea(
            top: false,
            child: compact
                ? _buildPersistentPageStack()
                : Row(
                    children: [
                      _buildNavigationRail(extended: extendedRail),
                      const VerticalDivider(width: 1),
                      Expanded(child: _buildPersistentPageStack()),
                    ],
                  ),
          ),
          bottomNavigationBar: compact ? _buildNavigationBar() : null,
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, double width) {
    final destination = _destinations[_selectedIndex];
    final showResthouseName = width >= 390;

    return AppBar(
      toolbarHeight: width < 600 ? 64 : 68,
      titleSpacing: width < 600 ? 16 : 24,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            destination.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (width >= 600)
            Text(
              'إدارة يومية واضحة للحجوزات والعمليات المالية',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
      actions: [
        Padding(
          padding: EdgeInsetsDirectional.only(
            end: width < 600 ? 10 : 20,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.surfaceSubtle,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: 10,
                vertical: 7,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.holiday_village_outlined,
                    size: 20,
                    color: AppColors.primary,
                  ),
                  if (showResthouseName) ...[
                    const SizedBox(width: 7),
                    Text(
                      'استراحة نوره',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: AppColors.textPrimary,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(),
      ),
    );
  }

  Widget _buildNavigationBar() {
    return NavigationBar(
      selectedIndex: _selectedIndex,
      onDestinationSelected: _selectDestination,
      destinations: [
        for (final destination in _destinations)
          NavigationDestination(
            icon: Icon(destination.icon),
            selectedIcon: Icon(destination.selectedIcon),
            label: destination.label,
            tooltip: destination.title,
          ),
      ],
    );
  }

  Widget _buildNavigationRail({required bool extended}) {
    return NavigationRail(
      selectedIndex: _selectedIndex,
      onDestinationSelected: _selectDestination,
      extended: extended,
      minWidth: 76,
      minExtendedWidth: 240,
      groupAlignment: -1,
      labelType:
          extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
      leading: Padding(
        padding: const EdgeInsetsDirectional.only(top: 12, bottom: 18),
        child: extended
            ? Container(
                width: 208,
                padding: const EdgeInsetsDirectional.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFCCFBF1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.home_work_outlined,
                      color: AppColors.primary,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'لوحة الإدارة',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : const Icon(
                Icons.home_work_outlined,
                color: AppColors.primary,
              ),
      ),
      destinations: [
        for (final destination in _destinations)
          NavigationRailDestination(
            icon: Icon(destination.icon),
            selectedIcon: Icon(destination.selectedIcon),
            label: Text(destination.label),
            padding: const EdgeInsetsDirectional.symmetric(vertical: 4),
          ),
      ],
    );
  }
}
