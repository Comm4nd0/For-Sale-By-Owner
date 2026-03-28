import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../models/offer.dart';
import 'edit_offer_screen.dart';

class OffersScreen extends StatefulWidget {
  final bool received;
  const OffersScreen({super.key, this.received = true});

  @override
  State<OffersScreen> createState() => _OffersScreenState();
}

class _OffersScreenState extends State<OffersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Offer> _receivedOffers = [];
  List<Offer> _sentOffers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.received ? 0 : 1);
    _loadOffers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadOffers() async {
    try {
      final api = context.read<ApiService>();
      final userId = context.read<AuthService>().userId;
      final received = await api.getOffers(received: true);
      final all = await api.getOffers();
      // Filter "sent" to only offers the current user made (not received)
      final sent = all.where((o) => o.buyerId == userId).toList();
      if (mounted) {
        setState(() {
          _receivedOffers = received;
          _sentOffers = sent;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'accepted': return Colors.green;
      case 'rejected': return Colors.red;
      case 'countered': return Colors.orange;
      case 'withdrawn': return Colors.grey;
      case 'expired': return Colors.grey;
      default: return Colors.blue;
    }
  }

  Future<void> _respondToOffer(Offer offer, String status) async {
    try {
      final api = context.read<ApiService>();
      await api.respondToOffer(offer.id, status);
      _loadOffers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Offer $status')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update offer')),
        );
      }
    }
  }

  Future<void> _withdrawOffer(Offer offer) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Withdraw Offer'),
        content: Text('Are you sure you want to withdraw your ${offer.formattedAmount} offer on ${offer.propertyTitle}?'),
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
      await api.withdrawOffer(offer.id);
      _loadOffers();
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

  void _editOffer(Offer offer) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditOfferScreen(offer: offer),
      ),
    ).then((result) {
      if (result == true) _loadOffers();
    });
  }

  Widget _buildOfferList(List<Offer> offers, {bool isReceived = false}) {
    if (offers.isEmpty) {
      return const Center(child: Text('No offers'));
    }
    return RefreshIndicator(
      onRefresh: _loadOffers,
      child: ListView.builder(
        itemCount: offers.length,
        itemBuilder: (context, index) {
          final offer = offers[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(offer.propertyTitle, style: const TextStyle(fontWeight: FontWeight.bold))),
                      Chip(
                        label: Text(offer.statusDisplay, style: const TextStyle(color: Colors.white, fontSize: 12)),
                        backgroundColor: _statusColor(offer.status),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(offer.formattedAmount, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  if (offer.counterAmount != null)
                    Text('Counter: \u00A3${offer.counterAmount!.toStringAsFixed(0)}',
                        style: const TextStyle(color: Colors.orange)),
                  const SizedBox(height: 4),
                  if (isReceived) Text('From: ${offer.buyerName}'),
                  if (offer.isCashBuyer) const Text('Cash buyer', style: TextStyle(color: Colors.green)),
                  if (offer.isChainFree) const Text('Chain free', style: TextStyle(color: Colors.green)),
                  if (offer.mortgageAgreed) const Text('Mortgage agreed in principle', style: TextStyle(color: Colors.green)),
                  if (offer.message != null && offer.message!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(offer.message!),
                  ],
                  if (offer.sellerResponse != null && offer.sellerResponse!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          PhosphorIcon(PhosphorIconsDuotone.arrowBendUpLeft, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 6),
                          Expanded(child: Text(offer.sellerResponse!, style: TextStyle(color: Colors.grey[700], fontSize: 13))),
                        ],
                      ),
                    ),
                  ],
                  if (isReceived && offer.status == 'submitted') ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: () => _respondToOffer(offer, 'accepted'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                          child: const Text('Accept'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () => _respondToOffer(offer, 'rejected'),
                          child: const Text('Reject'),
                        ),
                      ],
                    ),
                  ],
                  // Sent offer actions (buyer's view)
                  if (!isReceived && (offer.status == 'submitted' || offer.status == 'under_review' || offer.status == 'countered')) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (offer.status == 'submitted') ...[
                          ElevatedButton.icon(
                            onPressed: () => _editOffer(offer),
                            icon: PhosphorIcon(PhosphorIconsDuotone.pencilSimple, size: 16),
                            label: const Text('Edit'),
                          ),
                          const SizedBox(width: 8),
                        ],
                        OutlinedButton.icon(
                          onPressed: () => _withdrawOffer(offer),
                          icon: PhosphorIcon(PhosphorIconsDuotone.arrowCounterClockwise, size: 16),
                          label: const Text('Withdraw'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offers'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Received'),
            Tab(text: 'Sent'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOfferList(_receivedOffers, isReceived: true),
                _buildOfferList(_sentOffers),
              ],
            ),
    );
  }
}
