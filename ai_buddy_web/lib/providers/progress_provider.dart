import 'package:flutter/material.dart';

class ProgressProvider extends ChangeNotifier {
  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;

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