import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../constants/api_constants.dart';
import '../constants/app_theme.dart';
import '../widgets/branded_app_bar.dart';
import '../widgets/skeleton_loading.dart';
import '../models/property.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'property_detail_screen.dart';
import 'search_filter_screen.dart';
import 'services_screen.dart';
import 'house_prices_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _locationController = TextEditingController();
  final List<Property> _properties = [];
  Map<String, dynamic> _filters = {};
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 1;
  bool _initialLoad = true;
  bool _hasSearched = false;
  String _selectedPropertyType = '';
  int? _selectedBedrooms;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 300 &&
        !_isLoading &&
        _hasMore) {
      _loadMoreProperties();
    }
  }

  void _doSearch() {
    final filters = <String, dynamic>{};
    if (_locationController.text.isNotEmpty) {
      filters['location'] = _locationController.text;
    }
    if (_selectedPropertyType.isNotEmpty) {
      filters['property_type'] = _selectedPropertyType;
    }
    if (_selectedBedrooms != null) {
      filters['min_bedrooms'] = _selectedBedrooms;
    }
    setState(() {
      _filters = filters;
      _hasSearched = true;
    });
    _loadProperties();
  }

  Future<void> _loadProperties() async {
    setState(() {
      _isLoading = true;
      _currentPage = 1;
      _properties.clear();
      _hasMore = true;
    });

    try {
      final apiService = context.read<ApiService>();
      final result = await apiService.getProperties(
        location: _filters['location'],
        propertyType: _filters['property_type'],
        minPrice: _filters['min_price'] != null
            ? double.tryParse(_filters['min_price'].toString())
            : null,
        maxPrice: _filters['max_price'] != null
            ? double.tryParse(_filters['max_price'].toString())
            : null,
        minBedrooms: _filters['min_bedrooms'],
        minBathrooms: _filters['min_bathrooms'],
        epcRating: _filters['epc_rating'],
        page: 1,
      );

      if (!mounted) return;
      setState(() {
        _properties.addAll(result.results);
        _hasMore = result.hasMore;
        _isLoading = false;
        _initialLoad = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _initialLoad = false;
      });
    }
  }

  Future<void> _loadMoreProperties() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final apiService = context.read<ApiService>();
      final result = await apiService.getProperties(
        location: _filters['location'],
        propertyType: _filters['property_type'],
        minPrice: _filters['min_price'] != null
            ? double.tryParse(_filters['min_price'].toString())
            : null,
        maxPrice: _filters['max_price'] != null
            ? double.tryParse(_filters['max_price'].toString())
            : null,
        minBedrooms: _filters['min_bedrooms'],
        minBathrooms: _filters['min_bathrooms'],
        epcRating: _filters['epc_rating'],
        page: _currentPage + 1,
      );

      if (!mounted) return;
      setState(() {
        _currentPage++;
        _properties.addAll(result.results);
        _hasMore = result.hasMore;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _openFilters() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => SearchFilterScreen(
          location: _filters['location'],
          propertyType: _filters['property_type'],
          minPrice: _filters['min_price']?.toString(),
          maxPrice: _filters['max_price']?.toString(),
          minBedrooms: _filters['min_bedrooms'],
          minBathrooms: _filters['min_bathrooms'],
          epcRating: _filters['epc_rating'],
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _filters = result;
        _hasSearched = true;
        _locationController.text = result['location'] ?? '';
        _selectedPropertyType = result['property_type'] ?? '';
        _selectedBedrooms = result['min_bedrooms'];
      });
      _loadProperties();
    }
  }

  void _removeFilter(String key) {
    setState(() => _filters.remove(key));
    _loadProperties();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _hasSearched ? _buildResultsView() : _buildHeroView(),
    );
  }

  Widget _buildHeroView() {
    return CustomScrollView(
      slivers: [
        // Hero section
        SliverToBoxAdapter(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppTheme.forestDeep, Color(0xFF1A6570)],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
                child: Column(
                  children: [
                    // Logo area
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppTheme.goldWarm, AppTheme.goldEmber],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.home, color: Colors.white, size: 26),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'For Sale',
                              style: TextStyle(
                                fontFamily: 'Georgia',
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                height: 1.1,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              'BY OWNER',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                color: AppTheme.forestMist,
                                letterSpacing: 3,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Find Your Perfect Property',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '100% free for buyers and sellers. Always.',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'No fees. No commission. No hidden charges. Ever.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withAlpha(200),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    // Search card
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(60),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Location
                          TextField(
                            controller: _locationController,
                            decoration: InputDecoration(
                              labelText: 'Location',
                              hintText: 'e.g. Cheltenham, GL50',
                              prefixIcon: const Icon(Icons.location_on_outlined),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: AppTheme.pebble),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: AppTheme.forestMid, width: 2),
                              ),
                            ),
                            onSubmitted: (_) => _doSearch(),
                          ),
                          const SizedBox(height: 14),

                          // Property type + Bedrooms row
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _selectedPropertyType,
                                  decoration: InputDecoration(
                                    labelText: 'Property Type',
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(color: AppTheme.pebble),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(color: AppTheme.forestMid, width: 2),
                                    ),
                                  ),
                                  isExpanded: true,
                                  items: const [
                                    DropdownMenuItem(value: '', child: Text('Any Type')),
                                    DropdownMenuItem(value: 'detached', child: Text('Detached')),
                                    DropdownMenuItem(value: 'semi_detached', child: Text('Semi-Detached')),
                                    DropdownMenuItem(value: 'terraced', child: Text('Terraced')),
                                    DropdownMenuItem(value: 'flat', child: Text('Flat')),
                                    DropdownMenuItem(value: 'bungalow', child: Text('Bungalow')),
                                    DropdownMenuItem(value: 'cottage', child: Text('Cottage')),
                                    DropdownMenuItem(value: 'land', child: Text('Land')),
                                    DropdownMenuItem(value: 'other', child: Text('Other')),
                                  ],
                                  onChanged: (value) {
                                    setState(() => _selectedPropertyType = value ?? '');
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<int?>(
                                  value: _selectedBedrooms,
                                  decoration: InputDecoration(
                                    labelText: 'Bedrooms',
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(color: AppTheme.pebble),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(color: AppTheme.forestMid, width: 2),
                                    ),
                                  ),
                                  isExpanded: true,
                                  items: const [
                                    DropdownMenuItem(value: null, child: Text('Any')),
                                    DropdownMenuItem(value: 1, child: Text('1+')),
                                    DropdownMenuItem(value: 2, child: Text('2+')),
                                    DropdownMenuItem(value: 3, child: Text('3+')),
                                    DropdownMenuItem(value: 4, child: Text('4+')),
                                    DropdownMenuItem(value: 5, child: Text('5+')),
                                  ],
                                  onChanged: (value) {
                                    setState(() => _selectedBedrooms = value);
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Search button
                          SizedBox(
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: _doSearch,
                              icon: const Icon(Icons.search),
                              label: const Text(
                                'Search Properties',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.forestMid,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),

                          // More filters link
                          const SizedBox(height: 8),
                          Center(
                            child: TextButton(
                              onPressed: _openFilters,
                              child: const Text(
                                'More filters',
                                style: TextStyle(fontSize: 13),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Free forever banner
        SliverToBoxAdapter(
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFD1E8E2), Color(0xFFA9D6E5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.forestDeep,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '100% FREE',
                    style: TextStyle(
                      color: Color(0xFFD1E8E2),
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Free for Buyers & Sellers. Forever.',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.forestDeep,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'No listing fees. No commission. No hidden charges.\nNot now, not ever.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.forestMid,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: const [
                    _FreePoint('Free to list'),
                    _FreePoint('Free to browse'),
                    _FreePoint('No commission'),
                    _FreePoint('No hidden fees'),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Features section
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 8),
            child: Text(
              'Why sell with For Sale By Owner?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.forestDeep,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _featureRow(
                Icons.savings_outlined,
                'Completely Free',
                'No estate agent fees. No listing charges. No commission. Your sale, your money.',
              ),
              _featureRow(
                Icons.vpn_key_outlined,
                'Stay in Control',
                'Manage your listing, photos, and viewings on your own terms — without paying a penny.',
              ),
              _featureRow(
                Icons.bolt_outlined,
                'List in Minutes',
                'Create your free listing quickly with our simple process. No card required.',
              ),
            ]),
          ),
        ),
        // CTAs row
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HousePricesScreen()),
              ),
              icon: const Icon(Icons.trending_up),
              label: const Text('House Price Lookup'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                foregroundColor: AppTheme.goldEmber,
                side: const BorderSide(color: AppTheme.goldEmber),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ServicesScreen()),
              ),
              icon: const Icon(Icons.handyman_outlined),
              label: const Text('Find Local Services'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                foregroundColor: AppTheme.forestMid,
                side: const BorderSide(color: AppTheme.forestMid),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _featureRow(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.forestMist,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.forestMid, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: AppTheme.charcoal,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.slate,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsView() {
    return Scaffold(
      appBar: BrandedAppBar.build(
        context: context,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            setState(() => _hasSearched = false);
          },
        ),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: _filters.isNotEmpty,
              label: Text('${_filters.length}'),
              child: const Icon(Icons.filter_list),
            ),
            onPressed: _openFilters,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_filters.isNotEmpty) _buildFilterChips(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      width: double.infinity,
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: _filters.entries.map((entry) {
          String label;
          switch (entry.key) {
            case 'location':
              label = entry.value;
              break;
            case 'property_type':
              label = entry.value.toString().replaceAll('_', ' ');
              break;
            case 'min_price':
              label = 'Min \u00A3${entry.value}';
              break;
            case 'max_price':
              label = 'Max \u00A3${entry.value}';
              break;
            case 'min_bedrooms':
              label = '${entry.value}+ beds';
              break;
            case 'min_bathrooms':
              label = '${entry.value}+ baths';
              break;
            case 'epc_rating':
              label = 'EPC ${entry.value}';
              break;
            default:
              label = '${entry.key}: ${entry.value}';
          }
          return Chip(
            label: Text(label, style: const TextStyle(fontSize: 12)),
            deleteIcon: const Icon(Icons.close, size: 16),
            onDeleted: () => _removeFilter(entry.key),
            visualDensity: VisualDensity.compact,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBody() {
    if (_initialLoad && _isLoading) {
      return const SkeletonList(count: 3, useCards: true);
    }

    if (_properties.isEmpty && !_isLoading) {
      return Center(
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
                child: const Icon(Icons.search_off, size: 44, color: AppTheme.forestMid),
              ),
              const SizedBox(height: 24),
              Text(
                _filters.isNotEmpty
                    ? 'No Properties Match'
                    : 'No Properties Listed Yet',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.charcoal,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _filters.isNotEmpty
                    ? 'Try adjusting your filters or search in a different area.'
                    : 'Be the first to list a property in this area.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.slate, height: 1.5),
              ),
              if (_filters.isNotEmpty) ...[
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() => _filters.clear());
                    _loadProperties();
                  },
                  icon: const Icon(Icons.filter_list_off, size: 18),
                  label: const Text('Clear Filters'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => _loadProperties(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 600;
          if (isWide) {
            return GridView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(8),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: constraints.maxWidth >= 900 ? 3 : 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.75,
              ),
              itemCount: _properties.length + (_hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= _properties.length) {
                  return const Center(child: CircularProgressIndicator());
                }
                return PropertyCard(
                  property: _properties[index],
                  onSaveToggled: () => _loadProperties(),
                );
              },
            );
          }
          return ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: _properties.length + (_hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= _properties.length) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return PropertyCard(
                property: _properties[index],
                onSaveToggled: () => _loadProperties(),
              );
            },
          );
        },
      ),
    );
  }
}

