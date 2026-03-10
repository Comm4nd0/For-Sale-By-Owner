import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../constants/app_theme.dart';
import '../widgets/branded_app_bar.dart';
import '../widgets/skeleton_loading.dart';

class HousePricesScreen extends StatefulWidget {
  const HousePricesScreen({super.key});

  @override
  State<HousePricesScreen> createState() => _HousePricesScreenState();
}

class _HousePricesScreenState extends State<HousePricesScreen> {
  final _postcodeController = TextEditingController();
  List<SoldPrice> _results = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  String? _error;
  final _currencyFormat = NumberFormat.currency(locale: 'en_GB', symbol: '\u00A3', decimalDigits: 0);

  @override
  void dispose() {
    _postcodeController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final postcode = _postcodeController.text.trim();
    if (postcode.isEmpty) return;

    setState(() {
      _isLoading = true;
      _hasSearched = true;
      _error = null;
      _results = [];
    });

    try {
      final uri = Uri.https(
        'landregistry.data.gov.uk',
        '/data/ppi/transaction-record.json',
        {
          'propertyAddress.postcode': postcode.toUpperCase(),
          '_pageSize': '50',
          '_sort': '-transactionDate',
        },
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 30));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['result']?['items'] as List<dynamic>? ?? [];

        final results = items.map((item) {
          final address = item['propertyAddress'] ?? {};
          return SoldPrice(
            price: (item['pricePaid'] as num?)?.toInt() ?? 0,
            date: item['transactionDate'] as String? ?? '',
            paon: address['paon'] as String? ?? '',
            saon: address['saon'] as String? ?? '',
            street: address['street'] as String? ?? '',
            town: address['town'] as String? ?? '',
            postcode: address['postcode'] as String? ?? '',
            propertyType: _mapPropertyType(item['propertyType'] as String? ?? ''),
            newBuild: item['newBuild'] == true,
          );
        }).toList();

        setState(() {
          _results = results;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load data (${response.statusCode}). Please check the postcode and try again.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not connect to Land Registry. Please try again.\n($e)';
        _isLoading = false;
      });
    }
  }

  String _mapPropertyType(String type) {
    switch (type) {
      case 'lrcommon:detached':
        return 'Detached';
      case 'lrcommon:semi-detached':
        return 'Semi-Detached';
      case 'lrcommon:terraced':
        return 'Terraced';
      case 'lrcommon:flat-maisonette':
        return 'Flat/Maisonette';
      default:
        return type.replaceAll('lrcommon:', '').replaceAll('-', ' ');
    }
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('d MMM yyyy').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  int? _averagePrice() {
    if (_results.isEmpty) return null;
    final total = _results.fold<int>(0, (sum, r) => sum + r.price);
    return total ~/ _results.length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BrandedAppBar.build(context: context, showHomeButton: true),
      body: Column(
        children: [
          // Search header
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.forestDeep, Color(0xFF1A6570)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'House Price Lookup',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Search sold prices from HM Land Registry public records',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withAlpha(200),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _postcodeController,
                        style: const TextStyle(color: AppTheme.charcoal),
                        decoration: InputDecoration(
                          hintText: 'Enter postcode, e.g. SW1A 1AA',
                          filled: true,
                          fillColor: Colors.white,
                          prefixIcon: const Icon(Icons.location_on_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        textCapitalization: TextCapitalization.characters,
                        onSubmitted: (_) => _search(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _search,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.goldWarm,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Search', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Results
          Expanded(child: _buildResults()),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (!_hasSearched) {
      return _buildInitialState();
    }

    if (_isLoading) {
      return const SkeletonList(count: 5);
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 56, color: AppTheme.stone),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.slate),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _search,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off, size: 56, color: AppTheme.stone),
              const SizedBox(height: 16),
              const Text(
                'No sold prices found for this postcode',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.charcoal),
              ),
              const SizedBox(height: 8),
              const Text(
                'Try a different postcode or check the format',
                style: TextStyle(color: AppTheme.slate),
              ),
            ],
          ),
        ),
      );
    }

    final avg = _averagePrice();

    return Column(
      children: [
        // Summary bar
        if (avg != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            color: AppTheme.forestMist,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_results.length} sold prices found',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.forestDeep,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Average: ${_currencyFormat.format(avg)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.forestMid,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.forestDeep,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _postcodeController.text.trim().toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: _results.length,
            itemBuilder: (context, index) {
              final r = _results[index];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Price badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.forestMist,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _currencyFormat.format(r.price),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppTheme.forestDeep,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              r.fullAddress,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: AppTheme.charcoal,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.calendar_today, size: 13, color: AppTheme.stone),
                                const SizedBox(width: 4),
                                Text(
                                  _formatDate(r.date),
                                  style: const TextStyle(fontSize: 12, color: AppTheme.slate),
                                ),
                                const SizedBox(width: 12),
                                Icon(Icons.home_outlined, size: 13, color: AppTheme.stone),
                                const SizedBox(width: 4),
                                Text(
                                  r.propertyType,
                                  style: const TextStyle(fontSize: 12, color: AppTheme.slate),
                                ),
                                if (r.newBuild) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.goldSoft,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'New Build',
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.goldEmber),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInitialState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 32),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.forestMist,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.trending_up, size: 40, color: AppTheme.forestMid),
          ),
          const SizedBox(height: 20),
          const Text(
            'Discover Sold Prices',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.charcoal,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Search publicly available HM Land Registry data to see what properties have sold for in any area.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.slate, height: 1.5),
          ),
          const SizedBox(height: 32),
          _infoTile(
            Icons.search,
            'Search by postcode',
            'Enter any UK postcode to see recent sold prices in that area.',
          ),
          _infoTile(
            Icons.bar_chart,
            'Average prices',
            'See the average sold price to understand local market values.',
          ),
          _infoTile(
            Icons.verified_outlined,
            'Official data',
            'All data comes directly from HM Land Registry public records.',
          ),
        ],
      ),
    );
  }

  Widget _infoTile(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.forestMist,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.forestMid, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.charcoal)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 13, color: AppTheme.slate)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SoldPrice {
  final int price;
  final String date;
  final String paon;
  final String saon;
  final String street;
  final String town;
  final String postcode;
  final String propertyType;
  final bool newBuild;

  SoldPrice({
    required this.price,
    required this.date,
    required this.paon,
    required this.saon,
    required this.street,
    required this.town,
    required this.postcode,
    required this.propertyType,
    required this.newBuild,
  });

  String get fullAddress {
    final parts = <String>[];
    if (saon.isNotEmpty) parts.add(saon);
    if (paon.isNotEmpty) parts.add(paon);
    if (street.isNotEmpty) parts.add(street);
    if (town.isNotEmpty) parts.add(town);
    return parts.join(', ');
  }
}
