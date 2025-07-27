import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../models/message.dart';
import '../models/chat_mode.dart';

class ChatProvider with ChangeNotifier {
  final List<Message> _messages = [];
  final Dio _dio = Dio();
  bool _isLoading = false;
  ChatMode _currentMode = ChatMode.mentalHealth;
  String? _error;

  List<Message> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  ChatMode get currentMode => _currentMode;
  String? get error => _error;

  void setMode(ChatMode mode) {
    if (_currentMode != mode) {
      _currentMode = mode;
      notifyListeners();
    }
  }

  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty) return;

    final userMessage = Message(
      content: content,
      isUser: true,
      timestamp: DateTime.now(),
    );

    _messages.add(userMessage);
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _dio.post(
        'https://ai-mental-health-assistant-tddc.onrender.com/chat',
        data: {
          'prompt': content,
          'provider': 'gemini',
          'mode': _currentMode.name,
        },
      );

      if (response.statusCode == 200) {
        final aiMessage = Message(
          content: response.data['answer'],
          isUser: false,
          timestamp: DateTime.now(),
          riskLevel: response.data['risk_level'],
          resources: response.data['crisis_resources'],
        );

        _messages.add(aiMessage);
      } else {
        _error = 'Failed to get response from AI';
      }
    } catch (e) {
      _error = 'Error: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearChat() {
    _messages.clear();
    _error = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
} 