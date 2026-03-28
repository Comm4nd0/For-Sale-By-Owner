import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import '../constants/app_theme.dart';
import '../widgets/branded_app_bar.dart';
import '../models/enquiry.dart';
import '../models/reply.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class EnquiryDetailScreen extends StatefulWidget {
  final Enquiry enquiry;

  const EnquiryDetailScreen({super.key, required this.enquiry});

  @override
  State<EnquiryDetailScreen> createState() => _EnquiryDetailScreenState();
}

class _EnquiryDetailScreenState extends State<EnquiryDetailScreen> {
  final _replyController = TextEditingController();
  late List<Reply> _replies;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _replies = List.from(widget.enquiry.replies);
    _markAsRead();
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _markAsRead() async {
    if (widget.enquiry.isRead) return;

    try {
      final apiService = context.read<ApiService>();
      await apiService.markEnquiryRead(widget.enquiry.id);
    } catch (_) {
      // Silently fail
    }
  }

  Future<void> _sendReply() async {
    final message = _replyController.text.trim();
    if (message.isEmpty) return;

    setState(() => _isSending = true);

    try {
      final apiService = context.read<ApiService>();
      final reply = await apiService.replyToEnquiry(widget.enquiry.id, message);
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
                  // Original message card
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
                                widget.enquiry.senderName.isNotEmpty
                                    ? widget.enquiry.senderName
                                    : widget.enquiry.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                _formatDate(widget.enquiry.createdAt),
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[500]),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(widget.enquiry.message),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
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
                        : PhosphorIcon(PhosphorIconsDuotone.paperPlaneTilt, color: AppTheme.forestMid),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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
