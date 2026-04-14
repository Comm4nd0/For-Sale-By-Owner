import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import '../../constants/app_theme.dart';
import '../../models/sale_prompt_draft.dart';
import '../../services/api_service.dart';
import '../../widgets/branded_app_bar.dart';

class SaleTrackerPromptsScreen extends StatefulWidget {
  final int saleId;
  const SaleTrackerPromptsScreen({super.key, required this.saleId});

  @override
  State<SaleTrackerPromptsScreen> createState() =>
      _SaleTrackerPromptsScreenState();
}

class _SaleTrackerPromptsScreenState
    extends State<SaleTrackerPromptsScreen> {
  List<SalePromptDraft> _prompts = [];
  bool _loading = true;

  static const _counterpartyOptions = {
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

  static const _levelOptions = {
    'polite': 'Polite',
    'firm': 'Firm',
    'escalation': 'Escalation',
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final api = context.read<ApiService>();
      final json = await api.getSalePrompts(widget.saleId);
      if (mounted) {
        setState(() {
          _prompts =
              json.map((p) => SalePromptDraft.fromJson(p)).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load prompts: $e')),
        );
      }
    }
  }

  Future<void> _generatePrompt() async {
    String counterpartyType = 'seller_conveyancer';
    String level = 'polite';

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Generate Prompt'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: counterpartyType,
                decoration:
                    const InputDecoration(labelText: 'Counterparty'),
                items: _counterpartyOptions.entries
                    .map((e) => DropdownMenuItem(
                        value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: (v) =>
                    setDialogState(() => counterpartyType = v!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: level,
                decoration: const InputDecoration(labelText: 'Level'),
                items: _levelOptions.entries
                    .map((e) => DropdownMenuItem(
                        value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: (v) =>
                    setDialogState(() => level = v!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, {
                'counterparty_type': counterpartyType,
                'level': level,
              }),
              child: const Text('Generate'),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;

    try {
      final api = context.read<ApiService>();
      await api.generatePrompt(
        widget.saleId,
        result['counterparty_type']!,
        result['level']!,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Prompt generated')),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate prompt: $e')),
        );
      }
    }
  }

  Future<void> _markSent(SalePromptDraft prompt) async {
    try {
      final api = context.read<ApiService>();
      await api.markPromptSent(widget.saleId, prompt.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Marked as sent')),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to mark as sent: $e')),
        );
      }
    }
  }

  void _viewPrompt(SalePromptDraft prompt) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (ctx, scrollController) => Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            controller: scrollController,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      prompt.subject,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.charcoal,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(PhosphorIconsDuotone.x, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildLevelBadge(prompt.level, prompt.levelDisplay),
                  const SizedBox(width: 8),
                  Text(
                    prompt.recipientOwnerDisplay.isNotEmpty
                        ? prompt.recipientOwnerDisplay
                        : prompt.recipientOwner,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.slate),
                  ),
                ],
              ),
              const Divider(height: 24),
              SelectableText(
                prompt.bodyText,
                style: const TextStyle(
                    fontSize: 14, color: AppTheme.charcoal, height: 1.5),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(
                            ClipboardData(text: prompt.bodyText));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Copied to clipboard')),
                        );
                      },
                      icon: Icon(PhosphorIconsDuotone.copy),
                      label: const Text('Copy'),
                    ),
                  ),
                  if (!prompt.sentMarker) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _markSent(prompt);
                        },
                        icon: Icon(PhosphorIconsDuotone.paperPlaneTilt),
                        label: const Text('Mark Sent'),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _levelColour(String level) {
    switch (level) {
      case 'polite':
        return AppTheme.forestDeep;
      case 'firm':
        return AppTheme.warning;
      case 'escalation':
        return AppTheme.error;
      default:
        return AppTheme.slate;
    }
  }

  Widget _buildLevelBadge(String level, String display) {
    final colour = _levelColour(level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colour.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colour.withOpacity(0.3)),
      ),
      child: Text(
        display.isNotEmpty ? display : level,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: colour,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BrandedAppBar.build(context: context),
      floatingActionButton: FloatingActionButton(
        onPressed: _generatePrompt,
        backgroundColor: AppTheme.forestDeep,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: _prompts.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 100),
                        Center(
                          child: Column(
                            children: [
                              Icon(PhosphorIconsDuotone.megaphone,
                                  size: 48, color: AppTheme.stone),
                              SizedBox(height: 12),
                              Text('No prompts generated',
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
                      itemCount: _prompts.length + 1,
                      itemBuilder: (ctx, i) {
                        if (i == 0) {
                          return const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: Text(
                              'Prompts',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.charcoal,
                              ),
                            ),
                          );
                        }
                        return _buildPromptCard(_prompts[i - 1]);
                      },
                    ),
            ),
    );
  }

  Widget _buildPromptCard(SalePromptDraft prompt) {
    return Card(
      child: ListTile(
        leading: Icon(
          prompt.sentMarker
              ? PhosphorIconsDuotone.checkCircle
              : PhosphorIconsDuotone.envelope,
          color:
              prompt.sentMarker ? AppTheme.forestDeep : AppTheme.slate,
          size: 22,
        ),
        title: Text(
          prompt.subject,
          style:
              const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            _buildLevelBadge(prompt.level, prompt.levelDisplay),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                prompt.recipientOwnerDisplay.isNotEmpty
                    ? prompt.recipientOwnerDisplay
                    : prompt.recipientOwner,
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.slate),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        trailing: prompt.sentMarker
            ? const Text('Sent',
                style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.forestDeep,
                    fontWeight: FontWeight.w600))
            : Icon(PhosphorIconsDuotone.caretRight,
                size: 18, color: AppTheme.stone),
        onTap: () => _viewPrompt(prompt),
      ),
    );
  }
}
