import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../widgets/branded_app_bar.dart';
import '../widgets/scroll_to_top_button.dart';

class SearchFilterScreen extends StatefulWidget {
  final String? location;
  final String? propertyType;
  final String? minPrice;
  final String? maxPrice;
  final int? minBedrooms;
  final int? minBathrooms;
  final String? epcRating;

  const SearchFilterScreen({
    super.key,
    this.location,
    this.propertyType,
    this.minPrice,
    this.maxPrice,
    this.minBedrooms,
    this.minBathrooms,
    this.epcRating,
  });

  @override
  State<SearchFilterScreen> createState() => _SearchFilterScreenState();
}

class _SearchFilterScreenState extends State<SearchFilterScreen> {
  final ScrollController _scrollController = ScrollController();
  late final TextEditingController _locationController;
  late final TextEditingController _minPriceController;
  late final TextEditingController _maxPriceController;
  String _propertyType = '';
  int? _minBedrooms;
  int? _minBathrooms;
  String _epcRating = '';

  @override
  void initState() {
    super.initState();
    _locationController = TextEditingController(text: widget.location ?? '');
    _minPriceController = TextEditingController(text: widget.minPrice ?? '');
    _maxPriceController = TextEditingController(text: widget.maxPrice ?? '');
    _propertyType = widget.propertyType ?? '';
    _minBedrooms = widget.minBedrooms;
    _minBathrooms = widget.minBathrooms;
    _epcRating = widget.epcRating ?? '';
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _locationController.dispose();
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  void _applyFilters() {
    final filters = <String, dynamic>{};

    if (_locationController.text.isNotEmpty) {
      filters['location'] = _locationController.text;
    }
    if (_propertyType.isNotEmpty) {
      filters['property_type'] = _propertyType;
    }
    if (_minPriceController.text.isNotEmpty) {
      filters['min_price'] = _minPriceController.text;
    }
    if (_maxPriceController.text.isNotEmpty) {
      filters['max_price'] = _maxPriceController.text;
    }
    if (_minBedrooms != null) {
      filters['min_bedrooms'] = _minBedrooms;
    }
    if (_minBathrooms != null) {
      filters['min_bathrooms'] = _minBathrooms;
    }
    if (_epcRating.isNotEmpty) {
      filters['epc_rating'] = _epcRating;
    }

    Navigator.pop(context, filters);
  }

  void _clearFilters() {
    setState(() {
      _locationController.clear();
      _minPriceController.clear();
      _maxPriceController.clear();
      _propertyType = '';
      _minBedrooms = null;
      _minBathrooms = null;
      _epcRating = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BrandedAppBar.build(context: context, showHomeButton: true),
      floatingActionButton: ScrollToTopButton(scrollController: _scrollController),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Location',
                prefixIcon: PhosphorIcon(PhosphorIconsDuotone.mapPin),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _propertyType,
              decoration: const InputDecoration(
                labelText: 'Property Type',
              ),
              items: const [
                DropdownMenuItem(value: '', child: Text('All')),
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
              onChanged: (value) {
                setState(() => _propertyType = value ?? '');
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minPriceController,
                    decoration: const InputDecoration(
                      labelText: 'Min Price',
                      prefixText: '\u00A3 ',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _maxPriceController,
                    decoration: const InputDecoration(
                      labelText: 'Max Price',
                      prefixText: '\u00A3 ',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int?>(
              value: _minBedrooms,
              decoration: const InputDecoration(
                labelText: 'Min Bedrooms',
              ),
              items: const [
                DropdownMenuItem(value: null, child: Text('Any')),
                DropdownMenuItem(value: 1, child: Text('1+')),
                DropdownMenuItem(value: 2, child: Text('2+')),
                DropdownMenuItem(value: 3, child: Text('3+')),
                DropdownMenuItem(value: 4, child: Text('4+')),
                DropdownMenuItem(value: 5, child: Text('5+')),
              ],
              onChanged: (value) {
                setState(() => _minBedrooms = value);
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int?>(
              value: _minBathrooms,
              decoration: const InputDecoration(
                labelText: 'Min Bathrooms',
              ),
              items: const [
                DropdownMenuItem(value: null, child: Text('Any')),
                DropdownMenuItem(value: 1, child: Text('1+')),
                DropdownMenuItem(value: 2, child: Text('2+')),
                DropdownMenuItem(value: 3, child: Text('3+')),
              ],
              onChanged: (value) {
                setState(() => _minBathrooms = value);
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _epcRating,
              decoration: const InputDecoration(
                labelText: 'EPC Rating',
              ),
              items: const [
                DropdownMenuItem(value: '', child: Text('Any')),
                DropdownMenuItem(value: 'A', child: Text('A')),
                DropdownMenuItem(value: 'B', child: Text('B')),
                DropdownMenuItem(value: 'C', child: Text('C')),
                DropdownMenuItem(value: 'D', child: Text('D')),
                DropdownMenuItem(value: 'E', child: Text('E')),
                DropdownMenuItem(value: 'F', child: Text('F')),
                DropdownMenuItem(value: 'G', child: Text('G')),
              ],
              onChanged: (value) {
                setState(() => _epcRating = value ?? '');
              },
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _applyFilters,
              child: const Text('Apply Filters'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _clearFilters,
              child: const Text('Clear Filters'),
            ),
          ],
        ),
      ),
    );
  }
}
