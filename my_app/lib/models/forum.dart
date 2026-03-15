class ForumCategory {
  final int id;
  final String name;
  final String slug;
  final String description;
  final String icon;
  final int order;
  final int topicCount;

  ForumCategory({
    required this.id,
    required this.name,
    required this.slug,
    required this.description,
    required this.icon,
    required this.order,
    required this.topicCount,
  });

  factory ForumCategory.fromJson(Map<String, dynamic> json) {
    return ForumCategory(
      id: json['id'],
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      description: json['description'] ?? '',
      icon: json['icon'] ?? '',
      order: json['order'] ?? 0,
      topicCount: json['topic_count'] ?? 0,
    );
  }
}

class ForumTopic {
  final int id;
  final int category;
  final String categoryName;
  final int author;
  final String authorName;
  final String title;
  final String slug;
  final String content;
  final bool isPinned;
  final bool isLocked;
  final int viewCount;
  final int replyCount;
  final List<ForumPost>? posts;
  final String createdAt;
  final String updatedAt;

  ForumTopic({
    required this.id,
    required this.category,
    required this.categoryName,
    required this.author,
    required this.authorName,
    required this.title,
    required this.slug,
    required this.content,
    required this.isPinned,
    required this.isLocked,
    required this.viewCount,
    required this.replyCount,
    this.posts,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ForumTopic.fromJson(Map<String, dynamic> json) {
    return ForumTopic(
      id: json['id'],
      category: json['category'] ?? 0,
      categoryName: json['category_name'] ?? '',
      author: json['author'] ?? 0,
      authorName: json['author_name'] ?? '',
      title: json['title'] ?? '',
      slug: json['slug'] ?? '',
      content: json['content'] ?? '',
      isPinned: json['is_pinned'] ?? false,
      isLocked: json['is_locked'] ?? false,
      viewCount: json['view_count'] ?? 0,
      replyCount: json['reply_count'] ?? 0,
      posts: json['posts'] != null
          ? (json['posts'] as List).map((p) => ForumPost.fromJson(p)).toList()
          : null,
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
    );
  }
}

class ForumPost {
  final int id;
  final int topic;
  final int author;
  final String authorName;
  final String content;
  final bool isSolution;
  final String createdAt;
  final String updatedAt;

  ForumPost({
    required this.id,
    required this.topic,
    required this.author,
    required this.authorName,
    required this.content,
    required this.isSolution,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ForumPost.fromJson(Map<String, dynamic> json) {
    return ForumPost(
      id: json['id'],
      topic: json['topic'] ?? 0,
      author: json['author'] ?? 0,
      authorName: json['author_name'] ?? '',
      content: json['content'] ?? '',
      isSolution: json['is_solution'] ?? false,
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
    );
  }
}
