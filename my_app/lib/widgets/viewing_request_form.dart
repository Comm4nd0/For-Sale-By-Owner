import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../constants/app_theme.dart';
import '../services/api_service.dart';

class ViewingRequestForm extends StatefulWidget {
  final int propertyId;
  final VoidCallback onSent;

  const ViewingRequestForm({
    super.key,
    required this.propertyId,
    required this.onSent,
  });

  @override
  State<ViewingRequestForm> createState() => _ViewingRequestFormState();
}

class _ViewingRequestFormState extends State<ViewingRequestForm> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _messageController = TextEditingController();

  DateTime? _preferredDate;
  TimeOfDay? _preferredTime;
  DateTime? _alternativeDate;
  TimeOfDay? _alternativeTime;

  bool _isLoading = false;

  final _dateFormat = DateFormat('yyyy-MM-dd');
  final _displayDateFormat = DateFormat('EEE, d MMM yyyy');

  @override
  void dispose() {
    _phoneController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isAlternative}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
    );
    if (picked != null) {
      setState(() {
        if (isAlternative) {
          _alternativeDate = picked;
        } else {
          _preferredDate = picked;
        }
      });
    }
  }

  Future<void> _pickTime({required bool isAlternative}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
    );
    if (picked != null) {
      setState(() {
        if (isAlternative) {
          _alternativeTime = picked;
        } else {
          _preferredTime = picked;
        }
      });
    }
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatTimeDisplay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_preferredDate == null || _preferredTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a preferred date and time'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final apiService = context.read<ApiService>();
      await apiService.createViewing(
        propertyId: widget.propertyId,
        phone: _phoneController.text.trim(),
        preferredDate: _dateFormat.format(_preferredDate!),
        preferredTime: _formatTime(_preferredTime!),
        alternativeDate: _alternativeDate != null
            ? _dateFormat.format(_alternativeDate!)
            : null,
        alternativeTime: _alternativeTime != null
            ? _formatTime(_alternativeTime!)
            : null,
        message: _messageController.text.trim().isNotEmpty
            ? _messageController.text.trim()
            : null,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Viewing request sent!')),
      );
      widget.onSent();

      _phoneController.clear();
      _messageController.clear();
      setState(() {
        _preferredDate = null;
        _preferredTime = null;
        _alternativeDate = null;
        _alternativeTime = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to request viewing: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildDateField({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
  }) {
    return TextFormField(
      readOnly: true,
      controller: TextEditingController(
        text: value != null ? _displayDateFormat.format(value) : '',
      ),
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: PhosphorIcon(PhosphorIconsDuotone.calendar, size: 20),
      ),
      onTap: onTap,
    );
  }

  Widget _buildTimeField({
    required String label,
    required TimeOfDay? value,
    required VoidCallback onTap,
  }) {
    return TextFormField(
      readOnly: true,
      controller: TextEditingController(
        text: value != null ? _formatTimeDisplay(value) : '',
      ),
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: PhosphorIcon(PhosphorIconsDuotone.clock, size: 20),
      ),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      leading: PhosphorIcon(PhosphorIconsDuotone.calendar, color: AppTheme.forestMid),
      title: const Text(
        'Request a Viewing',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone (optional)',
                  ),
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                Text(
                  'Preferred Date & Time',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildDateField(
                        label: 'Date',
                        value: _preferredDate,
                        onTap: () => _pickDate(isAlternative: false),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: _buildTimeField(
                        label: 'Time',
                        value: _preferredTime,
                        onTap: () => _pickTime(isAlternative: false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Alternative Date & Time (optional)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildDateField(
                        label: 'Date',
                        value: _alternativeDate,
                        onTap: () => _pickDate(isAlternative: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: _buildTimeField(
                        label: 'Time',
                        value: _alternativeTime,
                        onTap: () => _pickTime(isAlternative: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _messageController,
                  decoration: const InputDecoration(
                    labelText: 'Message (optional)',
                    alignLabelWithHint: true,
                  ),
                  maxLines: 3,
                  textInputAction: TextInputAction.newline,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Request Viewing'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
