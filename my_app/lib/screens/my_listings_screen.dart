import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../constants/app_theme.dart';
import '../constants/api_constants.dart';
import '../models/property.dart';
import '../services/api_service.dart';
import 'property_detail_screen.dart';
import 'create_property_screen.dart';
import 'edit_property_screen.dart';

class MyListingsScreen extends StatefulWidget {
  const MyListingsScreen({super.key});

  @override
  State<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends State<MyListingsScreen> {
  List<Property> _properties = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadListings();
  }

  Future<void> _loadListings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final apiService = context.read<ApiService>();
      final response = await apiService.getProperties(mine: true);
      if (mounted) {
        setState(() {
          _properties = response.results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load listings';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteProperty(Property property) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Property'),
        content: Text(
            'Are you sure you want to delete "${property.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final apiService = context.read<ApiService>();
      await apiService.deleteProperty(property.id);
      _loadListings();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Property deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    }
  }

  void _showPropertyActions(Property property) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(context);
                _navigateToEdit(property);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title:
                  const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deleteProperty(property);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _navigateToEdit(Property property) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditPropertyScreen(property: property),
      ),
    );
    if (result == true) {
      _loadListings();
    }
  }

  void _navigateToCreate() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreatePropertyScreen()),
    );
    _loadListings();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'draft':
        return Colors.grey;
      case 'active':
        return Colors.green;
      case 'under_offer':
        return Colors.orange;
      case 'sold_stc':
      case 'sold':
        return Colors.red;
      case 'pending_review':
        return Colors.blue;
      case 'withdrawn':
        return Colors.grey[600]!;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Listings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _navigateToCreate,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToCreate,
        child: const Icon(Icons.add),
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
              onPressed: _loadListings,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_properties.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.home_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('No listings yet'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _navigateToCreate,
              child: const Text('Create Your First Listing'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadListings,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _properties.length,
        itemBuilder: (context, index) {
          final property = _properties[index];
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
                _loadListings();
              },
              onLongPress: () => _showPropertyActions(property),
              child: Row(
                children: [
                  SizedBox(
                    width: 120,
                    height: 110,
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
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _statusColor(property.status),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              property.statusDisplay,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
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
                              if (property.viewCount != null) ...[
                                const SizedBox(width: 8),
                                Icon(Icons.visibility,
                                    size: 14, color: Colors.grey[600]),
                                const SizedBox(width: 2),
                                Text('${property.viewCount}',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600])),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
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
