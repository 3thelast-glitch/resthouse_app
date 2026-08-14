import 'package:flutter/material.dart';
import '../utils/responsive.dart';
import 'ultimate_dashboard_page.dart';
import 'booking_manager_page.dart';
import 'finance_page.dart';
import 'settings_page.dart';

class MainShellPage extends StatefulWidget {
  const MainShellPage({super.key});

  @override
  State<MainShellPage> createState() => _MainShellPageState();
}

class _MainShellPageState extends State<MainShellPage> {
  int _selectedIndex = 0;
  int _dbSessionId = 0;

  void _handleDatabaseRestored() {
    setState(() {
      _dbSessionId++;
    });
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

  final List<String> _titles = [
    'لوحة التحكم الإحصائية',
    'إدارة الحجوزات والتقويم',
    'الملخص المالي والمصروفات',
    'الإعدادات والنسخ الاحتياطي',
  ];

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 750;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          _titles[_selectedIndex],
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 20.sp(context),
          ),
        ),
        centerTitle: false,
        backgroundColor: const Color(0xFF0F766E), // Teal 700
        elevation: 2,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.holiday_village_outlined, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  'استراحة نوره',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: isWide
          ? Row(
              children: [
                _buildSidebar(),
                const VerticalDivider(width: 1, thickness: 1, color: Color(0xFFE2E8F0)),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _pages[_selectedIndex],
                  ),
                ),
              ],
            )
          : AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _pages[_selectedIndex],
            ),
      bottomNavigationBar: isWide
          ? null
          : BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              selectedItemColor: const Color(0xFF0D9488),
              unselectedItemColor: Colors.grey.shade500,
              backgroundColor: Colors.white,
              elevation: 8,
              type: BottomNavigationBarType.fixed,
              selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.dashboard_outlined),
                  activeIcon: Icon(Icons.dashboard),
                  label: 'لوحة التحكم',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.calendar_month_outlined),
                  activeIcon: Icon(Icons.calendar_month),
                  label: 'الحجوزات',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.account_balance_wallet_outlined),
                  activeIcon: Icon(Icons.account_balance_wallet),
                  label: 'المالية',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.settings_outlined),
                  activeIcon: Icon(Icons.settings),
                  label: 'الإعدادات',
                ),
              ],
            ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 250,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header section inside sidebar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F766E), Color(0xFF0D9488)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'لوحة الإدارة',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16.sp(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'التحكم والمتابعة الفورية',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11.sp(context),
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
          const Spacer(),
          // Info Footer
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: Color(0xFF0D9488)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'الإصدار 1.0.0 (تجريبي)',
                    style: TextStyle(fontSize: 10.sp(context), color: Colors.grey),
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
        onTap: () {
          setState(() {
            _selectedIndex = index;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFECFDF5) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? activeIcon : icon,
                color: isSelected ? const Color(0xFF0D9488) : Colors.grey.shade600,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? const Color(0xFF0D9488) : Colors.grey.shade800,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 14.sp(context),
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
