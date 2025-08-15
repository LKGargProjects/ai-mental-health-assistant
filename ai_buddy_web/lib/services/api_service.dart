import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;
import '../config/feature_flags.dart';
import 'streaming/streaming_sse.dart' as sse;
import '../models/message.dart';
import '../models/mood_entry.dart';
import '../config/api_config.dart';

/// Optimized API service with better error handling and performance
class ApiService {
  static const String _sessionKey = 'session_id';
  static const String _analyticsConsentKey = 'analytics_consent';
  static const Duration _timeout = Duration(seconds: 30);
  static const int _maxRetries = 3;

  late final Dio _dio;
  late final FlutterSecureStorage _storage;
  String? _sessionId;

  ApiService() {
    _storage = const FlutterSecureStorage();
    _dio = _createDio();
    _setupInterceptors();
  }

  /// Best-effort country inference from device/browser locale (e.g., en_US -> US)
  String? _deriveCountry() {
    try {
      final locale = WidgetsBinding.instance.platformDispatcher.locale;
      final cc = locale.countryCode;
      if (cc != null && cc.trim().isNotEmpty) {
        return cc.toUpperCase();
      }
      // Fallback: try parsing from toString if needed (e.g., en_US)
      final s = locale.toString();
      final parts = s.split(RegExp(r'[_-]'));
      if (parts.length >= 2 && parts[1].trim().isNotEmpty) {
        return parts[1].toUpperCase();
      }
    } catch (_) {
      // Ignore and return null
    }
    return null;
  }

  /// Create Dio instance with optimized configuration
  Dio _createDio() {
    return Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: _timeout,
        receiveTimeout: _timeout,
        sendTimeout: _timeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
  }

