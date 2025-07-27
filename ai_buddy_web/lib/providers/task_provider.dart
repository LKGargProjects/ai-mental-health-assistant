import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/task.dart';

class TaskProvider extends ChangeNotifier {
  final ApiService _apiService;
  List<GamifiedTask> _tasks = [];
  List<TaskReminder> _reminders = [];
  List<TaskCompletion> _completions = [];
  bool _isLoading = false;
  String? _error;

  TaskProvider() : _apiService = ApiService();

  List<GamifiedTask> get tasks => List.unmodifiable(_tasks);
  List<TaskReminder> get reminders => List.unmodifiable(_reminders);
  List<TaskCompletion> get completions => List.unmodifiable(_completions);
  bool get isLoading => _isLoading;
  String? get error => _error;

  int get totalPointsEarned {
    return _completions.fold(0, (sum, completion) => sum + completion.pointsEarned);
  }

  Future<void> loadTasks() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final tasksData = await _apiService.getTasks();
      _tasks = tasksData
          .map((json) => GamifiedTask.fromJson(json))
          .toList();
    } catch (e) {
      _error = 'Failed to load tasks';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadReminders() async {
    try {
      final remindersData = await _apiService.getReminders();
      _reminders = remindersData
          .map((json) => TaskReminder.fromJson(json))
          .toList();
      notifyListeners();
    } catch (e) {
      print('Error loading reminders: $e');
    }
  }

  Future<void> completeTask(int taskId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _apiService.completeTask(taskId);
      final completion = TaskCompletion.fromJson(result);
      _completions.add(completion);
      
      // Remove from reminders if it was there
      _reminders.removeWhere((reminder) => reminder.taskId == taskId);
      
      // Reload reminders to update the list
      await loadReminders();
    } catch (e) {
      _error = 'Failed to complete task';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  bool isTaskCompletedToday(int taskId) {
    final today = DateTime.now();
    return _completions.any((completion) {
      if (completion.taskId != taskId) return false;
      final completionDate = DateTime.parse(completion.completionTimestamp);
      return completionDate.year == today.year &&
             completionDate.month == today.month &&
             completionDate.day == today.day;
    });
  }

  List<GamifiedTask> getAvailableTasks() {
    return _tasks.where((task) => !isTaskCompletedToday(task.id)).toList();
  }

  List<GamifiedTask> getCompletedTasksToday() {
    return _tasks.where((task) => isTaskCompletedToday(task.id)).toList();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void reset() {
    _tasks.clear();
    _reminders.clear();
    _completions.clear();
    _error = null;
    notifyListeners();
  }
} 