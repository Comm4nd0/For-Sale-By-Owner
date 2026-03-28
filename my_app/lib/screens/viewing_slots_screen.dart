import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import '../constants/app_theme.dart';
import '../services/api_service.dart';
import '../models/viewing_slot.dart';
import '../utils/auto_retry.dart';

class ViewingSlotsScreen extends StatefulWidget {
  final int propertyId;
  final bool isOwner;
  const ViewingSlotsScreen({super.key, required this.propertyId, this.isOwner = false});

  @override
  State<ViewingSlotsScreen> createState() => _ViewingSlotsScreenState();
}

class _ViewingSlotsScreenState extends State<ViewingSlotsScreen> with AutoRetryMixin {
  List<ViewingSlot> _slots = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSlots();
  }

  Future<void> _loadSlots() async {
    try {
      final api = context.read<ApiService>();
      final slots = await withRetry(() => api.getViewingSlots(widget.propertyId));
      if (mounted) setState(() { _slots = slots; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addSlot() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => const _AddSlotSheet(),
    );
    if (result == null || !mounted) return;

    try {
      final api = context.read<ApiService>();
      await api.createViewingSlot(widget.propertyId, result);
      _loadSlots();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Viewing slot added')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  Future<void> _bookSlot(ViewingSlot slot) async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Book Viewing'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Your Name')),
            TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Your Email')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Book')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final api = context.read<ApiService>();
      await api.bookViewingSlot(
        widget.propertyId,
        slot.id,
        name: nameController.text,
        email: emailController.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Viewing booked!')),
        );
      }
      _loadSlots();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final recurring = _slots.where((s) => s.isRecurring).toList();
    final oneOff = _slots.where((s) => !s.isRecurring).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Viewing Slots')),
      floatingActionButton: widget.isOwner
          ? FloatingActionButton(onPressed: _addSlot, child: PhosphorIcon(PhosphorIconsDuotone.plus))
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _slots.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: AppTheme.forestMist,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: PhosphorIcon(PhosphorIconsDuotone.calendar, size: 36, color: AppTheme.forestMid),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'No Viewing Slots',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.isOwner
                              ? 'Tap + to add available times for buyers to book viewings.'
                              : 'No viewing times are available for this property yet.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppTheme.slate, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadSlots,
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 80),
                    children: [
                      if (recurring.isNotEmpty) ...[
                        _buildSectionHeader('Weekly Schedule', PhosphorIconsDuotone.repeat),
                        ...recurring.map((slot) => _buildSlotCard(slot)),
                      ],
                      if (oneOff.isNotEmpty) ...[
                        _buildSectionHeader('Specific Dates', PhosphorIconsDuotone.calendarCheck),
                        ...oneOff.map((slot) => _buildSlotCard(slot)),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _buildSectionHeader(String title, PhosphorDuotoneIconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          PhosphorIcon(icon, size: 18, color: AppTheme.forestMid),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.forestMid,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlotCard(ViewingSlot slot) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: slot.isRecurring ? Colors.blue[50] : Colors.orange[50],
            borderRadius: BorderRadius.circular(10),
          ),
          child: PhosphorIcon(
            slot.isRecurring ? PhosphorIconsDuotone.repeat : PhosphorIconsDuotone.calendarCheck,
            size: 20,
            color: slot.isRecurring ? Colors.blue[700] : Colors.orange[700],
          ),
        ),
        title: Text(slot.displayTitle),
        subtitle: Text(
          '${slot.startTime} - ${slot.endTime}  \u2022  '
          '${slot.currentBookings}/${slot.maxBookings} booked',
        ),
        trailing: !widget.isOwner && slot.isAvailable
            ? ElevatedButton(
                onPressed: () => _bookSlot(slot),
                child: const Text('Book'),
              )
            : widget.isOwner
                ? IconButton(
                    icon: PhosphorIcon(PhosphorIconsDuotone.trash),
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete Slot'),
                          content: Text('Delete the ${slot.displayTitle} slot?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed != true) return;
                      final api = context.read<ApiService>();
                      await api.deleteViewingSlot(widget.propertyId, slot.id);
                      _loadSlots();
                    },
                  )
                : const Text('Full', style: TextStyle(color: Colors.red)),
      ),
    );
  }
}