  /// Setup interceptors for logging and error handling
  void _setupInterceptors() {
    // Add logging interceptor (only in debug mode)
    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          error: true,
          logPrint: (obj) {
            if (kDebugMode) debugPrint('API: $obj');
          },
        ),
      );
    }

    // Add error handling interceptor
    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (error, handler) {
          _logError(error);
          handler.next(error);
        },
        onRequest: (options, handler) async {
          // Add session ID to headers if available
          if (_sessionId != null) {
            options.headers['X-Session-ID'] = _sessionId;
          }
          // Attach a lightweight request ID for traceability
          options.headers['X-Request-ID'] = _newRequestId();
          handler.next(options);
        },
      ),
    );
  }

  /// Create a lightweight request ID without extra dependencies
  String _newRequestId() {
    final ts = DateTime.now().microsecondsSinceEpoch;
    final rnd = math.Random().nextInt(0x7fffffff);
    return 'req-$ts-$rnd';
  }

  /// Log error details for debugging
  void _logError(DioException error) {
    if (!kDebugMode) return;
    debugPrint('API Error: ${error.type} - ${error.message}');
    debugPrint('Status: ${error.response?.statusCode}');
    debugPrint('URL: ${error.requestOptions.uri}');
  }

  /// Get or create session ID
  Future<String> _getSessionId() async {
    if (_sessionId != null) return _sessionId!;

    try {
      _sessionId = await _storage.read(key: _sessionKey);
      if (_sessionId == null) {
        _sessionId = await _createNewSession();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Session error: $e');
      _sessionId = await _createNewSession();
    }

    return _sessionId!;
  }

  /// Check if minimal analytics is enabled (explicit consent only)
  Future<bool> isAnalyticsEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_analyticsConsentKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Persist analytics consent choice
  Future<void> setAnalyticsConsent(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_analyticsConsentKey, enabled);
    } catch (_) {
      // ignore
    }
  }

  /// Minimal client-side analytics logger (no PII). No-ops if consent is not given.
  Future<void> logAnalyticsEvent(String eventType, {Map<String, dynamic>? metadata}) async {
    try {
      if (!(await isAnalyticsEnabled())) return;
      await _getSessionId();
      await _dio.post(
        '/api/analytics/log',
        data: {
          'event_type': eventType,
          if (metadata != null) 'metadata': metadata,
        },
        options: Options(headers: {'X-Analytics-Consent': 'true'}),
      );
    } catch (_) {
      // Swallow analytics failures silently
    }
  }

  /// Create new session
  Future<String> _createNewSession() async {
    try {
      final response = await _dio.get('/api/get_or_create_session');
      final sessionId = response.data['session_id'] as String;
      await _storage.write(key: _sessionKey, value: sessionId);
      return sessionId;
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to create session: $e');
      // Generate fallback session ID
      return DateTime.now().millisecondsSinceEpoch.toString();
    }
  }

  /// Test backend connectivity with retry logic
  Future<Map<String, dynamic>> testBackendHealth() async {
    return _retryOperation(() async {
      final response = await _dio.get('/api/health');
      return response.data as Map<String, dynamic>;
    });
  }

  /// Open a streaming chat connection (SSE) when enabled and supported (web).
  /// Returns null if streaming is disabled or not supported; caller should fall back.
  Future<sse.SseHandle?> streamMessage(String message, {String? country}) async {
    if (!FeatureFlags.enableStreaming || !kIsWeb) return null;
    if (message.trim().isEmpty) return null;
    await _getSessionId();

    // Auto-derive country if not provided (web)
    country ??= _deriveCountry();
    if (kDebugMode) debugPrint('🔍 DEBUG: SSE country param resolved to: ${country ?? '(null)'}');

    final query = <String, String>{
      'message': message.trim(),
      if (country != null) 'country': country,
      'session_id': _sessionId ?? '',
    };

    final url = '${ApiConfig.baseUrl}/api/chat_stream';
    return sse.connectSse(url: url, query: query);
  }

  /// Send chat message with optimized error handling and geography-specific crisis detection
  Future<Message> sendMessage(String message, {String? country}) async {
    return _retryOperation(() async {
      await _getSessionId(); // Ensure session is available

      // Prepare request data with optional country parameter
      // Auto-derive country if not provided
      country ??= _deriveCountry();
      final requestData = <String, dynamic>{
        'message': message.trim(),
      };
      if (country != null) {
        requestData['country'] = country;
        if (kDebugMode) debugPrint('🔍 DEBUG: Adding country parameter: $country');
      } else {
        if (kDebugMode) debugPrint('🔍 DEBUG: No country parameter provided');
      }
      if (kDebugMode) debugPrint('🔍 DEBUG: Request data: $requestData');

      final response = await _dio.post(
        '/api/chat',
        data: requestData,
      );

      final data = response.data as Map<String, dynamic>;

      // Parse risk level from response
      RiskLevel riskLevel = RiskLevel.none;
      if (data['risk_level'] != null) {
        final riskLevelStr = data['risk_level'].toString().toLowerCase();
        if (kDebugMode) debugPrint('🔍 DEBUG: Raw risk_level from API: ${data['risk_level']}');
        if (kDebugMode) debugPrint('🔍 DEBUG: Processed risk_level: $riskLevelStr');
        switch (riskLevelStr) {
          case 'crisis':
          case 'high':
            riskLevel = RiskLevel.high;
            if (kDebugMode) debugPrint('🔍 DEBUG: Set riskLevel to RiskLevel.high');
            break;
          case 'medium':
            riskLevel = RiskLevel.medium;
            if (kDebugMode) debugPrint('🔍 DEBUG: Set riskLevel to RiskLevel.medium');
            break;
          case 'low':
            riskLevel = RiskLevel.low;
            if (kDebugMode) debugPrint('🔍 DEBUG: Set riskLevel to RiskLevel.low');
            break;
          default:
            riskLevel = RiskLevel.none;
            if (kDebugMode) debugPrint('🔍 DEBUG: Set riskLevel to RiskLevel.none (default)');
        }
      } else {
        if (kDebugMode) debugPrint('🔍 DEBUG: No risk_level field in API response');
      }
      if (kDebugMode) debugPrint('🔍 DEBUG: Final riskLevel: $riskLevel');

      // Parse geography-specific crisis data
      String? crisisMsg;
      List<Map<String, dynamic>>? crisisNumbers;
      
      if (kDebugMode) debugPrint('🔍 DEBUG: Full API response data: $data');
      if (kDebugMode) debugPrint('🔍 DEBUG: crisis_msg field exists: ${data.containsKey('crisis_msg')}');
      if (kDebugMode) debugPrint('🔍 DEBUG: crisis_numbers field exists: ${data.containsKey('crisis_numbers')}');
      
      if (data['crisis_msg'] != null) {
        crisisMsg = data['crisis_msg'] as String;
        if (kDebugMode) debugPrint('🔍 DEBUG: Crisis message: $crisisMsg');
      } else {
        if (kDebugMode) debugPrint('🔍 DEBUG: crisis_msg is null or missing');
      }
      
      if (data['crisis_numbers'] != null) {
        final numbersList = data['crisis_numbers'] as List<dynamic>;
        crisisNumbers = numbersList.map((item) => 
          Map<String, dynamic>.from(item)
        ).toList();
        if (kDebugMode) debugPrint('🔍 DEBUG: Crisis numbers: $crisisNumbers');
      } else {
        if (kDebugMode) debugPrint('🔍 DEBUG: crisis_numbers is null or missing');
      }

      return Message(
        content: data['response'] as String,
        isUser: false,
        type: MessageType.text,
        riskLevel: riskLevel,
        crisisMsg: crisisMsg,
        crisisNumbers: crisisNumbers,
      );
    });
  }

  /// Get chat history with pagination support
  Future<List<Message>> getChatHistory() async {
    return _retryOperation(() async {
      await _getSessionId();

      final response = await _dio.get('/api/chat_history');
      final List<dynamic> data = response.data as List<dynamic>;

      return data.map((json) => Message.fromJson(json)).toList();
    });
  }

  /// Submit self-assessment with validation
  Future<Map<String, dynamic>> submitSelfAssessment(
    Map<String, dynamic> data,
  ) async {
    return _retryOperation(() async {
      await _getSessionId();

      // Validate required fields
      final requiredFields = ['mood', 'energy', 'sleep', 'stress'];
      for (final field in requiredFields) {
        if (data[field] == null || data[field].toString().trim().isEmpty) {
          throw Exception('Missing required field: $field');
        }
      }

      final response = await _dio.post('/api/self_assessment', data: data);
      return response.data as Map<String, dynamic>;
    });
  }

  /// Get mood history
  Future<List<MoodEntry>> getMoodHistory() async {
    return _retryOperation(() async {
      await _getSessionId();

      final response = await _dio.get('/api/mood_history');
      final List<dynamic> data = response.data as List<dynamic>;

      return data.map((json) => MoodEntry.fromJson(json)).toList();
    });
  }

  /// Add mood entry
  Future<Map<String, dynamic>> addMoodEntry(Map<String, dynamic> data) async {
    return _retryOperation(() async {
      await _getSessionId();

      final response = await _dio.post('/api/mood_entry', data: data);
      return response.data as Map<String, dynamic>;
    });
  }

  /// Get user-friendly error message from DioException
  String getErrorMessage(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return 'Server not responding. Please try again.';
      case DioExceptionType.receiveTimeout:
        return 'Request timed out. Please try again.';
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        if (statusCode == 400) {
          return 'Invalid request. Please check your input.';
        } else if (statusCode == 401) {
          return 'Authentication required.';
        } else if (statusCode == 403) {
          return 'Access denied.';
        } else if (statusCode == 404) {
          return 'Service not found.';
        } else if (statusCode == 500) {
          return 'Server error. Please try again later.';
        } else {
          return 'Server error: $statusCode';
        }
      case DioExceptionType.connectionError:
        return 'Cannot connect to server. Check your internet connection.';
      default:
        return 'Network error. Please try again.';
    }
  }

  /// Generic retry operation with exponential backoff
  Future<T> _retryOperation<T>(Future<T> Function() operation) async {
    int attempts = 0;
    Duration delay = const Duration(milliseconds: 100);

    while (attempts < _maxRetries) {
      try {
        return await operation();
      } on DioException catch (e) {
        attempts++;

        if (attempts >= _maxRetries) {
          throw _createUserFriendlyError(e);
        }

        // Exponential backoff
        await Future.delayed(delay);
        delay *= 2;
      } catch (e) {
        throw Exception('Unexpected error: $e');
      }
    }

    throw Exception('Max retries exceeded');
  }

  /// Create user-friendly error messages
  Exception _createUserFriendlyError(DioException e) {
    String message = 'Connection error. ';

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        message += 'Server not responding. Please try again.';
        break;
      case DioExceptionType.receiveTimeout:
        message += 'Request timed out. Please try again.';
        break;
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        if (statusCode == 400) {
          message += 'Invalid request. Please check your input.';
        } else if (statusCode == 401) {
          message += 'Authentication required.';
        } else if (statusCode == 403) {
          message += 'Access denied.';
        } else if (statusCode == 404) {
          message += 'Service not found.';
        } else if (statusCode == 500) {
          message += 'Server error. Please try again later.';
        } else {
          message += 'Server error: $statusCode';
        }
        break;
      case DioExceptionType.connectionError:
        message += 'Cannot connect to server. Check your internet connection.';
        break;
      default:
        message += 'Network error. Please try again.';
    }

    return Exception(message);
  }

  /// Clear session data
  Future<void> clearSession() async {
    try {
      await _storage.delete(key: _sessionKey);
      _sessionId = null;
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to clear session: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _dio.close();
  }
}
