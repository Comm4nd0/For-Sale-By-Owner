import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../widgets/branded_app_bar.dart';

class StampDutyScreen extends StatefulWidget {
  const StampDutyScreen({super.key});

  @override
  State<StampDutyScreen> createState() => _StampDutyScreenState();
}

class _StampDutyScreenState extends State<StampDutyScreen> {
  static const _brandColor = Color(0xFF115E66);
  static const _countries = ['england', 'scotland', 'wales'];
  static const _countryLabels = ['England', 'Scotland', 'Wales'];

  final _formKey = GlobalKey<FormState>();
  final _priceController = TextEditingController();
  final _currencyFormat = NumberFormat.currency(locale: 'en_GB', symbol: '\u00A3', decimalDigits: 2);

  String _selectedCountry = 'england';
  bool _firstTimeBuyer = false;
  bool _additionalProperty = false;
  bool _calculating = false;
  Map<String, dynamic>? _result;

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _calculate() async {
    if (!_formKey.currentState!.validate()) return;

    final price = double.parse(_priceController.text.replaceAll(',', ''));

    setState(() => _calculating = true);
    try {
      final api = context.read<ApiService>();
      final result = await api.calculateStampDuty(
        price: price,
        country: _selectedCountry,
        firstTimeBuyer: _firstTimeBuyer,
        additionalProperty: _additionalProperty,
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

  String _formatCurrency(dynamic value) {
    final amount = (value is int) ? value.toDouble() : (value as double);
    return _currencyFormat.format(amount);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BrandedAppBar(title: 'Stamp Duty Calculator'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Property Price
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Property Price',
                  prefixText: '\u00A3 ',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Please enter a property price';
                  final parsed = double.tryParse(v.replaceAll(',', ''));
                  if (parsed == null || parsed <= 0) return 'Please enter a valid price';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Country selector
              Text('Country', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  segments: List.generate(_countries.length, (i) {
                    return ButtonSegment<String>(
                      value: _countries[i],
                      label: Text(_countryLabels[i]),
                    );
                  }),
                  selected: {_selectedCountry},
                  onSelectionChanged: (selection) {
                    setState(() => _selectedCountry = selection.first);
                  },
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return _brandColor;
                      }
                      return null;
                    }),
                    foregroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return Colors.white;
                      }
                      return null;
                    }),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Toggle switches
              SwitchListTile(
                title: const Text('First-Time Buyer'),
                value: _firstTimeBuyer,
                activeColor: _brandColor,
                contentPadding: EdgeInsets.zero,
                onChanged: (value) {
                  setState(() => _firstTimeBuyer = value);
                },
              ),
              SwitchListTile(
                title: const Text('Additional Property'),
                value: _additionalProperty,
                activeColor: _brandColor,
                contentPadding: EdgeInsets.zero,
                onChanged: (value) {
                  setState(() => _additionalProperty = value);
                },
              ),
              const SizedBox(height: 16),

              // Calculate button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _calculating ? null : _calculate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brandColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _calculating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Calculate', style: TextStyle(fontSize: 16)),
                ),
              ),

              // Results section
              if (_result != null) ...[
                const SizedBox(height: 24),
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Stamp Duty',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatCurrency(_result!['total_tax']),
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: _brandColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Effective Rate: ${(_result!['effective_rate'] as num).toStringAsFixed(2)}%',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const Divider(height: 24),

                        // Bands breakdown table
                        Text(
                          'Tax Band Breakdown',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        Table(
                          columnWidths: const {
                            0: FlexColumnWidth(3),
                            1: FlexColumnWidth(1),
                            2: FlexColumnWidth(2),
                          },
                          children: [
                            TableRow(
                              decoration: BoxDecoration(
                                color: _brandColor.withOpacity(0.1),
                              ),
                              children: const [
                                Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                  child: Text('Band', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                                Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                  child: Text('Rate', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                                Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                  child: Text('Tax', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right),
                                ),
                              ],
                            ),
                            ...(_result!['bands'] as List).map((band) {
                              final from = _formatCurrency(band['from']);
                              final to = band['to'] == null
                                  ? '+'
                                  : ' - ${_formatCurrency(band['to'])}';
                              final bandLabel = band['to'] == null ? '$from+' : '$from - ${_formatCurrency(band['to'])}';
                              return TableRow(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                                    child: Text(bandLabel, style: const TextStyle(fontSize: 13)),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                                    child: Text('${(band['rate'] as num).toStringAsFixed(0)}%'),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                                    child: Text(
                                      _formatCurrency(band['tax']),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                ],
                              );
                            }),
                          ],
                        ),
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
}
