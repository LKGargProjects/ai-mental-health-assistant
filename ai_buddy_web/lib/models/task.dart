class GamifiedTask {
  final int id;
  final String name;
  final String description;
  final int points;
  final String taskType;
  final bool isRecurring;

  GamifiedTask({
    required this.id,
    required this.name,
    required this.description,
    required this.points,
    required this.taskType,
    required this.isRecurring,
  });

  factory GamifiedTask.fromJson(Map<String, dynamic> json) {
    return GamifiedTask(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      points: json['points'],
      taskType: json['task_type'],
      isRecurring: json['is_recurring'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'points': points,
      'task_type': taskType,
      'is_recurring': isRecurring,
    };
  }
}

class TaskCompletion {
  final int taskId;
  final int pointsEarned;
  final String completionTimestamp;

  TaskCompletion({
    required this.taskId,
    required this.pointsEarned,
    required this.completionTimestamp,
  });

  factory TaskCompletion.fromJson(Map<String, dynamic> json) {
    return TaskCompletion(
      taskId: json['task_id'],
      pointsEarned: json['points_earned'],
      completionTimestamp: json['completion_timestamp'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'task_id': taskId,
      'points_earned': pointsEarned,
      'completion_timestamp': completionTimestamp,
    };
  }
}

class TaskReminder {
  final int taskId;
  final String name;
  final String description;
  final int points;
  final String taskType;
  final bool isRecurring;

  TaskReminder({
    required this.taskId,
    required this.name,
    required this.description,
    required this.points,
    required this.taskType,
    required this.isRecurring,
  });

  factory TaskReminder.fromJson(Map<String, dynamic> json) {
    return TaskReminder(
      taskId: json['task_id'],
      name: json['name'],
      description: json['description'],
      points: json['points'],
      taskType: json['task_type'],
      isRecurring: json['is_recurring'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'task_id': taskId,
      'name': name,
      'description': description,
      'points': points,
      'task_type': taskType,
      'is_recurring': isRecurring,
    };
  }
} 