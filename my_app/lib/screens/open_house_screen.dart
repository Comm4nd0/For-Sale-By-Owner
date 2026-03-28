import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import '../models/open_house_event.dart';
import '../services/api_service.dart';
import '../widgets/branded_app_bar.dart';

const _brandColor = Color(0xFF115E66);

class OpenHouseScreen extends StatefulWidget {
  final int? propertyId;
  const OpenHouseScreen({super.key, this.propertyId});

  @override
  State<OpenHouseScreen> createState() => _OpenHouseScreenState();
}

class _OpenHouseScreenState extends State<OpenHouseScreen> {
  List<OpenHouseEvent> _events = [];
  bool _loading = true;
  String? _error;

  bool get _isSellerView => widget.propertyId != null;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<ApiService>();
      final results = await api.getOpenHouseEvents(propertyId: widget.propertyId);
      if (mounted) {
        setState(() {
          _events = results
              .map<OpenHouseEvent>(
                  (json) => OpenHouseEvent.fromJson(json as Map<String, dynamic>))
              .toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  // ── Formatting helpers ──────────────────────────────────────────

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      const weekdays = [
        'Monday', 'Tuesday', 'Wednesday', 'Thursday',
        'Friday', 'Saturday', 'Sunday',
      ];
      final weekday = weekdays[date.weekday - 1];
      final month = months[date.month - 1];
      return '$weekday, $month ${date.day}, ${date.year}';
    } catch (_) {
      return dateStr;
    }
  }

  String _formatTime(String timeStr) {
    try {
      final parts = timeStr.split(':');
      final hour = int.parse(parts[0]);
      final minute = parts[1];
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
      return '$displayHour:$minute $period';
    } catch (_) {
      return timeStr;
    }
  }

  // ── Create event dialog ─────────────────────────────────────────

  Future<void> _showCreateEventDialog() async {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final maxAttendeesController = TextEditingController();

    DateTime? selectedDate;
    TimeOfDay startTime = const TimeOfDay(hour: 10, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 12, minute: 0);

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          String formatTimeOfDay(TimeOfDay t) =>
              '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

          String formatDateForApi(DateTime d) =>
              '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

          String displayTime(TimeOfDay t) {
            final period = t.hour >= 12 ? 'PM' : 'AM';
            final hour = t.hour == 0 ? 12 : (t.hour > 12 ? t.hour - 12 : t.hour);
            return '$hour:${t.minute.toString().padLeft(2, '0')} $period';
          }

          return AlertDialog(
            title: const Text('Create Open House Event'),
            content: SizedBox(
              width: double.maxFinite,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: 'Title',
                          hintText: 'e.g. Weekend Open House',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Title is required' : null,
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: ctx,
                            initialDate:
                                selectedDate ?? DateTime.now().add(const Duration(days: 1)),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 180)),
                          );
                          if (date != null) {
                            setDialogState(() => selectedDate = date);
                          }
                        },
                        icon: PhosphorIcon(PhosphorIconsDuotone.calendar, size: 18),
                        label: Text(
                          selectedDate != null
                              ? '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}'
                              : 'Select Date',
                        ),
                      ),
                      if (selectedDate == null)
                        const Padding(
                          padding: EdgeInsets.only(top: 4, left: 12),
                          child: Text(
                            'Date is required',
                            style: TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                final t = await showTimePicker(
                                    context: ctx, initialTime: startTime);
                                if (t != null) setDialogState(() => startTime = t);
                              },
                              child: Text('Start: ${displayTime(startTime)}'),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text('to'),
                          ),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                final t = await showTimePicker(
                                    context: ctx, initialTime: endTime);
                                if (t != null) setDialogState(() => endTime = t);
                              },
                              child: Text('End: ${displayTime(endTime)}'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          hintText: 'Details about the open house...',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: maxAttendeesController,
                        decoration: const InputDecoration(
                          labelText: 'Max Attendees (optional)',
                          hintText: 'Leave blank for unlimited',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v != null && v.isNotEmpty) {
                            final n = int.tryParse(v);
                            if (n == null || n < 1) {
                              return 'Enter a positive number';
                            }
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _brandColor),
                onPressed: () {
                  if (!formKey.currentState!.validate() || selectedDate == null) return;
                  final data = <String, dynamic>{
                    'property': widget.propertyId,
                    'title': titleController.text.trim(),
                    'date': formatDateForApi(selectedDate!),
                    'start_time': formatTimeOfDay(startTime),
                    'end_time': formatTimeOfDay(endTime),
                    'description': descriptionController.text.trim(),
                  };
                  final maxStr = maxAttendeesController.text.trim();
                  if (maxStr.isNotEmpty) {
                    data['max_attendees'] = int.parse(maxStr);
                  }
                  Navigator.pop(ctx, data);
                },
                child: const Text('Create', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );

    if (result == null || !mounted) return;

    try {
      final api = context.read<ApiService>();
      await api.createOpenHouseEvent(widget.propertyId!, result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Open house event created')),
        );
      }
      _loadEvents();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create event: $e')),
        );
      }
    }
  }

  // ── Delete event ────────────────────────────────────────────────

  Future<void> _deleteEvent(OpenHouseEvent event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Event'),
        content: Text('Are you sure you want to delete "${event.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final api = context.read<ApiService>();
      await api.deleteOpenHouseEvent(widget.propertyId!, event.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event deleted')),
        );
      }
      _loadEvents();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete event: $e')),
        );
      }
    }
  }

  // ── RSVP / Cancel RSVP ─────────────────────────────────────────

  Future<void> _toggleRsvp(OpenHouseEvent event) async {
    try {
      final api = context.read<ApiService>();
      if (event.userHasRsvpd) {
        await api.cancelRsvp(event.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('RSVP cancelled')),
          );
        }
      } else {
        await api.rsvpOpenHouse(event.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('RSVP confirmed!')),
          );
        }
      }
      _loadEvents();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  // ── Build ───────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BrandedAppBar.build(context: context, showHomeButton: true),
      floatingActionButton: _isSellerView
          ? FloatingActionButton(
              onPressed: _showCreateEventDialog,
              backgroundColor: _brandColor,
              child: PhosphorIcon(PhosphorIconsDuotone.plus, color: Colors.white),
            )
          : null,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _brandColor));
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PhosphorIcon(PhosphorIconsDuotone.warningCircle, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Failed to load events',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadEvents,
                icon: PhosphorIcon(PhosphorIconsDuotone.arrowClockwise),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(backgroundColor: _brandColor),
              ),
            ],
          ),
        ),
      );
    }

    if (_events.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: _brandColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: PhosphorIcon(PhosphorIconsDuotone.calendarX, size: 36, color: _brandColor),
              ),
              const SizedBox(height: 20),
              const Text(
                'No Open House Events',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
              ),
              const SizedBox(height: 8),
              Text(
                _isSellerView
                    ? 'Tap + to create an open house event for this property.'
                    : 'There are no upcoming open house events right now.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF666666), height: 1.5),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: _brandColor,
      onRefresh: _loadEvents,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: _events.length,
        itemBuilder: (context, index) => _buildEventCard(_events[index]),
      ),
    );
  }

  Widget _buildEventCard(OpenHouseEvent event) {
    final formattedDate = _formatDate(event.date);
    final formattedStart = _formatTime(event.startTime);
    final formattedEnd = _formatTime(event.endTime);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _brandColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: PhosphorIcon(PhosphorIconsDuotone.house, size: 22, color: _brandColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF222222),
                        ),
                      ),
                      if (!event.isActive)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Inactive',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ),
                    ],
                  ),
                ),
                if (_isSellerView)
                  IconButton(
                    icon: PhosphorIcon(PhosphorIconsDuotone.trash, color: Colors.red),
                    tooltip: 'Delete event',
                    onPressed: () => _deleteEvent(event),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Date & Time
            Row(
              children: [
                PhosphorIcon(PhosphorIconsDuotone.calendar, size: 15, color: _brandColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    formattedDate,
                    style: const TextStyle(fontSize: 14, color: Color(0xFF444444)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                PhosphorIcon(PhosphorIconsDuotone.clock, size: 15, color: _brandColor),
                const SizedBox(width: 6),
                Text(
                  '$formattedStart - $formattedEnd',
                  style: const TextStyle(fontSize: 14, color: Color(0xFF444444)),
                ),
              ],
            ),

            // Description
            if (event.description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                event.description,
                style: const TextStyle(fontSize: 13, color: Color(0xFF666666), height: 1.4),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 12),

            // RSVP info & action
            Row(
              children: [
                PhosphorIcon(PhosphorIconsDuotone.users, size: 16, color: _brandColor),
                const SizedBox(width: 6),
                Text(
                  event.maxAttendees != null
                      ? '${event.rsvpCount} / ${event.maxAttendees} attendees'
                      : '${event.rsvpCount} attendee${event.rsvpCount == 1 ? '' : 's'}',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF555555)),
                ),
                const Spacer(),
                if (!_isSellerView) _buildRsvpButton(event),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRsvpButton(OpenHouseEvent event) {
    if (event.userHasRsvpd) {
      return OutlinedButton.icon(
        onPressed: () => _toggleRsvp(event),
        icon: PhosphorIcon(PhosphorIconsDuotone.checkCircle, size: 16, color: _brandColor),
        label: const Text('Cancel RSVP'),
        style: OutlinedButton.styleFrom(
          foregroundColor: _brandColor,
          side: const BorderSide(color: _brandColor),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          textStyle: const TextStyle(fontSize: 13),
        ),
      );
    }

    if (!event.hasCapacity) {
      return const Chip(
        label: Text('Full', style: TextStyle(fontSize: 12, color: Colors.white)),
        backgroundColor: Colors.grey,
        padding: EdgeInsets.zero,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      );
    }

    return ElevatedButton.icon(
      onPressed: () => _toggleRsvp(event),
      icon: PhosphorIcon(PhosphorIconsDuotone.calendarCheck, size: 16),
      label: const Text('RSVP'),
      style: ElevatedButton.styleFrom(
        backgroundColor: _brandColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        textStyle: const TextStyle(fontSize: 13),
      ),
    );
  }
}
