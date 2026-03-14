import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../models/mortgage_calculation.dart';

class MortgageCalculatorScreen extends StatefulWidget {
  final double? propertyPrice;
  const MortgageCalculatorScreen({super.key, this.propertyPrice});

  @override
  State<MortgageCalculatorScreen> createState() => _MortgageCalculatorScreenState();
}

class _MortgageCalculatorScreenState extends State<MortgageCalculatorScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _priceController;
  final _depositController = TextEditingController(text: '10');
  final _rateController = TextEditingController(text: '4.5');
  final _termController = TextEditingController(text: '25');
  MortgageCalculation? _result;
  bool _calculating = false;

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController(
      text: widget.propertyPrice?.toStringAsFixed(0) ?? '',
    );
  }

  @override
  void dispose() {
    _priceController.dispose();
    _depositController.dispose();
    _rateController.dispose();
    _termController.dispose();
    super.dispose();
  }

  Future<void> _calculate() async {
    if (!_formKey.currentState!.validate()) return;

    final price = double.parse(_priceController.text);
    final depositPercent = double.parse(_depositController.text);

    setState(() => _calculating = true);
    try {
      final api = context.read<ApiService>();
      final result = await api.calculateMortgage(
        propertyPrice: price,
        depositPercent: depositPercent,
        interestRate: double.parse(_rateController.text),
        termYears: int.parse(_termController.text),
      );
      if (mounted) setState(() { _result = result; _calculating = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _calculating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Calculation failed: $e')),
        );
      }
    }
  }

  String _formatCurrency(double value) {
    return '\u00A3${value.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+\.)'),
      (m) => '${m[1]},',
    )}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mortgage Calculator')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Property Price (\u00A3)',
                  prefixText: '\u00A3',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _depositController,
                decoration: const InputDecoration(
                  labelText: 'Deposit (%)',
                  suffixText: '%',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _rateController,
                decoration: const InputDecoration(
                  labelText: 'Interest Rate (%)',
                  suffixText: '%',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _termController,
                decoration: const InputDecoration(
                  labelText: 'Term (years)',
                  suffixText: 'years',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _calculating ? null : _calculate,
                  child: _calculating
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Calculate'),
                ),
              ),
              if (_result != null) ...[
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Monthly Payment', style: Theme.of(context).textTheme.titleSmall),
                        Text(_formatCurrency(_result!.monthlyPayment),
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                        const Divider(height: 24),
                        _resultRow('Loan Amount', _formatCurrency(_result!.loanAmount)),
                        _resultRow('Total Repayment', _formatCurrency(_result!.totalRepayment)),
                        _resultRow('Total Interest', _formatCurrency(_result!.totalInterest)),
                        _resultRow('Stamp Duty', _formatCurrency(_result!.stampDuty)),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _resultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label), Text(value, style: const TextStyle(fontWeight: FontWeight.bold))],
      ),
    );
  }
}
