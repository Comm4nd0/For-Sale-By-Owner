import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../constants/app_theme.dart';

/// Wraps a form field with a label and an optional "?" help icon. Tapping
/// the icon opens a dialog with a longer explanation. Used throughout the
/// Phase 1 create form and Phase 2 complete-your-listing screen so every
/// ambiguous field has context right next to it.
class LabelledField extends StatelessWidget {
  final String label;
  final String? helpText;
  final Widget child;
  final EdgeInsets? padding;

  const LabelledField({
    super.key,
    required this.label,
    this.helpText,
    required this.child,
    this.padding,
  });

  void _showHelp(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(label),
        content: Text(helpText ?? ''),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: AppTheme.charcoal,
                      ),
                ),
              ),
              if (helpText != null && helpText!.isNotEmpty) ...[
                const SizedBox(width: 6),
                InkWell(
                  onTap: () => _showHelp(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Tooltip(
                    message: helpText!,
                    waitDuration: const Duration(milliseconds: 300),
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: AppTheme.forestMist,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: AppTheme.forestMid),
                      ),
                      child: Center(
                        child: Icon(
                          PhosphorIconsDuotone.question,
                          size: 12,
                          color: AppTheme.forestDeep,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}
