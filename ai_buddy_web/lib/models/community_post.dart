class CommunityPost {
  final int id;
  final String topic;
  final String body;
  final DateTime? createdAt;
  final int relate;
  final int helped;
  final int strength;

  CommunityPost({
    required this.id,
    required this.topic,
    required this.body,
    required this.createdAt,
    required this.relate,
    required this.helped,
    required this.strength,
  });

  factory CommunityPost.fromJson(Map<String, dynamic> json) {
    final reactions = (json['reactions'] as Map?) ?? const {};
    return CommunityPost(
      id: json['id'] as int,
      topic: (json['topic'] as String? ?? 'general').trim(),
      body: (json['body'] as String? ?? '').trim(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      relate: (reactions['relate'] as int?) ?? 0,
      helped: (reactions['helped'] as int?) ?? 0,
      strength: (reactions['strength'] as int?) ?? 0,
    );
  }
}
