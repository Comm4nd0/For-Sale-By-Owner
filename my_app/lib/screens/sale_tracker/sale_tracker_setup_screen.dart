import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import '../../constants/app_theme.dart';
import '../../services/api_service.dart';
import '../../widgets/branded_app_bar.dart';
import 'sale_tracker_dashboard_screen.dart';

class SaleTrackerSetupScreen extends StatefulWidget {
  const SaleTrackerSetupScreen({super.key});

  @override
  State<SaleTrackerSetupScreen> createState() => _SaleTrackerSetupScreenState();
}

class _SaleTrackerSetupScreenState extends State<SaleTrackerSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _submitting = false;

  final _addressController = TextEditingController();
  final _askingPriceController = TextEditingController();
  final _agreedPriceController = TextEditingController();
  final _buyerNameController = TextEditingController();
  final _buyerContactController = TextEditingController();
  final _chainLengthController = TextEditingController();
  final _agentNameController = TextEditingController();
  final _agentContactController = TextEditingController();
  final _sellerConveyancerNameController = TextEditingController();
  final _sellerConveyancerContactController = TextEditingController();
  final _buyerConveyancerNameController = TextEditingController();
  final _buyerConveyancerContactController = TextEditingController();

  String _tenure = 'freehold';
  String _buyerPosition = 'cash';
  DateTime? _targetExchangeDate;
  DateTime? _targetCompletionDate;

  static const _tenureOptions = {
    'freehold': 'Freehold',
    'leasehold': 'Leasehold',
    'share_of_freehold': 'Share of Freehold',
  };

  static const _buyerPositionOptions = {
    'cash': 'Cash',
    'mortgage': 'Mortgage',
    'chain': 'Chain',
  };

  @override
  void dispose() {
    _addressController.dispose();
    _askingPriceController.dispose();
    _agreedPriceController.dispose();
    _buyerNameController.dispose();
    _buyerContactController.dispose();
    _chainLengthController.dispose();
    _agentNameController.dispose();
    _agentContactController.dispose();
    _sellerConveyancerNameController.dispose();
    _sellerConveyancerContactController.dispose();
    _buyerConveyancerNameController.dispose();
    _buyerConveyancerContactController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isExchange) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (picked != null && mounted) {
      setState(() {
        if (isExchange) {
          _targetExchangeDate = picked;
        } else {
          _targetCompletionDate = picked;
        }
      });
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Not set';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    final data = <String, dynamic>{
      'property_address': _addressController.text.trim(),
      'tenure': _tenure,
      'buyer_position': _buyerPosition,
    };

    if (_askingPriceController.text.trim().isNotEmpty) {
      data['asking_price'] = _askingPriceController.text.trim();
    }
    if (_agreedPriceController.text.trim().isNotEmpty) {
      data['agreed_price'] = _agreedPriceController.text.trim();
    }
    if (_buyerNameController.text.trim().isNotEmpty) {
      data['buyer_name'] = _buyerNameController.text.trim();
    }
    if (_buyerContactController.text.trim().isNotEmpty) {
      data['buyer_contact'] = _buyerContactController.text.trim();
    }
    if (_buyerPosition == 'chain' &&
        _chainLengthController.text.trim().isNotEmpty) {
      data['chain_length'] =
          int.tryParse(_chainLengthController.text.trim()) ?? 0;
    }
    if (_agentNameController.text.trim().isNotEmpty) {
      data['agent_name'] = _agentNameController.text.trim();
    }
    if (_agentContactController.text.trim().isNotEmpty) {
      data['agent_contact'] = _agentContactController.text.trim();
    }
    if (_sellerConveyancerNameController.text.trim().isNotEmpty) {
      data['seller_conveyancer_name'] =
          _sellerConveyancerNameController.text.trim();
    }
    if (_sellerConveyancerContactController.text.trim().isNotEmpty) {
      data['seller_conveyancer_contact'] =
          _sellerConveyancerContactController.text.trim();
    }
    if (_buyerConveyancerNameController.text.trim().isNotEmpty) {
      data['buyer_conveyancer_name'] =
          _buyerConveyancerNameController.text.trim();
    }
    if (_buyerConveyancerContactController.text.trim().isNotEmpty) {
      data['buyer_conveyancer_contact'] =
          _buyerConveyancerContactController.text.trim();
    }
    if (_targetExchangeDate != null) {
      data['target_exchange_date'] =
          _targetExchangeDate!.toIso8601String().substring(0, 10);
    }
    if (_targetCompletionDate != null) {
      data['target_completion_date'] =
          _targetCompletionDate!.toIso8601String().substring(0, 10);
    }

    try {
      final api = context.read<ApiService>();
      final result = await api.createSale(data);
      if (mounted) {
        final saleId = result['id'] as int;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => SaleTrackerDashboardScreen(saleId: saleId),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create sale: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BrandedAppBar.build(context: context),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Set Up Sale Tracker',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.charcoal,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Enter the details of your sale to begin tracking.',
              style: TextStyle(fontSize: 14, color: AppTheme.slate),
            ),
            const SizedBox(height: 20),

            // Property address
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Property Address *',
                prefixIcon: Icon(PhosphorIconsDuotone.mapPin),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Address is required' : null,
            ),
            const SizedBox(height: 16),

            // Tenure
            DropdownButtonFormField<String>(
              value: _tenure,
              decoration: const InputDecoration(
                labelText: 'Tenure',
                prefixIcon: Icon(PhosphorIconsDuotone.house),
              ),
              items: _tenureOptions.entries
                  .map((e) =>
                      DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) => setState(() => _tenure = v!),
            ),
            const SizedBox(height: 16),

            // Prices
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _askingPriceController,
                    decoration: const InputDecoration(
                      labelText: 'Asking Price',
                      prefixText: '\u00a3 ',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _agreedPriceController,
                    decoration: const InputDecoration(
                      labelText: 'Agreed Price',
                      prefixText: '\u00a3 ',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            _buildSectionTitle('Buyer Details'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _buyerNameController,
              decoration: const InputDecoration(
                labelText: 'Buyer Name',
                prefixIcon: Icon(PhosphorIconsDuotone.user),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _buyerContactController,
              decoration: const InputDecoration(
                labelText: 'Buyer Contact',
                prefixIcon: Icon(PhosphorIconsDuotone.phone),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _buyerPosition,
              decoration: const InputDecoration(
                labelText: 'Buyer Position',
                prefixIcon: Icon(PhosphorIconsDuotone.currencyGbp),
              ),
              items: _buyerPositionOptions.entries
                  .map((e) =>
                      DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) => setState(() => _buyerPosition = v!),
            ),
            if (_buyerPosition == 'chain') ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _chainLengthController,
                decoration: const InputDecoration(
                  labelText: 'Chain Length',
                  prefixIcon: Icon(PhosphorIconsDuotone.link),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
            const SizedBox(height: 24),

            _buildSectionTitle('Estate Agent'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _agentNameController,
              decoration: const InputDecoration(
                labelText: 'Agent Name',
                prefixIcon: Icon(PhosphorIconsDuotone.storefront),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _agentContactController,
              decoration: const InputDecoration(
                labelText: 'Agent Contact',
                prefixIcon: Icon(PhosphorIconsDuotone.phone),
              ),
            ),
            const SizedBox(height: 24),

            _buildSectionTitle('Your Conveyancer'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _sellerConveyancerNameController,
              decoration: const InputDecoration(
                labelText: 'Conveyancer Name',
                prefixIcon: Icon(PhosphorIconsDuotone.scales),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _sellerConveyancerContactController,
              decoration: const InputDecoration(
                labelText: 'Conveyancer Contact',
                prefixIcon: Icon(PhosphorIconsDuotone.phone),
              ),
            ),
            const SizedBox(height: 24),

            _buildSectionTitle("Buyer's Conveyancer"),
            const SizedBox(height: 12),
            TextFormField(
              controller: _buyerConveyancerNameController,
              decoration: const InputDecoration(
                labelText: 'Conveyancer Name',
                prefixIcon: Icon(PhosphorIconsDuotone.scales),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _buyerConveyancerContactController,
              decoration: const InputDecoration(
                labelText: 'Conveyancer Contact',
                prefixIcon: Icon(PhosphorIconsDuotone.phone),
              ),
            ),
            const SizedBox(height: 24),

            _buildSectionTitle('Target Dates'),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(PhosphorIconsDuotone.calendarCheck,
                  color: AppTheme.forestMid),
              title: const Text('Target Exchange Date'),
              subtitle: Text(_formatDate(_targetExchangeDate)),
              trailing: IconButton(
                icon: Icon(PhosphorIconsDuotone.pencilSimple),
                onPressed: () => _pickDate(true),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(PhosphorIconsDuotone.calendarCheck,
                  color: AppTheme.forestMid),
              title: const Text('Target Completion Date'),
              subtitle: Text(_formatDate(_targetCompletionDate)),
              trailing: IconButton(
                icon: Icon(PhosphorIconsDuotone.pencilSimple),
                onPressed: () => _pickDate(false),
              ),
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(PhosphorIconsDuotone.rocketLaunch),
                label: Text(_submitting ? 'Creating...' : 'Create Sale Tracker'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppTheme.forestDeep,
      ),
    );
  }
}
