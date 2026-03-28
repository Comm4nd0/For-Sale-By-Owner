import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_theme.dart';
import '../widgets/branded_app_bar.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'my_listings_screen.dart';
import 'saved_properties_screen.dart';
import 'profile_screen.dart';
import 'buyer_profile_screen.dart';
import 'buyer_verification_screen.dart';
import 'two_factor_screen.dart';
import 'conveyancing_screen.dart';
import 'board_order_screen.dart';
import 'solicitor_quotes_screen.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

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
                  child: PhosphorIcon(PhosphorIconsDuotone.user, size: 44, color: AppTheme.forestMid),
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
                    icon: PhosphorIconsDuotone.tag,
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
                    icon: PhosphorIconsDuotone.heart,
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

            // Buyer section
            _buildSectionTitle('Buyer Tools'),
            const SizedBox(height: 8),
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  _buildMenuTile(
                    icon: PhosphorIconsDuotone.userFocus,
                    title: 'Buyer Profile',
                    subtitle: 'Budget, mortgage, and preferences',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const BuyerProfileScreen()),
                    ),
                  ),
                  const Divider(height: 1, indent: 56),
                  _buildMenuTile(
                    icon: PhosphorIconsDuotone.shieldCheck,
                    title: 'Buyer Verification',
                    subtitle: 'Upload proof of funds or mortgage AIP',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const BuyerVerificationScreen()),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Selling Tools section
            _buildSectionTitle('Selling Tools'),
            const SizedBox(height: 8),
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  _buildMenuTile(
                    icon: PhosphorIconsDuotone.gavel,
                    title: 'Conveyancing',
                    subtitle: 'Track your sale or purchase progress',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ConveyancingScreen()),
                    ),
                  ),
                  const Divider(height: 1, indent: 56),
                  _buildMenuTile(
                    icon: PhosphorIconsDuotone.fileText,
                    title: 'Solicitor Quotes',
                    subtitle: 'Get and compare conveyancer quotes',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SolicitorQuotesScreen()),
                    ),
                  ),
                  const Divider(height: 1, indent: 56),
                  _buildMenuTile(
                    icon: PhosphorIconsDuotone.signpost,
                    title: 'For Sale Boards',
                    subtitle: 'Order a physical For Sale board',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const BoardOrderScreen()),
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
                    icon: PhosphorIconsDuotone.user,
                    title: 'Profile',
                    subtitle: 'Edit your name, phone and password',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ProfileScreen()),
                    ),
                  ),
                  const Divider(height: 1, indent: 56),
                  _buildMenuTile(
                    icon: PhosphorIconsDuotone.shieldCheck,
                    title: 'Two-Factor Authentication',
                    subtitle: 'Add extra security to your account',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const TwoFactorScreen()),
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
                icon: PhosphorIcon(PhosphorIconsDuotone.signOut),
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
    required PhosphorIconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: PhosphorIcon(icon, color: AppTheme.forestMid),
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 13, color: AppTheme.slate),
      ),
      trailing: PhosphorIcon(PhosphorIconsDuotone.caretRight, color: AppTheme.stone),
      onTap: onTap,
    );
  }
}
