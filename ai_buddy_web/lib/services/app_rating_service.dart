import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_service.dart';

class AppRatingService {
  static final AppRatingService _instance = AppRatingService._internal();
  factory AppRatingService() => _instance;
  AppRatingService._internal();

  final InAppReview _inAppReview = InAppReview.instance;
  static const String _keyFirstLaunch = 'first_launch_date';
  static const String _keyLastRatingPrompt = 'last_rating_prompt';
  static const String _keySessionCount = 'session_count';
  static const String _keyPositiveMoodCount = 'positive_mood_count';
  static const String _keyHasRated = 'has_rated';

  // Rating trigger thresholds (optimized for mental health app)
  static const int _minSessions = 5;
  static const int _minPositiveMoods = 3;
  static const int _minDaysSinceInstall = 3;
  static const int _minDaysBetweenPrompts = 30;

  Future<void> checkAndRequestRating() async {
    final prefs = await SharedPreferences.getInstance();

    // Skip if already rated
    if (prefs.getBool(_keyHasRated) ?? false) return;

    // Check if available
    if (!await _inAppReview.isAvailable()) return;

    // Get metrics
    final sessionCount = prefs.getInt(_keySessionCount) ?? 0;
    final positiveMoodCount = prefs.getInt(_keyPositiveMoodCount) ?? 0;
    final firstLaunch = prefs.getString(_keyFirstLaunch);
    final lastPrompt = prefs.getString(_keyLastRatingPrompt);

    // Set first launch if not set
    if (firstLaunch == null) {
      await prefs.setString(_keyFirstLaunch, DateTime.now().toIso8601String());
      return;
    }

    // Check conditions
    final daysSinceInstall =
        DateTime.now().difference(DateTime.parse(firstLaunch)).inDays;

    if (daysSinceInstall < _minDaysSinceInstall) return;
    if (sessionCount < _minSessions) return;
    if (positiveMoodCount < _minPositiveMoods) return;

    // Check time since last prompt
    if (lastPrompt != null) {
      final daysSinceLastPrompt =
          DateTime.now().difference(DateTime.parse(lastPrompt)).inDays;
      if (daysSinceLastPrompt < _minDaysBetweenPrompts) return;
    }

    // Request rating
    await _requestRating();
  }

  Future<void> _requestRating() async {
    try {
      await _inAppReview.requestReview();

      // Log event
      FirebaseService().logEvent('rating_prompt_shown');

      // Update last prompt time
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _keyLastRatingPrompt, DateTime.now().toIso8601String());
    } catch (e) {
      // Silent fail - don't disrupt user experience
      FirebaseService().recordError(e, null);
    }
  }

  Future<void> incrementSessionCount() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_keySessionCount) ?? 0;
    await prefs.setInt(_keySessionCount, current + 1);
  }

  Future<void> recordPositiveMood() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_keyPositiveMoodCount) ?? 0;
    await prefs.setInt(_keyPositiveMoodCount, current + 1);

    // Check if we should prompt after positive experience
    if (current + 1 == _minPositiveMoods) {
      await checkAndRequestRating();
    }
  }

  Future<void> userRatedApp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHasRated, true);
    FirebaseService().logEvent('user_rated_app');
  }

  // Call this if user gives negative feedback to delay prompts
  Future<void> delayRatingPrompts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _keyLastRatingPrompt, DateTime.now().toIso8601String());
  }
}
