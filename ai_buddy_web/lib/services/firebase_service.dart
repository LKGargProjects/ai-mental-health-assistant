import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  late FirebaseAnalytics _analytics;
  late FirebaseCrashlytics _crashlytics;
  bool _initialized = false;

  FirebaseAnalytics get analytics => _analytics;

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      await Firebase.initializeApp();
      _analytics = FirebaseAnalytics.instance;
      _crashlytics = FirebaseCrashlytics.instance;

      // Configure Crashlytics
      await _crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);

      // Set up Flutter error handling
      FlutterError.onError = _crashlytics.recordFlutterFatalError;

      // Set up async error handling
      PlatformDispatcher.instance.onError = (error, stack) {
        _crashlytics.recordError(error, stack, fatal: true);
        return true;
      };

      _initialized = true;

      // Log app open
      await logEvent('app_open');
    } catch (e) {
      debugPrint('Firebase initialization failed: $e');
    }
  }

  // Analytics Events
  Future<void> logEvent(String name, [Map<String, dynamic>? parameters]) async {
    if (!_initialized) return;

    try {
      await _analytics.logEvent(
        name: name,
        parameters: parameters,
      );
    } catch (e) {
      debugPrint('Analytics event failed: $e');
    }
  }

  Future<void> logScreenView(String screenName) async {
    if (!_initialized) return;

    await _analytics.logScreenView(
      screenName: screenName,
      screenClass: screenName,
    );
  }

  Future<void> setUserId(String? userId) async {
    if (!_initialized) return;
    await _analytics.setUserId(id: userId);
  }

  Future<void> setUserProperty(String name, String? value) async {
    if (!_initialized) return;
    await _analytics.setUserProperty(name: name, value: value);
  }

  // Crashlytics
  Future<void> recordError(
    dynamic exception,
    StackTrace? stack, {
    bool fatal = false,
  }) async {
    if (!_initialized) return;
    await _crashlytics.recordError(exception, stack, fatal: fatal);
  }

  Future<void> log(String message) async {
    if (!_initialized) return;
    _crashlytics.log(message);
  }

  Future<void> setCustomKey(String key, dynamic value) async {
    if (!_initialized) return;
    _crashlytics.setCustomKey(key, value);
  }

  // Common events for mental health app
  Future<void> logMoodEntry(String mood, int score) async {
    await logEvent('mood_tracked', {
      'mood_type': mood,
      'mood_score': score,
    });
  }

  Future<void> logChatMessage(String messageType) async {
    await logEvent('chat_message', {
      'message_type': messageType,
    });
  }

  Future<void> logCrisisResourceAccess() async {
    await logEvent('crisis_resource_accessed');
  }

  Future<void> logExerciseCompleted(String exerciseType) async {
    await logEvent('exercise_completed', {
      'exercise_type': exerciseType,
    });
  }
}
