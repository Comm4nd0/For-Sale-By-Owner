import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import '../../constants/app_theme.dart';
import '../../models/sale_contact_log.dart';
import '../../services/api_service.dart';
import '../../widgets/branded_app_bar.dart';

class SaleTrackerContactLogScreen extends StatefulWidget {
  final int saleId;
  const SaleTrackerContactLogScreen({super.key, required this.saleId});

  @override
  State<SaleTrackerContactLogScreen> createState() =>
      _SaleTrackerContactLogScreenState();
}

class _SaleTrackerContactLogScreenState
    extends State<SaleTrackerContactLogScreen> {
  List<SaleContactLog> _entries = [];
  bool _loading = true;

  static const _channelOptions = {
    'phone': 'Phone',
    'email': 'Email',
    'in_person': 'In Person',
    'letter': 'Letter',
    'portal': 'Portal',
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
      final json = await api.getSaleContactLog(widget.saleId);
      if (mounted) {
        setState(() {
          _entries =
              json.map((e) => SaleContactLog.fromJson(e)).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load contact log: $e')),
        );
      }
    }
  }

  Future<void> _createEntry() async {
    String channel = 'phone';
    final counterpartyController = TextEditingController();
    final summaryController = TextEditingController();
    DateTime? followUpDate;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('New Contact Log Entry'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: channel,
                  decoration:
                      const InputDecoration(labelText: 'Channel'),
                  items: _channelOptions.entries
                      .map((e) => DropdownMenuItem(
                          value: e.key, child: Text(e.value)))
                      .toList(),
                  onChanged: (v) =>
                      setDialogState(() => channel = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: counterpartyController,
                  decoration: const InputDecoration(
                      labelText: 'Counterparty'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: summaryController,
                  decoration:
                      const InputDecoration(labelText: 'Summary'),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Follow-up Date'),
                  subtitle: Text(followUpDate != null
                      ? '${followUpDate!.day.toString().padLeft(2, '0')}/'
                          '${followUpDate!.month.toString().padLeft(2, '0')}/'
                          '${followUpDate!.year}'
                      : 'Not set'),
                  trailing:
                      Icon(PhosphorIconsDuotone.calendarPlus, size: 20),
                  onTap: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: now.add(const Duration(days: 7)),
                      firstDate: now,
                      lastDate:
                          now.add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setDialogState(
                          () => followUpDate = picked);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (summaryController.text.trim().isEmpty) return;
                final data = <String, dynamic>{
                  'channel': channel,
                  'counterparty': counterpartyController.text.trim(),
                  'summary': summaryController.text.trim(),
                };
                if (followUpDate != null) {
                  data['follow_up_date'] = followUpDate!
                      .toIso8601String()
                      .substring(0, 10);
                }
                Navigator.pop(ctx, data);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    counterpartyController.dispose();
    summaryController.dispose();

    if (result == null) return;

    try {
      final api = context.read<ApiService>();
      await api.createContactLog(widget.saleId, result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contact log entry created')),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create entry: $e')),
        );
      }
    }
  }

  IconData _channelIcon(String channel) {
    switch (channel) {
      case 'phone':
        return PhosphorIconsDuotone.phone;
      case 'email':
        return PhosphorIconsDuotone.envelope;
      case 'in_person':
        return PhosphorIconsDuotone.users;
      case 'letter':
        return PhosphorIconsDuotone.envelope;
      case 'portal':
        return PhosphorIconsDuotone.globe;
      default:
        return PhosphorIconsDuotone.dotsThree;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BrandedAppBar.build(context: context),
      floatingActionButton: FloatingActionButton(
        onPressed: _createEntry,
        backgroundColor: AppTheme.forestDeep,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: _entries.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 100),
                        Center(
                          child: Column(
                            children: [
                              Icon(PhosphorIconsDuotone.notebook,
                                  size: 48, color: AppTheme.stone),
                              SizedBox(height: 12),
                              Text('No contact log entries',
                                  style: TextStyle(
                                      color: AppTheme.slate,
                                      fontSize: 16)),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _entries.length + 1,
                      itemBuilder: (ctx, i) {
                        if (i == 0) {
                          return const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: Text(
                              'Contact Log',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.charcoal,
                              ),
                            ),
                          );
                        }
                        return _buildLogCard(_entries[i - 1]);
                      },
                    ),
            ),
    );
  }

  Widget _buildLogCard(SaleContactLog entry) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.forestMist,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _channelIcon(entry.channel),
                size: 18,
                color: AppTheme.forestDeep,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (entry.counterparty.isNotEmpty) ...[
                        Text(
                          entry.counterparty,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.charcoal,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.forestMist,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          entry.channelDisplay.isNotEmpty
                              ? entry.channelDisplay
                              : entry.channel,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.forestDeep,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.summary,
                    style: const TextStyle(
                        fontSize: 13, color: AppTheme.charcoal),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(PhosphorIconsDuotone.calendar,
                          size: 14, color: AppTheme.stone),
                      const SizedBox(width: 4),
                      Text(
                        entry.date,
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.slate),
                      ),
                      if (entry.followUpDate != null) ...[
                        const SizedBox(width: 12),
                        Icon(PhosphorIconsDuotone.bellRinging,
                            size: 14, color: AppTheme.warning),
                        const SizedBox(width: 4),
                        Text(
                          'Follow-up: ${entry.followUpDate}',
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.warning),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
