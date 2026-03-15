import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../models/forum.dart';
import '../widgets/branded_app_bar.dart';

const Color _brandColor = Color(0xFF115E66);

// ---------------------------------------------------------------------------
// Icon mapping for forum categories
// ---------------------------------------------------------------------------
IconData _categoryIcon(String icon) {
  switch (icon) {
    case 'gavel':
      return Icons.gavel;
    case 'home':
      return Icons.home;
    case 'attach_money':
      return Icons.attach_money;
    case 'question_answer':
      return Icons.question_answer;
    case 'handshake':
      return Icons.handshake;
    case 'build':
      return Icons.build;
    case 'landscape':
      return Icons.landscape;
    case 'school':
      return Icons.school;
    case 'description':
      return Icons.description;
    case 'camera_alt':
      return Icons.camera_alt;
    case 'tips_and_updates':
      return Icons.tips_and_updates;
    default:
      return Icons.forum;
  }
}

// ============================================================================
// ForumScreen – categories list (View 1)
// ============================================================================
class ForumScreen extends StatefulWidget {
  const ForumScreen({super.key});

  @override
  State<ForumScreen> createState() => _ForumScreenState();
}

class _ForumScreenState extends State<ForumScreen> {
  List<ForumCategory> _categories = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<ApiService>();
      final data = await api.getForumCategories();
      final list =
          data.map<ForumCategory>((j) => ForumCategory.fromJson(j)).toList();
      list.sort((a, b) => a.order.compareTo(b.order));
      if (!mounted) return;
      setState(() {
        _categories = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _openCategory(ForumCategory category) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _TopicListScreen(category: category),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BrandedAppBar.build(context: context),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: _brandColor),
      );
    }
    if (_error != null) {
      return _ErrorRetry(message: _error!, onRetry: _loadCategories);
    }
    if (_categories.isEmpty) {
      return const _EmptyState(
        icon: Icons.forum_outlined,
        title: 'No categories yet',
        subtitle: 'Forum categories will appear here once created.',
      );
    }

    return RefreshIndicator(
      color: _brandColor,
      onRefresh: _loadCategories,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = constraints.maxWidth > 600 ? 3 : 2;
          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.0,
            ),
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              return _CategoryCard(
                category: _categories[index],
                onTap: () => _openCategory(_categories[index]),
              );
            },
          );
        },
      ),
    );
  }
}

// ============================================================================
// Category card widget
// ============================================================================
class _CategoryCard extends StatelessWidget {
  final ForumCategory category;
  final VoidCallback onTap;

  const _CategoryCard({required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _brandColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _categoryIcon(category.icon),
                  color: _brandColor,
                  size: 26,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                category.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _brandColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                category.description,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _brandColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${category.topicCount} topic${category.topicCount == 1 ? '' : 's'}',
                  style: const TextStyle(fontSize: 11, color: _brandColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Topic list screen – View 2: topics in a category (pinned first, then date)
// ============================================================================
class _TopicListScreen extends StatefulWidget {
  final ForumCategory category;

  const _TopicListScreen({required this.category});

  @override
  State<_TopicListScreen> createState() => _TopicListScreenState();
}

class _TopicListScreenState extends State<_TopicListScreen> {
  List<ForumTopic> _topics = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTopics();
  }

  Future<void> _loadTopics() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<ApiService>();
      final data = await api.getForumTopics(category: widget.category.id);
      final list =
          data.map<ForumTopic>((j) => ForumTopic.fromJson(j)).toList();

      // Sort: pinned first, then by creation date (newest first).
      list.sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        return b.createdAt.compareTo(a.createdAt);
      });

      if (!mounted) return;
      setState(() {
        _topics = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _openTopic(ForumTopic topic) async {
    final refreshNeeded = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _TopicDetailScreen(topicId: topic.id),
      ),
    );
    if (refreshNeeded == true) _loadTopics();
  }

  Future<void> _createTopic() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _CreateTopicScreen(category: widget.category),
      ),
    );
    if (created == true) _loadTopics();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BrandedAppBar.build(context: context),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _brandColor,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: _createTopic,
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: _brandColor),
      );
    }
    if (_error != null) {
      return _ErrorRetry(message: _error!, onRetry: _loadTopics);
    }
    if (_topics.isEmpty) {
      return const _EmptyState(
        icon: Icons.topic_outlined,
        title: 'No topics yet',
        subtitle: 'Be the first to start a discussion!',
      );
    }

    return RefreshIndicator(
      color: _brandColor,
      onRefresh: _loadTopics,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _topics.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, indent: 16, endIndent: 16),
        itemBuilder: (context, index) {
          final topic = _topics[index];
          return _TopicTile(topic: topic, onTap: () => _openTopic(topic));
        },
      ),
    );
  }
}

