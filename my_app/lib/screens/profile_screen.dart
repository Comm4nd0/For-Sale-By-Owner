import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_theme.dart';
import '../widgets/branded_app_bar.dart';
import '../models/saved_search.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'services_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Profile form
  final _profileFormKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _profileLoading = true;
  bool _profileSaving = false;

  // Password form
  final _passwordFormKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _passwordChanging = false;

  // Saved searches
  List<SavedSearch> _savedSearches = [];
  bool _searchesLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadSavedSearches();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final apiService = context.read<ApiService>();
      final profile = await apiService.getProfile();
      if (mounted) {
        setState(() {
          _firstNameController.text = profile.firstName;
          _lastNameController.text = profile.lastName;
          _phoneController.text = profile.phone;
          _profileLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _profileLoading = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_profileFormKey.currentState!.validate()) return;

    setState(() => _profileSaving = true);

    try {
      final apiService = context.read<ApiService>();
      await apiService.updateProfile({
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'phone': _phoneController.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _profileSaving = false);
    }
  }

  Future<void> _changePassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;

    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    setState(() => _passwordChanging = true);

    try {
      final apiService = context.read<ApiService>();
      final success = await apiService.changePassword(
        _currentPasswordController.text,
        _newPasswordController.text,
        _confirmPasswordController.text,
      );

      if (mounted) {
        if (success) {
          _currentPasswordController.clear();
          _newPasswordController.clear();
          _confirmPasswordController.clear();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Password changed successfully')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Failed to change password. Check your current password.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _passwordChanging = false);
    }
  }

  Future<void> _loadSavedSearches() async {
    try {
      final apiService = context.read<ApiService>();
      final searches = await apiService.getSavedSearches();
      if (mounted) {
        setState(() {
          _savedSearches = searches;
          _searchesLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _searchesLoading = false);
      }
    }
  }

  Future<void> _toggleSearchAlerts(SavedSearch search, bool enabled) async {
    try {
      final apiService = context.read<ApiService>();
      await apiService.toggleSearchAlerts(search.id, enabled);
      _loadSavedSearches();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update alerts: $e')),
        );
      }
    }
  }

  Future<void> _deleteSavedSearch(SavedSearch search) async {
    try {
      final apiService = context.read<ApiService>();
      await apiService.deleteSavedSearch(search.id);
      setState(() {
        _savedSearches.removeWhere((s) => s.id == search.id);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete search: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();

    return Scaffold(
      appBar: BrandedAppBar.build(context: context),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Section 1: Edit Profile
            _buildSectionHeader('Edit Profile'),
            const SizedBox(height: 8),
            _buildProfileSection(),
            const SizedBox(height: 24),

            // Section 2: Change Password
            _buildSectionHeader('Change Password'),
            const SizedBox(height: 8),
            _buildPasswordSection(),
            const SizedBox(height: 24),

            // Section 3: Saved Searches
            _buildSectionHeader('Saved Searches'),
            const SizedBox(height: 8),
            _buildSavedSearchesSection(),
            const SizedBox(height: 24),

            // Services link
            Card(
              child: ListTile(
                leading: const Icon(Icons.handyman_outlined, color: AppTheme.forestMid),
                title: const Text('Local Services'),
                subtitle: const Text('Find or register a local service'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ServicesScreen()),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Section 4: Logout
            ElevatedButton(
              onPressed: () => authService.logout(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error,
              ),
              child: const Text('Logout'),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.forestDeep,
          ),
    );
  }

  Widget _buildProfileSection() {
    if (_profileLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Form(
      key: _profileFormKey,
      child: Column(
        children: [
          TextFormField(
            controller: _firstNameController,
            decoration: const InputDecoration(labelText: 'First Name'),
            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _lastNameController,
            decoration: const InputDecoration(labelText: 'Last Name'),
            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phoneController,
            decoration: const InputDecoration(labelText: 'Phone'),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _profileSaving ? null : _saveProfile,
              child: _profileSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save Changes'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordSection() {
    return Form(
      key: _passwordFormKey,
      child: Column(
        children: [
          TextFormField(
            controller: _currentPasswordController,
            decoration: const InputDecoration(labelText: 'Current Password'),
            obscureText: true,
            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _newPasswordController,
            decoration: const InputDecoration(labelText: 'New Password'),
            obscureText: true,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Required';
              if (v.length < 8) return 'Min 8 characters';
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _confirmPasswordController,
            decoration:
                const InputDecoration(labelText: 'Confirm New Password'),
            obscureText: true,
            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _passwordChanging ? null : _changePassword,
              child: _passwordChanging
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Change Password'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedSearchesSection() {
    if (_searchesLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_savedSearches.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Text(
            'No saved searches',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _savedSearches.length,
      itemBuilder: (context, index) {
        final search = _savedSearches[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        search.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      iconSize: 20,
                      onPressed: () => _deleteSavedSearch(search),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (search.location.isNotEmpty)
                      _buildCriteriaChip(search.location),
                    if (search.propertyType.isNotEmpty)
                      _buildCriteriaChip(search.propertyType),
                    if (search.minBedrooms != null)
                      _buildCriteriaChip('${search.minBedrooms}+ beds'),
                    if (search.minBathrooms != null)
                      _buildCriteriaChip('${search.minBathrooms}+ baths'),
                    if (search.minPrice != null)
                      _buildCriteriaChip(
                          'Min \u00A3${search.minPrice!.toStringAsFixed(0)}'),
                    if (search.maxPrice != null)
                      _buildCriteriaChip(
                          'Max \u00A3${search.maxPrice!.toStringAsFixed(0)}'),
                    if (search.epcRating.isNotEmpty)
                      _buildCriteriaChip('EPC: ${search.epcRating}'),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Email Alerts',
                        style: TextStyle(fontSize: 13)),
                    Switch(
                      value: search.emailAlerts,
                      onChanged: (value) =>
                          _toggleSearchAlerts(search, value),
                      activeColor: AppTheme.forestMid,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCriteriaChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.forestMist,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, color: AppTheme.forestDeep),
      ),
    );
  }
}
