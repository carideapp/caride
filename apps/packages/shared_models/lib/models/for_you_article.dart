/// Educational & blog article model for the customer "For you" section.
class ForYouArticle {
  const ForYouArticle({
    required this.id,
    required this.title,
    required this.shortDescription,
    required this.content,
    required this.coverImageUrl,
    this.category = 'Safety',
    this.readTime = '3 min read',
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String shortDescription;
  final String content;
  final String coverImageUrl;
  final String category;
  final String readTime;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory ForYouArticle.fromMap(Map<String, dynamic> map, String docId) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is DateTime) return val;
      if (val is String) return DateTime.tryParse(val);
      try {
        return (val as dynamic).toDate() as DateTime;
      } catch (_) {
        return null;
      }
    }

    return ForYouArticle(
      id: docId,
      title: (map['title'] as String?)?.trim() ?? '',
      shortDescription: (map['shortDescription'] as String?)?.trim() ?? '',
      content: (map['content'] as String?)?.trim() ?? '',
      coverImageUrl: (map['coverImageUrl'] as String?)?.trim() ?? '',
      category: (map['category'] as String?)?.trim() ?? 'Tips',
      readTime: (map['readTime'] as String?)?.trim() ?? '3 min read',
      isActive: map['isActive'] as bool? ?? true,
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'shortDescription': shortDescription,
      'content': content,
      'coverImageUrl': coverImageUrl,
      'category': category,
      'readTime': readTime,
      'isActive': isActive,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}
