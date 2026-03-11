import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../models/referral.dart';

class ReferralsScreen extends StatefulWidget {
  const ReferralsScreen({super.key});

  @override
  State<ReferralsScreen> createState() => _ReferralsScreenState();
}

class _ReferralsScreenState extends State<ReferralsScreen> {
  ReferralInfo? _info;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadReferrals();
  }

  Future<void> _loadReferrals() async {
    try {
      final api = context.read<ApiService>();
      final info = await api.getReferrals();
      if (mounted) setState(() { _info = info; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Referrals')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _info == null
              ? const Center(child: Text('Failed to load referrals'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              const Text('Your Referral Code', style: TextStyle(fontSize: 14, color: Colors.grey)),
                              const SizedBox(height: 8),
                              Text(_info!.referralCode,
                                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 4)),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: _info!.referralCode));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Referral code copied!')),
                                  );
                                },
                                icon: const Icon(Icons.copy),
                                label: const Text('Copy Code'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _statCard('Total Referrals', '${_info!.totalReferrals}')),
                          const SizedBox(width: 16),
                          Expanded(child: _statCard('Rewards Earned', '${_info!.rewardsEarned}')),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text('Referral History', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      if (_info!.referrals.isEmpty)
                        const Text('No referrals yet. Share your code to get started!')
                      else
                        ...(_info!.referrals.map((r) => ListTile(
                              leading: const CircleAvatar(child: Icon(Icons.person)),
                              title: Text(r.referredUserName.isNotEmpty ? r.referredUserName : r.referredUserEmail),
                              subtitle: Text(r.createdAt),
                              trailing: r.rewardGranted
                                  ? const Chip(label: Text('Rewarded'), backgroundColor: Colors.green)
                                  : const Chip(label: Text('Pending')),
                            ))),
                    ],
                  ),
                ),
    );
  }

  Widget _statCard(String label, String value) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
