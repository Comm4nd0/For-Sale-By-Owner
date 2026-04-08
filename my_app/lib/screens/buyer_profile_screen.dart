import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../models/buyer_profile.dart';
import '../widgets/branded_app_bar.dart';

class BuyerProfileScreen extends StatefulWidget {
  const BuyerProfileScreen({super.key});
  @override
  State<BuyerProfileScreen> createState() => _BuyerProfileScreenState();
}

class _BuyerProfileScreenState extends State<BuyerProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _budgetCtrl = TextEditingController();
  final _depositCtrl = TextEditingController();
  final _mortgageCtrl = TextEditingController();
  final _areasCtrl = TextEditingController();
  bool _mortgageApproved = false;
  bool _firstTimeBuyer = false;
  bool _cashBuyer = false;
  bool _hasPropertyToSell = false;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final api = context.read<ApiService>();
      final data = await api.getBuyerProfile();
      final profile = BuyerProfile.fromJson(data);
      setState(() {
        if (profile.maxBudget != null) _budgetCtrl.text = profile.maxBudget!.toStringAsFixed(0);
        if (profile.depositAmount != null) _depositCtrl.text = profile.depositAmount!.toStringAsFixed(0);
        if (profile.mortgageAmount != null) _mortgageCtrl.text = profile.mortgageAmount!.toStringAsFixed(0);
        _areasCtrl.text = profile.preferredAreas;
        _mortgageApproved = profile.mortgageApproved;
        _firstTimeBuyer = profile.isFirstTimeBuyer;
        _cashBuyer = profile.isCashBuyer;
        _hasPropertyToSell = profile.hasPropertyToSell;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final api = context.read<ApiService>();
      await api.updateBuyerProfile({
        'max_budget': double.tryParse(_budgetCtrl.text),
        'deposit_amount': double.tryParse(_depositCtrl.text),
        'mortgage_amount': double.tryParse(_mortgageCtrl.text),
        'mortgage_approved': _mortgageApproved,
        'is_first_time_buyer': _firstTimeBuyer,
        'is_cash_buyer': _cashBuyer,
        'has_property_to_sell': _hasPropertyToSell,
        'preferred_areas': _areasCtrl.text,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile saved')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BrandedAppBar.build(context: context, showHomeButton: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Set up your buyer profile to get matched with affordable properties.',
                        style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _budgetCtrl,
                      decoration: const InputDecoration(labelText: 'Maximum Budget (\u00A3)', prefixText: '\u00A3 ', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _depositCtrl,
                      decoration: const InputDecoration(labelText: 'Deposit Amount (\u00A3)', prefixText: '\u00A3 ', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _mortgageCtrl,
                      decoration: const InputDecoration(labelText: 'Mortgage Amount (\u00A3)', prefixText: '\u00A3 ', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _areasCtrl,
                      decoration: const InputDecoration(labelText: 'Preferred Areas', hintText: 'e.g. BS1, GL50, Bristol', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Mortgage Approved'),
                      subtitle: const Text('I have a mortgage agreement in principle'),
                      value: _mortgageApproved,
                      onChanged: (v) => setState(() => _mortgageApproved = v),
                      activeColor: const Color(0xFF115E66),
                    ),
                    SwitchListTile(
                      title: const Text('First-Time Buyer'),
                      value: _firstTimeBuyer,
                      onChanged: (v) => setState(() => _firstTimeBuyer = v),
                      activeColor: const Color(0xFF115E66),
                    ),
                    SwitchListTile(
                      title: const Text('Cash Buyer'),
                      value: _cashBuyer,
                      onChanged: (v) => setState(() => _cashBuyer = v),
                      activeColor: const Color(0xFF115E66),
                    ),
                    SwitchListTile(
                      title: const Text('Has Property to Sell'),
                      value: _hasPropertyToSell,
                      onChanged: (v) => setState(() => _hasPropertyToSell = v),
                      activeColor: const Color(0xFF115E66),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF115E66), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                        child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save Profile'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
