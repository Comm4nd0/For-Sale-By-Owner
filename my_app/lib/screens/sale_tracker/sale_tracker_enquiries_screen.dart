import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import '../../constants/app_theme.dart';
import '../../models/sale_enquiry.dart';
import '../../services/api_service.dart';
import '../../widgets/branded_app_bar.dart';
import '../../widgets/ownership_badge.dart';

class SaleTrackerEnquiriesScreen extends StatefulWidget {
  final int saleId;
  const SaleTrackerEnquiriesScreen({super.key, required this.saleId});

  @override
  State<SaleTrackerEnquiriesScreen> createState() =>
      _SaleTrackerEnquiriesScreenState();
}

class _SaleTrackerEnquiriesScreenState
    extends State<SaleTrackerEnquiriesScreen> {
  List<SaleEnquiry> _enquiries = [];
  bool _loading = true;
  final Set<int> _expandedIds = {};

  static const _ownerChoices = {
    'seller': 'You (Seller)',
    'seller_conveyancer': 'Your Conveyancer',
    'buyer': 'Buyer',
    'buyer_conveyancer': "Buyer's Conveyancer",
    'estate_agent': 'Estate Agent',
    'lender': 'Lender',
    'freeholder_or_managing_agent': 'Freeholder / Managing Agent',
    'surveyor': 'Surveyor',
    'local_authority_or_search_provider': 'Local Authority / Search Provider',
    'other': 'Other',
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final api = context.read<ApiService>();
      final json = await api.getSaleEnquiries(widget.saleId);
      if (mounted) {
        setState(() {
          _enquiries =
              json.map((e) => SaleEnquiry.fromJson(e)).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load enquiries: $e')),
        );
      }
    }
  }

  Future<void> _createEnquiry() async {
    final questionController = TextEditingController();
    final raisedByController = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Enquiry'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: raisedByController,
              decoration: const InputDecoration(labelText: 'Raised By'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: questionController,
              decoration: const InputDecoration(labelText: 'Question'),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (questionController.text.trim().isEmpty) return;
              Navigator.pop(ctx, {
                'raised_by': raisedByController.text.trim(),
                'question': questionController.text.trim(),
              });
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    questionController.dispose();
    raisedByController.dispose();

    if (result == null) return;

    try {
      final api = context.read<ApiService>();
      await api.createEnquiry(widget.saleId, result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enquiry created')),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create enquiry: $e')),
        );
      }
    }
  }

  Future<void> _reassignEnquiry(SaleEnquiry enquiry) async {
    String? selectedOwner;

    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Reassign Enquiry',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.charcoal),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'New Owner'),
                items: _ownerChoices.entries
                    .map((e) => DropdownMenuItem(
                        value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: (v) =>
                    setSheetState(() => selectedOwner = v),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: selectedOwner != null
                      ? () => Navigator.pop(ctx, selectedOwner)
                      : null,
                  child: const Text('Reassign'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (result == null) return;

    try {
      final api = context.read<ApiService>();
      await api.reassignEnquiry(widget.saleId, enquiry.id, result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enquiry reassigned')),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reassign: $e')),
        );
      }
    }
  }

  Color _statusColour(String status) {
    switch (status) {
      case 'resolved':
        return AppTheme.forestDeep;
      case 'open':
        return AppTheme.warning;
      default:
        return AppTheme.stone;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BrandedAppBar.build(context: context),
      floatingActionButton: FloatingActionButton(
        onPressed: _createEnquiry,
        backgroundColor: AppTheme.forestDeep,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: _enquiries.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 100),
                        Center(
                          child: Column(
                            children: [
                              Icon(PhosphorIconsDuotone.chatCircleDots,
                                  size: 48, color: AppTheme.stone),
                              SizedBox(height: 12),
                              Text('No enquiries yet',
                                  style: TextStyle(
                                      color: AppTheme.slate, fontSize: 16)),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _enquiries.length + 1,
                      itemBuilder: (ctx, i) {
                        if (i == 0) {
                          return const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: Text(
                              'Enquiries',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.charcoal,
                              ),
                            ),
                          );
                        }
                        return _buildEnquiryCard(_enquiries[i - 1]);
                      },
                    ),
            ),
    );
  }

  Widget _buildEnquiryCard(SaleEnquiry enquiry) {
    final isExpanded = _expandedIds.contains(enquiry.id);

    return Card(
      child: Column(
        children: [
          ListTile(
            leading: OwnershipBadge(
              ownerType: enquiry.currentOwner,
              compact: true,
            ),
            title: Text(
              enquiry.question,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600),
              maxLines: isExpanded ? null : 2,
              overflow:
                  isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
            ),
            subtitle: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color:
                        _statusColour(enquiry.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    enquiry.statusDisplay,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _statusColour(enquiry.status),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  enquiry.raisedDate,
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.slate),
                ),
              ],
            ),
            trailing: Icon(
              isExpanded
                  ? PhosphorIconsDuotone.caretUp
                  : PhosphorIconsDuotone.caretDown,
              size: 18,
              color: AppTheme.stone,
            ),
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedIds.remove(enquiry.id);
                } else {
                  _expandedIds.add(enquiry.id);
                }
              });
            },
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.only(
                  left: 16, right: 16, bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (enquiry.raisedBy.isNotEmpty)
                    Text('Raised by: ${enquiry.raisedBy}',
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.slate)),
                  if (enquiry.response.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text('Response:',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.charcoal)),
                    const SizedBox(height: 4),
                    Text(enquiry.response,
                        style: const TextStyle(
                            fontSize: 13, color: AppTheme.charcoal)),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      OwnershipBadge(
                        ownerType: enquiry.currentOwner,
                        displayName: enquiry.currentOwnerDisplay,
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () =>
                            _reassignEnquiry(enquiry),
                        icon: Icon(PhosphorIconsDuotone.arrowsLeftRight,
                            size: 16),
                        label: const Text('Reassign',
                            style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
