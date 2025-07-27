import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/message.dart';
import '../models/mood_entry.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:5058'; // Updated port to match Flask
  final Dio _dio;
  final FlutterSecureStorage _storage;

  ApiService()
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        )),
        _storage = const FlutterSecureStorage();

  Future<void> _setupSession() async {
    String? sessionId = await _storage.read(key: 'session_id');
    if (sessionId == null) {
      // Get new session from backend
      final response = await _dio.get('/get_or_create_session');
      sessionId = response.data['session_id'];
      await _storage.write(key: 'session_id', value: sessionId);
    }
    // Add session ID to all requests
    _dio.options.headers['X-Session-ID'] = sessionId;
  }

  Future<Message> sendMessage(String content) async {
    await _setupSession();
    try {
      final response = await _dio.post('/chat', data: {
        'message': content,
        'mode': 'mental_health', // Always use mental health mode for now
      });

      if (response.data['error'] != null) {
        throw DioException(
          requestOptions: RequestOptions(path: '/chat'),
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
        content: response.data['response'] ?? response.data['message'] ?? 'No response received',
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
        content: e.response?.data?['error'] ?? 'An error occurred while communicating with the AI. Please try again.',
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
      final response = await _dio.get('/mood_history');
      return (response.data as List)
          .map((json) => MoodEntry.fromJson(json))
          .toList();
    } catch (e) {
      print('Error getting mood history: $e');
      return [];
    }
  }

  Future<MoodEntry> addMoodEntry(MoodEntry entry) async {
    await _setupSession();
    try {
      final response = await _dio.post('/mood_entry', data: entry.toJson());
      return MoodEntry.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception(e.response?.data?['error'] ?? 'Failed to save mood entry');
    }
  }

  Future<List<Message>> getChatHistory() async {
    await _setupSession();
    try {
      final response = await _dio.get('/chat_history');
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
} 