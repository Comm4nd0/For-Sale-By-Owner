import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../models/offer.dart';

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
      final received = await api.getOffers(received: true);
      final sent = await api.getOffers(received: false);
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

  Future<void> _respondToOffer(Offer offer, String action) async {
    try {
      final api = context.read<ApiService>();
      await api.respondToOffer(offer.id, action);
      _loadOffers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Offer ${action}ed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to $action offer')),
        );
      }
    }
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
                  if (isReceived && offer.status == 'submitted') ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: () => _respondToOffer(offer, 'accept'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                          child: const Text('Accept'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () => _respondToOffer(offer, 'reject'),
                          child: const Text('Reject'),
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