class PropertyCard extends StatelessWidget {
  final Property property;
  final VoidCallback? onSaveToggled;

  const PropertyCard({super.key, required this.property, this.onSaveToggled});

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final imageUrl = property.primaryImageUrl != null
        ? ApiConstants.fullUrl(property.primaryImageUrl!)
        : null;

    return Semantics(
      button: true,
      label: '${property.title}, ${property.formattedPrice}, '
          '${property.bedrooms} bedrooms, ${property.bathrooms} bathrooms, '
          '${property.addressLine1}, ${property.city}',
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PropertyDetailScreen(propertyId: property.id),
          ),
        ).then((_) => onSaveToggled?.call()),
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                if (imageUrl != null)
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[200],
                        child:
                            const Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.broken_image,
                            size: 48, color: Colors.grey),
                      ),
                    ),
                  )
                else
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Container(
                      color: Colors.grey[200],
                      child:
                          const Icon(Icons.home, size: 48, color: Colors.grey),
                    ),
                  ),
                if (authService.isAuthenticated)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: _SaveButton(property: property),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          property.title,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ),
                      if (property.ownerIsVerified)
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(Icons.verified,
                              size: 18, color: Colors.blue),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    property.formattedPrice,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppTheme.goldEmber,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    property.propertyTypeDisplay,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  Text(
                    '${property.addressLine1}, ${property.city} ${property.postcode}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _detail(Icons.bed, '${property.bedrooms} bed'),
                      const SizedBox(width: 16),
                      _detail(Icons.bathtub_outlined,
                          '${property.bathrooms} bath'),
                      const SizedBox(width: 16),
                      _detail(Icons.weekend_outlined,
                          '${property.receptionRooms} recep'),
                      if (property.epcRating.isNotEmpty) ...[
                        const SizedBox(width: 16),
                        _detail(Icons.bolt, 'EPC ${property.epcRating}'),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _detail(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
      ],
    );
  }
}

class _SaveButton extends StatefulWidget {
  final Property property;

  const _SaveButton({required this.property});

  @override
  State<_SaveButton> createState() => _SaveButtonState();
}

class _SaveButtonState extends State<_SaveButton> {
  late bool _isSaved;

  @override
  void initState() {
    super.initState();
    _isSaved = widget.property.isSaved;
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: _isSaved ? 'Remove from saved properties' : 'Save property',
      child: GestureDetector(
        onTap: () async {
          try {
            final apiService = context.read<ApiService>();
            await apiService.toggleSaveProperty(
              widget.property.id,
              save: !_isSaved,
            );
            if (mounted) setState(() => _isSaved = !_isSaved);
          } catch (_) {}
        },
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(100),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _isSaved ? Icons.favorite : Icons.favorite_border,
            color: _isSaved ? Colors.red : Colors.white,
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _FreePoint extends StatelessWidget {
  final String text;
  const _FreePoint(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle, size: 16, color: AppTheme.forestMid),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppTheme.forestDeep,
          ),
        ),
      ],
    );
  }
}
