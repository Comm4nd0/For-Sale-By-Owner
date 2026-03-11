import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../models/neighbourhood_info.dart';

class NeighbourhoodScreen extends StatefulWidget {
  final int propertyId;
  const NeighbourhoodScreen({super.key, required this.propertyId});

  @override
  State<NeighbourhoodScreen> createState() => _NeighbourhoodScreenState();
}

class _NeighbourhoodScreenState extends State<NeighbourhoodScreen> {
  NeighbourhoodInfo? _info;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final api = context.read<ApiService>();
      final info = await api.getNeighbourhoodInfo(widget.propertyId);
      if (mounted) setState(() { _info = info; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Neighbourhood')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Failed to load: $_error'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_info?.postcodeData != null) ...[
                        Text('Area Info', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                if (_info!.postcodeData!['admin_district'] != null)
                                  _infoRow('District', _info!.postcodeData!['admin_district']),
                                if (_info!.postcodeData!['parish'] != null)
                                  _infoRow('Parish', _info!.postcodeData!['parish']),
                                if (_info!.postcodeData!['region'] != null)
                                  _infoRow('Region', _info!.postcodeData!['region']),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (_info?.crimeData != null) ...[
                        Text('Crime Data', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: _info!.crimeData!.entries.isEmpty
                                ? const Text('No crime data available')
                                : Column(
                                    children: _info!.crimeData!.entries
                                        .map((e) => _infoRow(e.key, e.value.toString()))
                                        .toList(),
                                  ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
