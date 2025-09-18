import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import 'storage/kv_storage.dart';

/// Centralized session ID coordinator to deduplicate network calls to
/// `/api/get_or_create_session` across services.
class SessionManager {
  static const String _sessionKey = 'session_id';
  static String? _sessionId;
  static Completer<String>? _inflight;

  /// Returns an in-memory session id if present, else loads from secure storage,
  /// else performs a single, deduplicated network call to create one.
  static Future<String> getOrCreateSessionId() async {
    // Fast path: in-memory
    if (_sessionId != null && _sessionId!.trim().isNotEmpty) return _sessionId!;

    // Try persisted storage
    try {
      final existing = await KvStorage.read(_sessionKey);
      if (existing != null && existing.trim().isNotEmpty) {
        _sessionId = existing;
        return _sessionId!;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('SessionManager: storage read error: $e');
    }

    // If another caller is already creating a session, await it
    if (_inflight != null) {
      return _inflight!.future;
    }

    // Create once and share
    _inflight = Completer<String>();
    try {
      final dio = Dio(
        BaseOptions(
          baseUrl: ApiConfig.baseUrl,
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 30),
          headers: const {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );
      final resp = await dio.get('/api/get_or_create_session');
      final sid = (resp.data is Map) ? resp.data['session_id'] as String? : null;
      _sessionId = (sid != null && sid.trim().isNotEmpty)
          ? sid
          : _fallbackSessionId();
      try {
        await KvStorage.write(_sessionKey, _sessionId);
      } catch (e) {
        if (kDebugMode) debugPrint('SessionManager: storage write error: $e');
      }
      _inflight!.complete(_sessionId!);
    } catch (e) {
      if (kDebugMode) debugPrint('SessionManager: network error: $e');
      _sessionId = _fallbackSessionId();
      _inflight!.complete(_sessionId!);
    } finally {
      _inflight = null;
    }
    return _sessionId!;
  }

  /// Returns the current in-memory session id if already loaded.
  static String? peekSessionId() => _sessionId;

  /// Clears the cached session id (both memory and storage).
  static Future<void> clear() async {
    _sessionId = null;
    try {
      await KvStorage.delete(_sessionKey);
    } catch (e) {
      if (kDebugMode) debugPrint('SessionManager: clear error: $e');
    }
  }

  static String _fallbackSessionId() =>
      DateTime.now().millisecondsSinceEpoch.toString();
}
