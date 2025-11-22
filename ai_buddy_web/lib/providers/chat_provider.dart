import 'dart:async';
import 'package:flutter/foundation.dart';
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
  bool _isSending = false; // Prevent concurrent sends (tap debouncing)
  final List<StreamSubscription<Map<String, dynamic>>> _subscriptions = [];
  final List<void Function()> _closers = [];

  ChatProvider() : _apiService = ApiService() {
    // Pre-insert a greeting immediately for instant UI; hydrate history in background
    if (_messages.isEmpty && !_hasShownGreeting) {
      _messages.add(
        Message(
          content:
              "Hey there! How are you doing today? I'm here if you want to chat about anything. 🙂",
          isUser: false,
          type: MessageType.text,
        ),
      );
      _hasShownGreeting = true;
      notifyListeners();
    }
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
      // Only replace local messages if server has any. If history is empty,
      // keep the pre-inserted greeting for a friendlier first-load UX.
      if (history.isNotEmpty) {
        _messages
          ..clear()
          ..addAll(history);
      }
    } catch (e) {
      debugPrint('❌ Error loading chat history: $e');
      _error = 'Failed to load chat history';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> sendMessage(String content, {String? country}) async {
    if (content.trim().isEmpty) return;
    if (_isSending) return; // debounce concurrent taps
    _isSending = true;
    _error = null;
    _isLoading = true;

    // Optimistic UI: show user's message immediately and turn on typing indicator
    final userMessage = Message(content: content, isUser: true);
    _messages.add(userMessage);
    _isTyping = true;
    notifyListeners();

    try {
      // Try streaming first (web-only, feature-gated). Fallback to non-streaming.
      final handle = await _apiService.streamMessage(content, country: country);
      if (handle != null) {
        Message? streaming; // create lazily on first token
        _error = null;
        notifyListeners();

        bool firstToken = true;
        RiskLevel metaRisk = RiskLevel.none;
        String? metaCrisisMsg;
        List<Map<String, dynamic>>? metaCrisisNumbers;
        final sub = handle.stream.listen(
          (event) async {
            final type = event['type'] as String?;
            if (type == 'meta') {
              // Capture meta and replace message to include immutable fields
              metaRisk = _mapRisk(event['risk_level']) ?? RiskLevel.none;
              metaCrisisMsg = event['crisis_msg'] as String?;
              metaCrisisNumbers = (event['crisis_numbers'] as List?)
                  ?.cast<Map<String, dynamic>>();
              if (kDebugMode) {
                debugPrint(
                  '🟡 [SSE meta] risk=${event['risk_level']}, crisis_msg=${metaCrisisMsg?.substring(0, metaCrisisMsg!.length.clamp(0, 120))}',
                );
                final nums = metaCrisisNumbers
                    ?.map((e) => e['phone'] ?? e['name'] ?? e.toString())
                    .toList();
                debugPrint('🟡 [SSE meta] crisis_numbers=${nums?.join(', ')}');
              }
              if (streaming != null) {
                final idx = _messages.lastIndexOf(streaming!);
                if (idx != -1) {
                  final replaced = Message(
                    id: streaming!.id,
                    content: streaming!.content,
                    isUser: false,
                    timestamp: streaming!.timestamp,
                    type: MessageType.text,
                    riskLevel: metaRisk,
                    crisisMsg: metaCrisisMsg,
                    crisisNumbers: metaCrisisNumbers,
                  );
                  _messages[idx] = replaced;
                  streaming = replaced; // update reference
                  notifyListeners();
                }
              }
            } else if (type == 'token') {
              final text = (event['text'] as String?) ?? '';
              // Create the streaming message on first token
              if (streaming == null) {
                streaming = Message(
                  content: '',
                  isUser: false,
                  type: MessageType.text,
                  riskLevel: metaRisk,
                  crisisMsg: metaCrisisMsg,
                  crisisNumbers: metaCrisisNumbers,
                );
                _messages.add(streaming!);
              }
              streaming!.content += text;
              if (kDebugMode) {
                final sample =
                    text.length > 60 ? '${text.substring(0, 60)}…' : text;
                debugPrint(
                  '🟢 [SSE token] +${text.length} chars: "$sample" (total=${streaming!.content.length})',
                );
              }
              if (firstToken) {
                firstToken = false;
                if (_isTyping) _isTyping = false;
              }
              notifyListeners();
            } else if (type == 'done') {
              if (_isTyping) _isTyping = false;
              notifyListeners();
              if (kDebugMode) {
                debugPrint(
                  '🔵 [SSE done] total_chars=${streaming?.content.length ?? 0}, risk=$metaRisk',
                );
              }
              handle.close();
            } else if (type == 'error') {
              // Show a soft error and stop typing
              _messages.add(
                Message(
                  content: 'Streaming error. Retrying soon...',
                  isUser: false,
                  type: MessageType.error,
                ),
              );
              if (_isTyping) _isTyping = false;
              notifyListeners();
              if (kDebugMode) {
                debugPrint('🔴 [SSE error] event=$event');
              }
              handle.close();
            }
          },
          onError: (_) {
            if (_isTyping) _isTyping = false;
            notifyListeners();
            if (kDebugMode) {
              debugPrint('🔴 [SSE onError]');
            }
            handle.close();
          },
          onDone: () {
            if (_isTyping) _isTyping = false;
            notifyListeners();
            if (kDebugMode) {
              debugPrint('🔵 [SSE onDone]');
            }
          },
          cancelOnError: true,
        );
        _subscriptions.add(sub);
        _closers.add(handle.close);
        return; // streaming path done
      }

      // Fallback: non-streaming request, progressively reveal locally
      final aiMessage = await _apiService.sendMessage(
        content,
        country: country,
      );
      if (kDebugMode) {
        debugPrint('🟣 [HTTP chat] risk=${aiMessage.riskLevel}');
        debugPrint(
          '🟣 [HTTP chat] crisis_msg_len=${aiMessage.crisisMsg?.length ?? 0}',
        );
        debugPrint(
          '🟣 [HTTP chat] crisis_numbers=${aiMessage.crisisNumbers?.length ?? 0}',
        );
      }

      // Avoid adding an empty bubble. Delay insertion until first chunk exists.
      final full = aiMessage.content;
      final lines =
          full.contains('\n') ? full.split('\n') : _splitIntoSentences(full);

      if (lines.isEmpty || full.trim().isEmpty) {
        // Nothing meaningful to show; just stop typing and return.
        if (_isTyping) _isTyping = false;
        _error = null;
        notifyListeners();
        return;
      }

      // Insert message with the first chunk immediately
      final first = lines.first;
      final streaming = Message(
        content: first,
        isUser: false,
        type: aiMessage.type,
        riskLevel: aiMessage.riskLevel,
        crisisMsg: aiMessage.crisisMsg,
        crisisNumbers: aiMessage.crisisNumbers,
      );
      _messages.add(streaming);
      _error = null;
      if (_isTyping) _isTyping = false;
      notifyListeners();

      // Append remaining chunks with a subtle delay for progressive effect
      for (var i = 1; i < lines.length; i++) {
        final line = lines[i];
        streaming.content += '\n$line';
        notifyListeners();
        final ms = (line.trim().length * 15).clamp(120, 600);
        await Future.delayed(Duration(milliseconds: ms));
      }
    } on DioException catch (e) {
      debugPrint('🚨 DIO Exception in sendMessage:');
      debugPrint('   Type: ${e.type}');
      debugPrint('   Message: ${e.message}');
      debugPrint('   Status Code: ${e.response?.statusCode}');
      debugPrint('   Response Data: ${e.response?.data}');

      final String errorMessage = _apiService.getErrorMessage(e);
      _error = errorMessage;
      if (_isTyping) _isTyping = false;

      // Add error message bubble (user message already added above)
      _messages.add(
        Message(content: errorMessage, isUser: false, type: MessageType.error),
      );
    } catch (e) {
      debugPrint('❌ Unexpected error in sendMessage: $e');

      // Surface any user-friendly message from wrapped exceptions (e.g. from
      // ApiService._retryOperation), otherwise fall back to a clearer
      // cold-start style message instead of a generic error.
      final raw = e.toString();
      final cleaned = raw.replaceFirst('Exception: ', '').trim();
      final friendly = cleaned.isNotEmpty && cleaned != 'Exception'
          ? cleaned
          : 'The server is waking up or temporarily unavailable. Please wait a few seconds and try again.';

      _error = friendly;
      if (_isTyping) _isTyping = false;

      _messages.add(
        Message(
          content: friendly,
          isUser: false,
          type: MessageType.error,
        ),
      );
    } finally {
      _isSending = false; // reset tap debounce so future sends work
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
      return text
          .split(',')
          .map((e) => e.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return parts;
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

  // Map string risk level to enum if present
  RiskLevel? _mapRisk(dynamic level) {
    if (level == null) return null;
    final s = level.toString().toLowerCase();
    switch (s) {
      case 'high':
      case 'crisis':
        return RiskLevel.high;
      case 'medium':
        return RiskLevel.medium;
      case 'low':
        return RiskLevel.low;
      default:
        return RiskLevel.none;
    }
  }

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    for (final c in _closers) {
      try {
        c();
      } catch (_) {}
    }
    _subscriptions.clear();
    _closers.clear();
    super.dispose();
  }
}
