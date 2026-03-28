import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_theme.dart';
import '../widgets/branded_app_bar.dart';
import '../models/property_feature.dart';
import '../services/api_service.dart';
import 'image_management_screen.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class CreatePropertyScreen extends StatefulWidget {
  const CreatePropertyScreen({super.key});

  @override
  State<CreatePropertyScreen> createState() => _CreatePropertyScreenState();
}

class _CreatePropertyScreenState extends State<CreatePropertyScreen> {
  int _currentStep = 0;
  bool _isSubmitting = false;

  // Form keys for each step
  final _basicFormKey = GlobalKey<FormState>();
  final _locationFormKey = GlobalKey<FormState>();
  final _detailsFormKey = GlobalKey<FormState>();

  // Step 0 - Basic Details
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  String _propertyType = 'detached';

  // Step 1 - Location
  final _addressLine1Controller = TextEditingController();
  final _addressLine2Controller = TextEditingController();
  final _cityController = TextEditingController();
  final _countyController = TextEditingController();
  final _postcodeController = TextEditingController();

  // Step 2 - Details
  int _bedrooms = 1;
  int _bathrooms = 1;
  int _receptionRooms = 1;
  final _sqftController = TextEditingController();
  String _epcRating = '';

  // Step 3 - Features
  List<PropertyFeature> _allFeatures = [];
  List<int> _selectedFeatureIds = [];
  bool _featuresLoading = true;

  // Step 4 - Review
  String _status = 'draft';

  @override
  void initState() {
    super.initState();
    _loadFeatures();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _addressLine1Controller.dispose();
    _addressLine2Controller.dispose();
    _cityController.dispose();
    _countyController.dispose();
    _postcodeController.dispose();
    _sqftController.dispose();
    super.dispose();
  }

  Future<void> _loadFeatures() async {
    try {
      final apiService = context.read<ApiService>();
      final features = await apiService.getFeatures();
      if (mounted) {
        setState(() {
          _allFeatures = features;
          _featuresLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _featuresLoading = false);
      }
    }
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _basicFormKey.currentState?.validate() ?? false;
      case 1:
        return _locationFormKey.currentState?.validate() ?? false;
      case 2:
        return _detailsFormKey.currentState?.validate() ?? false;
      case 3:
        return true;
      case 4:
        return true;
      default:
        return false;
    }
  }

