class MoodEntry {
  final String id;
  final DateTime timestamp;
  final int moodLevel; // 1-5: 1=very bad, 5=very good
  final String? note;

  MoodEntry({
    String? id,
    required this.moodLevel,
    this.note,
    DateTime? timestamp,
  })  : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        timestamp = timestamp ?? DateTime.now(),
        assert(moodLevel >= 1 && moodLevel <= 5, 'Mood level must be between 1 and 5');

  factory MoodEntry.fromJson(Map<String, dynamic> json) {
    return MoodEntry(
      id: json['id'] as String?,
      moodLevel: json['mood_level'] as int,
      note: json['note'] as String?,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'mood_level': moodLevel,
      'note': note,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  String get moodEmoji {
    switch (moodLevel) {
      case 1:
        return '😢';
      case 2:
        return '😕';
      case 3:
        return '😐';
      case 4:
        return '🙂';
      case 5:
        return '😊';
      default:
        return '❓';
    }
  }

  String get moodDescription {
    switch (moodLevel) {
      case 1:
        return 'Very Bad';
      case 2:
        return 'Bad';
      case 3:
        return 'Okay';
      case 4:
        return 'Good';
      case 5:
        return 'Very Good';
      default:
        return 'Unknown';
    }
  }
} 