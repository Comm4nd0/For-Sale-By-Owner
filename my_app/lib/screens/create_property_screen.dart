import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../constants/app_theme.dart';
import '../services/api_service.dart';
import '../utils/price_input_formatter.dart';
import '../widgets/branded_app_bar.dart';
import '../widgets/labelled_field.dart';
import 'complete_property_screen.dart';

/// Phase 1 listing creation — minimal fields needed to publish:
/// title, property type, price, postcode, bedrooms + at least one photo.
/// Everything else is captured on the [CompletePropertyScreen] after the
/// listing is live.
class CreatePropertyScreen extends StatefulWidget {
  const CreatePropertyScreen({super.key});

  @override
  State<CreatePropertyScreen> createState() => _CreatePropertyScreenState();
}

class _CreatePropertyScreenState extends State<CreatePropertyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _priceController = TextEditingController();
  final _postcodeController = TextEditingController();
  final _bedroomsController = TextEditingController(text: '3');

  String _propertyType = 'detached';
  final List<XFile> _photos = [];
  Map<String, dynamic>? _postcodeResult;
  bool _lookingUp = false;
  String? _postcodeMessage;
  bool _submitting = false;
  String? _submitError;

  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _postcodeController.dispose();
    _bedroomsController.dispose();
    super.dispose();
  }

  Future<void> _runPostcodeLookup() async {
    final raw = _postcodeController.text.trim();
    if (raw.isEmpty) return;
    setState(() {
      _lookingUp = true;
      _postcodeMessage = null;
    });
    try {
      final result = await context.read<ApiService>().lookupPostcode(raw);
      if (!mounted) return;
      setState(() {
        _postcodeResult = result;
        final district = result['admin_district']?.toString() ?? '';
        final region = result['region']?.toString() ?? '';
        final parts = <String>[
          if (district.isNotEmpty) district,
          if (region.isNotEmpty) region,
        ];
        _postcodeMessage = parts.isEmpty
            ? 'Found.'
            : 'Found: ${parts.join(", ")}. You can add the street name later.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _postcodeResult = null;
        _postcodeMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _lookingUp = false);
    }
  }

  Future<void> _pickPhotos() async {
    final picked = await _picker.pickMultiImage(
      imageQuality: 85,
      maxWidth: 1920,
      maxHeight: 1920,
    );
    if (picked.isEmpty) return;
    setState(() {
      _photos.addAll(picked);
      if (_photos.length > 10) _photos.removeRange(10, _photos.length);
    });
  }

  void _removePhoto(int index) {
    setState(() => _photos.removeAt(index));
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_photos.isEmpty) {
      setState(() => _submitError = 'Please add at least one photo.');
      return;
    }
    setState(() {
      _submitting = true;
      _submitError = null;
    });

    final api = context.read<ApiService>();
    try {
      final body = <String, dynamic>{
        'title': _titleController.text.trim(),
        'property_type': _propertyType,
        'price': PriceInputFormatter.stripCommas(_priceController.text),
        'postcode': _postcodeController.text.trim(),
        'bedrooms': int.tryParse(_bedroomsController.text.trim()) ?? 0,
        'status': 'active',
      };

      // Pre-fill lat/lon/city/county if the lookup was run successfully
      if (_postcodeResult != null) {
        final lat = _postcodeResult!['latitude'];
        final lon = _postcodeResult!['longitude'];
        final district = _postcodeResult!['admin_district'];
        final county = _postcodeResult!['admin_county'] ?? _postcodeResult!['region'];
        if (lat != null) body['latitude'] = lat;
        if (lon != null) body['longitude'] = lon;
        if (district != null) body['city'] = district;
        if (county != null) body['county'] = county;
      }

      final property = await api.createProperty(body);

      // Upload photos in sequence (keeps ordering stable)
      for (final photo in _photos) {
        try {
          await api.uploadPropertyImage(property.id, photo);
        } catch (_) {
          // Non-fatal: user can re-add failed photos from the complete screen
        }
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CompletePropertyScreen(propertyId: property.id),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitError = e.toString().replaceFirst('Exception: ', '');
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BrandedAppBar.build(
        context: context,
        showHomeButton: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'List your property',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppTheme.forestDeep,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Just the basics to publish — you can add more details after.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.charcoal.withValues(alpha: 0.7),
                    ),
              ),
              const SizedBox(height: 20),
              if (_submitError != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    border: Border.all(color: Colors.red.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _submitError!,
                    style: TextStyle(color: Colors.red.shade900),
                  ),
                ),
              LabelledField(
                label: 'Property title',
                helpText:
                    "Eye-catching headline. Keep it short — 'Beautiful 3-bed semi in Cheltenham' works better than a long list.",
                child: TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Beautiful 3-bed semi in Cheltenham',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
              ),
              LabelledField(
                label: 'Property type',
                child: DropdownButtonFormField<String>(
                  value: _propertyType,
                  items: const [
                    DropdownMenuItem(value: 'detached', child: Text('Detached')),
                    DropdownMenuItem(
                        value: 'semi_detached', child: Text('Semi-Detached')),
                    DropdownMenuItem(value: 'terraced', child: Text('Terraced')),
                    DropdownMenuItem(
                        value: 'flat', child: Text('Flat / Apartment')),
                    DropdownMenuItem(value: 'bungalow', child: Text('Bungalow')),
                    DropdownMenuItem(value: 'cottage', child: Text('Cottage')),
                    DropdownMenuItem(value: 'land', child: Text('Land')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (v) =>
                      setState(() => _propertyType = v ?? 'detached'),
                ),
              ),
              LabelledField(
                label: 'Asking price (£)',
                helpText:
                    'Type the price in pounds. Commas are added automatically as you type.',
                child: TextFormField(
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    PriceInputFormatter(),
                  ],
                  decoration: const InputDecoration(
                    prefixText: '£ ',
                    hintText: 'e.g. 350,000',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
              ),
              LabelledField(
                label: 'Postcode',
                helpText:
                    "We look up the area from your postcode to get a rough location. You'll add the full street address after publishing.",
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _postcodeController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          hintText: 'e.g. BS1 1AA',
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _lookingUp ? null : _runPostcodeLookup,
                      child: _lookingUp
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Look up'),
                    ),
                  ],
                ),
              ),
              if (_postcodeMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12, left: 2),
                  child: Text(
                    _postcodeMessage!,
                    style: TextStyle(
                      fontSize: 12,
                      color: _postcodeResult != null
                          ? AppTheme.forestMid
                          : Colors.red.shade700,
                    ),
                  ),
                ),
              LabelledField(
                label: 'Bedrooms',
                child: SizedBox(
                  width: 160,
                  child: TextFormField(
                    controller: _bedroomsController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      if (n == null || n < 0) return 'Required';
                      return null;
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Photos',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.forestDeep,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _pickPhotos,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppTheme.forestMid.withValues(alpha: 0.4),
                      width: 2,
                      style: BorderStyle.solid,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    color: AppTheme.forestMist.withValues(alpha: 0.3),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        PhosphorIconsDuotone.camera,
                        size: 36,
                        color: AppTheme.forestMid,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _photos.isEmpty
                            ? 'Tap to add photos'
                            : 'Add more (${_photos.length}/10)',
                        style: TextStyle(
                          color: AppTheme.forestDeep,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'At least one photo is required.',
                        style: TextStyle(
                          color: AppTheme.charcoal.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_photos.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (int i = 0; i < _photos.length; i++)
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: FutureBuilder<Uint8List>(
                              future: _photos[i].readAsBytes(),
                              builder: (context, snap) {
                                if (snap.connectionState !=
                                        ConnectionState.done ||
                                    snap.data == null) {
                                  return Container(
                                    width: 96,
                                    height: 96,
                                    color: AppTheme.forestMist,
                                  );
                                }
                                return Image.memory(
                                  snap.data!,
                                  width: 96,
                                  height: 96,
                                  fit: BoxFit.cover,
                                );
                              },
                            ),
                          ),
                          Positioned(
                            top: 2,
                            right: 2,
                            child: InkWell(
                              onTap: () => _removePhoto(i),
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 14,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Publish & continue →'),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: _submitting
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

