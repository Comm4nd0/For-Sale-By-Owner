import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../constants/api_constants.dart';
import '../constants/app_theme.dart';
import '../models/property.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/epc_rating_bar.dart';
import '../widgets/mortgage_calculator.dart';
import '../widgets/stamp_duty_calculator.dart';
import '../widgets/enquiry_form.dart';
import '../widgets/viewing_request_form.dart';
import 'image_management_screen.dart';
import 'edit_property_screen.dart';
import '../widgets/service_providers_section.dart';

class PropertyDetailScreen extends StatefulWidget {
  final int propertyId;

  const PropertyDetailScreen({super.key, required this.propertyId});

  @override
  State<PropertyDetailScreen> createState() => _PropertyDetailScreenState();
}

class _PropertyDetailScreenState extends State<PropertyDetailScreen> {
  late Future<Property> _propertyFuture;
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isSaved = false;
  List<Property> _similarProperties = [];

  @override
  void initState() {
    super.initState();
    _loadProperty();
    _loadSimilarProperties();
  }

  void _loadProperty() {
    final apiService = context.read<ApiService>();
    _propertyFuture = apiService.getProperty(widget.propertyId);
    _propertyFuture.then((p) {
      if (mounted) setState(() => _isSaved = p.isSaved);
    });
  }

