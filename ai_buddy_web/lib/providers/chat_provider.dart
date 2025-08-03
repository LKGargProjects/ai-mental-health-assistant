import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../models/message.dart';
import '../services/api_service.dart';

class ChatProvider extends ChangeNotifier {
  final ApiService _apiService;
  final List<Message> _messages = [];
  bool _isLoading = false;
  String? _error;
  bool _hasShownGreeting = false; // Track if greeting has been shown

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

      // Always add initial greeting if no messages exist OR if we haven't shown greeting yet
      if (_messages.isEmpty || !_hasShownGreeting) {
        _messages.add(
          Message(
            content:
                "Hey there! How are you doing today? I'm here if you want to chat about anything. 🙂",
            isUser: false,
            type: MessageType.text,
          ),
        );
        _hasShownGreeting = true;
      }
    } catch (e) {
      print('❌ Error loading chat history: $e');
      _error = 'Failed to load chat history';

      // Always add initial greeting even if history loading fails
      if (_messages.isEmpty || !_hasShownGreeting) {
        _messages.add(
          Message(
            content:
                "Hey there! How are you doing today? I'm here if you want to chat about anything. 🙂",
            isUser: false,
            type: MessageType.text,
          ),
        );
        _hasShownGreeting = true;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> sendMessage(String content, {String? country}) async {
    if (content.trim().isEmpty) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Test backend connectivity first
      await _testBackendConnection();

      // Ensure session exists
      await _setupSession();

      // Send message to backend first with optional country parameter
      final aiMessage = await _apiService.sendMessage(content, country: country);

      // Only add user message to UI after backend successfully processes it
      final userMessage = Message(content: content, isUser: true);
      _messages.add(userMessage);
      _messages.add(aiMessage);
      _error = null;
    } on DioException catch (e) {
      print('🚨 DIO Exception in sendMessage:');
      print('   Type: ${e.type}');
      print('   Message: ${e.message}');
      print('   Status Code: ${e.response?.statusCode}');
      print('   Response Data: ${e.response?.data}');

      String errorMessage = _apiService.getErrorMessage(e);
      _error = errorMessage;

      // Add user message even if backend fails
      _messages.add(Message(content: content, isUser: true));

      // Add error message
      _messages.add(
        Message(content: errorMessage, isUser: false, type: MessageType.error),
      );
    } catch (e) {
      print('❌ Unexpected error in sendMessage: $e');
      _error = 'An unexpected error occurred. Please try again.';

      // Add user message even if backend fails
      _messages.add(Message(content: content, isUser: true));

      _messages.add(
        Message(
          content: 'An unexpected error occurred. Please try again.',
          isUser: false,
          type: MessageType.error,
        ),
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _testBackendConnection() async {
    try {
      await _apiService.testBackendHealth();
    } catch (e) {
      print('❌ Backend connection test failed: $e');
      throw Exception('Backend not reachable. Please start your Flask server.');
    }
  }

  Future<void> _setupSession() async {
    try {
      // This will be handled by the API service
      // Just ensure we have a valid session
    } catch (e) {
      print('❌ Session setup failed: $e');
      throw Exception('Failed to establish session with backend.');
    }
  }

  Future<void> prefetchSession() async {
    await _loadChatHistory();
  }

  void clearChat() {
    _messages.clear();
    _hasShownGreeting = false; // Reset greeting flag
    _apiService.clearSession();
    notifyListeners();
  }
}
