import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/api_config.dart';

const String _sessionKey = 'session_id';
const String _analyticsConsentKey = 'analytics_consent';

final Dio _dio = Dio(
  BaseOptions(
    baseUrl: ApiConfig.baseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    sendTimeout: const Duration(seconds: 30),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  ),
);

final FlutterSecureStorage _storage = const FlutterSecureStorage();

Future<bool> _isAnalyticsEnabled() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_analyticsConsentKey) ?? false;
  } catch (_) {
    return false;
  }
}

Future<String?> _getOrCreateSessionId() async {
  try {
    final existing = await _storage.read(key: _sessionKey);
    if (existing != null && existing.trim().isNotEmpty) return existing;

    // Best-effort create a session if missing
    final resp = await _dio.get('/api/get_or_create_session');
    final sid = (resp.data is Map) ? resp.data['session_id'] as String? : null;
    if (sid != null && sid.trim().isNotEmpty) {
      await _storage.write(key: _sessionKey, value: sid);
      return sid;
    }
  } catch (e) {
    if (kDebugMode) debugPrint('analytics: session error: $e');
  }
  return null;
}

Future<void> logAnalyticsEvent(String eventType, {Map<String, dynamic>? metadata}) async {
  try {
    if (!(await _isAnalyticsEnabled())) return;
    final sid = await _getOrCreateSessionId();
    await _dio.post(
      '/api/analytics/log',
      data: {
        'event_type': eventType,
        if (metadata != null) 'metadata': metadata,
      },
      options: Options(headers: {
        if (sid != null) 'X-Session-ID': sid,
        'X-Analytics-Consent': 'true',
      }),
    );
  } catch (e) {
    // Swallow errors silently for analytics
    if (kDebugMode) debugPrint('analytics: log error: $e');
  }
}
