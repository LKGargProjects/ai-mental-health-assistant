import 'package:flutter/material.dart';

class ProgressProvider extends ChangeNotifier {
  bool _isLoading = false;
  String? _error;
  int _stepsLeft = 0;
  int _xpEarned = 0;
  int _lifetimeXp = 0; // Explore tab header

  bool get isLoading => _isLoading;
  String? get error => _error;
  int get stepsLeft => _stepsLeft;
  int get xpEarned => _xpEarned;
  int get lifetimeXp => _lifetimeXp;

  // Week 0: allow quests engine to push computed progress without UI changes
  void updateFromQuests({required int stepsLeft, required int xpEarned}) {
    _stepsLeft = stepsLeft;
    _xpEarned = xpEarned;
    notifyListeners();
  }

  // Explore: set lifetime XP (from engine.computeLifetimeXp())
  void updateLifetimeXp(int value) {
    _lifetimeXp = value;
    notifyListeners();
  }

  // Generic: increment XP counters
  void addXp(int delta) {
    if (delta == 0) return;
    _xpEarned += delta;
    _lifetimeXp += delta;
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