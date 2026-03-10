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
import 'login_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  NotificationCounts? _notificationCounts;
  Timer? _notificationTimer;

  final List<Widget> _tabs = const [
    HomeScreen(),
    DashboardScreen(),
    ServicesScreen(),
    AccountScreen(),
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

  void _onTabTapped(int index) {
    if (index == 1 || index == 3) {
      final authService = context.read<AuthService>();
      if (!authService.isAuthenticated) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        ).then((_) {
          final auth = context.read<AuthService>();
          if (auth.isAuthenticated) {
            setState(() => _currentIndex = index);
            _fetchNotificationCounts();
          }
        });
        return;
      }
    }
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final int badgeCount = authService.isAuthenticated
        ? (_notificationCounts?.total ?? 0)
        : 0;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _tabs,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.forestMid,
        unselectedItemColor: AppTheme.stone,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.search_outlined),
            activeIcon: Icon(Icons.search),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: badgeCount > 0
                ? Badge(
                    label: Text('$badgeCount'),
                    child: const Icon(Icons.dashboard_outlined),
                  )
                : const Icon(Icons.dashboard_outlined),
            activeIcon: badgeCount > 0
                ? Badge(
                    label: Text('$badgeCount'),
                    child: const Icon(Icons.dashboard),
                  )
                : const Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.handyman_outlined),
            activeIcon: Icon(Icons.handyman),
            label: 'Services',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Account',
          ),
        ],
      ),
    );
  }
}
