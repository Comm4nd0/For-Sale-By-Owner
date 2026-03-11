import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../models/viewing_slot.dart';

class ViewingSlotsScreen extends StatefulWidget {
  final int propertyId;
  final bool isOwner;
  const ViewingSlotsScreen({super.key, required this.propertyId, this.isOwner = false});

  @override
  State<ViewingSlotsScreen> createState() => _ViewingSlotsScreenState();
}

class _ViewingSlotsScreenState extends State<ViewingSlotsScreen> {
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
      final slots = await api.getViewingSlots(widget.propertyId);
      if (mounted) setState(() { _slots = slots; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addSlot() async {
    DateTime? date;
    TimeOfDay? startTime;
    TimeOfDay? endTime;

    date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (date == null || !mounted) return;

    startTime = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 10, minute: 0));
    if (startTime == null || !mounted) return;

    endTime = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 11, minute: 0));
    if (endTime == null || !mounted) return;

    try {
      final api = context.read<ApiService>();
      await api.createViewingSlot(widget.propertyId, {
        'date': '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
        'start_time': '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}',
        'end_time': '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
      });
      _loadSlots();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
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
    return Scaffold(
      appBar: AppBar(title: const Text('Viewing Slots')),
      floatingActionButton: widget.isOwner
          ? FloatingActionButton(onPressed: _addSlot, child: const Icon(Icons.add))
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _slots.isEmpty
              ? const Center(child: Text('No viewing slots available'))
              : RefreshIndicator(
                  onRefresh: _loadSlots,
                  child: ListView.builder(
                    itemCount: _slots.length,
                    itemBuilder: (context, index) {
                      final slot = _slots[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: ListTile(
                          leading: const Icon(Icons.calendar_today),
                          title: Text(slot.date ?? slot.dayOfWeekDisplay),
                          subtitle: Text('${slot.startTime} - ${slot.endTime}\n'
                              '${slot.currentBookings}/${slot.maxBookings} booked'),
                          isThreeLine: true,
                          trailing: !widget.isOwner && slot.isAvailable
                              ? ElevatedButton(
                                  onPressed: () => _bookSlot(slot),
                                  child: const Text('Book'),
                                )
                              : widget.isOwner
                                  ? IconButton(
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: () async {
                                        final api = context.read<ApiService>();
                                        await api.deleteViewingSlot(widget.propertyId, slot.id);
                                        _loadSlots();
                                      },
                                    )
                                  : const Text('Full', style: TextStyle(color: Colors.red)),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
