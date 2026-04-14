import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import '../../constants/app_theme.dart';
import '../../services/api_service.dart';
import '../../widgets/branded_app_bar.dart';

class SaleTrackerTimelineScreen extends StatefulWidget {
  final int saleId;
  const SaleTrackerTimelineScreen({super.key, required this.saleId});

  @override
  State<SaleTrackerTimelineScreen> createState() =>
      _SaleTrackerTimelineScreenState();
}

class _SaleTrackerTimelineScreenState
    extends State<SaleTrackerTimelineScreen> {
  List<Map<String, dynamic>> _events = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final api = context.read<ApiService>();
      final json = await api.getSaleTimeline(widget.saleId);
      if (mounted) {
        setState(() {
          _events = json
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load timeline: $e')),
        );
      }
    }
  }

  IconData _eventIcon(String? eventType) {
    switch (eventType) {
      case 'task_completed':
        return PhosphorIconsDuotone.checkCircle;
      case 'task_reassigned':
        return PhosphorIconsDuotone.arrowsLeftRight;
      case 'stage_started':
        return PhosphorIconsDuotone.flag;
      case 'stage_completed':
        return PhosphorIconsDuotone.flagCheckered;
      case 'document_uploaded':
        return PhosphorIconsDuotone.fileArrowUp;
      case 'enquiry_raised':
        return PhosphorIconsDuotone.chatCircleDots;
      case 'enquiry_resolved':
        return PhosphorIconsDuotone.checkSquare;
      case 'sale_instructed':
        return PhosphorIconsDuotone.rocketLaunch;
      case 'contact_logged':
        return PhosphorIconsDuotone.notebook;
      case 'prompt_generated':
        return PhosphorIconsDuotone.megaphone;
      default:
        return PhosphorIconsDuotone.clockCounterClockwise;
    }
  }

  Color _eventColour(String? eventType) {
    switch (eventType) {
      case 'task_completed':
      case 'stage_completed':
      case 'enquiry_resolved':
        return AppTheme.forestDeep;
      case 'sale_instructed':
        return AppTheme.forestMid;
      case 'task_reassigned':
        return AppTheme.warning;
      case 'enquiry_raised':
        return AppTheme.info;
      case 'document_uploaded':
        return const Color(0xFF3B82F6);
      default:
        return AppTheme.slate;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BrandedAppBar.build(context: context),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: _events.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 100),
                        Center(
                          child: Column(
                            children: [
                              Icon(
                                  PhosphorIconsDuotone
                                      .clockCounterClockwise,
                                  size: 48,
                                  color: AppTheme.stone),
                              SizedBox(height: 12),
                              Text('No timeline events yet',
                                  style: TextStyle(
                                      color: AppTheme.slate,
                                      fontSize: 16)),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _events.length + 1,
                      itemBuilder: (ctx, i) {
                        if (i == 0) {
                          return const Padding(
                            padding: EdgeInsets.only(bottom: 16),
                            child: Text(
                              'Timeline',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.charcoal,
                              ),
                            ),
                          );
                        }
                        return _buildTimelineEntry(
                          _events[i - 1],
                          isLast: i == _events.length,
                        );
                      },
                    ),
            ),
    );
  }

  Widget _buildTimelineEntry(
    Map<String, dynamic> event, {
    bool isLast = false,
  }) {
    final eventType = event['event_type'] as String?;
    final title = event['title'] as String? ?? '';
    final description = event['description'] as String? ?? '';
    final timestamp = event['timestamp'] as String? ?? '';
    final colour = _eventColour(eventType);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Vertical line + dot
        SizedBox(
          width: 32,
          child: Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: colour.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _eventIcon(eventType),
                  size: 14,
                  color: colour,
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 48,
                  color: AppTheme.pebble,
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Content
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.charcoal,
                  ),
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(
                        fontSize: 13, color: AppTheme.slate),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  timestamp,
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.stone),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
