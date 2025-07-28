import 'package:flutter/material.dart';
import '../models/message.dart';
import '../services/api_service.dart';

class ChatProvider extends ChangeNotifier {
  final ApiService _apiService;
  final List<Message> _messages = [];
  bool _isLoading = false;
  String? _error;

  ChatProvider() : _apiService = ApiService() {
    _loadChatHistory();
  }

  List<Message> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> _loadChatHistory() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final history = await _apiService.getChatHistory();
      _messages.clear();
      _messages.addAll(history);
    } catch (e) {
      _error = 'Failed to load chat history';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty) return;

    final userMessage = Message(content: content, isUser: true);

    _messages.add(userMessage);
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final aiMessage = await _apiService.sendMessage(content);
      _messages.add(aiMessage);
      _error = null;
    } catch (e) {
      _error = 'Failed to send message';
      _messages.add(
        Message(
          content: 'Failed to get response. Please try again.',
          isUser: false,
          type: MessageType.error,
        ),
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> prefetchSession() async {
    await _loadChatHistory();
  }

  void clearChat() {
    _messages.clear();
    _apiService.clearSession();
    notifyListeners();
  }
}
