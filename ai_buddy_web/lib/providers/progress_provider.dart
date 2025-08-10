import 'package:flutter/material.dart';

class ProgressProvider extends ChangeNotifier {
  bool _isLoading = false;
  String? _error;
  int _stepsLeft = 0;
  int _xpEarned = 0;

  bool get isLoading => _isLoading;
  String? get error => _error;
  int get stepsLeft => _stepsLeft;
  int get xpEarned => _xpEarned;

  // Week 0: allow quests engine to push computed progress without UI changes
  void updateFromQuests({required int stepsLeft, required int xpEarned}) {
    _stepsLeft = stepsLeft;
    _xpEarned = xpEarned;
    notifyListeners();
  }

  Future<void> loadProgress() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // TODO: Implement progress loading
      await Future.delayed(const Duration(seconds: 1)); // Simulate API call
      _error = null;
    } catch (e) {
      _error = 'Failed to load progress';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
} 