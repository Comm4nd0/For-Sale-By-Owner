import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/conveyancer_quote.dart';
import '../services/api_service.dart';
import '../widgets/branded_app_bar.dart';

class SolicitorQuotesScreen extends StatefulWidget {
  const SolicitorQuotesScreen({super.key});

  @override
  State<SolicitorQuotesScreen> createState() => _SolicitorQuotesScreenState();
}

class _SolicitorQuotesScreenState extends State<SolicitorQuotesScreen> {
  static const Color _primary = Color(0xFF115E66);

  List<ConveyancerQuoteRequest> _requests = [];
  bool _loading = true;
  String? _error;
  final Set<int> _expandedIds = {};
  final _currencyFormat = NumberFormat.currency(locale: 'en_GB', symbol: '\u00A3');

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = context.read<ApiService>();
      final data = await api.getQuoteRequests();
      if (mounted) {
        setState(() {
          _requests = data
              .map((json) =>
                  ConveyancerQuoteRequest.fromJson(json as Map<String, dynamic>))
              .toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _acceptQuote(ConveyancerQuote quote) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Accept Quote'),
        content: Text(
          'Accept the quote from ${quote.providerName} '
          'for ${_currencyFormat.format(quote.total)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _primary),
            child: const Text('Accept'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final api = context.read<ApiService>();
      await api.acceptQuote(quote.id);
      await _loadRequests();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Quote from ${quote.providerName} accepted'),
            backgroundColor: _primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to accept quote: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showCreateRequestDialog() {
    final propertyIdController = TextEditingController();
    final additionalInfoController = TextEditingController();
    String transactionType = 'buying';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('New Quote Request'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: propertyIdController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Property ID',
                    border: OutlineInputBorder(),
                    hintText: 'Enter property ID',
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: transactionType,
                  decoration: const InputDecoration(
                    labelText: 'Transaction Type',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'buying', child: Text('Buying')),
                    DropdownMenuItem(value: 'selling', child: Text('Selling')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => transactionType = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: additionalInfoController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Additional Information',
                    border: OutlineInputBorder(),
                    hintText: 'Any details for the solicitor...',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final propertyId =
                    int.tryParse(propertyIdController.text.trim());
                if (propertyId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a valid property ID'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                Navigator.pop(ctx);
                await _createRequest(
                  propertyId,
                  transactionType,
                  additionalInfoController.text.trim(),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: _primary),
              child: const Text('Submit Request'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createRequest(
    int propertyId,
    String transactionType,
    String additionalInfo,
  ) async {
    try {
      final api = context.read<ApiService>();
      await api.createQuoteRequest(
        propertyId,
        transactionType,
        additionalInfo: additionalInfo,
      );
      await _loadRequests();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Quote request created successfully'),
            backgroundColor: _primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'quoted':
        return Colors.blue;
      case 'accepted':
        return Colors.green;
      case 'closed':
        return Colors.grey;
      case 'open':
      default:
        return Colors.orange;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'quoted':
        return 'Quoted';
      case 'accepted':
        return 'Accepted';
      case 'closed':
        return 'Closed';
      case 'open':
      default:
        return 'Open';
    }
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BrandedAppBar.build(
        context: context,
        actions: [
          IconButton(
            icon: PhosphorIcon(PhosphorIconsDuotone.arrowClockwise),
            tooltip: 'Refresh',
            onPressed: _loadRequests,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Solicitor Quotes',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: _primary,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _showCreateRequestDialog,
                  icon: PhosphorIcon(PhosphorIconsDuotone.plus, size: 18),
                  label: const Text('New Request'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: _primary),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PhosphorIcon(PhosphorIconsDuotone.warningCircle, size: 56, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Failed to load quote requests',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadRequests,
                icon: PhosphorIcon(PhosphorIconsDuotone.arrowClockwise),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(backgroundColor: _primary),
              ),
            ],
          ),
        ),
      );
    }

    if (_requests.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PhosphorIcon(PhosphorIconsDuotone.fileText,
                  size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No Quote Requests',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tap "New Request" to request quotes from '
                'solicitors and conveyancers for your property transaction.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: _primary,
      onRefresh: _loadRequests,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        itemCount: _requests.length,
        itemBuilder: (context, index) =>
            _buildRequestCard(_requests[index]),
      ),
    );
  }

  Widget _buildRequestCard(ConveyancerQuoteRequest request) {
    final isExpanded = _expandedIds.contains(request.id);
    final hasQuotes = request.quotes.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: hasQuotes
                ? () {
                    setState(() {
                      if (isExpanded) {
                        _expandedIds.remove(request.id);
                      } else {
                        _expandedIds.add(request.id);
                      }
                    });
                  }
                : null,
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(12),
              bottom: isExpanded ? Radius.zero : const Radius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          request.propertyTitle,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _statusColor(request.status),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _statusLabel(request.status),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      PhosphorIcon(PhosphorIconsDuotone.arrowsLeftRight, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        request.transactionType == 'buying'
                            ? 'Buying'
                            : 'Selling',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(width: 16),
                      PhosphorIcon(PhosphorIconsDuotone.calendar,
                          size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(request.createdAt),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(width: 16),
                      PhosphorIcon(PhosphorIconsDuotone.quotes,
                          size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        '${request.quotes.length} quote${request.quotes.length == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                  if (request.additionalInfo.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      request.additionalInfo,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  if (hasQuotes) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          isExpanded ? 'Hide Quotes' : 'Compare Quotes',
                          style: const TextStyle(
                            color: _primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        PhosphorIcon(
                          isExpanded
                              ? PhosphorIconsDuotone.caretUp
                              : PhosphorIconsDuotone.caretDown,
                          color: _primary,
                          size: 20,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isExpanded && hasQuotes) _buildQuotesList(request.quotes),
        ],
      ),
    );
  }

  Widget _buildQuotesList(List<ConveyancerQuote> quotes) {
    final sorted = List<ConveyancerQuote>.from(quotes)
      ..sort((a, b) => a.total.compareTo(b.total));

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(height: 1, color: Colors.grey[300]),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              'Received Quotes (sorted by total)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          ),
          ...sorted.map((quote) => _buildQuoteCard(quote)),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildQuoteCard(ConveyancerQuote quote) {
    final isAccepted = quote.isAccepted;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isAccepted ? Colors.green[50] : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isAccepted ? Colors.green.shade300 : Colors.grey.shade200,
          width: isAccepted ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    quote.providerName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (isAccepted)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PhosphorIcon(PhosphorIconsDuotone.check, color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'Accepted',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildFeeItem('Legal Fee', quote.legalFee),
                ),
                Expanded(
                  child: _buildFeeItem('Disbursements', quote.disbursements),
                ),
                Expanded(
                  child: _buildFeeItem('Total', quote.total, isBold: true),
                ),
              ],
            ),
            if (quote.estimatedWeeks != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  PhosphorIcon(PhosphorIconsDuotone.clockAfternoon, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Estimated: ${quote.estimatedWeeks} week${quote.estimatedWeeks == 1 ? '' : 's'}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ],
            if (quote.notes.isNotEmpty) ...[
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
                    PhosphorIcon(PhosphorIconsDuotone.notepad, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        quote.notes,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (!isAccepted) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _acceptQuote(quote),
                  icon: PhosphorIcon(PhosphorIconsDuotone.checkCircle, size: 18),
                  label: const Text('Accept Quote'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFeeItem(String label, double amount, {bool isBold = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _currencyFormat.format(amount),
          style: TextStyle(
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: isBold ? _primary : Colors.black87,
          ),
        ),
      ],
    );
  }
}
