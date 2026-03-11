import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../models/offer.dart';

class EditOfferScreen extends StatefulWidget {
  final Offer offer;

  const EditOfferScreen({super.key, required this.offer});

  @override
  State<EditOfferScreen> createState() => _EditOfferScreenState();
}

class _EditOfferScreenState extends State<EditOfferScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _messageController;
  late bool _isCashBuyer;
  late bool _isChainFree;
  late bool _mortgageAgreed;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.offer.amount.toStringAsFixed(0),
    );
    _messageController = TextEditingController(
      text: widget.offer.message ?? '',
    );
    _isCashBuyer = widget.offer.isCashBuyer;
    _isChainFree = widget.offer.isChainFree;
    _mortgageAgreed = widget.offer.mortgageAgreed;
  }

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
      await api.updateOffer(
        widget.offer.id,
        amount: double.parse(_amountController.text),
        message: _messageController.text.isNotEmpty ? _messageController.text : '',
        isCashBuyer: _isCashBuyer,
        isChainFree: _isChainFree,
        mortgageAgreed: _mortgageAgreed,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Offer updated successfully')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _submitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update offer: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Offer')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.offer.propertyTitle,
                  style: Theme.of(context).textTheme.titleMedium),
              Text('Current offer: ${widget.offer.formattedAmount}',
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
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Update Offer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
