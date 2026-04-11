import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../constants/app_theme.dart';
import '../models/property.dart';
import '../services/api_service.dart';
import '../widgets/branded_app_bar.dart';
import '../widgets/labelled_field.dart';

/// Phase 2 "Complete your listing" screen.
///
/// Shown right after a successful Phase 1 publish and re-openable from
/// MyListings when a listing's quality score is below 80. Every field is
/// optional; the user can close the screen at any time and come back later.
/// Changes autosave per-section with an 800ms debounce.
class CompletePropertyScreen extends StatefulWidget {
  final int propertyId;

  const CompletePropertyScreen({super.key, required this.propertyId});

  @override
  State<CompletePropertyScreen> createState() => _CompletePropertyScreenState();
}

class _CompletePropertyScreenState extends State<CompletePropertyScreen> {
  Property? _property;
  bool _loading = true;
  String? _loadError;
  int _score = 0;

  // One pending-save timer per section key
  final Map<String, Timer> _saveTimers = {};
  final Map<String, bool> _savingNow = {};
  final Map<String, bool> _savedOnce = {};

  // ── Controllers for string fields ──────────────────────────────
  final Map<String, TextEditingController> _text = {};

  // ── Current values ─────────────────────────────────────────────
  final Map<String, dynamic> _values = {};

