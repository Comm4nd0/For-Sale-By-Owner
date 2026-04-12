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

      if (result['bulk'] == true) {
        // Multi-day weekly bulk create with per-day schedule
        await api.bulkCreateViewingSlotsSchedule(
          widget.propertyId,
          schedule: (result['schedule'] as List).cast<Map<String, dynamic>>(),
          maxBookings: result['max_bookings'] as int,
        );
        final count = (result['schedule'] as List).length;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$count weekly slot${count != 1 ? 's' : ''} added')),
          );
        }
      } else {
        // Single one-off slot
        await api.createViewingSlot(widget.propertyId, result);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Viewing slot added')),
          );
        }
      }
      _loadSlots();
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
    if (!mounted) return;

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
                      if (!mounted) return;
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

class _AddSlotSheetState extends State<_AddSlotSheet> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // Weekly state
  final Set<int> _selectedDays = {};
  final Map<int, TimeOfDay> _dayStarts = {};
  final Map<int, TimeOfDay> _dayEnds = {};
  int _weeklyMaxBookings = 1;

  // One-off state
  DateTime? _selectedDate;
  TimeOfDay _oneOffStart = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay _oneOffEnd   = const TimeOfDay(hour: 11, minute: 0);
  int _oneOffMaxBookings = 1;

  static const _dayAbbr = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _saveWeekly() {
    if (_selectedDays.isEmpty) return;
    final schedule = (_selectedDays.toList()..sort()).map((d) {
      final start = _dayStarts[d] ?? const TimeOfDay(hour: 10, minute: 0);
      final end = _dayEnds[d] ?? const TimeOfDay(hour: 11, minute: 0);
      return {'day': d, 'start_time': _fmt(start), 'end_time': _fmt(end)};
    }).toList();
    Navigator.pop(context, {
      'bulk': true,
      'schedule': schedule,
      'max_bookings': _weeklyMaxBookings,
    });
  }

  void _saveOneOff() {
    if (_selectedDate == null) return;
    Navigator.pop(context, {
      'bulk': false,
      'date': _fmtDate(_selectedDate!),
      'start_time': _fmt(_oneOffStart),
      'end_time': _fmt(_oneOffEnd),
      'max_bookings': _oneOffMaxBookings,
    });
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
            // Drag handle
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
            const SizedBox(height: 16),

            // Tab bar
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: AppTheme.forestMid,
                  borderRadius: BorderRadius.circular(8),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Colors.white,
                unselectedLabelColor: AppTheme.slate,
                labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PhosphorIcon(PhosphorIconsDuotone.repeat, size: 16),
                        const SizedBox(width: 6),
                        const Text('Weekly'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PhosphorIcon(PhosphorIconsDuotone.calendarCheck, size: 16),
                        const SizedBox(width: 6),
                        const Text('One-off'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Tab content (shown inline, not via TabBarView, to keep bottom sheet sizing simple)
            if (_tabController.index == 0) _buildWeeklyPanel(),
            if (_tabController.index == 1) _buildOneOffPanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyPanel() {
    final sortedDays = _selectedDays.toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Select days',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          'Tap the days, then set the time for each day below.',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(height: 12),

        // Day chips
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(7, (i) {
            final selected = _selectedDays.contains(i);
            return GestureDetector(
              onTap: () => setState(() {
                if (selected) {
                  _selectedDays.remove(i);
                  _dayStarts.remove(i);
                  _dayEnds.remove(i);
                } else {
                  _selectedDays.add(i);
                  _dayStarts[i] = const TimeOfDay(hour: 10, minute: 0);
                  _dayEnds[i] = const TimeOfDay(hour: 11, minute: 0);
                }
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? AppTheme.forestMid : Colors.grey[100],
                  border: Border.all(
                    color: selected ? AppTheme.forestMid : Colors.grey[300]!,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    _dayAbbr[i].substring(0, 2),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: selected ? Colors.white : AppTheme.slate,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 20),

        // Per-day time pickers
        if (sortedDays.isNotEmpty) ...[
          const Text('Time per day', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ...sortedDays.map((d) {
            final start = _dayStarts[d] ?? const TimeOfDay(hour: 10, minute: 0);
            final end = _dayEnds[d] ?? const TimeOfDay(hour: 11, minute: 0);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 70,
                    child: Text(
                      _dayAbbr[d],
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.forestDeep),
                    ),
                  ),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final t = await showTimePicker(context: context, initialTime: start);
                        if (t != null) setState(() => _dayStarts[d] = t);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        textStyle: const TextStyle(fontSize: 13),
                      ),
                      child: Text(start.format(context)),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Text('to', style: TextStyle(fontSize: 12)),
                  ),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final t = await showTimePicker(context: context, initialTime: end);
                        if (t != null) setState(() => _dayEnds[d] = t);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        textStyle: const TextStyle(fontSize: 13),
                      ),
                      child: Text(end.format(context)),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 12),
        ],

        // Max bookings
        const Text('Max Bookings', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        _buildBookingsStepper(
          value: _weeklyMaxBookings,
          onDecrement: () => setState(() => _weeklyMaxBookings--),
          onIncrement: () => setState(() => _weeklyMaxBookings++),
        ),
        const SizedBox(height: 24),

        ElevatedButton(
          onPressed: _selectedDays.isNotEmpty ? _saveWeekly : null,
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
          child: Text(
            _selectedDays.isEmpty
                ? 'Select at least one day'
                : 'Add ${_selectedDays.length} Weekly Slot${_selectedDays.length != 1 ? 's' : ''}',
          ),
        ),
      ],
    );
  }

  Widget _buildOneOffPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Date picker
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
        const SizedBox(height: 20),

        // Time row
        const Text('Time', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  final t = await showTimePicker(context: context, initialTime: _oneOffStart);
                  if (t != null) setState(() => _oneOffStart = t);
                },
                child: Text('Start: ${_oneOffStart.format(context)}'),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('to'),
            ),
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  final t = await showTimePicker(context: context, initialTime: _oneOffEnd);
                  if (t != null) setState(() => _oneOffEnd = t);
                },
                child: Text('End: ${_oneOffEnd.format(context)}'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Max bookings
        const Text('Max Bookings', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        _buildBookingsStepper(
          value: _oneOffMaxBookings,
          onDecrement: () => setState(() => _oneOffMaxBookings--),
          onIncrement: () => setState(() => _oneOffMaxBookings++),
        ),
        const SizedBox(height: 24),

        ElevatedButton(
          onPressed: _selectedDate != null ? _saveOneOff : null,
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
          child: const Text('Add One-off Slot'),
        ),
      ],
    );
  }

  Widget _buildBookingsStepper({
    required int value,
    required VoidCallback onDecrement,
    required VoidCallback onIncrement,
  }) {
    return Row(
      children: [
        IconButton(
          onPressed: value > 1 ? onDecrement : null,
          icon: PhosphorIcon(PhosphorIconsDuotone.minusCircle),
        ),
        Text('$value', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        IconButton(
          onPressed: value < 10 ? onIncrement : null,
          icon: PhosphorIcon(PhosphorIconsDuotone.plusCircle),
        ),
        const SizedBox(width: 8),
        Text(
          value == 1 ? 'booking per slot' : 'bookings per slot',
          style: TextStyle(color: Colors.grey[600]),
        ),
      ],
    );
  }
}