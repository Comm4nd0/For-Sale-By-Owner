import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../constants/app_theme.dart';
import '../constants/api_constants.dart';
import '../models/saved_property.dart';
import '../services/api_service.dart';
import 'property_detail_screen.dart';

class SavedPropertiesScreen extends StatefulWidget {
  const SavedPropertiesScreen({super.key});

  @override
  State<SavedPropertiesScreen> createState() => _SavedPropertiesScreenState();
}

class _SavedPropertiesScreenState extends State<SavedPropertiesScreen> {
  List<SavedProperty> _savedProperties = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSavedProperties();
  }

  Future<void> _loadSavedProperties() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final apiService = context.read<ApiService>();
      final response = await apiService.getSavedProperties();
      if (mounted) {
        setState(() {
          _savedProperties = response.results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load saved properties';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _removeSaved(SavedProperty saved) async {
    try {
      final apiService = context.read<ApiService>();
      await apiService.removeSavedProperty(saved.id);
      setState(() {
        _savedProperties.removeWhere((s) => s.id == saved.id);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Property removed from saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Properties'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(_error!, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _loadSavedProperties,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_savedProperties.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.favorite_border, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('No saved properties yet'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Browse Properties'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSavedProperties,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _savedProperties.length,
        itemBuilder: (context, index) {
          final saved = _savedProperties[index];
          final property = saved.propertyDetail;
          if (property == null) return const SizedBox.shrink();

          final imageUrl = property.primaryImageUrl != null
              ? ApiConstants.fullUrl(property.primaryImageUrl!)
              : null;

          return Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        PropertyDetailScreen(propertyId: property.id),
                  ),
                );
                _loadSavedProperties();
              },
              child: Row(
                children: [
                  SizedBox(
                    width: 120,
                    height: 100,
                    child: imageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.grey[200],
                              child: const Center(
                                  child: CircularProgressIndicator()),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey[200],
                              child: const Icon(Icons.broken_image,
                                  color: Colors.grey),
                            ),
                          )
                        : Container(
                            color: Colors.grey[200],
                            child: const Icon(Icons.home,
                                size: 32, color: Colors.grey),
                          ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            property.title,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            property.formattedPrice,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: AppTheme.goldEmber,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${property.addressLine1}, ${property.city}',
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.bed,
                                  size: 14, color: Colors.grey[600]),
                              const SizedBox(width: 2),
                              Text('${property.bedrooms}',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600])),
                              const SizedBox(width: 8),
                              Icon(Icons.bathtub_outlined,
                                  size: 14, color: Colors.grey[600]),
                              const SizedBox(width: 2),
                              Text('${property.bathrooms}',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600])),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => _removeSaved(saved),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
