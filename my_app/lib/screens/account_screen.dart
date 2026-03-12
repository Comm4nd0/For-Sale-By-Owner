import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_theme.dart';
import '../widgets/branded_app_bar.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'my_listings_screen.dart';
import 'saved_properties_screen.dart';
import 'profile_screen.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  String _firstName = '';
  String _lastName = '';
  String _email = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final authService = context.read<AuthService>();
    if (authService.isAuthenticated) {
      _loadProfile();
    } else {
      _loading = false;
    }
  }

  Future<void> _loadProfile() async {
    try {
      final apiService = context.read<ApiService>();
      final profile = await apiService.getProfile();
      if (mounted) {
        setState(() {
          _firstName = profile.firstName;
          _lastName = profile.lastName;
          _email = profile.email;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String get _initials {
    final first = _firstName.isNotEmpty ? _firstName[0] : '';
    final last = _lastName.isNotEmpty ? _lastName[0] : '';
    return '$first$last'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();

    if (!authService.isAuthenticated) {
      return Scaffold(
        appBar: BrandedAppBar.build(context: context),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: AppTheme.forestMist,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(Icons.person_outline, size: 44, color: AppTheme.forestMid),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Login Required',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.charcoal,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please log in to access your account.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.slate, height: 1.5),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: BrandedAppBar.build(context: context),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // User greeting
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.forestMist,
                borderRadius: BorderRadius.circular(12),
              ),
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: AppTheme.forestMid,
                          child: Text(
                            _initials,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _firstName.isNotEmpty
                                    ? 'Hi, $_firstName'
                                    : 'My Account',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.charcoal,
                                ),
                              ),
                              if (_email.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    _email,
                                    style: const TextStyle(
                                      color: AppTheme.slate,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),

            const SizedBox(height: 20),

            // Your Properties section
            _buildSectionTitle('Your Properties'),
            const SizedBox(height: 8),
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  _buildMenuTile(
                    icon: Icons.sell_outlined,
                    title: 'My Listings',
                    subtitle: 'Manage your property listings',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const MyListingsScreen()),
                    ),
                  ),
                  const Divider(height: 1, indent: 56),
                  _buildMenuTile(
                    icon: Icons.favorite_border,
                    title: 'Saved Properties',
                    subtitle: 'Properties you have saved',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SavedPropertiesScreen()),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Settings section
            _buildSectionTitle('Settings'),
            const SizedBox(height: 8),
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  _buildMenuTile(
                    icon: Icons.person_outline,
                    title: 'Profile',
                    subtitle: 'Edit your name, phone and password',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ProfileScreen()),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Logout
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => authService.logout(),
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.error,
                  side: const BorderSide(color: AppTheme.error),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.forestDeep,
          ),
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.forestMid),
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 13, color: AppTheme.slate),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppTheme.stone),
      onTap: onTap,
    );
  }
}
