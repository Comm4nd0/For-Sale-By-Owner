import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/app_theme.dart';

enum BuyerType { standard, firstTime, additional }

class StampDutyCalculator extends StatefulWidget {
  final double propertyPrice;

  const StampDutyCalculator({super.key, required this.propertyPrice});

  @override
  State<StampDutyCalculator> createState() => _StampDutyCalculatorState();
}

class _StampDutyCalculatorState extends State<StampDutyCalculator> {
  BuyerType _buyerType = BuyerType.standard;

  final _currencyFormat = NumberFormat('#,##0', 'en_GB');

  double _calculateStampDuty() {
    final price = widget.propertyPrice;

    if (_buyerType == BuyerType.firstTime) {
      return _calculateFirstTime(price);
    }

    final standardDuty = _calculateStandard(price);

    if (_buyerType == BuyerType.additional) {
      final surcharge = price * 0.03;
      return standardDuty + surcharge;
    }

    return standardDuty;
  }

  double _calculateStandard(double price) {
    double duty = 0;

    if (price > 1500000) {
      duty += (price - 1500000) * 0.12;
      price = 1500000;
    }
    if (price > 925000) {
      duty += (price - 925000) * 0.10;
      price = 925000;
    }
    if (price > 250000) {
      duty += (price - 250000) * 0.05;
    }

    return duty;
  }

  double _calculateFirstTime(double price) {
    if (price > 625000) {
      return _calculateStandard(price);
    }

    double duty = 0;
    if (price > 425000) {
      duty += (price - 425000) * 0.05;
    }
    return duty;
  }

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      leading: const Icon(Icons.receipt_long, color: AppTheme.forestMid),
      title: const Text(
        'Stamp Duty Calculator',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Standard'),
                    selected: _buyerType == BuyerType.standard,
                    onSelected: (_) =>
                        setState(() => _buyerType = BuyerType.standard),
                    selectedColor: AppTheme.forestMist,
                  ),
                  ChoiceChip(
                    label: const Text('First-time'),
                    selected: _buyerType == BuyerType.firstTime,
                    onSelected: (_) =>
                        setState(() => _buyerType = BuyerType.firstTime),
                    selectedColor: AppTheme.forestMist,
                  ),
                  ChoiceChip(
                    label: const Text('Additional'),
                    selected: _buyerType == BuyerType.additional,
                    onSelected: (_) =>
                        setState(() => _buyerType = BuyerType.additional),
                    selectedColor: AppTheme.forestMist,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildResult(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResult() {
    final duty = _calculateStampDuty();
    final effectiveRate = widget.propertyPrice > 0
        ? (duty / widget.propertyPrice) * 100
        : 0.0;

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
            'Stamp Duty',
            style: TextStyle(fontSize: 13, color: AppTheme.slate),
          ),
          const SizedBox(height: 4),
          Text(
            '\u00A3${_currencyFormat.format(duty)}',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.forestDeep,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Effective rate: ${effectiveRate.toStringAsFixed(2)}%',
            style: const TextStyle(fontSize: 13, color: AppTheme.slate),
          ),
        ],
      ),
    );
  }
}
