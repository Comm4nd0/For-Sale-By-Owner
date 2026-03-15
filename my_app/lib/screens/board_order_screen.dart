import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../models/board_order.dart';
import '../widgets/branded_app_bar.dart';

class BoardOrderScreen extends StatefulWidget {
  final int? propertyId;
  const BoardOrderScreen({super.key, this.propertyId});

  @override
  State<BoardOrderScreen> createState() => _BoardOrderScreenState();
}

class _BoardOrderScreenState extends State<BoardOrderScreen> {
  static const _brandColor = Color(0xFF115E66);

  final _currencyFormat = NumberFormat.currency(
    locale: 'en_GB',
    symbol: '£',
    decimalDigits: 2,
  );

  List<BoardOrder> _orders = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<ApiService>();
      final data = await api.getBoardOrders();
      if (mounted) {
        setState(() {
          _orders = data.map((j) => BoardOrder.fromJson(j)).toList();
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

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.amber;
      case 'processing':
        return Colors.blue;
      case 'shipped':
        return Colors.purple;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _boardTypeIcon(String type) {
    switch (type) {
      case 'premium':
        return Icons.star;
      case 'solar_lit':
        return Icons.wb_sunny;
      default:
        return Icons.signpost;
    }
  }

  Future<void> _openNewOrderForm() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _NewBoardOrderForm(propertyId: widget.propertyId),
      ),
    );
    if (result == true) {
      _loadOrders();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BrandedAppBar.build(
        context: context,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOrders,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNewOrderForm,
        backgroundColor: _brandColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Order Board',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text('Failed to load orders', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(_error!, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadOrders, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.signpost_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No board orders yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Order a For Sale board for your property',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _openNewOrderForm,
              icon: const Icon(Icons.add),
              label: const Text('Order Board'),
              style: ElevatedButton.styleFrom(backgroundColor: _brandColor),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _orders.length,
        itemBuilder: (context, index) => _buildOrderCard(_orders[index]),
      ),
    );
  }

  Widget _buildOrderCard(BoardOrder order) {
    final statusColor = _statusColor(order.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_boardTypeIcon(order.boardType), color: _brandColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    order.boardTypeDisplay.isNotEmpty
                        ? order.boardTypeDisplay
                        : order.boardType,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    order.statusDisplay.isNotEmpty
                        ? order.statusDisplay
                        : order.status,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            if (order.propertyTitle.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.home_outlined, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      order.propertyTitle,
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    order.deliveryAddress,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _currencyFormat.format(order.price),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: _brandColor,
                  ),
                ),
                if (order.trackingNumber.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.local_shipping_outlined, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        order.trackingNumber,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
              ],
            ),
            if (order.notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                order.notes,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              _formatDate(order.createdAt),
              style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('d MMM yyyy, HH:mm').format(date);
    } catch (_) {
      return dateStr;
    }
  }
}

// ── New Board Order Form ────────────────────────────────────────────

class _NewBoardOrderForm extends StatefulWidget {
  final int? propertyId;
  const _NewBoardOrderForm({this.propertyId});

  @override
  State<_NewBoardOrderForm> createState() => _NewBoardOrderFormState();
}

class _NewBoardOrderFormState extends State<_NewBoardOrderForm> {
  static const _brandColor = Color(0xFF115E66);

  final _currencyFormat = NumberFormat.currency(
    locale: 'en_GB',
    symbol: '£',
    decimalDigits: 2,
  );

  final _formKey = GlobalKey<FormState>();
  final _propertyIdController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();

  List<BoardPricingOption> _pricingOptions = [];
  BoardPricingOption? _selectedOption;
  bool _loadingPricing = true;
  bool _submitting = false;
  String? _pricingError;

  @override
  void initState() {
    super.initState();
    if (widget.propertyId != null) {
      _propertyIdController.text = widget.propertyId.toString();
    }
    _loadPricing();
  }

