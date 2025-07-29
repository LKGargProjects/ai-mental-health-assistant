import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/message.dart';
import '../models/mood_entry.dart';
import '../config/api_config.dart';

class ApiService {
  static String get baseUrl => ApiConfig.baseUrl;
  final Dio _dio;
  final FlutterSecureStorage _storage;

  ApiService()
    : _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      ),
      _storage = const FlutterSecureStorage() {
    _setupInterceptors();
  }

  void _setupInterceptors() {
    // Add comprehensive logging interceptor
    _dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        error: true,
        logPrint: (obj) => print('🌐 DIO LOG: $obj'),
      ),
    );

    // Add error handling interceptor
    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (error, handler) {
          print('🚨 === DIO ERROR DETAILS ===');
          print('Error Type: ${error.type}');
          print('Error Message: ${error.message}');
          print('Response Status: ${error.response?.statusCode}');
          print('Response Data: ${error.response?.data}');
          print('Request URL: ${error.requestOptions.uri}');
          print('Request Headers: ${error.requestOptions.headers}');
          print('Request Data: ${error.requestOptions.data}');
          print('Base URL: ${_dio.options.baseUrl}');
          handler.next(error);
        },
      ),
    );
  }

  /// Test backend connectivity and health
  Future<Map<String, dynamic>> testBackendHealth() async {
    try {
      print('🔍 Testing backend health at: ${_dio.options.baseUrl}');
      final response = await _dio.get('/api/health');
      print('✅ Backend health check passed: ${response.data}');
      return response.data;
    } on DioException catch (e) {
      print('❌ Backend health check failed:');
      print('   Type: ${e.type}');
      print('   Message: ${e.message}');
      print('   Status: ${e.response?.statusCode}');
      print('   URL: ${e.requestOptions.uri}');

      String errorMessage = 'Backend connection failed. ';

      switch (e.type) {
        case DioExceptionType.connectionTimeout:
          errorMessage +=
              'Backend server not responding. Is it running on port 5055?';
          break;
        case DioExceptionType.receiveTimeout:
          errorMessage += 'Server response timeout.';
          break;
        case DioExceptionType.badResponse:
          if (e.response?.statusCode == 505) {
            errorMessage +=
                'Server error 505: HTTP Version Not Supported. This might be a CORS or server configuration issue.';
          } else {
            errorMessage += 'Server error: ${e.response?.statusCode}';
          }
          break;
        case DioExceptionType.connectionError:
          errorMessage +=
              'Cannot connect to backend. Check if Flask server is running.';
          break;
        default:
          errorMessage += 'Unexpected error: ${e.message}';
      }

      throw Exception(errorMessage);
    } catch (e) {
      print('❌ Unexpected error during health check: $e');
      throw Exception('Backend not reachable. Please start your Flask server.');
    }
  }

  /// Get detailed error message for user display
  String getErrorMessage(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return 'Backend server not responding. Please check if the Flask server is running on port 5055.';
      case DioExceptionType.receiveTimeout:
        return 'Server response timeout. Please try again.';
      case DioExceptionType.badResponse:
        if (e.response?.statusCode == 505) {
          return 'Server error 505: HTTP Version Not Supported. This might be a CORS or server configuration issue. Please check the backend deployment.';
        }
        return 'Server error: ${e.response?.statusCode}. Please try again later.';
      case DioExceptionType.connectionError:
        return 'Cannot connect to backend. Please ensure the Flask server is running.';
      case DioExceptionType.cancel:
        return 'Request was cancelled.';
      default:
        return 'Network error: ${e.message}. Please check your connection and try again.';
    }
  }

  Future<void> _setupSession() async {
    String? sessionId = await _storage.read(key: 'session_id');
    if (sessionId == null) {
      // Get new session from backend
      try {
        final response = await _dio.get('/api/get_or_create_session');
        sessionId = response.data['session_id'];
        await _storage.write(key: 'session_id', value: sessionId);
      } catch (e) {
        print('❌ Failed to create session: $e');
        throw Exception('Failed to establish session with backend.');
      }
    }
    // Add session ID to all requests
    _dio.options.headers['X-Session-ID'] = sessionId;
  }

  Future<Message> sendMessage(String content) async {
    // Ensure session is created and available before sending the first message
    await _setupSession();
    String? sessionId = await _storage.read(key: 'session_id');
    if (sessionId == null) {
      // Defensive: try to get session again
      try {
        final response = await _dio.get('/api/get_or_create_session');
        sessionId = response.data['session_id'];
        await _storage.write(key: 'session_id', value: sessionId);
        _dio.options.headers['X-Session-ID'] = sessionId;
      } catch (e) {
        print('❌ Failed to create session in sendMessage: $e');
        throw Exception('Failed to establish session with backend.');
      }
    }

    try {
      print('📤 Sending message to: ${_dio.options.baseUrl}/api/chat');
      final response = await _dio.post(
        '/api/chat',
        data: {
          'message': content,
          'mode': 'mental_health', // Always use mental health mode for now
        },
      );

      if (response.data['error'] != null) {
        throw DioException(
          requestOptions: RequestOptions(path: '/api/chat'),
          error: response.data['error'],
        );
      }

      // Extract risk level and resources if present
      String riskLevel = 'none';
      List<String>? resources;

      if (response.data['risk_level'] != null) {
        riskLevel = response.data['risk_level'];
      }

      if (response.data['resources'] != null) {
        resources = List<String>.from(response.data['resources']);
      }

      // Create message with appropriate type
      MessageType messageType = MessageType.text;
      if (riskLevel == 'high' && resources != null && resources.isNotEmpty) {
        messageType = MessageType.system; // Use system for crisis messages
      }

      // Convert string risk level to RiskLevel enum
      RiskLevel riskLevelEnum = RiskLevel.none;
      switch (riskLevel.toLowerCase()) {
        case 'low':
          riskLevelEnum = RiskLevel.low;
          break;
        case 'medium':
          riskLevelEnum = RiskLevel.medium;
          break;
        case 'high':
          riskLevelEnum = RiskLevel.high;
          break;
        default:
          riskLevelEnum = RiskLevel.none;
      }

      return Message(
        content: response.data['response'],
        isUser: false,
        type: messageType,
        riskLevel: riskLevelEnum,
        resources: resources,
      );
    } on DioException catch (e) {
      print('🚨 DIO Exception in sendMessage:');
      print('   Type: ${e.type}');
      print('   Message: ${e.message}');
      print('   Status: ${e.response?.statusCode}');
      print('   URL: ${e.requestOptions.uri}');
      rethrow;
    } catch (e) {
      print('❌ Unexpected error in sendMessage: $e');
      rethrow;
    }
  }

  Future<List<Message>> getChatHistory() async {
    try {
      await _setupSession();
      final response = await _dio.get('/api/chat_history');

      if (response.data is List) {
        return response.data.map<Message>((msg) {
          // Convert string risk level to RiskLevel enum
          RiskLevel riskLevel = RiskLevel.none;
          switch ((msg['riskLevel'] ?? 'none').toString().toLowerCase()) {
            case 'low':
              riskLevel = RiskLevel.low;
              break;
            case 'medium':
              riskLevel = RiskLevel.medium;
              break;
            case 'high':
              riskLevel = RiskLevel.high;
              break;
            default:
              riskLevel = RiskLevel.none;
          }

          return Message(
            content: msg['content'],
            isUser: msg['isUser'],
            type: MessageType.text,
            riskLevel: riskLevel,
            resources: msg['resources'] != null
                ? List<String>.from(msg['resources'])
                : null,
          );
        }).toList();
      }
      return [];
    } catch (e) {
      print('❌ Error getting chat history: $e');
      return [];
    }
  }

  Future<List<MoodEntry>> getMoodHistory() async {
    try {
      await _setupSession();
      final response = await _dio.get('/api/mood_history');

      if (response.data is List) {
        return response.data
            .map<MoodEntry>(
              (entry) => MoodEntry(
                moodLevel: entry['mood_level'] ?? 3,
                timestamp: DateTime.parse(entry['timestamp']),
                note: entry['note'],
              ),
            )
            .toList();
      }
      return [];
    } catch (e) {
      print('❌ Error getting mood history: $e');
      return [];
    }
  }

  Future<void> addMoodEntry(MoodEntry entry) async {
    try {
      await _setupSession();
      await _dio.post(
        '/api/mood_entry',
        data: {
          'mood_level': entry.moodLevel,
          'timestamp': entry.timestamp.toIso8601String(),
          'note': entry.note,
        },
      );
    } catch (e) {
      print('❌ Error adding mood entry: $e');
      rethrow;
    }
  }

  Future<void> submitSelfAssessment(Map<String, dynamic> assessment) async {
    try {
      await _setupSession();
      await _dio.post('/api/self_assessment', data: assessment);
    } catch (e) {
      print('❌ Error submitting self assessment: $e');
      rethrow;
    }
  }

  void clearSession() {
    _storage.delete(key: 'session_id');
  }
}