// ============================================================================
// Topic list tile
// ============================================================================
class _TopicTile extends StatelessWidget {
  final ForumTopic topic;
  final VoidCallback onTap;

  const _TopicTile({required this.topic, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (topic.isPinned)
            const Icon(Icons.push_pin, size: 18, color: _brandColor)
          else if (topic.isLocked)
            Icon(Icons.lock, size: 18, color: Colors.grey.shade500)
          else
            const Icon(
                Icons.chat_bubble_outline, size: 18, color: _brandColor),
        ],
      ),
      title: Row(
        children: [
          if (topic.isPinned)
            Container(
              margin: const EdgeInsets.only(right: 6),
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: _brandColor.withAlpha(25),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Pinned',
                style: TextStyle(
                  fontSize: 10,
                  color: _brandColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (topic.isLocked)
            Container(
              margin: const EdgeInsets.only(right: 6),
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Locked',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.orange.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Expanded(
            child: Text(
              topic.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            Text(
              topic.authorName,
              style:
                  TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(width: 10),
            Icon(Icons.visibility, size: 13, color: Colors.grey.shade400),
            const SizedBox(width: 3),
            Text(
              '${topic.viewCount}',
              style:
                  TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
            const SizedBox(width: 10),
            Icon(Icons.reply, size: 13, color: Colors.grey.shade400),
            const SizedBox(width: 3),
            Text(
              '${topic.replyCount}',
              style:
                  TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
      trailing: Text(
        _formatDate(topic.createdAt),
        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
      ),
    );
  }
}

// ============================================================================
// Topic detail screen – View 3: original post + replies + reply input
// ============================================================================
class _TopicDetailScreen extends StatefulWidget {
  final int topicId;

  const _TopicDetailScreen({required this.topicId});

  @override
  State<_TopicDetailScreen> createState() => _TopicDetailScreenState();
}

class _TopicDetailScreenState extends State<_TopicDetailScreen> {
  ForumTopic? _topic;
  bool _loading = true;
  String? _error;
  bool _replying = false;
  final TextEditingController _replyController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadTopic();
  }

  @override
  void dispose() {
    _replyController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadTopic() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<ApiService>();
      final data = await api.getForumTopic(widget.topicId);
      if (!mounted) return;
      setState(() {
        _topic = ForumTopic.fromJson(data);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _submitReply() async {
    final content = _replyController.text.trim();
    if (content.isEmpty) return;
    setState(() => _replying = true);
    try {
      final api = context.read<ApiService>();
      await api.createForumPost(widget.topicId, content);
      _replyController.clear();
      FocusScope.of(context).unfocus();
      await _loadTopic();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to post reply: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _replying = false);
    }
  }

  Future<void> _markSolution(int postId) async {
    try {
      final api = context.read<ApiService>();
      await api.markForumSolution(postId);
      await _loadTopic();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Post marked as solution'),
          backgroundColor: _brandColor,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to mark solution: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BrandedAppBar.build(context: context),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: _brandColor),
      );
    }
    if (_error != null) {
      return _ErrorRetry(message: _error!, onRetry: _loadTopic);
    }
    if (_topic == null) {
      return const _EmptyState(
        icon: Icons.topic_outlined,
        title: 'Topic not found',
        subtitle: 'This topic may have been removed.',
      );
    }

    final topic = _topic!;
    final posts = topic.posts ?? [];

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            color: _brandColor,
            onRefresh: _loadTopic,
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
              children: [
                // Topic header
                _TopicHeader(topic: topic),
                // Original post
                _PostCard(
                  authorName: topic.authorName,
                  content: topic.content,
                  createdAt: topic.createdAt,
                  isSolution: false,
                  isOriginalPost: true,
                  showMarkSolution: false,
                  onMarkSolution: null,
                ),
                if (posts.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      '${posts.length} Repl${posts.length == 1 ? 'y' : 'ies'}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _brandColor,
                      ),
                    ),
                  ),
                ...posts.map((post) {
                  return _PostCard(
                    authorName: post.authorName,
                    content: post.content,
                    createdAt: post.createdAt,
                    isSolution: post.isSolution,
                    isOriginalPost: false,
                    showMarkSolution: !post.isSolution,
                    onMarkSolution: () => _markSolution(post.id),
                  );
                }),
                if (topic.isLocked)
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.lock,
                            size: 18, color: Colors.orange.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'This topic is locked. New replies are not allowed.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.orange.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (!topic.isLocked) _buildReplyBar(),
      ],
    );
  }

  Widget _buildReplyBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 6,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        8 + MediaQuery.of(context).padding.bottom,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _replyController,
              maxLines: 4,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Write a reply...',
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _replying
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _brandColor,
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.send_rounded, color: _brandColor),
                  onPressed: _submitReply,
                ),
        ],
      ),
    );
  }
}

