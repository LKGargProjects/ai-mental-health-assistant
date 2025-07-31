import 'package:flutter/material.dart';

class TaskProvider extends ChangeNotifier {
  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadTasks() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // TODO: Implement task loading
      await Future.delayed(const Duration(seconds: 1)); // Simulate API call
      _error = null;
    } catch (e) {
      _error = 'Failed to load tasks';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
} 