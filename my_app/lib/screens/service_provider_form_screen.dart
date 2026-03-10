import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_theme.dart';
import '../widgets/branded_app_bar.dart';
import '../models/service_category.dart';
import '../services/api_service.dart';

class ServiceProviderFormScreen extends StatefulWidget {
  const ServiceProviderFormScreen({super.key});

  @override
  State<ServiceProviderFormScreen> createState() =>
      _ServiceProviderFormScreenState();
}

class _ServiceProviderFormScreenState extends State<ServiceProviderFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _websiteController = TextEditingController();
  final _pricingController = TextEditingController();
  final _yearsController = TextEditingController();
  final _countiesController = TextEditingController();
  final _postcodesController = TextEditingController();

  List<ServiceCategory> _categories = [];
  Set<int> _selectedCategoryIds = {};
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _websiteController.dispose();
    _pricingController.dispose();
    _yearsController.dispose();
    _countiesController.dispose();
    _postcodesController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    try {
      final apiService = context.read<ApiService>();
      final cats = await apiService.getServiceCategories();
      if (mounted) setState(() {
        _categories = cats;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one category')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final apiService = context.read<ApiService>();
      final body = <String, dynamic>{
        'business_name': _nameController.text,
        'description': _descController.text,
        'contact_email': _emailController.text,
        'contact_phone': _phoneController.text,
        'website': _websiteController.text,
        'pricing_info': _pricingController.text,
        'coverage_counties': _countiesController.text,
        'coverage_postcodes': _postcodesController.text,
        'category_ids': _selectedCategoryIds.toList(),
      };
      final years = int.tryParse(_yearsController.text);
      if (years != null) body['years_established'] = years;

      await apiService.createServiceProvider(body);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Service registered successfully!')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }

    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BrandedAppBar.build(context: context, showHomeButton: true),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Business info
                    const Text('Business Information',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.forestDeep)),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nameController,
                      decoration:
                          const InputDecoration(labelText: 'Business Name *'),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descController,
                      decoration: const InputDecoration(
                        labelText: 'Description *',
                        alignLabelWithHint: true,
                      ),
                      maxLines: 4,
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    // Categories
                    const Text('Categories *',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.slate)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _categories.map((cat) {
                        final selected =
                            _selectedCategoryIds.contains(cat.id);
                        return FilterChip(
                          label: Text(cat.name),
                          selected: selected,
                          onSelected: (val) {
                            setState(() {
                              if (val) {
                                _selectedCategoryIds.add(cat.id);
                              } else {
                                _selectedCategoryIds.remove(cat.id);
                              }
                            });
                          },
                          selectedColor: AppTheme.forestMid,
                          labelStyle: TextStyle(
                            color: selected
                                ? Colors.white
                                : AppTheme.forestDeep,
                            fontSize: 13,
                          ),
                          checkmarkColor: Colors.white,
                          backgroundColor: AppTheme.forestMist,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _yearsController,
                            decoration: const InputDecoration(
                                labelText: 'Years Established'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _pricingController,
                      decoration: const InputDecoration(
                        labelText: 'Pricing Information',
                        alignLabelWithHint: true,
                      ),
                      maxLines: 3,
                    ),

                    const SizedBox(height: 24),
                    const Text('Contact Information',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.forestDeep)),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailController,
                      decoration:
                          const InputDecoration(labelText: 'Contact Email *'),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneController,
                      decoration:
                          const InputDecoration(labelText: 'Contact Phone'),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _websiteController,
                      decoration: const InputDecoration(labelText: 'Website'),
                      keyboardType: TextInputType.url,
                    ),

                    const SizedBox(height: 24),
                    const Text('Coverage Area',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.forestDeep)),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _countiesController,
                      decoration: const InputDecoration(
                        labelText: 'Counties',
                        helperText: 'Comma-separated, e.g. Gloucestershire, Oxfordshire',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _postcodesController,
                      decoration: const InputDecoration(
                        labelText: 'Postcode Prefixes',
                        helperText: 'Comma-separated, e.g. GL, OX, SN',
                      ),
                    ),

                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Register Service',
                              style: TextStyle(fontSize: 16)),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }
}
