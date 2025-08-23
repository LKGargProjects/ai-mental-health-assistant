import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;

import '../config/api_config.dart';
import 'session_manager.dart';

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

String _newRequestId() {
  final ts = DateTime.now().microsecondsSinceEpoch;
  final rnd = math.Random().nextInt(0x7fffffff);
  return 'req-$ts-$rnd';
}

Future<bool> _isAnalyticsEnabled() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_analyticsConsentKey) ?? false;
  } catch (_) {
    return false;
  }
}

Future<void> logAnalyticsEvent(String eventType, {Map<String, dynamic>? metadata}) async {
  try {
    if (!(await _isAnalyticsEnabled())) return;
    // Centralized session ID (deduplicated) via SessionManager
    final sid = await SessionManager.getOrCreateSessionId();
    await _dio.post(
      '/api/analytics/log',
      data: {
        'event_type': eventType,
        if (metadata != null) 'metadata': metadata,
      },
      options: Options(headers: {
        'X-Session-ID': sid,
        'X-Analytics-Consent': 'true',
        'X-Request-ID': _newRequestId(),
      }),
    );
  } catch (e) {
    // Swallow errors silently for analytics
    if (kDebugMode) debugPrint('analytics: log error: $e');
  }
}
