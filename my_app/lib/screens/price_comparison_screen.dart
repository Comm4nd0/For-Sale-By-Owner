import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../widgets/branded_app_bar.dart';
import 'package:intl/intl.dart';

class PriceComparisonScreen extends StatefulWidget {
  const PriceComparisonScreen({super.key});
  @override
  State<PriceComparisonScreen> createState() => _PriceComparisonScreenState();
}

class _PriceComparisonScreenState extends State<PriceComparisonScreen> {
  final _postcodeController = TextEditingController();
  final _currencyFormat = NumberFormat.currency(locale: 'en_GB', symbol: '\u00A3', decimalDigits: 0);
  bool _loading = false;
  Map<String, dynamic>? _data;
  String? _error;

  Future<void> _search() async {
    final postcode = _postcodeController.text.trim();
    if (postcode.isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      final api = context.read<ApiService>();
      final data = await api.getPriceComparison(postcode);
      setState(() { _data = data; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BrandedAppBar.build(context: context, showHomeButton: true),
      body: Column(
        children: [
          Container(
            color: const Color(0xFF115E66),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("What's My Home Worth?", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text('Compare sold prices and local listings', style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _postcodeController,
                        decoration: InputDecoration(
                          hintText: 'Enter postcode (e.g. BS1 4DJ)',
                          filled: true, fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        textCapitalization: TextCapitalization.characters,
                        onSubmitted: (_) => _search(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _loading ? null : _search,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF115E66)),
                      child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Search'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_error != null) Padding(padding: const EdgeInsets.all(16), child: Text(_error!, style: const TextStyle(color: Colors.red))),
          if (_data != null) Expanded(child: _buildResults()),
          if (_data == null && !_loading && _error == null)
            const Expanded(child: Center(child: Text('Enter a postcode to see price comparisons', style: TextStyle(color: Colors.grey)))),
        ],
      ),
    );
  }

  Widget _buildResults() {
    final stats = _data!['statistics'] as Map<String, dynamic>? ?? {};
    final sold = _data!['sold_prices'] as List? ?? [];
    final listings = _data!['local_listings'] as List? ?? [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (stats.isNotEmpty) ...[
          Wrap(
            spacing: 8, runSpacing: 8,
            children: [
              if (stats['average_price'] != null) _statCard('Average', _currencyFormat.format(stats['average_price'])),
              if (stats['median_price'] != null) _statCard('Median', _currencyFormat.format(stats['median_price'])),
              if (stats['min_price'] != null) _statCard('Lowest', _currencyFormat.format(stats['min_price'])),
              if (stats['max_price'] != null) _statCard('Highest', _currencyFormat.format(stats['max_price'])),
              if (stats['avg_price_per_sqft'] != null) _statCard('Avg/sqft', _currencyFormat.format(stats['avg_price_per_sqft'])),
              if (stats['total_comparables'] != null) _statCard('Comparables', '${stats['total_comparables']}'),
            ],
          ),
          const SizedBox(height: 16),
        ],
        if (sold.isNotEmpty) ...[
          const Text('Recent Sold Prices (Land Registry)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF115E66))),
          const SizedBox(height: 8),
          ...sold.take(10).map((s) => ListTile(
            dense: true,
            title: Text(s['address'] ?? 'Unknown'),
            subtitle: Text('${(s['date'] ?? '').toString().substring(0, 10.clamp(0, (s['date'] ?? '').toString().length))} - ${s['property_type'] ?? ''}'),
            trailing: Text(_currencyFormat.format(s['price'] ?? 0), style: const TextStyle(fontWeight: FontWeight.bold)),
          )),
          const SizedBox(height: 16),
        ],
        if (listings.isNotEmpty) ...[
          const Text('Current FSBO Listings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF115E66))),
          const SizedBox(height: 8),
          ...listings.take(10).map((l) => ListTile(
            dense: true,
            title: Text(l['title'] ?? ''),
            subtitle: Text('${l['bedrooms'] ?? '-'} bed - ${l['property_type'] ?? ''}'),
            trailing: Text(_currencyFormat.format(l['price'] ?? 0), style: const TextStyle(fontWeight: FontWeight.bold)),
          )),
        ],
        if (sold.isEmpty && listings.isEmpty)
          const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No data found for this postcode'))),
      ],
    );
  }

  Widget _statCard(String label, String value) {
    return Container(
      width: 110, padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF115E66))),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }
}
