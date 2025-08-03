import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/message.dart';
import '../models/mood_entry.dart';
import '../config/api_config.dart';

/// Optimized API service with better error handling and performance
class ApiService {
  static const String _sessionKey = 'session_id';
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
          logPrint: (obj) => print('API: $obj'),
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
          handler.next(options);
        },
      ),
    );
  }

  /// Log error details for debugging
  void _logError(DioException error) {
    if (!kDebugMode) return;

    print('API Error: ${error.type} - ${error.message}');
    print('Status: ${error.response?.statusCode}');
    print('URL: ${error.requestOptions.uri}');
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
      print('Session error: $e');
      _sessionId = await _createNewSession();
    }

    return _sessionId!;
  }

  /// Create new session
  Future<String> _createNewSession() async {
    try {
      final response = await _dio.get('/api/get_or_create_session');
      final sessionId = response.data['session_id'] as String;
      await _storage.write(key: _sessionKey, value: sessionId);
      return sessionId;
    } catch (e) {
      print('Failed to create session: $e');
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

  /// Send chat message with optimized error handling and geography-specific crisis detection
  Future<Message> sendMessage(String message, {String? country}) async {
    return _retryOperation(() async {
      await _getSessionId(); // Ensure session is available

      // Prepare request data with optional country parameter
      final requestData = <String, dynamic>{
        'message': message.trim(),
      };
      if (country != null) {
        requestData['country'] = country;
        print('🔍 DEBUG: Adding country parameter: $country');
      } else {
        print('🔍 DEBUG: No country parameter provided');
      }
      print('🔍 DEBUG: Request data: $requestData');

      final response = await _dio.post(
        '/api/chat',
        data: requestData,
      );

      final data = response.data as Map<String, dynamic>;

      // Parse risk level from response
      RiskLevel riskLevel = RiskLevel.none;
      if (data['risk_level'] != null) {
        final riskLevelStr = data['risk_level'].toString().toLowerCase();
        print('🔍 DEBUG: Raw risk_level from API: ${data['risk_level']}');
        print('🔍 DEBUG: Processed risk_level: $riskLevelStr');
        switch (riskLevelStr) {
          case 'crisis':
          case 'high':
            riskLevel = RiskLevel.high;
            print('🔍 DEBUG: Set riskLevel to RiskLevel.high');
            break;
          case 'medium':
            riskLevel = RiskLevel.medium;
            print('🔍 DEBUG: Set riskLevel to RiskLevel.medium');
            break;
          case 'low':
            riskLevel = RiskLevel.low;
            print('🔍 DEBUG: Set riskLevel to RiskLevel.low');
            break;
          default:
            riskLevel = RiskLevel.none;
            print('🔍 DEBUG: Set riskLevel to RiskLevel.none (default)');
        }
      } else {
        print('🔍 DEBUG: No risk_level field in API response');
      }
      print('🔍 DEBUG: Final riskLevel: $riskLevel');

      // Parse geography-specific crisis data
      String? crisisMsg;
      List<Map<String, dynamic>>? crisisNumbers;
      
      print('🔍 DEBUG: Full API response data: $data');
      print('🔍 DEBUG: crisis_msg field exists: ${data.containsKey('crisis_msg')}');
      print('🔍 DEBUG: crisis_numbers field exists: ${data.containsKey('crisis_numbers')}');
      
      if (data['crisis_msg'] != null) {
        crisisMsg = data['crisis_msg'] as String;
        print('🔍 DEBUG: Crisis message: $crisisMsg');
      } else {
        print('🔍 DEBUG: crisis_msg is null or missing');
      }
      
      if (data['crisis_numbers'] != null) {
        final numbersList = data['crisis_numbers'] as List<dynamic>;
        crisisNumbers = numbersList.map((item) => 
          Map<String, dynamic>.from(item)
        ).toList();
        print('🔍 DEBUG: Crisis numbers: $crisisNumbers');
      } else {
        print('🔍 DEBUG: crisis_numbers is null or missing');
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
      print('Failed to clear session: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _dio.close();
  }
}