  Future<void> _submitProperty() async {
    setState(() => _isSubmitting = true);

    try {
      final apiService = context.read<ApiService>();

      final body = <String, dynamic>{
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'property_type': _propertyType,
        'price': _priceController.text.trim(),
        'address_line_1': _addressLine1Controller.text.trim(),
        'address_line_2': _addressLine2Controller.text.trim(),
        'city': _cityController.text.trim(),
        'county': _countyController.text.trim(),
        'postcode': _postcodeController.text.trim(),
        'bedrooms': _bedrooms,
        'bathrooms': _bathrooms,
        'reception_rooms': _receptionRooms,
        'epc_rating': _epcRating,
        'status': _status,
        'features': _selectedFeatureIds,
      };

      if (_sqftController.text.isNotEmpty) {
        body['square_feet'] = int.tryParse(_sqftController.text.trim());
      }

      final property = await apiService.createProperty(body);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Property created! Add some photos.')),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ImageManagementScreen(property: property),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create property: $e')),
        );
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BrandedAppBar.build(context: context, showHomeButton: true),
      body: Stepper(
        type: StepperType.vertical,
        currentStep: _currentStep,
        onStepContinue: () {
          if (_validateCurrentStep()) {
            if (_currentStep < 4) {
              setState(() => _currentStep += 1);
            } else {
              _submitProperty();
            }
          }
        },
        onStepCancel: () {
          if (_currentStep > 0) {
            setState(() => _currentStep -= 1);
          }
        },
        onStepTapped: (step) {
          if (step < _currentStep) {
            setState(() => _currentStep = step);
          }
        },
        controlsBuilder: (context, details) {
          return Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Row(
              children: [
                if (_currentStep == 4)
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : details.onStepContinue,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Create Listing'),
                  )
                else
                  ElevatedButton(
                    onPressed: details.onStepContinue,
                    child: const Text('Continue'),
                  ),
                const SizedBox(width: 8),
                if (_currentStep > 0)
                  TextButton(
                    onPressed: details.onStepCancel,
                    child: const Text('Back'),
                  ),
              ],
            ),
          );
        },
        steps: [
          Step(
            title: const Text('Basic Details'),
            isActive: _currentStep >= 0,
            state: _currentStep > 0 ? StepState.complete : StepState.indexed,
            content: _buildBasicDetailsStep(),
          ),
          Step(
            title: const Text('Location'),
            isActive: _currentStep >= 1,
            state: _currentStep > 1 ? StepState.complete : StepState.indexed,
            content: _buildLocationStep(),
          ),
          Step(
            title: const Text('Details'),
            isActive: _currentStep >= 2,
            state: _currentStep > 2 ? StepState.complete : StepState.indexed,
            content: _buildDetailsStep(),
          ),
          Step(
            title: const Text('Features'),
            isActive: _currentStep >= 3,
            state: _currentStep > 3 ? StepState.complete : StepState.indexed,
            content: _buildFeaturesStep(),
          ),
          Step(
            title: const Text('Review & Publish'),
            isActive: _currentStep >= 4,
            content: _buildReviewStep(),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicDetailsStep() {
    return Form(
      key: _basicFormKey,
      child: Column(
        children: [
          TextFormField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Title'),
            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descriptionController,
            decoration: const InputDecoration(labelText: 'Description'),
            maxLines: 5,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _propertyType,
            decoration: const InputDecoration(labelText: 'Property Type'),
            items: const [
              DropdownMenuItem(value: 'detached', child: Text('Detached')),
              DropdownMenuItem(
                  value: 'semi_detached', child: Text('Semi-Detached')),
              DropdownMenuItem(value: 'terraced', child: Text('Terraced')),
              DropdownMenuItem(
                  value: 'flat', child: Text('Flat/Apartment')),
              DropdownMenuItem(value: 'bungalow', child: Text('Bungalow')),
              DropdownMenuItem(value: 'cottage', child: Text('Cottage')),
              DropdownMenuItem(value: 'land', child: Text('Land')),
              DropdownMenuItem(value: 'other', child: Text('Other')),
            ],
            onChanged: (v) => setState(() => _propertyType = v ?? 'detached'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _priceController,
            decoration: const InputDecoration(
              labelText: 'Price',
              prefixText: '\u00A3 ',
            ),
            keyboardType: TextInputType.number,
            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildLocationStep() {
    return Form(
      key: _locationFormKey,
      child: Column(
        children: [
          TextFormField(
            controller: _addressLine1Controller,
            decoration: const InputDecoration(labelText: 'Address Line 1'),
            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _addressLine2Controller,
            decoration: const InputDecoration(labelText: 'Address Line 2'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _cityController,
            decoration: const InputDecoration(labelText: 'City'),
            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _countyController,
            decoration: const InputDecoration(labelText: 'County'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _postcodeController,
            decoration: const InputDecoration(labelText: 'Postcode'),
            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsStep() {
    return Form(
      key: _detailsFormKey,
      child: Column(
        children: [
          _buildNumberRow('Bedrooms', _bedrooms, (v) {
            setState(() => _bedrooms = v);
          }),
          const SizedBox(height: 16),
          _buildNumberRow('Bathrooms', _bathrooms, (v) {
            setState(() => _bathrooms = v);
          }),
          const SizedBox(height: 16),
          _buildNumberRow('Reception Rooms', _receptionRooms, (v) {
            setState(() => _receptionRooms = v);
          }),
          const SizedBox(height: 16),
          TextFormField(
            controller: _sqftController,
            decoration: const InputDecoration(
              labelText: 'Square Feet (optional)',
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _epcRating,
            decoration: const InputDecoration(labelText: 'EPC Rating'),
            items: const [
              DropdownMenuItem(value: '', child: Text('Not specified')),
              DropdownMenuItem(value: 'A', child: Text('A')),
              DropdownMenuItem(value: 'B', child: Text('B')),
              DropdownMenuItem(value: 'C', child: Text('C')),
              DropdownMenuItem(value: 'D', child: Text('D')),
              DropdownMenuItem(value: 'E', child: Text('E')),
              DropdownMenuItem(value: 'F', child: Text('F')),
              DropdownMenuItem(value: 'G', child: Text('G')),
            ],
            onChanged: (v) => setState(() => _epcRating = v ?? ''),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberRow(String label, int value, ValueChanged<int> onChanged) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        IconButton(
          onPressed: value > 0
              ? () => onChanged(value - 1)
              : null,
          icon: PhosphorIcon(PhosphorIconsDuotone.minusCircle),
        ),
        Text(
          '$value',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        IconButton(
          onPressed: () => onChanged(value + 1),
          icon: PhosphorIcon(PhosphorIconsDuotone.plusCircle),
        ),
      ],
    );
  }

  Widget _buildFeaturesStep() {
    if (_featuresLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_allFeatures.isEmpty) {
      return const Text('No features available.');
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _allFeatures.map((feature) {
        final selected = _selectedFeatureIds.contains(feature.id);
        return FilterChip(
          label: Text(feature.name),
          selected: selected,
          selectedColor: AppTheme.forestMist,
          checkmarkColor: AppTheme.forestDeep,
          onSelected: (isSelected) {
            setState(() {
              if (isSelected) {
                _selectedFeatureIds.add(feature.id);
              } else {
                _selectedFeatureIds.remove(feature.id);
              }
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildReviewStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Title: ${_titleController.text}',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Price: \u00A3${_priceController.text}'),
        const SizedBox(height: 8),
        Text('Type: $_propertyType'),
        const SizedBox(height: 8),
        Text(
            'Address: ${_addressLine1Controller.text}, ${_cityController.text} ${_postcodeController.text}'),
        const SizedBox(height: 8),
        Text(
            'Rooms: $_bedrooms bed, $_bathrooms bath, $_receptionRooms reception'),
        if (_sqftController.text.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Size: ${_sqftController.text} sq ft'),
        ],
        if (_epcRating.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('EPC: $_epcRating'),
        ],
        if (_selectedFeatureIds.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
              'Features: ${_selectedFeatureIds.length} selected'),
        ],
        const Divider(height: 24),
        DropdownButtonFormField<String>(
          value: _status,
          decoration: const InputDecoration(labelText: 'Status'),
          items: const [
            DropdownMenuItem(value: 'draft', child: Text('Draft')),
            DropdownMenuItem(value: 'active', child: Text('Active')),
          ],
          onChanged: (v) => setState(() => _status = v ?? 'draft'),
        ),
      ],
    );
  }
}