  @override
  void dispose() {
    _propertyIdController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadPricing() async {
    try {
      final api = context.read<ApiService>();
      final data = await api.getBoardPricing();
      final options = (data['options'] as List<dynamic>?)
              ?.map((j) => BoardPricingOption.fromJson(j))
              .toList() ??
          [];

      // Fallback if API returns empty
      final resolvedOptions = options.isNotEmpty
          ? options
          : [
              BoardPricingOption(
                type: 'standard',
                name: 'Standard',
                price: 29.99,
                description: 'Classic for sale board with your details',
              ),
              BoardPricingOption(
                type: 'premium',
                name: 'Premium',
                price: 49.99,
                description: 'Premium quality board with weather-resistant finish',
              ),
              BoardPricingOption(
                type: 'solar_lit',
                name: 'Solar Lit',
                price: 79.99,
                description: 'Solar-powered illuminated board for maximum visibility',
              ),
            ];

      if (mounted) {
        setState(() {
          _pricingOptions = resolvedOptions;
          _selectedOption = resolvedOptions.first;
          _loadingPricing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          // Use default pricing on error
          _pricingOptions = [
            BoardPricingOption(
              type: 'standard',
              name: 'Standard',
              price: 29.99,
              description: 'Classic for sale board with your details',
            ),
            BoardPricingOption(
              type: 'premium',
              name: 'Premium',
              price: 49.99,
              description: 'Premium quality board with weather-resistant finish',
            ),
            BoardPricingOption(
              type: 'solar_lit',
              name: 'Solar Lit',
              price: 79.99,
              description: 'Solar-powered illuminated board for maximum visibility',
            ),
          ];
          _selectedOption = _pricingOptions.first;
          _loadingPricing = false;
          _pricingError = e.toString();
        });
      }
    }
  }

  IconData _boardTypeIcon(String type) {
    switch (type) {
      case 'premium':
        return Icons.star;
      case 'solar_lit':
        return Icons.wb_sunny;
      default:
        return Icons.signpost;
    }
  }

  Future<void> _submitOrder() async {
    if (!_formKey.currentState!.validate() || _selectedOption == null) return;

    final propertyId = int.tryParse(_propertyIdController.text.trim());
    if (propertyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid property ID')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Order'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Board type: ${_selectedOption!.name}'),
            const SizedBox(height: 4),
            Text('Delivery to: ${_addressController.text.trim()}'),
            const SizedBox(height: 12),
            Text(
              'Total: ${_currencyFormat.format(_selectedOption!.price)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: _brandColor,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _brandColor),
            child: const Text('Confirm Order', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _submitting = true);

    try {
      final api = context.read<ApiService>();
      await api.createBoardOrder(
        propertyId,
        _selectedOption!.type,
        _addressController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Board order placed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to place order: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order For Sale Board'),
        backgroundColor: _brandColor,
        foregroundColor: Colors.white,
      ),
      body: _loadingPricing
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_pricingError != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          'Using default pricing (could not load live pricing)',
                          style: TextStyle(color: Colors.orange.shade700, fontSize: 12),
                        ),
                      ),

                    // Board type selection
                    Text(
                      'Choose Your Board',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    ..._pricingOptions.map(_buildPricingCard),

                    const SizedBox(height: 24),

                    // Property ID
                    TextFormField(
                      controller: _propertyIdController,
                      decoration: const InputDecoration(
                        labelText: 'Property ID',
                        prefixIcon: Icon(Icons.home),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      readOnly: widget.propertyId != null,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Property ID is required';
                        }
                        if (int.tryParse(v.trim()) == null) {
                          return 'Enter a valid number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Delivery address
                    TextFormField(
                      controller: _addressController,
                      decoration: const InputDecoration(
                        labelText: 'Delivery Address',
                        prefixIcon: Icon(Icons.location_on),
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Delivery address is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Notes
                    TextFormField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                        prefixIcon: Icon(Icons.notes),
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 24),

                    // Price total
                    if (_selectedOption != null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _brandColor.withAlpha(15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _brandColor.withAlpha(50)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Order Total',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              _currencyFormat.format(_selectedOption!.price),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: _brandColor,
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 24),

                    // Submit button
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _submitting ? null : _submitOrder,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _brandColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _submitting
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Place Order',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPricingCard(BoardPricingOption option) {
    final isSelected = _selectedOption?.type == option.type;

    return GestureDetector(
      onTap: () => setState(() => _selectedOption = option),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _brandColor : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          color: isSelected ? _brandColor.withAlpha(10) : Colors.white,
        ),
        child: Row(
          children: [
            Icon(
              _boardTypeIcon(option.type),
              color: isSelected ? _brandColor : Colors.grey,
              size: 28,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: isSelected ? _brandColor : Colors.black87,
                    ),
                  ),
                  if (option.description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      option.description,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ],
              ),
            ),
            Text(
              _currencyFormat.format(option.price),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isSelected ? _brandColor : Colors.black87,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: isSelected ? _brandColor : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
}
