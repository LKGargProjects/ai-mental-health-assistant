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
  bool _isTyping = false; // AI typing indicator state

  ChatProvider() : _apiService = ApiService() {
    _loadChatHistory();
  }

  List<Message> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isTyping => _isTyping;

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
    _error = null;

    // Optimistic UI: show user's message immediately and turn on typing indicator
    final userMessage = Message(content: content, isUser: true);
    _messages.add(userMessage);
    _isTyping = true;
    notifyListeners();

    try {
      // Test backend connectivity and ensure session
      await _testBackendConnection();
      await _setupSession();

      // Send to backend with optional country parameter
      final aiMessage = await _apiService.sendMessage(content, country: country);

      // Progressive render: create an empty AI message and stream in chunks
      final streaming = Message(
        content: '',
        isUser: false,
        type: aiMessage.type,
        riskLevel: aiMessage.riskLevel,
        crisisMsg: aiMessage.crisisMsg,
        crisisNumbers: aiMessage.crisisNumbers,
      );
      _messages.add(streaming);
      _error = null;
      notifyListeners();

      // Prepare chunks: prefer newline-based lines; if single line, split by sentence-ish boundaries
      final full = aiMessage.content;
      final lines = full.contains('\n')
          ? full.split('\n')
          : _splitIntoSentences(full);

      // Reveal lines with natural timing
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        // Respect empty lines too for structure
        streaming.content += (i == 0 ? '' : '\n') + line;
        // First chunk: turn off typing indicator
        if (_isTyping) _isTyping = false;
        notifyListeners();
        // Delay proportional to line length with sane bounds
        final ms = (line.trim().length * 15).clamp(120, 600);
        await Future.delayed(Duration(milliseconds: ms));
      }
      // In case there were zero chunks, ensure typing is off
      if (_isTyping) {
        _isTyping = false;
        notifyListeners();
      }
    } on DioException catch (e) {
      print('🚨 DIO Exception in sendMessage:');
      print('   Type: ${e.type}');
      print('   Message: ${e.message}');
      print('   Status Code: ${e.response?.statusCode}');
      print('   Response Data: ${e.response?.data}');

      final String errorMessage = _apiService.getErrorMessage(e);
      _error = errorMessage;

      // Add error message bubble (user message already added above)
      _messages.add(
        Message(content: errorMessage, isUser: false, type: MessageType.error),
      );
    } catch (e) {
      print('❌ Unexpected error in sendMessage: $e');
      _error = 'An unexpected error occurred. Please try again.';

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

  // Split a paragraph into sentence-like chunks for smoother progressive rendering
  List<String> _splitIntoSentences(String text) {
    final regex = RegExp(r'(?<=[.!?])\s+');
    final parts = text.split(regex).where((s) => s.isNotEmpty).toList();
    // Fallback: if still one long part, split by commas to add a bit more granularity
    if (parts.length <= 1 && text.contains(',')) {
      return text.split(',').map((e) => e.trim()).where((s) => s.isNotEmpty).toList();
    }
    return parts;
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