// ── Add Slot Bottom Sheet ────────────────────────────────────────

class _AddSlotSheet extends StatefulWidget {
  const _AddSlotSheet();

  @override
  State<_AddSlotSheet> createState() => _AddSlotSheetState();
}

class _AddSlotSheetState extends State<_AddSlotSheet> {
  bool _isRecurring = false;
  DateTime? _selectedDate;
  int? _selectedDayOfWeek;
  TimeOfDay _startTime = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 11, minute: 0);
  int _maxBookings = 1;

  static const _dayNames = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday',
    'Friday', 'Saturday', 'Sunday',
  ];

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  bool get _canSave {
    if (_isRecurring) return _selectedDayOfWeek != null;
    return _selectedDate != null;
  }

  void _save() {
    if (!_canSave) return;

    final body = <String, dynamic>{
      'start_time': _formatTime(_startTime),
      'end_time': _formatTime(_endTime),
      'max_bookings': _maxBookings,
    };

    if (_isRecurring) {
      body['day_of_week'] = _selectedDayOfWeek;
    } else {
      body['date'] = _formatDate(_selectedDate!);
    }

    Navigator.pop(context, body);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Add Viewing Slot',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // Slot type toggle
            const Text('Slot Type', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  icon: PhosphorIcon(PhosphorIconsDuotone.calendarCheck, size: 18),
                  label: Text('One-off'),
                ),
                ButtonSegment(
                  value: true,
                  icon: PhosphorIcon(PhosphorIconsDuotone.repeat, size: 18),
                  label: Text('Weekly'),
                ),
              ],
              selected: {_isRecurring},
              onSelectionChanged: (v) => setState(() {
                _isRecurring = v.first;
                _selectedDate = null;
                _selectedDayOfWeek = null;
              }),
            ),
            const SizedBox(height: 20),

            // Date or day picker
            if (_isRecurring) ...[
              const Text('Day of Week', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(7, (i) {
                  final selected = _selectedDayOfWeek == i;
                  return ChoiceChip(
                    label: Text(_dayNames[i].substring(0, 3)),
                    selected: selected,
                    onSelected: (_) => setState(() => _selectedDayOfWeek = i),
                    selectedColor: AppTheme.forestMid,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : null,
                      fontWeight: selected ? FontWeight.bold : null,
                    ),
                  );
                }),
              ),
            ] else ...[
              const Text('Date', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate ?? DateTime.now().add(const Duration(days: 1)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 90)),
                  );
                  if (date != null) setState(() => _selectedDate = date);
                },
                icon: PhosphorIcon(PhosphorIconsDuotone.calendar, size: 18),
                label: Text(
                  _selectedDate != null
                      ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                      : 'Select a date',
                ),
              ),
            ],
            const SizedBox(height: 20),

            // Time pickers
            const Text('Time', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final t = await showTimePicker(context: context, initialTime: _startTime);
                      if (t != null) setState(() => _startTime = t);
                    },
                    child: Text('Start: ${_startTime.format(context)}'),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('to'),
                ),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final t = await showTimePicker(context: context, initialTime: _endTime);
                      if (t != null) setState(() => _endTime = t);
                    },
                    child: Text('End: ${_endTime.format(context)}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Max bookings
            const Text('Max Bookings', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  onPressed: _maxBookings > 1 ? () => setState(() => _maxBookings--) : null,
                  icon: PhosphorIcon(PhosphorIconsDuotone.minusCircle),
                ),
                Text(
                  '$_maxBookings',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: _maxBookings < 10 ? () => setState(() => _maxBookings++) : null,
                  icon: PhosphorIcon(PhosphorIconsDuotone.plusCircle),
                ),
                const SizedBox(width: 8),
                Text(
                  _maxBookings == 1 ? 'booking per slot' : 'bookings per slot',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Save button
            ElevatedButton(
              onPressed: _canSave ? _save : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(_isRecurring ? 'Add Weekly Slot' : 'Add One-off Slot'),
            ),
          ],
        ),
      ),
    );
  }
}
