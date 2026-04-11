import 'package:flutter/services.dart';

/// Text input formatter that adds thousand-separator commas as the user
/// types. Strip commas with [stripCommas] before sending to the API.
class PriceInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(text: '');
    }
    final formatted = _insertCommas(digits);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  static String _insertCommas(String digits) {
    final buf = StringBuffer();
    int count = 0;
    for (int i = digits.length - 1; i >= 0; i--) {
      buf.write(digits[i]);
      count++;
      if (count == 3 && i != 0) {
        buf.write(',');
        count = 0;
      }
    }
    return buf.toString().split('').reversed.join();
  }

  /// Convert a formatted price ("1,250,000") back to a plain number string
  /// suitable for sending to the API ("1250000"). Safe on empty / null.
  static String stripCommas(String? value) {
    if (value == null) return '';
    return value.replaceAll(RegExp(r'[^0-9.]'), '');
  }

  /// Format a raw number as "1,234,567" for prefilling controllers.
  static String format(num? value) {
    if (value == null) return '';
    return _insertCommas(value.toStringAsFixed(0));
  }
}
