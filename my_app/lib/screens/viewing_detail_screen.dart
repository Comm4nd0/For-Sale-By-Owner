import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_theme.dart';
import '../widgets/branded_app_bar.dart';
import '../models/viewing_request.dart';
import '../models/reply.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class ViewingDetailScreen extends StatefulWidget {
  final ViewingRequest viewing;

  const ViewingDetailScreen({super.key, required this.viewing});

  @override
  State<ViewingDetailScreen> createState() => _ViewingDetailScreenState();
}

class _ViewingDetailScreenState extends State<ViewingDetailScreen> {
  final _replyController = TextEditingController();
  late List<Reply> _replies;
  late String _status;
  bool _isSending = false;
  bool _isUpdatingStatus = false;

  @override
  void initState() {
    super.initState();
    _replies = List.from(widget.viewing.replies);
    _status = widget.viewing.status;
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _isUpdatingStatus = true);

    try {
      final apiService = context.read<ApiService>();
      await apiService.updateViewingStatus(widget.viewing.id, newStatus);
      setState(() {
        _status = newStatus;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Viewing $newStatus')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdatingStatus = false);
    }
  }

  Future<void> _sendReply() async {
    final message = _replyController.text.trim();
    if (message.isEmpty) return;

    setState(() => _isSending = true);

    try {
      final apiService = context.read<ApiService>();
      final reply =
          await apiService.replyToViewing(widget.viewing.id, message);
      setState(() {
        _replies.add(reply);
        _replyController.clear();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send reply: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.green;
      case 'declined':
        return Colors.red;
      case 'completed':
        return Colors.blue;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final currentUserId = authService.userId;

    return Scaffold(
      appBar: BrandedAppBar.build(context: context, showHomeButton: true),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Details card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                widget.viewing.requesterName.isNotEmpty
                                    ? widget.viewing.requesterName
                                    : widget.viewing.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _statusColor(_status),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  _status,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildDetailRow(Icons.calendar_today,
                              'Preferred: ${widget.viewing.preferredDate} at ${widget.viewing.preferredTime}'),
                          if (widget.viewing.alternativeDate != null &&
                              widget.viewing.alternativeDate!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            _buildDetailRow(Icons.event_available,
                                'Alternative: ${widget.viewing.alternativeDate} at ${widget.viewing.alternativeTime ?? ''}'),
                          ],
                          if (widget.viewing.message.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(widget.viewing.message),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Action buttons for property owner
                  _buildActionButtons(currentUserId),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    'Replies',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (_replies.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: Text(
                          'No replies yet',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    ..._replies.map((reply) {
                      final isOwn = reply.authorId == currentUserId;
                      return _buildReplyBubble(reply, isOwn);
                    }),
                ],
              ),
            ),
          ),
          // Reply input
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.white,
              border: Border(
                top: BorderSide(color: AppTheme.pebble),
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _replyController,
                      decoration: const InputDecoration(
                        hintText: 'Type a reply...',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                      maxLines: null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _isSending ? null : _sendReply,
                    icon: _isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send, color: AppTheme.forestMid),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(int? currentUserId) {
    // Check if current user is the property owner (not the requester)
    final isPropertyOwner =
        widget.viewing.requesterId != currentUserId;

    if (_isUpdatingStatus) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (isPropertyOwner && _status == 'pending') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () => _updateStatus('confirmed'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                ),
                child: const Text('Confirm'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () => _updateStatus('declined'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                child: const Text('Decline'),
              ),
            ),
          ],
        ),
      );
    }

    if (isPropertyOwner && _status == 'confirmed') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => _updateStatus('completed'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
            ),
            child: const Text('Mark Completed'),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildDetailRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
      ],
    );
  }

  Widget _buildReplyBubble(Reply reply, bool isOwn) {
    return Align(
      alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isOwn ? AppTheme.forestMid : Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              reply.authorName,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: isOwn ? Colors.white70 : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              reply.message,
              style: TextStyle(
                color: isOwn ? Colors.white : AppTheme.charcoal,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatDate(reply.createdAt),
              style: TextStyle(
                fontSize: 10,
                color: isOwn ? Colors.white60 : Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr;
    }
  }
}