  // Map controller
  MapController? _mapController;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final t in _saveTimers.values) {
      t.cancel();
    }
    for (final c in _text.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final prop = await context.read<ApiService>().getProperty(widget.propertyId);
      if (!mounted) return;
      setState(() {
        _property = prop;
        _score = prop.listingQualityScore ?? 0;
        _hydrateFromProperty(prop);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  void _hydrateFromProperty(Property p) {
    // Populate _values with every editable field
    _values.addAll({
      // address
      'address_line_1': p.addressLine1,
      'address_line_2': p.addressLine2,
      'city': p.city,
      'county': p.county,
      'postcode': p.postcode,
      'what3words': p.whatThreeWords,
      'latitude': p.latitude,
      'longitude': p.longitude,
      // basics
      'bathrooms': p.bathrooms,
      'reception_rooms': p.receptionRooms,
      'square_feet': p.squareFeet,
      'floor_area_sqm': p.floorAreaSqm,
      'year_built': p.yearBuilt,
      'construction_type': p.constructionType,
      'epc_rating': p.epcRating,
      // tenure
      'tenure': p.tenure,
      'council_tax_band': p.councilTaxBand,
      'lease_years_remaining': p.leaseYearsRemaining,
      'ground_rent_amount': p.groundRentAmount,
      'service_charge_amount': p.serviceChargeAmount,
      'service_charge_frequency': p.serviceChargeFrequency,
      'managing_agent_details': p.managingAgentDetails,
      'ground_rent_review_terms': p.groundRentReviewTerms,
      'annual_gas_bill': p.annualGasBill,
      'annual_electricity_bill': p.annualElectricityBill,
      'annual_water_bill': p.annualWaterBill,
      // utilities
      'electricity_supply': p.electricitySupply,
      'water_supply': p.waterSupply,
      'sewerage': p.sewerage,
      'heating_type': p.heatingType,
      'broadband_speed': p.broadbandSpeed,
      'broadband_provider': p.broadbandProvider,
      'broadband_monthly_cost': p.broadbandMonthlyCost,
      'parking_type': p.parkingType,
      // risks
      'flood_risk': p.floodRisk,
      'listed_building': p.listedBuilding,
      'mining_area': p.miningArea,
      'japanese_knotweed': p.japaneseKnotweed,
      'conservation_area': p.conservationArea,
      'coastal_erosion_risk': p.coastalErosionRisk,
      'restrictive_covenants': p.restrictiveCovenants,
      'rights_of_way': p.rightsOfWay,
      'restrictive_covenants_details': p.restrictiveCovenantsDetails,
      'rights_of_way_details': p.rightsOfWayDetails,
      'cladding_type': p.claddingType,
      'ews1_available': p.ews1Available,
      'non_standard_construction': p.nonStandardConstruction,
      'accessibility_features': p.accessibilityFeatures,
      // works history
      'extensions_year': p.extensionsYear,
      'loft_conversion_year': p.loftConversionYear,
      'rewiring_year': p.rewiringYear,
      'reroof_year': p.reroofYear,
      'new_boiler_year': p.newBoilerYear,
      'new_windows_year': p.newWindowsYear,
      'damp_proofing_year': p.dampProofingYear,
      'works_notes': p.worksNotes,
      'nhbc_years_remaining': p.nhbcYearsRemaining,
      'solar_panels': p.solarPanels,
      // outside
      'garden_size_sqm': p.gardenSizeSqm,
      'garden_orientation': p.gardenOrientation,
      'outbuildings': p.outbuildings,
      'chain_status': p.chainStatus,
      'earliest_completion_date': p.earliestCompletionDate,
      'reason_for_sale': p.reasonForSale,
      'fixtures_included': p.fixturesIncluded,
      'fixtures_excluded': p.fixturesExcluded,
      // extras
      'nearest_station_name': p.nearestStationName,
      'nearest_station_distance_km': p.nearestStationDistanceKm,
      'nearby_schools': p.nearbySchools,
      'noise_sources': p.noiseSources,
      'radon_risk': p.radonRisk,
      'smart_home': p.smartHome,
      'ev_charging': p.evCharging,
      'solar_battery_storage': p.solarBatteryStorage,
      'rainwater_harvesting': p.rainwaterHarvesting,
      'home_office': p.homeOffice,
      'pet_friendly_features': p.petFriendlyFeatures,
      // description
      'brief_description': p.briefDescription,
      'description': p.description,
    });

    // Create text controllers for all string/number fields
    final textFields = [
      'address_line_1', 'address_line_2', 'city', 'county', 'postcode',
      'what3words', 'managing_agent_details', 'ground_rent_review_terms',
      'broadband_provider', 'restrictive_covenants_details',
      'rights_of_way_details', 'cladding_type', 'accessibility_features',
      'works_notes', 'outbuildings', 'reason_for_sale', 'fixtures_included',
      'fixtures_excluded', 'nearest_station_name', 'nearby_schools',
      'noise_sources', 'brief_description', 'description',
      // numeric kept as text controllers
      'bathrooms', 'reception_rooms', 'square_feet', 'floor_area_sqm',
      'year_built', 'lease_years_remaining', 'ground_rent_amount',
      'service_charge_amount', 'annual_gas_bill', 'annual_electricity_bill',
      'annual_water_bill', 'broadband_monthly_cost', 'extensions_year',
      'loft_conversion_year', 'rewiring_year', 'reroof_year',
      'new_boiler_year', 'new_windows_year', 'damp_proofing_year',
      'nhbc_years_remaining', 'garden_size_sqm',
      'nearest_station_distance_km',
    ];
    for (final key in textFields) {
      final v = _values[key];
      _text[key] = TextEditingController(
        text: v == null ? '' : v.toString(),
      );
    }
  }

  /// Fields covered by each section (for badge counts + grouped autosave).
  static const Map<String, List<String>> _sectionFields = {
    'address': ['address_line_1', 'address_line_2', 'city', 'county', 'what3words', 'latitude'],
    'basics': ['bathrooms', 'reception_rooms', 'square_feet', 'floor_area_sqm', 'year_built', 'construction_type', 'epc_rating'],
    'tenure': ['tenure', 'council_tax_band', 'lease_years_remaining', 'service_charge_amount', 'annual_gas_bill', 'annual_electricity_bill', 'annual_water_bill', 'managing_agent_details'],
    'utilities': ['electricity_supply', 'water_supply', 'sewerage', 'heating_type', 'broadband_speed', 'parking_type', 'broadband_provider'],
    'risks': ['flood_risk', 'listed_building', 'mining_area', 'japanese_knotweed', 'conservation_area', 'coastal_erosion_risk', 'restrictive_covenants', 'rights_of_way', 'ews1_available', 'accessibility_features'],
    'works': ['extensions_year', 'loft_conversion_year', 'rewiring_year', 'reroof_year', 'new_boiler_year', 'new_windows_year', 'damp_proofing_year'],
    'outside': ['garden_size_sqm', 'garden_orientation', 'outbuildings', 'chain_status', 'earliest_completion_date', 'reason_for_sale', 'fixtures_included', 'fixtures_excluded'],
    'extras': ['nearest_station_name', 'nearest_station_distance_km', 'nearby_schools', 'noise_sources', 'radon_risk', 'smart_home', 'ev_charging', 'solar_battery_storage', 'rainwater_harvesting', 'home_office', 'pet_friendly_features'],
    'description': ['brief_description', 'description'],
  };

  bool _isFilled(String key) {
    final v = _values[key];
    if (v == null) return false;
    if (v is bool) return v;
    if (v is String) return v.trim().isNotEmpty;
    if (v is num) return true;
    return true;
  }

  int _sectionFilled(String section) =>
      _sectionFields[section]!.where(_isFilled).length;

  int _sectionTotal(String section) => _sectionFields[section]!.length;

  /// Mark a field dirty and queue a debounced autosave for its section.
  void _onFieldChanged(String section, String field, dynamic value) {
    setState(() {
      _values[field] = value;
    });
    _saveTimers[section]?.cancel();
    _saveTimers[section] = Timer(const Duration(milliseconds: 800), () {
      _saveSection(section);
    });
  }

  Future<void> _saveSection(String section) async {
    final api = context.read<ApiService>();
    final payload = <String, dynamic>{};
    for (final field in _sectionFields[section]!) {
      payload[field] = _prepareValue(field);
    }
    // Address section also carries map lat/lon
    if (section == 'address') {
      payload['latitude'] = _values['latitude'];
      payload['longitude'] = _values['longitude'];
      payload['postcode'] = _text['postcode']?.text.trim();
    }
    setState(() => _savingNow[section] = true);
    try {
      final updated = await api.updateProperty(widget.propertyId, payload);
      if (!mounted) return;
      setState(() {
        _property = updated;
        _score = updated.listingQualityScore ?? _score;
        _savingNow[section] = false;
        _savedOnce[section] = true;
      });
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _savedOnce[section] = false);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _savingNow[section] = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Save failed: ${e.toString().replaceFirst('Exception: ', '')}'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  dynamic _prepareValue(String field) {
    final v = _values[field];
    if (v is String && v.isEmpty) return null;
    return v;
  }

  Future<void> _runPostcodeLookup() async {
    final raw = _text['postcode']?.text.trim() ?? '';
    if (raw.isEmpty) return;
    try {
      final result = await context.read<ApiService>().lookupPostcode(raw);
      if (!mounted) return;
      final lat = result['latitude'];
      final lon = result['longitude'];
      final district = result['admin_district']?.toString();
      final county = result['admin_county']?.toString() ??
          result['region']?.toString();
      setState(() {
        if (lat is num) _values['latitude'] = lat.toDouble();
        if (lon is num) _values['longitude'] = lon.toDouble();
        if (district != null && district.isNotEmpty) {
          _values['city'] = district;
          _text['city']?.text = district;
        }
        if (county != null && county.isNotEmpty) {
          _values['county'] = county;
          _text['county']?.text = county;
        }
      });
      if (lat is num && lon is num && _mapController != null) {
        _mapController!.move(LatLng(lat.toDouble(), lon.toDouble()), 15);
      }
      _saveSection('address');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _autoFillBriefDescription() async {
    if (_property == null) return;
    try {
      final text = await context.read<ApiService>().generateBriefDescription(
            propertyType: _property!.propertyType,
            bedrooms: _property!.bedrooms,
            bathrooms: _values['bathrooms'] is int
                ? _values['bathrooms']
                : _property!.bathrooms,
            receptionRooms: _values['reception_rooms'] is int
                ? _values['reception_rooms']
                : _property!.receptionRooms,
            squareFeet: _values['square_feet'] is int
                ? _values['square_feet']
                : _property!.squareFeet,
            location: (_values['city'] as String?)?.isNotEmpty == true
                ? _values['city'] as String
                : _property!.city,
            epcRating: _values['epc_rating'] as String? ?? '',
            featureNames: _property!.features.map((f) => f.name).toList(),
          );
      if (!mounted) return;
      setState(() {
        _values['brief_description'] = text;
        _text['brief_description']?.text = text;
      });
      _saveSection('description');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Could not generate: ${e.toString().replaceFirst('Exception: ', '')}')),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────
  // UI
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BrandedAppBar.build(
        context: context,
        showHomeButton: true,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
            child: const Text(
              'Finish later',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(child: Text('Error: $_loadError'))
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCompletionHeader(),
          const SizedBox(height: 16),
          _buildAddressSection(),
          _buildBasicsSection(),
          _buildTenureSection(),
          _buildUtilitiesSection(),
          _buildRisksSection(),
          _buildWorksSection(),
          _buildOutsideSection(),
          _buildExtrasSection(),
          _buildDescriptionSection(),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                child: const Text("I'll finish later"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                child: const Text('Done'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.forestDeep, AppTheme.forestMid],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_property?.title ?? "Your listing"} is live!',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          const Text(
            'Add more details to stand out. Nothing here is required — you can come back later.',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: _score / 100,
              minHeight: 10,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF5C542)),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$_score% complete',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  // ── Section shell ─────────────────────────────────────────────
  Widget _section({
    required String key,
    required String icon,
    required String title,
    required Widget child,
    bool initiallyExpanded = false,
  }) {
    final filled = _sectionFilled(key);
    final total = _sectionTotal(key);
    final saving = _savingNow[key] == true;
    final justSaved = _savedOnce[key] == true;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          initiallyExpanded: initiallyExpanded,
          title: Row(
            children: [
              Text('$icon  $title',
                  style: TextStyle(
                      color: AppTheme.forestDeep,
                      fontWeight: FontWeight.w600)),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.forestMist,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('$filled / $total',
                    style: TextStyle(
                        color: AppTheme.forestDeep,
                        fontSize: 11,
                        fontWeight: FontWeight.w500)),
              ),
              const Spacer(),
              if (saving)
                const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2))
              else if (justSaved)
                Text(
                  'Saved ✓',
                  style: TextStyle(
                      color: AppTheme.forestMid,
                      fontSize: 12,
                      fontWeight: FontWeight.w500),
                ),
            ],
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [child],
        ),
      ),
    );
  }

  // ── Reusable inputs ──────────────────────────────────────────
  Widget _text_(String section, String field,
      {String label = '',
      String? helpText,
      TextInputType? keyboard,
      int maxLines = 1,
      String? hint}) {
    return LabelledField(
      label: label,
      helpText: helpText,
      child: TextField(
        controller: _text[field],
        keyboardType: keyboard,
        maxLines: maxLines,
        decoration: InputDecoration(hintText: hint),
        onChanged: (v) {
          _values[field] = v;
          _saveTimers[section]?.cancel();
          _saveTimers[section] = Timer(const Duration(milliseconds: 800),
              () => _saveSection(section));
        },
      ),
    );
  }

  Widget _dropdown<T>(String section, String field, String label,
      List<DropdownMenuItem<T>> items,
      {String? helpText}) {
    // Pick the first item value whose payload matches the stored value, so
    // we never pass a value that isn't in the items list (which would throw).
    final raw = _values[field];
    T? selected;
    for (final item in items) {
      if (item.value == raw || (raw == null && item.value == '')) {
        selected = item.value;
        break;
      }
    }
    return LabelledField(
      label: label,
      helpText: helpText,
      child: DropdownButtonFormField<T>(
        value: selected,
        items: items,
        onChanged: (v) => _onFieldChanged(section, field, v ?? ''),
      ),
    );
  }

  Widget _check(String section, String field, String label,
      {String? helpText}) {
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      title: Row(
        children: [
          Flexible(child: Text(label)),
          if (helpText != null) ...[
            const SizedBox(width: 6),
            IconButton(
              iconSize: 16,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: helpText,
              onPressed: () => showDialog<void>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(label),
                  content: Text(helpText),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Got it'),
                    ),
                  ],
                ),
              ),
              icon: Icon(PhosphorIconsDuotone.question,
                  color: AppTheme.forestMid),
            ),
          ],
        ],
      ),
      value: _values[field] == true,
      onChanged: (v) => _onFieldChanged(section, field, v ?? false),
    );
  }

  // ── Sections ──────────────────────────────────────────────────

  Widget _buildAddressSection() {
    final hasCoords =
        _values['latitude'] is num && _values['longitude'] is num;
    final center = hasCoords
        ? LatLng(
            (_values['latitude'] as num).toDouble(),
            (_values['longitude'] as num).toDouble(),
          )
        : const LatLng(54.5, -2.5);
    _mapController ??= MapController();

    return _section(
      key: 'address',
      icon: '📍',
      title: 'Address & location',
      initiallyExpanded: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _text_('address', 'address_line_1', label: 'Address Line 1'),
          _text_('address', 'address_line_2', label: 'Address Line 2'),
          _text_('address', 'city', label: 'City / Town'),
          _text_('address', 'county', label: 'County'),
          LabelledField(
            label: 'Postcode',
            helpText:
                'Changing the postcode re-runs the lookup and pans the map.',
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _text['postcode'],
                    textCapitalization: TextCapitalization.characters,
                    onChanged: (v) {
                      _values['postcode'] = v;
                      _saveTimers['address']?.cancel();
                      _saveTimers['address'] = Timer(
                          const Duration(milliseconds: 800),
                          () => _saveSection('address'));
                    },
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _runPostcodeLookup,
                  child: const Text('Look up'),
                ),
              ],
            ),
          ),
          Text(
            'Map pin (tap or drag to adjust)',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.charcoal.withValues(alpha: 0.7),
                ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 240,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: hasCoords ? 15 : 6,
                  onTap: (tapPosition, point) {
                    setState(() {
                      _values['latitude'] = point.latitude;
                      _values['longitude'] = point.longitude;
                    });
                    _saveSection('address');
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.fsbo.my_app',
                  ),
                  if (hasCoords)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: center,
                          width: 40,
                          height: 40,
                          child: Icon(
                            PhosphorIconsDuotone.mapPin,
                            color: AppTheme.forestDeep,
                            size: 36,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 12),
            child: Text(
              '© OpenStreetMap contributors',
              style: TextStyle(
                fontSize: 10,
                color: AppTheme.charcoal.withValues(alpha: 0.5),
              ),
            ),
          ),
          LabelledField(
            label: 'what3words (optional)',
            helpText:
                'A 3-word address for the exact spot — e.g. index.home.raft. Leave blank if you don\'t know it.',
            child: TextField(
              controller: _text['what3words'],
              decoration: const InputDecoration(hintText: 'word.word.word'),
              onChanged: (v) {
                _values['what3words'] = v;
                _saveTimers['address']?.cancel();
                _saveTimers['address'] = Timer(
                    const Duration(milliseconds: 800),
                    () => _saveSection('address'));
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicsSection() {
    return _section(
      key: 'basics',
      icon: '🏠',
      title: 'Property basics',
      child: Column(
        children: [
          _numberField('basics', 'bathrooms', 'Bathrooms'),
          _numberField('basics', 'reception_rooms', 'Reception rooms'),
          _numberField('basics', 'square_feet', 'Square feet'),
          _numberField('basics', 'floor_area_sqm', 'Square metres',
              asDouble: true),
          _numberField('basics', 'year_built', 'Year built',
              helpText:
                  'Approximate is fine — helps buyers judge the era of the property.'),
          _dropdown<String>(
            'basics',
            'construction_type',
            'Construction',
            const [
              DropdownMenuItem(value: '', child: Text('Not specified')),
              DropdownMenuItem(value: 'standard', child: Text('Standard brick')),
              DropdownMenuItem(value: 'timber', child: Text('Timber frame')),
              DropdownMenuItem(value: 'concrete', child: Text('Concrete')),
              DropdownMenuItem(value: 'steel', child: Text('Steel frame')),
              DropdownMenuItem(value: 'cob', child: Text('Cob')),
              DropdownMenuItem(value: 'other', child: Text('Other')),
            ],
            helpText:
                'Non-standard construction (timber, concrete, steel frame, cob) can affect mortgage availability.',
          ),
          _dropdown<String>(
            'basics',
            'epc_rating',
            'EPC rating',
            const [
              DropdownMenuItem(value: '', child: Text('Not specified')),
              DropdownMenuItem(value: 'A', child: Text('A')),
              DropdownMenuItem(value: 'B', child: Text('B')),
              DropdownMenuItem(value: 'C', child: Text('C')),
              DropdownMenuItem(value: 'D', child: Text('D')),
              DropdownMenuItem(value: 'E', child: Text('E')),
              DropdownMenuItem(value: 'F', child: Text('F')),
              DropdownMenuItem(value: 'G', child: Text('G')),
            ],
            helpText:
                'Energy Performance Certificate rating from A (best) to G (worst). Required by law for most sales.',
          ),
        ],
      ),
    );
  }

  Widget _buildTenureSection() {
    final isLeasehold = _values['tenure'] == 'leasehold' ||
        _values['tenure'] == 'share_of_freehold';
    return _section(
      key: 'tenure',
      icon: '📜',
      title: 'Tenure & running costs',
      child: Column(
        children: [
          _dropdown<String>(
            'tenure',
            'tenure',
            'Tenure',
            const [
              DropdownMenuItem(value: '', child: Text('Not specified')),
              DropdownMenuItem(value: 'freehold', child: Text('Freehold')),
              DropdownMenuItem(value: 'leasehold', child: Text('Leasehold')),
              DropdownMenuItem(
                  value: 'share_of_freehold', child: Text('Share of Freehold')),
              DropdownMenuItem(value: 'commonhold', child: Text('Commonhold')),
            ],
            helpText:
                'Freehold = you own the building and land. Leasehold = you own the property for a fixed term.',
          ),
          _dropdown<String>(
            'tenure',
            'council_tax_band',
            'Council tax band',
            const [
              DropdownMenuItem(value: '', child: Text('Not specified')),
              DropdownMenuItem(value: 'A', child: Text('A')),
              DropdownMenuItem(value: 'B', child: Text('B')),
              DropdownMenuItem(value: 'C', child: Text('C')),
              DropdownMenuItem(value: 'D', child: Text('D')),
              DropdownMenuItem(value: 'E', child: Text('E')),
              DropdownMenuItem(value: 'F', child: Text('F')),
              DropdownMenuItem(value: 'G', child: Text('G')),
              DropdownMenuItem(value: 'H', child: Text('H')),
            ],
          ),
          if (isLeasehold) ...[
            _numberField('tenure', 'lease_years_remaining',
                'Years remaining on lease'),
            _numberField('tenure', 'ground_rent_amount', 'Ground rent (£/year)',
                asDouble: true),
            _numberField('tenure', 'service_charge_amount',
                'Service charge (£)',
                asDouble: true),
            _dropdown<String>(
              'tenure',
              'service_charge_frequency',
              'Service charge frequency',
              const [
                DropdownMenuItem(value: '', child: Text('Not specified')),
                DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                DropdownMenuItem(value: 'quarterly', child: Text('Quarterly')),
                DropdownMenuItem(value: 'annual', child: Text('Annual')),
              ],
            ),
            _text_('tenure', 'managing_agent_details',
                label: 'Managing agent details', maxLines: 3),
          ],
          const Divider(),
          Text('Annual running costs (optional)',
              style: TextStyle(
                  color: AppTheme.forestDeep, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _numberField('tenure', 'annual_gas_bill', 'Gas (£/year)',
              asDouble: true),
          _numberField(
              'tenure', 'annual_electricity_bill', 'Electricity (£/year)',
              asDouble: true),
          _numberField('tenure', 'annual_water_bill', 'Water (£/year)',
              asDouble: true),
        ],
      ),
    );
  }

  Widget _buildUtilitiesSection() {
    return _section(
      key: 'utilities',
      icon: '🔌',
      title: 'Utilities & services',
      child: Column(
        children: [
          _dropdown<String>('utilities', 'electricity_supply', 'Electricity',
              const [
                DropdownMenuItem(value: '', child: Text('Not specified')),
                DropdownMenuItem(value: 'mains', child: Text('Mains')),
                DropdownMenuItem(value: 'off_grid', child: Text('Off-grid')),
                DropdownMenuItem(value: 'solar', child: Text('Solar')),
              ]),
          _dropdown<String>('utilities', 'water_supply', 'Water', const [
            DropdownMenuItem(value: '', child: Text('Not specified')),
            DropdownMenuItem(value: 'mains', child: Text('Mains')),
            DropdownMenuItem(value: 'private', child: Text('Private')),
            DropdownMenuItem(value: 'shared', child: Text('Shared')),
          ]),
          _dropdown<String>('utilities', 'sewerage', 'Sewerage', const [
            DropdownMenuItem(value: '', child: Text('Not specified')),
            DropdownMenuItem(value: 'mains', child: Text('Mains')),
            DropdownMenuItem(value: 'septic', child: Text('Septic tank')),
            DropdownMenuItem(value: 'cesspit', child: Text('Cesspit')),
            DropdownMenuItem(
                value: 'treatment_plant', child: Text('Treatment plant')),
          ],
              helpText:
                  'Not everyone has mains drainage — rural homes often have septic tanks.'),
          _dropdown<String>('utilities', 'heating_type', 'Heating', const [
            DropdownMenuItem(value: '', child: Text('Not specified')),
            DropdownMenuItem(value: 'gas_central', child: Text('Gas central')),
            DropdownMenuItem(value: 'electric', child: Text('Electric')),
            DropdownMenuItem(value: 'oil', child: Text('Oil')),
            DropdownMenuItem(value: 'lpg', child: Text('LPG')),
            DropdownMenuItem(value: 'heat_pump', child: Text('Heat pump')),
            DropdownMenuItem(value: 'none', child: Text('None')),
          ]),
          _dropdown<String>('utilities', 'broadband_speed', 'Broadband', const [
            DropdownMenuItem(value: '', child: Text('Not specified')),
            DropdownMenuItem(value: 'standard', child: Text('Standard')),
            DropdownMenuItem(value: 'superfast', child: Text('Superfast')),
            DropdownMenuItem(value: 'ultrafast', child: Text('Ultrafast')),
            DropdownMenuItem(value: 'full_fibre', child: Text('Full fibre')),
            DropdownMenuItem(value: 'unknown', child: Text('Unknown')),
          ]),
          _dropdown<String>('utilities', 'parking_type', 'Parking', const [
            DropdownMenuItem(value: '', child: Text('Not specified')),
            DropdownMenuItem(value: 'garage', child: Text('Garage')),
            DropdownMenuItem(value: 'driveway', child: Text('Driveway')),
            DropdownMenuItem(value: 'allocated', child: Text('Allocated')),
            DropdownMenuItem(value: 'permit', child: Text('Permit')),
            DropdownMenuItem(value: 'on_street', child: Text('On-street')),
            DropdownMenuItem(value: 'none', child: Text('None')),
          ]),
          _text_('utilities', 'broadband_provider',
              label: 'Broadband provider'),
        ],
      ),
    );
  }

  Widget _buildRisksSection() {
    return _section(
      key: 'risks',
      icon: '⚠️',
      title: 'Rights, restrictions & risks',
      child: Column(
        children: [
          _dropdown<String>('risks', 'flood_risk', 'Flood risk', const [
            DropdownMenuItem(value: '', child: Text('Not specified')),
            DropdownMenuItem(value: 'none', child: Text('None')),
            DropdownMenuItem(value: 'river', child: Text('River')),
            DropdownMenuItem(value: 'surface_water', child: Text('Surface water')),
            DropdownMenuItem(value: 'groundwater', child: Text('Groundwater')),
            DropdownMenuItem(value: 'multiple', child: Text('Multiple')),
          ],
              helpText:
                  'Material information — buyers and lenders expect known flood risks to be disclosed.'),
          _dropdown<String>(
              'risks', 'listed_building', 'Listed building', const [
            DropdownMenuItem(value: '', child: Text('Not specified')),
            DropdownMenuItem(value: 'none', child: Text('None')),
            DropdownMenuItem(value: 'grade_1', child: Text('Grade I')),
            DropdownMenuItem(value: 'grade_2_star', child: Text('Grade II*')),
            DropdownMenuItem(value: 'grade_2', child: Text('Grade II')),
          ]),
          _dropdown<String>('risks', 'mining_area', 'Mining area', const [
            DropdownMenuItem(value: '', child: Text('Not specified')),
            DropdownMenuItem(value: 'none', child: Text('None')),
            DropdownMenuItem(value: 'coal', child: Text('Coal')),
            DropdownMenuItem(value: 'tin', child: Text('Tin')),
            DropdownMenuItem(value: 'other', child: Text('Other')),
          ]),
          _dropdown<String>(
              'risks', 'japanese_knotweed', 'Japanese knotweed', const [
            DropdownMenuItem(value: '', child: Text('Not specified')),
            DropdownMenuItem(value: 'none', child: Text('Never')),
            DropdownMenuItem(value: 'present', child: Text('Present')),
            DropdownMenuItem(value: 'treated', child: Text('Treated')),
            DropdownMenuItem(value: 'unsure', child: Text('Unsure')),
          ],
              helpText:
                  'Invasive plant that can damage foundations and is a material fact buyers ask about.'),
          _check('risks', 'conservation_area', 'Conservation area'),
          _check('risks', 'coastal_erosion_risk', 'Coastal erosion risk'),
          _check('risks', 'restrictive_covenants', 'Restrictive covenants'),
          _check('risks', 'rights_of_way', 'Rights of way affect the property'),
          _check('risks', 'ews1_available', 'EWS1 form available',
              helpText:
                  'The External Wall System 1 form confirms a building\'s external walls meet fire-safety standards.'),
          _text_('risks', 'restrictive_covenants_details',
              label: 'Covenant details', maxLines: 3),
          _text_('risks', 'rights_of_way_details',
              label: 'Rights of way details', maxLines: 3),
          _text_('risks', 'cladding_type', label: 'Cladding type (flats only)'),
          _text_('risks', 'accessibility_features',
              label: 'Accessibility features', maxLines: 3),
        ],
      ),
    );
  }

  Widget _buildWorksSection() {
    return _section(
      key: 'works',
      icon: '🛠️',
      title: 'Works history',
      child: Column(
        children: [
          _numberField('works', 'extensions_year', 'Extensions (year)'),
          _numberField('works', 'loft_conversion_year', 'Loft conversion'),
          _numberField('works', 'rewiring_year', 'Rewiring'),
          _numberField('works', 'reroof_year', 'Re-roof'),
          _numberField('works', 'new_boiler_year', 'New boiler'),
          _numberField('works', 'new_windows_year', 'New windows'),
          _numberField('works', 'damp_proofing_year', 'Damp-proofing'),
        ],
      ),
    );
  }

  Widget _buildOutsideSection() {
    return _section(
      key: 'outside',
      icon: '🌳',
      title: 'Outside space & chain',
      child: Column(
        children: [
          _numberField('outside', 'garden_size_sqm', 'Garden size (sq m)',
              asDouble: true),
          _dropdown<String>(
              'outside', 'garden_orientation', 'Garden orientation', const [
            DropdownMenuItem(value: '', child: Text('Not specified')),
            DropdownMenuItem(value: 'none', child: Text('No garden')),
            DropdownMenuItem(value: 'n', child: Text('North')),
            DropdownMenuItem(value: 'ne', child: Text('North-East')),
            DropdownMenuItem(value: 'e', child: Text('East')),
            DropdownMenuItem(value: 'se', child: Text('South-East')),
            DropdownMenuItem(value: 's', child: Text('South')),
            DropdownMenuItem(value: 'sw', child: Text('South-West')),
            DropdownMenuItem(value: 'w', child: Text('West')),
            DropdownMenuItem(value: 'nw', child: Text('North-West')),
          ]),
          _text_('outside', 'outbuildings',
              label: 'Outbuildings (shed, studio, garage)', maxLines: 3),
          _dropdown<String>('outside', 'chain_status', 'Chain status', const [
            DropdownMenuItem(value: '', child: Text('Not specified')),
            DropdownMenuItem(value: 'no_chain', child: Text('No chain')),
            DropdownMenuItem(value: 'in_chain', child: Text('In chain')),
            DropdownMenuItem(
                value: 'part_exchange', child: Text('Part exchange')),
          ],
              helpText:
                  "'No chain' means you can sell without waiting for another transaction. Buyers prefer no-chain properties."),
          _text_('outside', 'reason_for_sale',
              label: 'Reason for sale', maxLines: 3),
          _text_('outside', 'fixtures_included',
              label: 'Fixtures included', maxLines: 3),
          _text_('outside', 'fixtures_excluded',
              label: 'Fixtures NOT included', maxLines: 3),
        ],
      ),
    );
  }

  Widget _buildExtrasSection() {
    return _section(
      key: 'extras',
      icon: '✨',
      title: 'Neighbourhood & extras',
      child: Column(
        children: [
          _text_('extras', 'nearest_station_name', label: 'Nearest station'),
          _numberField(
              'extras', 'nearest_station_distance_km', 'Distance (km)',
              asDouble: true),
          _text_('extras', 'nearby_schools', label: 'Nearby schools', maxLines: 3),
          _text_('extras', 'noise_sources',
              label: 'Noise sources (road, rail, flight path)'),
          _dropdown<String>('extras', 'radon_risk', 'Radon risk', const [
            DropdownMenuItem(value: '', child: Text('Not specified')),
            DropdownMenuItem(value: 'unknown', child: Text('Unknown')),
            DropdownMenuItem(value: 'none', child: Text('None')),
            DropdownMenuItem(value: 'low', child: Text('Low')),
            DropdownMenuItem(value: 'medium', child: Text('Medium')),
            DropdownMenuItem(value: 'high', child: Text('High')),
          ]),
          const Divider(),
          _check('extras', 'smart_home', 'Smart home'),
          _check('extras', 'ev_charging', 'EV charging'),
          _check('extras', 'solar_battery_storage', 'Solar battery storage'),
          _check('extras', 'rainwater_harvesting', 'Rainwater harvesting'),
          _check('extras', 'home_office', 'Home office'),
          _check('extras', 'pet_friendly_features', 'Pet-friendly features'),
        ],
      ),
    );
  }

  Widget _buildDescriptionSection() {
    return _section(
      key: 'description',
      icon: '📝',
      title: 'Description',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _text_(
            'description',
            'brief_description',
            label: 'Brief description (shown in search results)',
            helpText:
                'A 1–2 sentence summary. Tap "Auto-fill" to generate one from your details.',
            maxLines: 3,
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _autoFillBriefDescription,
              icon: Icon(PhosphorIconsDuotone.sparkle,
                  color: AppTheme.forestMid),
              label: const Text('Auto-fill from my details'),
            ),
          ),
          const SizedBox(height: 12),
          _text_(
            'description',
            'description',
            label: 'Full description',
            maxLines: 8,
          ),
        ],
      ),
    );
  }

  // ── Numeric text field helper (handles int / double conversion) ─────

  Widget _numberField(String section, String field, String label,
      {bool asDouble = false, String? helpText}) {
    return LabelledField(
      label: label,
      helpText: helpText,
      child: TextField(
        controller: _text[field],
        keyboardType: TextInputType.numberWithOptions(decimal: asDouble),
        onChanged: (v) {
          final trimmed = v.trim();
          dynamic parsed;
          if (trimmed.isEmpty) {
            parsed = null;
          } else if (asDouble) {
            parsed = double.tryParse(trimmed);
          } else {
            parsed = int.tryParse(trimmed);
          }
          _values[field] = parsed;
          _saveTimers[section]?.cancel();
          _saveTimers[section] = Timer(const Duration(milliseconds: 800),
              () => _saveSection(section));
        },
      ),
    );
  }
}

