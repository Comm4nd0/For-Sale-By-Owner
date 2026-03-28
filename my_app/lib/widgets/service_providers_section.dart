import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import '../constants/api_constants.dart';
import '../constants/app_theme.dart';
import '../models/service_provider.dart';
import '../services/api_service.dart';
import '../screens/service_provider_detail_screen.dart';
import '../screens/services_screen.dart';

class ServiceProvidersSection extends StatefulWidget {
  final int propertyId;

  const ServiceProvidersSection({super.key, required this.propertyId});

  @override
  State<ServiceProvidersSection> createState() =>
      _ServiceProvidersSectionState();
}

class _ServiceProvidersSectionState extends State<ServiceProvidersSection> {
  List<ServiceProvider>? _providers;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final apiService = context.read<ApiService>();
      final providers = await apiService.getPropertyServices(widget.propertyId);
      if (mounted) setState(() => _providers = providers);
    } catch (_) {
      if (mounted) setState(() => _providers = []);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_providers == null || _providers!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Local Services',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.forestDeep,
              ),
            ),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ServicesScreen()),
              ),
              child: const Text('View all'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _providers!.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final p = _providers![index];
              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ServiceProviderDetailScreen(providerId: p.id),
                  ),
                ),
                child: Container(
                  width: 200,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.pebble),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: p.logoUrl != null
                                ? Image.network(
                                    ApiConstants.fullUrl(p.logoUrl!),
                                    width: 36,
                                    height: 36,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        _miniLogo(),
                                  )
                                : _miniLogo(),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              p.businessName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: AppTheme.forestDeep,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        p.categories.map((c) => c.name).join(', '),
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.slate),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      if (p.averageRating != null)
                        Row(
                          children: [
                            PhosphorIcon(PhosphorIconsDuotone.star,
                                size: 13, color: AppTheme.goldEmber),
                            const SizedBox(width: 2),
                            Text(
                              '${p.averageRating!.toStringAsFixed(1)} (${p.reviewCount})',
                              style: const TextStyle(
                                  fontSize: 11, color: AppTheme.slate),
                            ),
                          ],
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

  Widget _miniLogo() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppTheme.forestMist,
        borderRadius: BorderRadius.circular(6),
      ),
      child: PhosphorIcon(PhosphorIconsDuotone.buildings, size: 18, color: AppTheme.stone),
    );
  }
}