  void _loadSimilarProperties() async {
    try {
      final apiService = context.read<ApiService>();
      final similar = await apiService.getSimilarProperties(widget.propertyId);
      if (mounted) setState(() => _similarProperties = similar);
    } catch (_) {}
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _toggleSave() async {
    try {
      final apiService = context.read<ApiService>();
      await apiService.toggleSaveProperty(widget.propertyId, save: !_isSaved);
      if (mounted) setState(() => _isSaved = !_isSaved);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update saved status')),
        );
      }
    }
  }

  void _shareProperty(Property property) {
    final url = '${ApiConstants.baseUrl}/properties/${property.slug}/';
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<Property>(
        future: _propertyFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              appBar: AppBar(title: const Text('Property Details')),
              body: const Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasError) {
            return Scaffold(
              appBar: AppBar(title: const Text('Property Details')),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text('Failed to load property'),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => setState(() => _loadProperty()),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final property = snapshot.data!;
          final authService = context.watch<AuthService>();
          final isOwner = authService.userId == property.ownerId;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 300,
                pinned: true,
                actions: [
                  if (authService.isAuthenticated) ...[
                    IconButton(
                      icon: Icon(
                        _isSaved ? Icons.favorite : Icons.favorite_border,
                        color: _isSaved ? Colors.red : Colors.white,
                      ),
                      onPressed: _toggleSave,
                    ),
                  ],
                  IconButton(
                    icon: const Icon(Icons.share),
                    onPressed: () => _shareProperty(property),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: _buildImageCarousel(property),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Price and title
                      Text(
                        property.formattedPrice,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(
                              color: AppTheme.goldEmber,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              property.title,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          if (property.ownerIsVerified)
                            const Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: Chip(
                                label: Text('Verified',
                                    style: TextStyle(fontSize: 11)),
                                avatar:
                                    Icon(Icons.verified, size: 16, color: Colors.blue),
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        property.propertyTypeDisplay,
                        style:
                            TextStyle(color: Colors.grey[600], fontSize: 16),
                      ),
                      if (property.viewCount != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${property.viewCount} views',
                          style: TextStyle(
                              color: Colors.grey[500], fontSize: 13),
                        ),
                      ],

                      const SizedBox(height: 16),
                      _buildAddress(property),
                      const SizedBox(height: 16),
                      _buildDetails(property),

                      // EPC Rating
                      if (property.epcRating.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        EpcRatingBar(epcRating: property.epcRating),
                      ],

                      // Features
                      if (property.features.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Text('Features',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: property.features.map((f) {
                            return Chip(
                              label: Text(f.name),
                              avatar: f.icon.isNotEmpty
                                  ? Text(f.icon)
                                  : null,
                              visualDensity: VisualDensity.compact,
                            );
                          }).toList(),
                        ),
                      ],

                      // Description
                      if (property.description.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Text('Description',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(property.description),
                      ],

                      // Floorplans
                      if (property.floorplans.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Text('Floorplans',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 120,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: property.floorplans.length,
                            itemBuilder: (context, index) {
                              final fp = property.floorplans[index];
                              return GestureDetector(
                                onTap: () => _showFloorplan(fp.fileUrl, fp.title),
                                child: Container(
                                  width: 160,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey[300]!),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    children: [
                                      Expanded(
                                        child: CachedNetworkImage(
                                          imageUrl: ApiConstants.fullUrl(fp.fileUrl),
                                          fit: BoxFit.contain,
                                          errorWidget: (_, __, ___) =>
                                              const Icon(Icons.description, size: 40),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(4),
                                        child: Text(fp.title,
                                            style: const TextStyle(fontSize: 12),
                                            overflow: TextOverflow.ellipsis),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],

                      // Price History
                      if (property.priceHistory.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Text('Price History',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        ...property.priceHistory.asMap().entries.map((entry) {
                          final i = entry.key;
                          final ph = entry.value;
                          final prevPrice = i < property.priceHistory.length - 1
                              ? property.priceHistory[i + 1].price
                              : null;
                          final isUp = prevPrice != null && ph.price > prevPrice;
                          final isDown = prevPrice != null && ph.price < prevPrice;

                          String dateStr = ph.changedAt;
                          try {
                            final date = DateTime.parse(ph.changedAt);
                            dateStr = DateFormat('d MMM yyyy').format(date);
                          } catch (_) {}

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                if (isUp)
                                  const Icon(Icons.arrow_upward,
                                      size: 16, color: Colors.red)
                                else if (isDown)
                                  const Icon(Icons.arrow_downward,
                                      size: 16, color: Colors.green)
                                else
                                  const SizedBox(width: 16),
                                const SizedBox(width: 8),
                                Text(
                                  '\u00A3${ph.price.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                const Spacer(),
                                Text(dateStr,
                                    style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 13)),
                              ],
                            ),
                          );
                        }),
                      ],

                      // Owner actions
                      if (isOwner) ...[
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final result = await Navigator.push<bool>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          EditPropertyScreen(property: property),
                                    ),
                                  );
                                  if (result == true) {
                                    setState(() => _loadProperty());
                                  }
                                },
                                icon: const Icon(Icons.edit),
                                label: const Text('Edit'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          ImageManagementScreen(property: property),
                                    ),
                                  );
                                  setState(() => _loadProperty());
                                },
                                icon: const Icon(Icons.photo_library),
                                label: Text(
                                    'Photos (${property.images.length})'),
                              ),
                            ),
                          ],
                        ),
                      ],

                      // Contact forms (non-owners only)
                      if (!isOwner && authService.isAuthenticated) ...[
                        const SizedBox(height: 24),
                        EnquiryForm(
                          propertyId: property.id,
                          onSent: () {},
                        ),
                        const SizedBox(height: 8),
                        ViewingRequestForm(
                          propertyId: property.id,
                          onSent: () {},
                        ),
                      ],

                      if (!isOwner && !authService.isAuthenticated) ...[
                        const SizedBox(height: 24),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                const Text(
                                    'Log in to contact the seller or request a viewing'),
                                const SizedBox(height: 8),
                                ElevatedButton(
                                  onPressed: () => Navigator.pushNamed(
                                      context, '/login'),
                                  child: const Text('Log In'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],

                      // Calculators
                      const SizedBox(height: 24),
                      MortgageCalculator(propertyPrice: property.price),
                      const SizedBox(height: 8),
                      StampDutyCalculator(propertyPrice: property.price),

                      // Local Services
                      const SizedBox(height: 24),
                      ServiceProvidersSection(propertyId: property.id),

                      // Similar Properties
                      if (_similarProperties.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Text('Similar Properties',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 220,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _similarProperties.length,
                            itemBuilder: (context, index) {
                              final sp = _similarProperties[index];
                              return _buildSimilarCard(sp);
                            },
                          ),
                        ),
                      ],

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildImageCarousel(Property property) {
    if (property.images.isEmpty) {
      return Container(
        color: Colors.grey[200],
        child: const Center(
            child: Icon(Icons.home, size: 64, color: Colors.grey)),
      );
    }

    return Stack(
      children: [
        PageView.builder(
          controller: _pageController,
          itemCount: property.images.length,
          onPageChanged: (index) => setState(() => _currentPage = index),
          itemBuilder: (context, index) {
            final imageUrl =
                ApiConstants.fullUrl(property.images[index].imageUrl);
            return GestureDetector(
              onTap: () => _showFullScreenImage(property, index),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.grey[200],
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[200],
                  child: const Icon(Icons.broken_image,
                      size: 48, color: Colors.grey),
                ),
              ),
            );
          },
        ),
        if (property.images.length > 1)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                property.images.length,
                (index) => Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentPage == index
                        ? Colors.white
                        : Colors.white.withAlpha(128),
                  ),
                ),
              ),
            ),
          ),
        Positioned(
          bottom: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(128),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_currentPage + 1}/${property.images.length}',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }

  void _showFullScreenImage(Property property, int initialIndex) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: EdgeInsets.zero,
          backgroundColor: Colors.black,
          child: Stack(
            children: [
              PageView.builder(
                controller: PageController(initialPage: initialIndex),
                itemCount: property.images.length,
                itemBuilder: (context, index) {
                  return InteractiveViewer(
                    child: Center(
                      child: CachedNetworkImage(
                        imageUrl: ApiConstants.fullUrl(
                            property.images[index].imageUrl),
                        fit: BoxFit.contain,
                      ),
                    ),
                  );
                },
              ),
              Positioned(
                top: 40,
                right: 16,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showFloorplan(String fileUrl, String title) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                title: Text(title),
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              InteractiveViewer(
                child: CachedNetworkImage(
                  imageUrl: ApiConstants.fullUrl(fileUrl),
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAddress(Property property) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.location_on, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            [
              property.addressLine1,
              if (property.addressLine2.isNotEmpty) property.addressLine2,
              property.city,
              if (property.county.isNotEmpty) property.county,
              property.postcode,
            ].join(', '),
            style: const TextStyle(fontSize: 15),
          ),
        ),
      ],
    );
  }

  Widget _buildDetails(Property property) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _detailChip(Icons.bed, '${property.bedrooms}', 'Beds'),
        _detailChip(
            Icons.bathtub_outlined, '${property.bathrooms}', 'Baths'),
        _detailChip(Icons.weekend_outlined, '${property.receptionRooms}',
            'Recep'),
        if (property.squareFeet != null)
          _detailChip(
              Icons.square_foot, '${property.squareFeet}', 'sq ft'),
      ],
    );
  }

  Widget _detailChip(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, size: 24, color: Colors.grey[700]),
        const SizedBox(height: 4),
        Text(value,
            style:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label,
            style: TextStyle(color: Colors.grey[600], fontSize: 12)),
      ],
    );
  }

  Widget _buildSimilarCard(Property property) {
    final imageUrl = property.primaryImageUrl != null
        ? ApiConstants.fullUrl(property.primaryImageUrl!)
        : null;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PropertyDetailScreen(propertyId: property.id),
        ),
      ),
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(right: 12),
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (imageUrl != null)
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      color: Colors.grey[200],
                      child: const Icon(Icons.home, color: Colors.grey),
                    ),
                  ),
                )
              else
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Container(
                    color: Colors.grey[200],
                    child: const Icon(Icons.home, color: Colors.grey),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      property.formattedPrice,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.goldEmber,
                      ),
                    ),
                    Text(
                      property.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${property.bedrooms} bed | ${property.bathrooms} bath',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[600]),
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
}
