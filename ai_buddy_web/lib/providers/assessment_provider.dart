import 'package:flutter/material.dart';

class AssessmentProvider extends ChangeNotifier {
  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> submitAssessment(Map<String, dynamic> data) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // TODO: Implement assessment submission
      await Future.delayed(const Duration(seconds: 1)); // Simulate API call
      _error = null;
    } catch (e) {
      _error = 'Failed to submit assessment';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
} 