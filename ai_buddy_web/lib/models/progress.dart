class ProgressPost {
  final int id;
  final String timestamp;
  final Map<String, dynamic> progressSummary;
  final String? sharedText;

  ProgressPost({
    required this.id,
    required this.timestamp,
    required this.progressSummary,
    this.sharedText,
  });

  factory ProgressPost.fromJson(Map<String, dynamic> json) {
    return ProgressPost(
      id: json['id'],
      timestamp: json['timestamp'],
      progressSummary: Map<String, dynamic>.from(json['progress_summary']),
      sharedText: json['shared_text'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp,
      'progress_summary': progressSummary,
      'shared_text': sharedText,
    };
  }
}

class CommunityFeedItem {
  final int id;
  final String timestamp;
  final Map<String, dynamic> progressSummary;
  final String? sharedText;

  CommunityFeedItem({
    required this.id,
    required this.timestamp,
    required this.progressSummary,
    this.sharedText,
  });

  factory CommunityFeedItem.fromJson(Map<String, dynamic> json) {
    return CommunityFeedItem(
      id: json['id'],
      timestamp: json['timestamp'],
      progressSummary: Map<String, dynamic>.from(json['progress_summary']),
      sharedText: json['shared_text'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp,
      'progress_summary': progressSummary,
      'shared_text': sharedText,
    };
  }
}

class ProgressSummary {
  final int assessmentCount;
  final int taskCompletions;
  final int totalPointsEarned;
  final double? lastAssessmentScore;

  ProgressSummary({
    required this.assessmentCount,
    required this.taskCompletions,
    required this.totalPointsEarned,
    this.lastAssessmentScore,
  });

  factory ProgressSummary.fromJson(Map<String, dynamic> json) {
    return ProgressSummary(
      assessmentCount: json['assessment_count'] ?? 0,
      taskCompletions: json['task_completions'] ?? 0,
      totalPointsEarned: json['total_points_earned'] ?? 0,
      lastAssessmentScore: json['last_assessment_score']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'assessment_count': assessmentCount,
      'task_completions': taskCompletions,
      'total_points_earned': totalPointsEarned,
      'last_assessment_score': lastAssessmentScore,
    };
  }
} 