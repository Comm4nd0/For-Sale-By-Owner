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
import '../widgets/branded_app_bar.dart';
import '../widgets/scroll_to_top_button.dart';
import '../models/viewing_slot.dart';
import 'make_offer_screen.dart';
import 'edit_offer_screen.dart';
import 'chat_screen.dart';
import 'viewing_slots_screen.dart';
import 'offers_screen.dart';
import 'login_screen.dart';
import 'register_screen.dart';
import 'open_house_screen.dart';
import 'neighbourhood_review_screen.dart';
import '../models/offer.dart';
import '../utils/auto_retry.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class PropertyDetailScreen extends StatefulWidget {
  final int propertyId;

  const PropertyDetailScreen({super.key, required this.propertyId});

  @override
  State<PropertyDetailScreen> createState() => _PropertyDetailScreenState();
}

class _PropertyDetailScreenState extends State<PropertyDetailScreen> with AutoRetryMixin {
  late Future<Property> _propertyFuture;
  final PageController _pageController = PageController();
  final ScrollController _scrollController = ScrollController();
  int _currentPage = 0;
  bool _isSaved = false;
  List<Property> _similarProperties = [];
  Offer? _existingOffer;

  @override
  void initState() {
    super.initState();
    _loadProperty();
    _loadSimilarProperties();
    _loadExistingOffer();
  }

  void _loadProperty() {
    final apiService = context.read<ApiService>();
    _propertyFuture = withRetry(() => apiService.getProperty(widget.propertyId));
    _propertyFuture.then((p) {
      if (mounted) setState(() => _isSaved = p.isSaved);
    });
  }

