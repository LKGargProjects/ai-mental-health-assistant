import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/assessment.dart';

class AssessmentProvider extends ChangeNotifier {
  final ApiService _apiService;
  List<AssessmentQuestion> _questions = [];
  List<AssessmentResponse> _responses = [];
  AssessmentResult? _currentResult;
  List<AssessmentResult> _history = [];
  bool _isLoading = false;
  String? _error;

  AssessmentProvider() : _apiService = ApiService();

  List<AssessmentQuestion> get questions => List.unmodifiable(_questions);
  List<AssessmentResponse> get responses => List.unmodifiable(_responses);
  AssessmentResult? get currentResult => _currentResult;
  List<AssessmentResult> get history => List.unmodifiable(_history);
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadQuestions() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await _apiService.fetchAssessmentQuestions();
      _questions = (data['questions'] as List)
          .map((json) => AssessmentQuestion.fromJson(json))
          .toList();
    } catch (e) {
      _error = 'Failed to load assessment questions';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setResponse(int questionId, String answer) {
    final question = _questions.firstWhere((q) => q.id == questionId);
    final existingIndex = _responses.indexWhere((r) => r.questionId == questionId);
    
    final response = AssessmentResponse(
      questionId: questionId,
      question: question.question,
      type: question.type,
      options: question.options,
      min: question.min,
      max: question.max,
      category: question.category,
      answer: answer,
    );

    if (existingIndex >= 0) {
      _responses[existingIndex] = response;
    } else {
      _responses.add(response);
    }
    notifyListeners();
  }

  void clearResponses() {
    _responses.clear();
    notifyListeners();
  }

  Future<void> submitAssessment() async {
    if (_responses.length != _questions.length) {
      _error = 'Please answer all questions before submitting';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final responsesData = _responses.map((r) => r.toJson()).toList();
      final result = await _apiService.submitAssessment(responsesData);
      
      _currentResult = AssessmentResult.fromJson(result);
      _history.insert(0, _currentResult!);
      
      // Clear responses after successful submission
      _responses.clear();
    } catch (e) {
      _error = 'Failed to submit assessment';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadHistory() async {
    try {
      final historyData = await _apiService.getAssessmentHistory();
      _history = historyData
          .map((json) => AssessmentResult.fromJson(json))
          .toList();
      notifyListeners();
    } catch (e) {
      print('Error loading assessment history: $e');
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void reset() {
    _questions.clear();
    _responses.clear();
    _currentResult = null;
    _error = null;
    notifyListeners();
  }
} 