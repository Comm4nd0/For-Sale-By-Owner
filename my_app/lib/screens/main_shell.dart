import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_theme.dart';
import '../models/notification_counts.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';
import 'dashboard_screen.dart';
import 'services_screen.dart';
import 'account_screen.dart';
import 'tools_screen.dart';
import 'login_screen.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  NotificationCounts? _notificationCounts;
  Timer? _notificationTimer;

  // Authenticated tabs: Home, Dashboard, Tools, Services, Account
  final List<Widget> _authTabs = const [
    HomeScreen(),
    DashboardScreen(),
    ToolsScreen(),
    ServicesScreen(),
    AccountScreen(),
  ];

  // Unauthenticated tabs: Home, Tools, Services, Login
  final List<Widget> _guestTabs = const [
    HomeScreen(),
    ToolsScreen(),
    ServicesScreen(),
    LoginScreen(embedded: true),
  ];

  @override
  void initState() {
    super.initState();
    _startNotificationPolling();
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    super.dispose();
  }

  void _startNotificationPolling() {
    _fetchNotificationCounts();
    _notificationTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _fetchNotificationCounts(),
    );
  }

  Future<void> _fetchNotificationCounts() async {
    final authService = context.read<AuthService>();
    if (!authService.isAuthenticated) return;

    try {
      final apiService = context.read<ApiService>();
      final counts = await apiService.getNotificationCounts();
      if (mounted) {
        setState(() => _notificationCounts = counts);
      }
    } catch (_) {
      // Silently fail for background polling
    }
  }

  void _onTabTapped(int index, bool isAuthenticated) {
    if (isAuthenticated && (index == 1 || index == 4)) {
      // Dashboard and Account require auth (already authenticated here)
    }
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final isAuthenticated = authService.isAuthenticated;
    final int badgeCount = isAuthenticated
        ? (_notificationCounts?.total ?? 0)
        : 0;

    final tabs = isAuthenticated ? _authTabs : _guestTabs;

    // Reset index if it's out of bounds after auth state change
    if (_currentIndex >= tabs.length) {
      _currentIndex = 0;
    }

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: tabs,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => _onTabTapped(index, isAuthenticated),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.forestMid,
        unselectedItemColor: AppTheme.stone,
        items: isAuthenticated
            ? [
                BottomNavigationBarItem(
                  icon: PhosphorIcon(PhosphorIconsDuotone.magnifyingGlass),
                  activeIcon: PhosphorIcon(PhosphorIconsDuotone.magnifyingGlass),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: badgeCount > 0
                      ? Badge(
                          label: Text('$badgeCount'),
                          child: PhosphorIcon(PhosphorIconsDuotone.squaresFour),
                        )
                      : PhosphorIcon(PhosphorIconsDuotone.squaresFour),
                  activeIcon: badgeCount > 0
                      ? Badge(
                          label: Text('$badgeCount'),
                          child: PhosphorIcon(PhosphorIconsDuotone.squaresFour),
                        )
                      : PhosphorIcon(PhosphorIconsDuotone.squaresFour),
                  label: 'Dashboard',
                ),
                BottomNavigationBarItem(
                  icon: PhosphorIcon(PhosphorIconsDuotone.calculator),
                  activeIcon: PhosphorIcon(PhosphorIconsDuotone.calculator),
                  label: 'Tools',
                ),
                BottomNavigationBarItem(
                  icon: PhosphorIcon(PhosphorIconsDuotone.wrench),
                  activeIcon: PhosphorIcon(PhosphorIconsDuotone.wrench),
                  label: 'Services',
                ),
                BottomNavigationBarItem(
                  icon: PhosphorIcon(PhosphorIconsDuotone.user),
                  activeIcon: PhosphorIcon(PhosphorIconsDuotone.user),
                  label: 'Account',
                ),
              ]
            : [
                BottomNavigationBarItem(
                  icon: PhosphorIcon(PhosphorIconsDuotone.magnifyingGlass),
                  activeIcon: PhosphorIcon(PhosphorIconsDuotone.magnifyingGlass),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: PhosphorIcon(PhosphorIconsDuotone.calculator),
                  activeIcon: PhosphorIcon(PhosphorIconsDuotone.calculator),
                  label: 'Tools',
                ),
                BottomNavigationBarItem(
                  icon: PhosphorIcon(PhosphorIconsDuotone.wrench),
                  activeIcon: PhosphorIcon(PhosphorIconsDuotone.wrench),
                  label: 'Services',
                ),
                BottomNavigationBarItem(
                  icon: PhosphorIcon(PhosphorIconsDuotone.signIn),
                  activeIcon: PhosphorIcon(PhosphorIconsDuotone.signIn),
                  label: 'Login',
                ),
              ],
      ),
    );
  }
}
