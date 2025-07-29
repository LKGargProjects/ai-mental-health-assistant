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
          handler.next(error);
        },
      ),
    );
  }

  Future<void> _setupSession() async {
    String? sessionId = await _storage.read(key: 'session_id');
    if (sessionId == null) {
      // Get new session from backend
      final response = await _dio.get('/api/get_or_create_session');
      sessionId = response.data['session_id'];
      await _storage.write(key: 'session_id', value: sessionId);
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
      final response = await _dio.get('/api/get_or_create_session');
      sessionId = response.data['session_id'];
      await _storage.write(key: 'session_id', value: sessionId);
      _dio.options.headers['X-Session-ID'] = sessionId;
    }
    try {
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
        riskLevel = response.data['risk_level'].toString().toLowerCase();
      }

      if (response.data['resources'] != null) {
        resources = List<String>.from(response.data['resources']);
      }

      final message = Message(
        content:
            response.data['response'] ??
            response.data['message'] ??
            'No response received',
        isUser: false,
        riskLevel: RiskLevel.values.firstWhere(
          (e) => e.toString().split('.').last == riskLevel,
          orElse: () => RiskLevel.none,
        ),
        resources: resources,
      );

      return message;
    } on DioException catch (e) {
      print('Error sending message: ${e.message}');
      print('Error response: ${e.response?.data}');
      return Message(
        content:
            e.response?.data?['error'] ??
            'An error occurred while communicating with the AI. Please try again.',
        isUser: false,
        type: MessageType.error,
      );
    } catch (e) {
      print('Unexpected error: $e');
      return Message(
        content: 'An unexpected error occurred. Please try again.',
        isUser: false,
        type: MessageType.error,
      );
    }
  }

  Future<List<MoodEntry>> getMoodHistory() async {
    await _setupSession();
    try {
      final response = await _dio.get('/api/mood_history');
      return (response.data as List)
          .map((json) => MoodEntry.fromJson(json))
          .toList();
    } catch (e) {
      print('Error getting mood history: $e');
      return [];
    }
  }

  Future<void> addMoodEntry(MoodEntry entry) async {
    await _setupSession();
    try {
      await _dio.post('/api/mood_entry', data: entry.toJson());
    } catch (e) {
      print('Error adding mood entry: $e');
      throw e;
    }
  }

  Future<List<Message>> getChatHistory() async {
    await _setupSession();
    try {
      final response = await _dio.get('/api/chat_history');
      return (response.data as List)
          .map((json) => Message.fromJson(json))
          .toList();
    } catch (e) {
      print('Error getting chat history: $e');
      return [];
    }
  }

  Future<void> clearSession() async {
    await _storage.delete(key: 'session_id');
  }

  /// Test backend connectivity and health
  Future<Map<String, dynamic>> testBackendHealth() async {
    try {
      print('🔍 Testing backend health...');
      final response = await _dio.get('/api/health');
      print('✅ Backend health check passed: ${response.data}');
      return response.data;
    } on DioException catch (e) {
      print('❌ Backend health check failed:');
      print('   Type: ${e.type}');
      print('   Message: ${e.message}');
      print('   Status: ${e.response?.statusCode}');

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
          errorMessage += 'Server error: ${e.response?.statusCode}';
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
        return 'Server error: ${e.response?.statusCode}. Please try again later.';
      case DioExceptionType.connectionError:
        return 'Cannot connect to backend. Please ensure the Flask server is running.';
      case DioExceptionType.cancel:
        return 'Request was cancelled.';
      default:
        return 'Network error: ${e.message}. Please check your connection and try again.';
    }
  }
}
