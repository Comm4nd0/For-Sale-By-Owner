import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';

class MakeOfferScreen extends StatefulWidget {
  final int propertyId;
  final String propertyTitle;
  final double askingPrice;

  const MakeOfferScreen({
    super.key,
    required this.propertyId,
    required this.propertyTitle,
    required this.askingPrice,
  });

  @override
  State<MakeOfferScreen> createState() => _MakeOfferScreenState();
}

class _MakeOfferScreenState extends State<MakeOfferScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isCashBuyer = false;
  bool _isChainFree = false;
  bool _mortgageAgreed = false;
  bool _submitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      final api = context.read<ApiService>();
      await api.createOffer(
        propertyId: widget.propertyId,
        amount: double.parse(_amountController.text),
        message: _messageController.text.isNotEmpty ? _messageController.text : null,
        isCashBuyer: _isCashBuyer,
        isChainFree: _isChainFree,
        mortgageAgreed: _mortgageAgreed,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Offer submitted successfully')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _submitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit offer: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Make an Offer')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.propertyTitle, style: Theme.of(context).textTheme.titleMedium),
              Text('Asking price: \u00A3${widget.askingPrice.toStringAsFixed(0)}',
                  style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Offer Amount (\u00A3)',
                  prefixText: '\u00A3',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter an amount';
                  if (double.tryParse(v) == null) return 'Enter a valid number';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _messageController,
                decoration: const InputDecoration(
                  labelText: 'Message (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Cash buyer'),
                value: _isCashBuyer,
                onChanged: (v) => setState(() => _isCashBuyer = v),
              ),
              SwitchListTile(
                title: const Text('Chain free'),
                value: _isChainFree,
                onChanged: (v) => setState(() => _isChainFree = v),
              ),
              SwitchListTile(
                title: const Text('Mortgage agreed in principle'),
                value: _mortgageAgreed,
                onChanged: (v) => setState(() => _mortgageAgreed = v),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Submit Offer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
