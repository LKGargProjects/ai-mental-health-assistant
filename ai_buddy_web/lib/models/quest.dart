import 'package:flutter/material.dart';

enum QuestStatus { locked, unlocked, inProgress, completed }
enum QuestCategory { mindfulness, activity, social, learning, challenge }

class Quest {
  final String id;
  final String title;
  final String description;
  final int xpReward;
  final QuestCategory category;
  final IconData icon;
  final DateTime? completedAt;
  final int progress;
  final int target;
  final QuestStatus status;

  Quest({
    required this.id,
    required this.title,
    required this.description,
    required this.xpReward,
    required this.category,
    required this.icon,
    this.completedAt,
    this.progress = 0,
    required this.target,
    this.status = QuestStatus.locked,
  });

  Quest copyWith({
    int? progress,
    QuestStatus? status,
    DateTime? completedAt,
  }) {
    return Quest(
      id: id,
      title: title,
      description: description,
      xpReward: xpReward,
      category: category,
      icon: icon,
      progress: progress ?? this.progress,
      target: target,
      status: status ?? this.status,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  double get progressPercentage => (progress / target).clamp(0.0, 1.0);
  
  bool get isCompleted => status == QuestStatus.completed;
  
  bool get canStart => status == QuestStatus.unlocked || status == QuestStatus.inProgress;
  
  String get categoryName {
    switch (category) {
      case QuestCategory.mindfulness:
        return 'Mindfulness';
      case QuestCategory.activity:
        return 'Activity';
      case QuestCategory.social:
        return 'Social';
      case QuestCategory.learning:
        return 'Learning';
      case QuestCategory.challenge:
        return 'Challenge';
    }
  }
  
  Color get categoryColor {
    switch (category) {
      case QuestCategory.mindfulness:
        return Colors.blue;
      case QuestCategory.activity:
        return Colors.green;
      case QuestCategory.social:
        return Colors.purple;
      case QuestCategory.learning:
        return Colors.orange;
      case QuestCategory.challenge:
        return Colors.red;
    }
  }
  
  static IconData getIconForCategory(QuestCategory category) {
    switch (category) {
      case QuestCategory.mindfulness:
        return Icons.self_improvement;
      case QuestCategory.activity:
        return Icons.directions_run;
      case QuestCategory.social:
        return Icons.people;
      case QuestCategory.learning:
        return Icons.school;
      case QuestCategory.challenge:
        return Icons.emoji_events;
    }
  }
}

// Sample quests for demonstration
final List<Quest> defaultQuests = [
  Quest(
    id: 'mindfulness_1',
    title: 'Morning Meditation',
    description: 'Complete a 5-minute meditation session',
    xpReward: 50,
    category: QuestCategory.mindfulness,
    icon: Icons.self_improvement,
    target: 1,
    status: QuestStatus.unlocked,
  ),
  Quest(
    id: 'activity_1',
    title: 'Take a Walk',
    description: 'Go for a 10-minute walk outside',
    xpReward: 30,
    category: QuestCategory.activity,
    icon: Icons.directions_walk,
    target: 10, // minutes
    progress: 3,
    status: QuestStatus.inProgress,
  ),
  Quest(
    id: 'social_1',
    title: 'Connect with a Friend',
    description: 'Reach out to someone you care about',
    xpReward: 40,
    category: QuestCategory.social,
    icon: Icons.people,
    target: 1,
    status: QuestStatus.locked,
  ),
  Quest(
    id: 'learning_1',
    title: 'Learn About Mental Health',
    description: 'Read an article about mental wellness',
    xpReward: 25,
    category: QuestCategory.learning,
    icon: Icons.menu_book,
    target: 1,
    status: QuestStatus.unlocked,
  ),
  Quest(
    id: 'challenge_1',
    title: '7-Day Streak',
    description: 'Check in for 7 days in a row',
    xpReward: 100,
    category: QuestCategory.challenge,
    icon: Icons.emoji_events,
    target: 7,
    progress: 2,
    status: QuestStatus.inProgress,
  ),
];