// ============================================================================
// Topic header (title, badges, meta)
// ============================================================================
class _TopicHeader extends StatelessWidget {
  final ForumTopic topic;

  const _TopicHeader({required this.topic});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _brandColor.withAlpha(10),
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _badge(topic.categoryName, _brandColor),
              if (topic.isPinned) _badge('Pinned', _brandColor),
              if (topic.isLocked)
                _badge('Locked', Colors.orange.shade700),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            topic.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: _brandColor.withAlpha(40),
                child: Text(
                  topic.authorName.isNotEmpty
                      ? topic.authorName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _brandColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                topic.authorName,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              Icon(Icons.visibility,
                  size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 3),
              Text(
                '${topic.viewCount} views',
                style:
                    TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
              const SizedBox(width: 12),
              Text(
                _formatDate(topic.createdAt),
                style:
                    TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
            fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ============================================================================
// Post card – original post and replies
// ============================================================================
class _PostCard extends StatelessWidget {
  final String authorName;
  final String content;
  final String createdAt;
  final bool isSolution;
  final bool isOriginalPost;
  final bool showMarkSolution;
  final VoidCallback? onMarkSolution;

  const _PostCard({
    required this.authorName,
    required this.content,
    required this.createdAt,
    required this.isSolution,
    required this.isOriginalPost,
    required this.showMarkSolution,
    required this.onMarkSolution,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      decoration: BoxDecoration(
        color: isSolution ? const Color(0xFFE8F5E9) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color:
              isSolution ? Colors.green.shade300 : Colors.grey.shade200,
          width: isSolution ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author header
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isOriginalPost
                  ? _brandColor.withAlpha(12)
                  : Colors.grey.shade50,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(9)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: isOriginalPost
                      ? _brandColor.withAlpha(40)
                      : _brandColor.withAlpha(30),
                  child: Text(
                    authorName.isNotEmpty
                        ? authorName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _brandColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        authorName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _formatDate(createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSolution)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.green.shade600,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle,
                            size: 14, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'Solution',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (showMarkSolution)
                  TextButton.icon(
                    onPressed: onMarkSolution,
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: const Text('Mark Solution',
                        style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.green.shade700,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(14),
            child: Text(
              content,
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Create topic screen
// ============================================================================
class _CreateTopicScreen extends StatefulWidget {
  final ForumCategory category;

  const _CreateTopicScreen({required this.category});

  @override
  State<_CreateTopicScreen> createState() => _CreateTopicScreenState();
}

class _CreateTopicScreenState extends State<_CreateTopicScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final api = context.read<ApiService>();
      await api.createForumTopic(
        widget.category.id,
        _titleController.text.trim(),
        _contentController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create topic: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BrandedAppBar.build(
        context: context,
        actions: [
          _submitting
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.check),
                  tooltip: 'Submit',
                  onPressed: _submit,
                ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'New Topic in ${widget.category.name}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: _brandColor,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _titleController,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Title',
                  hintText: 'Give your topic a descriptive title',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: _brandColor, width: 2),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Title is required';
                  }
                  if (val.trim().length < 5) {
                    return 'Title must be at least 5 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _contentController,
                maxLines: 10,
                minLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Content',
                  hintText:
                      'Describe your question or topic in detail...',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: _brandColor, width: 2),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Content is required';
                  }
                  if (val.trim().length < 20) {
                    return 'Content must be at least 20 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brandColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    disabledBackgroundColor: _brandColor.withAlpha(120),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Create Topic',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Shared utility widgets
// ============================================================================

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorRetry({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: 56, color: Colors.red.shade300),
            const SizedBox(height: 16),
            const Text(
              'Something went wrong',
              style:
                  TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontSize: 13, color: Colors.grey.shade600),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _brandColor,
                side: const BorderSide(color: _brandColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Date formatting helper
// ============================================================================
String _formatDate(String dateStr) {
  if (dateStr.isEmpty) return '';
  try {
    final date = DateTime.parse(dateStr);
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 365) {
      final month = _monthAbbrev(date.month);
      return '$month ${date.day}';
    }
    return '${_monthAbbrev(date.month)} ${date.day}, ${date.year}';
  } catch (_) {
    return dateStr;
  }
}

String _monthAbbrev(int month) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return months[month - 1];
}
