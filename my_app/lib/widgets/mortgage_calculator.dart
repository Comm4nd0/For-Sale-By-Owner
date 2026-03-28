import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../constants/app_theme.dart';

class MortgageCalculator extends StatefulWidget {
  final double propertyPrice;

  const MortgageCalculator({super.key, required this.propertyPrice});

  @override
  State<MortgageCalculator> createState() => _MortgageCalculatorState();
}

class _MortgageCalculatorState extends State<MortgageCalculator> {
  late final TextEditingController _depositController;
  late final TextEditingController _rateController;
  late final TextEditingController _termController;

  final _currencyFormat = NumberFormat('#,##0.00', 'en_GB');

  @override
  void initState() {
    super.initState();
    final defaultDeposit = (widget.propertyPrice * 0.10).toStringAsFixed(0);
    _depositController = TextEditingController(text: defaultDeposit);
    _rateController = TextEditingController(text: '4.5');
    _termController = TextEditingController(text: '25');
  }

  @override
  void dispose() {
    _depositController.dispose();
    _rateController.dispose();
    _termController.dispose();
    super.dispose();
  }

  double? _calculateMonthlyPayment() {
    final deposit = double.tryParse(_depositController.text);
    final annualRate = double.tryParse(_rateController.text);
    final years = int.tryParse(_termController.text);

    if (deposit == null || annualRate == null || years == null) return null;
    if (years <= 0) return null;

    final loanAmount = widget.propertyPrice - deposit;
    if (loanAmount <= 0) return 0;

    if (annualRate == 0) {
      final totalMonths = years * 12;
      return loanAmount / totalMonths;
    }

    final r = annualRate / 100 / 12;
    final n = years * 12;
    final payment = loanAmount * (r * pow(1 + r, n)) / (pow(1 + r, n) - 1);
    return payment;
  }

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      leading: PhosphorIcon(PhosphorIconsDuotone.calculator, color: AppTheme.forestMid),
      title: const Text(
        'Mortgage Calculator',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _depositController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Deposit amount (\u00A3)',
                  prefixText: '\u00A3 ',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _rateController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Interest rate (%)',
                  suffixText: '%',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _termController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Loan term (years)',
                  suffixText: 'years',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 20),
              _buildResult(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResult() {
    final monthly = _calculateMonthlyPayment();
    if (monthly == null) {
      return Text(
        'Enter valid values to calculate',
        style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.forestMist,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          const Text(
            'Estimated Monthly Payment',
            style: TextStyle(fontSize: 13, color: AppTheme.slate),
          ),
          const SizedBox(height: 4),
          Text(
            '\u00A3${_currencyFormat.format(monthly)}',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.forestDeep,
            ),
          ),
        ],
      ),
    );
  }
}
