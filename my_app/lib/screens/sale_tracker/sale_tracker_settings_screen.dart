import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import '../../constants/app_theme.dart';
import '../../models/sale.dart';
import '../../services/api_service.dart';
import '../../widgets/branded_app_bar.dart';

class SaleTrackerSettingsScreen extends StatefulWidget {
  final int saleId;
  const SaleTrackerSettingsScreen({super.key, required this.saleId});

  @override
  State<SaleTrackerSettingsScreen> createState() =>
      _SaleTrackerSettingsScreenState();
}

class _SaleTrackerSettingsScreenState
    extends State<SaleTrackerSettingsScreen> {
  bool _loading = true;
  bool _saving = false;

  final _sellerConveyancerNameController = TextEditingController();
  final _sellerConveyancerContactController = TextEditingController();
  final _buyerConveyancerNameController = TextEditingController();
  final _buyerConveyancerContactController = TextEditingController();

  DateTime? _targetExchangeDate;
  DateTime? _targetCompletionDate;
  String _notificationFrequency = 'daily_digest';

  static const _frequencyOptions = {
    'real_time': 'Real-time',
    'daily_digest': 'Daily Digest',
    'weekly_digest': 'Weekly Digest',
    'off': 'Off',
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _sellerConveyancerNameController.dispose();
    _sellerConveyancerContactController.dispose();
    _buyerConveyancerNameController.dispose();
    _buyerConveyancerContactController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final api = context.read<ApiService>();
      final json = await api.getSaleDetail(widget.saleId);
      if (mounted) {
        final sale = Sale.fromJson(json);
        setState(() {
          _sellerConveyancerNameController.text = sale.sellerConveyancerName;
          _sellerConveyancerContactController.text =
              sale.sellerConveyancerContact;
          _buyerConveyancerNameController.text = sale.buyerConveyancerName;
          _buyerConveyancerContactController.text =
              sale.buyerConveyancerContact;
          _notificationFrequency = sale.notificationFrequency;
          _targetExchangeDate = sale.targetExchangeDate != null
              ? DateTime.tryParse(sale.targetExchangeDate!)
              : null;
          _targetCompletionDate = sale.targetCompletionDate != null
              ? DateTime.tryParse(sale.targetCompletionDate!)
              : null;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load settings: $e')),
        );
      }
    }
  }

  Future<void> _pickDate(bool isExchange) async {
    final now = DateTime.now();
    final initial = isExchange
        ? _targetExchangeDate ?? now.add(const Duration(days: 30))
        : _targetCompletionDate ?? now.add(const Duration(days: 60));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
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

  Future<void> _saveSettings() async {
    setState(() => _saving = true);

    final data = <String, dynamic>{
      'seller_conveyancer_name':
          _sellerConveyancerNameController.text.trim(),
      'seller_conveyancer_contact':
          _sellerConveyancerContactController.text.trim(),
      'buyer_conveyancer_name':
          _buyerConveyancerNameController.text.trim(),
      'buyer_conveyancer_contact':
          _buyerConveyancerContactController.text.trim(),
      'notification_frequency': _notificationFrequency,
    };

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
      await api.updateSale(widget.saleId, data);
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save settings: $e')),
        );
      }
    }
  }

  Future<void> _exportGdpr() async {
    try {
      final api = context.read<ApiService>();
      await api.getGdprExport();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Data export requested. Check your email.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Future<void> _deleteGdpr() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete All Data'),
        content: const Text(
          'This will permanently delete all your sale tracker data. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Double confirmation
    final doubleConfirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Are you sure?'),
        content: const Text(
          'All sale tracker data will be permanently removed. '
          'This cannot be reversed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Delete Everything'),
          ),
        ],
      ),
    );

    if (doubleConfirmed != true) return;

    try {
      final api = context.read<ApiService>();
      await api.gdprDelete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All data deleted')),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BrandedAppBar.build(context: context),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.charcoal,
                  ),
                ),
                const SizedBox(height: 20),

                // Target dates
                _buildSectionTitle('Target Dates'),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(PhosphorIconsDuotone.calendarCheck,
                            color: AppTheme.forestMid),
                        title: const Text('Target Exchange Date'),
                        subtitle:
                            Text(_formatDate(_targetExchangeDate)),
                        trailing: IconButton(
                          icon: Icon(PhosphorIconsDuotone.pencilSimple),
                          onPressed: () => _pickDate(true),
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(PhosphorIconsDuotone.calendarCheck,
                            color: AppTheme.forestMid),
                        title: const Text('Target Completion Date'),
                        subtitle:
                            Text(_formatDate(_targetCompletionDate)),
                        trailing: IconButton(
                          icon: Icon(PhosphorIconsDuotone.pencilSimple),
                          onPressed: () => _pickDate(false),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Conveyancer details
                _buildSectionTitle('Your Conveyancer'),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        TextField(
                          controller: _sellerConveyancerNameController,
                          decoration: const InputDecoration(
                            labelText: 'Name',
                            prefixIcon:
                                Icon(PhosphorIconsDuotone.scales),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller:
                              _sellerConveyancerContactController,
                          decoration: const InputDecoration(
                            labelText: 'Contact',
                            prefixIcon:
                                Icon(PhosphorIconsDuotone.phone),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                _buildSectionTitle("Buyer's Conveyancer"),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        TextField(
                          controller: _buyerConveyancerNameController,
                          decoration: const InputDecoration(
                            labelText: 'Name',
                            prefixIcon:
                                Icon(PhosphorIconsDuotone.scales),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller:
                              _buyerConveyancerContactController,
                          decoration: const InputDecoration(
                            labelText: 'Contact',
                            prefixIcon:
                                Icon(PhosphorIconsDuotone.phone),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Notification frequency
                _buildSectionTitle('Notifications'),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: DropdownButtonFormField<String>(
                      value: _notificationFrequency,
                      decoration: const InputDecoration(
                        labelText: 'Notification Frequency',
                        prefixIcon: Icon(PhosphorIconsDuotone.bell),
                      ),
                      items: _frequencyOptions.entries
                          .map((e) => DropdownMenuItem(
                              value: e.key, child: Text(e.value)))
                          .toList(),
                      onChanged: (v) => setState(
                          () => _notificationFrequency = v!),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Save button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _saveSettings,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(PhosphorIconsDuotone.floppyDisk),
                    label: Text(_saving ? 'Saving...' : 'Save Changes'),
                  ),
                ),
                const SizedBox(height: 32),

                // GDPR section
                _buildSectionTitle('Data & Privacy'),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(PhosphorIconsDuotone.download,
                            color: AppTheme.forestMid),
                        title: const Text('Export Data'),
                        subtitle: const Text(
                          'Request a copy of all your sale tracker data',
                          style: TextStyle(fontSize: 12),
                        ),
                        trailing: OutlinedButton(
                          onPressed: _exportGdpr,
                          child: const Text('Export'),
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(PhosphorIconsDuotone.trash,
                            color: AppTheme.error),
                        title: const Text('Delete All Data'),
                        subtitle: const Text(
                          'Permanently remove all sale tracker data',
                          style: TextStyle(fontSize: 12),
                        ),
                        trailing: OutlinedButton(
                          onPressed: _deleteGdpr,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.error,
                            side:
                                const BorderSide(color: AppTheme.error),
                          ),
                          child: const Text('Delete'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
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
