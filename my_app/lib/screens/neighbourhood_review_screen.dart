import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../models/neighbourhood_review.dart';
import '../widgets/branded_app_bar.dart';

const Color _primaryColor = Color(0xFF115E66);

// =============================================================================
// NeighbourhoodReviewScreen
// =============================================================================

class NeighbourhoodReviewScreen extends StatefulWidget {
  final String? postcode;
  const NeighbourhoodReviewScreen({super.key, this.postcode});

  @override
  State<NeighbourhoodReviewScreen> createState() =>
      _NeighbourhoodReviewScreenState();
}

class _NeighbourhoodReviewScreenState extends State<NeighbourhoodReviewScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<NeighbourhoodReview> _reviews = [];
  NeighbourhoodSummary? _summary;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.postcode != null && widget.postcode!.isNotEmpty) {
      _searchController.text = widget.postcode!;
      _search();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final postcode = _searchController.text.trim();
    if (postcode.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = context.read<ApiService>();
      final results = await Future.wait([
        api.getNeighbourhoodReviews(postcodeArea: postcode),
        api.getNeighbourhoodSummary(postcode),
      ]);

      final reviewList = (results[0] as List<dynamic>)
          .map<NeighbourhoodReview>(
              (j) => NeighbourhoodReview.fromJson(j as Map<String, dynamic>))
          .toList();
      final summary =
          NeighbourhoodSummary.fromJson(results[1] as Map<String, dynamic>);

      if (!mounted) return;
      setState(() {
        _reviews = reviewList;
        _summary = summary;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _openAddReview() {
    if (!context.read<AuthService>().isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to add a neighbourhood review'),
        ),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _AddReviewSheet(
        initialPostcode: _searchController.text.trim(),
        onSubmitted: _search,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BrandedAppBar.build(context: context, showHomeButton: true),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _primaryColor,
        onPressed: _openAddReview,
        child: PhosphorIcon(PhosphorIconsDuotone.chatText, color: Colors.white),
      ),
      body: Column(
        children: [
          // ── Search bar ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: 'Enter postcode area (e.g. SW1)',
                      prefixIcon: PhosphorIcon(PhosphorIconsDuotone.magnifyingGlass),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: _primaryColor, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _search,
                  child: const Text('Search'),
                ),
              ],
            ),
          ),

          // ── Body ────────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              PhosphorIcon(PhosphorIconsDuotone.warningCircle,
                                  size: 48, color: Colors.red),
                              const SizedBox(height: 12),
                              Text('Failed to load reviews',
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 4),
                              Text(_error!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.grey)),
                              const SizedBox(height: 16),
                              OutlinedButton(
                                onPressed: _search,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _summary == null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                PhosphorIcon(PhosphorIconsDuotone.buildings,
                                    size: 64,
                                    color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                Text(
                                  'Search for a postcode area\nto see neighbourhood reviews',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 16),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _search,
                            child: ListView(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                              children: [
                                _SummaryCard(summary: _summary!),
                                const SizedBox(height: 16),
                                Text(
                                  'Reviews (${_reviews.length})',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                if (_reviews.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 32),
                                    child: Center(
                                      child: Text(
                                        'No reviews yet for this area.\nBe the first to leave one!',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                    ),
                                  ),
                                ..._reviews.map((r) => _ReviewCard(review: r)),
                              ],
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Summary card showing average ratings
// =============================================================================

class _SummaryCard extends StatelessWidget {
  final NeighbourhoodSummary summary;
  const _SummaryCard({required this.summary});

  static const _labels = {
    'overall_rating': 'Overall',
    'community_rating': 'Community',
    'noise_rating': 'Noise',
    'parking_rating': 'Parking',
    'shops_rating': 'Shops',
    'safety_rating': 'Safety',
    'schools_rating': 'Schools',
    'transport_rating': 'Transport',
  };

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                PhosphorIcon(PhosphorIconsDuotone.chartBar, color: _primaryColor),
                const SizedBox(width: 8),
                Text(
                  '${summary.postcodeArea} Summary',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _primaryColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${summary.reviewCount} review${summary.reviewCount == 1 ? '' : 's'}',
                    style: const TextStyle(
                        color: _primaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            ..._labels.entries.map((entry) {
              final value = summary.ratings[entry.key];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 90,
                      child: Text(entry.value,
                          style: const TextStyle(fontSize: 13)),
                    ),
                    Expanded(child: _StarBar(rating: value ?? 0)),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 30,
                      child: Text(
                        value != null ? value.toStringAsFixed(1) : '—',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Star bar – shows filled / half / empty stars for a 0-5 rating
// =============================================================================

class _StarBar extends StatelessWidget {
  final double rating;
  final double size;
  const _StarBar({required this.rating, this.size = 18});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final starValue = i + 1;
        if (rating >= starValue) {
          return PhosphorIcon(PhosphorIconsDuotone.star, color: Colors.amber, size: size);
        } else if (rating >= starValue - 0.5) {
          return PhosphorIcon(PhosphorIconsDuotone.starHalf, color: Colors.amber, size: size);
        } else {
          return PhosphorIcon(PhosphorIconsDuotone.star, color: Colors.amber, size: size);
        }
      }),
    );
  }
}

// =============================================================================
// Individual review card
// =============================================================================

class _ReviewCard extends StatelessWidget {
  final NeighbourhoodReview review;
  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _primaryColor.withAlpha(30),
                  radius: 18,
                  child: Text(
                    review.reviewerName.isNotEmpty
                        ? review.reviewerName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        color: _primaryColor, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(review.reviewerName,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      Row(
                        children: [
                          if (review.isCurrentResident)
                            Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text('Current resident',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.green.shade700)),
                            ),
                          if (review.yearsLived != null)
                            Text(
                              '${review.yearsLived} yr${review.yearsLived == 1 ? '' : 's'} lived',
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                _StarBar(rating: review.overallRating.toDouble(), size: 16),
              ],
            ),
            const SizedBox(height: 12),

            // Comment
            if (review.comment.isNotEmpty) ...[
              Text(review.comment, style: const TextStyle(height: 1.4)),
              const SizedBox(height: 12),
            ],

            // Sub-ratings grid
            _subRatingsGrid(),

            // Date
            Text(
              _formatDate(review.createdAt),
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _subRatingsGrid() {
    final subs = <String, int?>{
      'Community': review.communityRating,
      'Noise': review.noiseRating,
      'Parking': review.parkingRating,
      'Shops': review.shopsRating,
      'Safety': review.safetyRating,
      'Schools': review.schoolsRating,
      'Transport': review.transportRating,
    };
    final present =
        subs.entries.where((e) => e.value != null).toList();
    if (present.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        children: present.map((e) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${e.key}: ',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              _StarBar(rating: e.value!.toDouble(), size: 14),
            ],
          );
        }).toList(),
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }
}

// =============================================================================
// Add review bottom sheet
// =============================================================================

class _AddReviewSheet extends StatefulWidget {
  final String initialPostcode;
  final VoidCallback onSubmitted;
  const _AddReviewSheet({
    required this.initialPostcode,
    required this.onSubmitted,
  });

  @override
  State<_AddReviewSheet> createState() => _AddReviewSheetState();
}

class _AddReviewSheetState extends State<_AddReviewSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _postcodeCtrl;
  late final TextEditingController _commentCtrl;
  late final TextEditingController _yearsCtrl;

  int _overallRating = 0;
  int? _communityRating;
  int? _noiseRating;
  int? _parkingRating;
  int? _shopsRating;
  int? _safetyRating;
  int? _schoolsRating;
  int? _transportRating;
  bool _isCurrentResident = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _postcodeCtrl = TextEditingController(text: widget.initialPostcode);
    _commentCtrl = TextEditingController();
    _yearsCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _postcodeCtrl.dispose();
    _commentCtrl.dispose();
    _yearsCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_overallRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an overall rating')),
      );
      return;
    }

    setState(() => _submitting = true);

    final data = <String, dynamic>{
      'postcode_area': _postcodeCtrl.text.trim().toUpperCase(),
      'overall_rating': _overallRating,
      'comment': _commentCtrl.text.trim(),
      'is_current_resident': _isCurrentResident,
    };
    if (_communityRating != null) data['community_rating'] = _communityRating;
    if (_noiseRating != null) data['noise_rating'] = _noiseRating;
    if (_parkingRating != null) data['parking_rating'] = _parkingRating;
    if (_shopsRating != null) data['shops_rating'] = _shopsRating;
    if (_safetyRating != null) data['safety_rating'] = _safetyRating;
    if (_schoolsRating != null) data['schools_rating'] = _schoolsRating;
    if (_transportRating != null) data['transport_rating'] = _transportRating;
    if (_yearsCtrl.text.trim().isNotEmpty) {
      data['years_lived'] = int.tryParse(_yearsCtrl.text.trim());
    }

    try {
      final api = context.read<ApiService>();
      await api.createNeighbourhoodReview(data);
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onSubmitted();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review submitted successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Add a Review',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              // Postcode
              TextFormField(
                controller: _postcodeCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Postcode Area',
                  hintText: 'e.g. SW1',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // Overall rating (required)
              const Text('Overall Rating *',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              _TappableStarRow(
                rating: _overallRating,
                onChanged: (v) => setState(() => _overallRating = v),
              ),
              const SizedBox(height: 16),

              // Optional sub-ratings
              const Text('Category Ratings (optional)',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: Colors.grey)),
              const SizedBox(height: 8),
              _optionalRatingRow('Community', _communityRating,
                  (v) => setState(() => _communityRating = v)),
              _optionalRatingRow('Noise', _noiseRating,
                  (v) => setState(() => _noiseRating = v)),
              _optionalRatingRow('Parking', _parkingRating,
                  (v) => setState(() => _parkingRating = v)),
              _optionalRatingRow('Shops', _shopsRating,
                  (v) => setState(() => _shopsRating = v)),
              _optionalRatingRow('Safety', _safetyRating,
                  (v) => setState(() => _safetyRating = v)),
              _optionalRatingRow('Schools', _schoolsRating,
                  (v) => setState(() => _schoolsRating = v)),
              _optionalRatingRow('Transport', _transportRating,
                  (v) => setState(() => _transportRating = v)),
              const SizedBox(height: 16),

              // Comment
              TextFormField(
                controller: _commentCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Comment',
                  hintText: 'Share your experience of this area...',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // Years lived
              TextFormField(
                controller: _yearsCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Years Lived (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              // Current resident toggle
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Current Resident'),
                activeColor: _primaryColor,
                value: _isCurrentResident,
                onChanged: (v) => setState(() => _isCurrentResident = v),
              ),
              const SizedBox(height: 16),

              // Submit
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Submit Review',
                          style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _optionalRatingRow(
      String label, int? current, ValueChanged<int?> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: const TextStyle(fontSize: 13)),
          ),
          _TappableStarRow(
            rating: current ?? 0,
            onChanged: (v) => onChanged(v == current ? null : v),
            size: 22,
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Tappable star row for input
// =============================================================================

class _TappableStarRow extends StatelessWidget {
  final int rating;
  final ValueChanged<int> onChanged;
  final double size;
  const _TappableStarRow({
    required this.rating,
    required this.onChanged,
    this.size = 32,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final starValue = i + 1;
        return GestureDetector(
          onTap: () => onChanged(starValue),
          child: Padding(
            padding: const EdgeInsets.only(right: 4),
            child: PhosphorIcon(
              PhosphorIconsDuotone.star,
              color: starValue <= rating ? Colors.amber : Colors.grey.shade400,
              size: size,
            ),
          ),
        );
      }),
    );
  }
}