  void _loadExistingOffer() async {
    try {
      final apiService = context.read<ApiService>();
      final authService = context.read<AuthService>();
      if (!authService.isAuthenticated) return;
      final userId = authService.userId;
      final allOffers = await apiService.getOffers();
      final myOffers = allOffers
          .where((o) => o.propertyId == widget.propertyId && o.buyerId == userId)
          .toList();
      if (myOffers.isNotEmpty && mounted) {
        setState(() => _existingOffer = myOffers.first);
      }
    } catch (_) {}
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
    _scrollController.dispose();
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
    final url = '${ApiConstants.websiteUrl}/properties/${property.slug}/';
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: ScrollToTopButton(scrollController: _scrollController),
      body: FutureBuilder<Property>(
        future: _propertyFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              appBar: BrandedAppBar.build(context: context, showHomeButton: true),
              body: const Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasError) {
            return Scaffold(
              appBar: BrandedAppBar.build(context: context, showHomeButton: true),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    PhosphorIcon(PhosphorIconsDuotone.warningCircle,
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
            controller: _scrollController,
            slivers: [
              SliverAppBar(
                expandedHeight: 300,
                pinned: true,
                actions: [
                  if (authService.isAuthenticated) ...[
                    IconButton(
                      icon: PhosphorIcon(
                        PhosphorIconsDuotone.heart,
                        color: _isSaved ? Colors.red : Colors.white,
                      ),
                      onPressed: _toggleSave,
                    ),
                  ],
                  IconButton(
                    icon: PhosphorIcon(PhosphorIconsDuotone.shareFat),
                    onPressed: () => _shareProperty(property),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: _buildImageCarousel(property),
                ),
              ),
              SliverToBoxAdapter(
                child: _buildThumbnailStrip(property),
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
                                    PhosphorIcon(PhosphorIconsDuotone.sealCheck, size: 16, color: Colors.blue),
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
                                              PhosphorIcon(PhosphorIconsDuotone.fileText, size: 40),
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
                                  PhosphorIcon(PhosphorIconsDuotone.arrowUp,
                                      size: 16, color: Colors.red)
                                else if (isDown)
                                  PhosphorIcon(PhosphorIconsDuotone.arrowDown,
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
                                icon: PhosphorIcon(PhosphorIconsDuotone.pencilSimple),
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
                                icon: PhosphorIcon(PhosphorIconsDuotone.images),
                                label: Text(
                                    'Photos (${property.images.length})'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ViewingSlotsScreen(
                                      propertyId: property.id,
                                      isOwner: true,
                                    ),
                                  ),
                                ),
                                icon: PhosphorIcon(PhosphorIconsDuotone.calendar),
                                label: const Text('Viewing Slots'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const OffersScreen(received: true),
                                  ),
                                ),
                                icon: PhosphorIcon(PhosphorIconsDuotone.tag),
                                label: const Text('Offers'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => OpenHouseScreen(
                                      propertyId: property.id,
                                    ),
                                  ),
                                ),
                                icon: PhosphorIcon(PhosphorIconsDuotone.calendarCheck),
                                label: const Text('Open House'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _showListingQuality(property.id),
                                icon: PhosphorIcon(PhosphorIconsDuotone.star),
                                label: const Text('Quality Score'),
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
                        const SizedBox(height: 12),
                        _buildBuyerActionsCard(property),
                        _buildAvailableSlots(property.id),
                      ],

                      if (!isOwner && !authService.isAuthenticated) ...[
                        const SizedBox(height: 24),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Interested in this property?',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 12),
                                _buildLoginFeatureRow(
                                  PhosphorIconsDuotone.chat,
                                  'Message the seller',
                                ),
                                const SizedBox(height: 8),
                                _buildLoginFeatureRow(
                                  PhosphorIconsDuotone.calendar,
                                  'Book a viewing',
                                ),
                                const SizedBox(height: 8),
                                _buildLoginFeatureRow(
                                  PhosphorIconsDuotone.tag,
                                  'Make an offer',
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => const LoginScreen()),
                                  ),
                                  icon: PhosphorIcon(PhosphorIconsDuotone.signIn),
                                  label: const Text('Log in'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const RegisterScreen()),
                                  ),
                                  icon: PhosphorIcon(PhosphorIconsDuotone.userPlus),
                                  label: const Text('Create a free account'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],

                      // Open House Events (for non-owners)
                      if (!isOwner) ...[
                        const SizedBox(height: 16),
                        _buildOpenHouseSection(property),
                      ],

                      // Neighbourhood Reviews (only when postcode is available, i.e. owner)
                      if (property.postcode.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Card(
                          child: ListTile(
                            leading: PhosphorIcon(PhosphorIconsDuotone.buildings, color: AppTheme.forestMid),
                            title: const Text('Neighbourhood Reviews'),
                            subtitle: Text('See what residents say about ${property.postcode.split(' ').first}'),
                            trailing: PhosphorIcon(PhosphorIconsDuotone.caretRight),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => NeighbourhoodReviewScreen(
                                  postcode: property.postcode.split(' ').first,
                                ),
                              ),
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

  void _startChat(Property property) async {
    try {
      final apiService = context.read<ApiService>();
      final room = await apiService.getOrCreateChatRoom(property.id);
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(room: room),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to start conversation')),
        );
      }
    }
  }

  Color _offerStatusColor(String status) {
    switch (status) {
      case 'accepted': return Colors.green;
      case 'rejected': return Colors.red;
      case 'countered': return Colors.orange;
      case 'withdrawn': return Colors.grey;
      case 'expired': return Colors.grey;
      case 'under_review': return Colors.orange;
      default: return Colors.blue;
    }
  }

  Widget _buildLoginFeatureRow(PhosphorIconData icon, String text) {
    return Row(
      children: [
        PhosphorIcon(icon, size: 20, color: AppTheme.forestMid),
        const SizedBox(width: 12),
        Text(text, style: const TextStyle(fontSize: 14)),
      ],
    );
  }

  Widget _buildBuyerActionsCard(Property property) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _existingOffer != null ? 'Your Offer' : 'Interested?',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (_existingOffer != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _existingOffer!.formattedAmount,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _offerStatusColor(_existingOffer!.status),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _existingOffer!.statusDisplay,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_existingOffer!.counterAmount != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Counter offer: \u00A3${_existingOffer!.counterAmount!.toStringAsFixed(0)}',
                        style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w600),
                      ),
                    ],
                    if (_existingOffer!.sellerResponse != null && _existingOffer!.sellerResponse!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          PhosphorIcon(PhosphorIconsDuotone.arrowBendUpLeft, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _existingOffer!.sellerResponse!,
                              style: TextStyle(color: Colors.grey[700], fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (_existingOffer!.status == 'submitted') ...[
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EditOfferScreen(offer: _existingOffer!),
                            ),
                          );
                          if (result == true) _loadExistingOffer();
                        },
                        icon: PhosphorIcon(PhosphorIconsDuotone.pencilSimple, size: 16),
                        label: const Text('Edit Offer'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _withdrawExistingOffer(),
                        icon: PhosphorIcon(PhosphorIconsDuotone.arrowCounterClockwise, size: 16),
                        label: const Text('Withdraw'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else if (_existingOffer!.status == 'under_review' || _existingOffer!.status == 'countered') ...[
                OutlinedButton.icon(
                  onPressed: () => _withdrawExistingOffer(),
                  icon: PhosphorIcon(PhosphorIconsDuotone.arrowCounterClockwise, size: 16),
                  label: const Text('Withdraw Offer'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ] else if (_existingOffer!.status == 'rejected' || _existingOffer!.status == 'withdrawn' || _existingOffer!.status == 'expired') ...[
                ElevatedButton.icon(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MakeOfferScreen(
                          propertyId: property.id,
                          propertyTitle: property.title,
                          askingPrice: property.price,
                        ),
                      ),
                    );
                    if (result == true) _loadExistingOffer();
                  },
                  icon: PhosphorIcon(PhosphorIconsDuotone.tag),
                  label: const Text('Make New Offer'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ],
            ] else ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MakeOfferScreen(
                        propertyId: property.id,
                        propertyTitle: property.title,
                        askingPrice: property.price,
                      ),
                    ),
                  );
                  if (result == true) _loadExistingOffer();
                },
                icon: PhosphorIcon(PhosphorIconsDuotone.tag),
                label: const Text('Make an Offer'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ],
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _startChat(property),
              icon: PhosphorIcon(PhosphorIconsDuotone.chat),
              label: const Text('Message Seller'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _withdrawExistingOffer() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Withdraw Offer'),
        content: Text('Are you sure you want to withdraw your ${_existingOffer!.formattedAmount} offer?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final api = context.read<ApiService>();
      await api.withdrawOffer(_existingOffer!.id);
      _loadExistingOffer();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Offer withdrawn')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to withdraw offer')),
        );
      }
    }
  }

  void _showListingQuality(int propertyId) async {
    try {
      final api = context.read<ApiService>();
      final data = await api.getListingQualityScore(propertyId);
      if (!mounted) return;
      final score = data['score'] ?? 0;
      final tips = (data['tips'] as List?)?.cast<String>() ?? [];
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              PhosphorIcon(PhosphorIconsDuotone.star, color: const Color(0xFF115E66)),
              const SizedBox(width: 8),
              Text('Quality Score: $score/100'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearProgressIndicator(
                value: score / 100,
                backgroundColor: Colors.grey[200],
                color: score >= 80 ? Colors.green : score >= 50 ? Colors.orange : Colors.red,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
              if (tips.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Tips to improve:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...tips.map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PhosphorIcon(PhosphorIconsDuotone.lightbulb, size: 16, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(child: Text(t, style: const TextStyle(fontSize: 13))),
                    ],
                  ),
                )),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load quality score')),
        );
      }
    }
  }

  Widget _buildOpenHouseSection(Property property) {
    return FutureBuilder<List<dynamic>>(
      future: context.read<ApiService>().getOpenHouseEvents(propertyId: property.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox.shrink();
        final events = snapshot.data!;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Open House Events',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...events.take(3).map((e) {
                  final event = e is Map<String, dynamic> ? e : {};
                  return ListTile(
                    dense: true,
                    leading: PhosphorIcon(PhosphorIconsDuotone.calendarCheck, color: AppTheme.forestMid),
                    title: Text(event['title'] ?? 'Open House'),
                    subtitle: Text('${event['date'] ?? ''} ${event['start_time'] ?? ''} - ${event['end_time'] ?? ''}'),
                    trailing: (event['user_has_rsvpd'] == true)
                        ? const Chip(label: Text('RSVP\'d', style: TextStyle(fontSize: 11, color: Colors.white)), backgroundColor: Colors.green)
                        : TextButton(
                            onPressed: () async {
                              try {
                                await context.read<ApiService>().rsvpOpenHouse(event['id']);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('RSVP confirmed!')),
                                  );
                                  setState(() {});
                                }
                              } catch (err) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('RSVP failed: $err')),
                                  );
                                }
                              }
                            },
                            child: const Text('RSVP'),
                          ),
                  );
                }),
                if (events.length > 3)
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => OpenHouseScreen(propertyId: property.id)),
                    ),
                    child: Text('View all ${events.length} events'),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAvailableSlots(int propertyId) {
    return FutureBuilder<List<ViewingSlot>>(
      future: context.read<ApiService>().getViewingSlots(propertyId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }
        final slots = snapshot.data!
            .where((s) => s.isAvailable)
            .toList();
        if (slots.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Available Viewing Times',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...slots.take(5).map((slot) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            PhosphorIcon(PhosphorIconsDuotone.calendar,
                                size: 16, color: AppTheme.forestMid),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${slot.displayTitle}  ${slot.startTime} - ${slot.endTime}',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            TextButton(
                              onPressed: () => _bookSlot(propertyId, slot),
                              child: const Text('Book'),
                            ),
                          ],
                        ),
                      )),
                  if (slots.length > 5) ...[
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ViewingSlotsScreen(
                            propertyId: propertyId,
                            isOwner: false,
                          ),
                        ),
                      ),
                      child: Text('View all ${slots.length} slots'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _bookSlot(int propertyId, ViewingSlot slot) async {
    final authService = context.read<AuthService>();
    final name = [authService.firstName, authService.lastName]
        .where((s) => s != null && s.isNotEmpty)
        .join(' ');
    final email = authService.email ?? '';
    try {
      final apiService = context.read<ApiService>();
      await apiService.bookViewingSlot(propertyId, slot.id,
          name: name, email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Viewing slot booked!')),
        );
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  Widget _buildImageCarousel(Property property) {
    if (property.images.isEmpty) {
      return Container(
        color: Colors.grey[200],
        child: Center(
            child: PhosphorIcon(PhosphorIconsDuotone.house, size: 64, color: Colors.grey)),
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
                  child: PhosphorIcon(PhosphorIconsDuotone.imageSquare,
                      size: 48, color: Colors.grey),
                ),
              ),
            );
          },
        ),
        Positioned(
          bottom: 8,
          right: 12,
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

  Widget _buildThumbnailStrip(Property property) {
    if (property.images.length <= 1) return const SizedBox.shrink();
    return SizedBox(
      height: 56,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        itemCount: property.images.length,
        itemBuilder: (context, index) {
          final thumbUrl = property.images[index].thumbnailUrl != null
              ? ApiConstants.fullUrl(property.images[index].thumbnailUrl!)
              : ApiConstants.fullUrl(property.images[index].imageUrl);
          final isActive = _currentPage == index;
          return GestureDetector(
            onTap: () => _pageController.animateToPage(
              index,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            ),
            child: Container(
              width: 72,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isActive ? const Color(0xFF115E66) : Colors.transparent,
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: Opacity(
                  opacity: isActive ? 1.0 : 0.5,
                  child: CachedNetworkImage(
                    imageUrl: thumbUrl,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          );
        },
      ),
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
                  icon: PhosphorIcon(PhosphorIconsDuotone.x, color: Colors.white, size: 30),
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
                    icon: PhosphorIcon(PhosphorIconsDuotone.x),
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
    final parts = <String>[
      if (property.addressLine1.isNotEmpty) property.addressLine1,
      property.city,
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PhosphorIcon(PhosphorIconsDuotone.mapPin, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                parts.join(', '),
                style: const TextStyle(fontSize: 15),
              ),
              if (property.addressLine1.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Full address available from the seller',
                    style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetails(Property property) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _detailChip(PhosphorIconsDuotone.bed, '${property.bedrooms}', 'Beds'),
        _detailChip(
            PhosphorIconsDuotone.bathtub, '${property.bathrooms}', 'Baths'),
        _detailChip(PhosphorIconsDuotone.armchair, '${property.receptionRooms}',
            'Recep'),
        if (property.squareFeet != null)
          _detailChip(
              PhosphorIconsDuotone.ruler, '${property.squareFeet}', 'sq ft'),
      ],
    );
  }

  Widget _detailChip(PhosphorIconData icon, String value, String label) {
    return Column(
      children: [
        PhosphorIcon(icon, size: 24, color: Colors.grey[700]),
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
                      child: PhosphorIcon(PhosphorIconsDuotone.house, color: Colors.grey),
                    ),
                  ),
                )
              else
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Container(
                    color: Colors.grey[200],
                    child: PhosphorIcon(PhosphorIconsDuotone.house, color: Colors.grey),
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
