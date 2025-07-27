import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/progress.dart';

class ProgressProvider extends ChangeNotifier {
  final ApiService _apiService;
  List<CommunityFeedItem> _communityFeed = [];
  List<ProgressPost> _userPosts = [];
  bool _isLoading = false;
  String? _error;

  ProgressProvider() : _apiService = ApiService();

  List<CommunityFeedItem> get communityFeed => List.unmodifiable(_communityFeed);
  List<ProgressPost> get userPosts => List.unmodifiable(_userPosts);
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadCommunityFeed() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final feedData = await _apiService.getCommunityFeed();
      _communityFeed = feedData
          .map((json) => CommunityFeedItem.fromJson(json))
          .toList();
    } catch (e) {
      _error = 'Failed to load community feed';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> shareProgress({String? sharedText, String privacySetting = 'public'}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _apiService.shareProgress(
        sharedText: sharedText,
        privacySetting: privacySetting,
      );
      
      // Add to user posts if successful
      final post = ProgressPost(
        id: result['post_id'],
        timestamp: result['timestamp'],
        progressSummary: {}, // Will be populated by backend
        sharedText: sharedText,
      );
      _userPosts.insert(0, post);
      
      // Reload community feed to include the new post
      await loadCommunityFeed();
    } catch (e) {
      _error = 'Failed to share progress';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String formatProgressSummary(Map<String, dynamic> summary) {
    final assessmentCount = summary['assessment_count'] ?? 0;
    final taskCompletions = summary['task_completions'] ?? 0;
    final totalPoints = summary['total_points_earned'] ?? 0;
    final lastScore = summary['last_assessment_score'];

    final List<String> achievements = [];
    
    if (assessmentCount > 0) {
      achievements.add('Completed $assessmentCount assessment${assessmentCount > 1 ? 's' : ''}');
    }
    
    if (taskCompletions > 0) {
      achievements.add('Completed $taskCompletions task${taskCompletions > 1 ? 's' : ''}');
    }
    
    if (totalPoints > 0) {
      achievements.add('Earned $totalPoints points');
    }
    
    if (lastScore != null) {
      achievements.add('Latest assessment score: ${lastScore.toStringAsFixed(1)}%');
    }

    return achievements.isEmpty ? 'Starting their wellness journey' : achievements.join(', ');
  }

  String formatTimestamp(String timestamp) {
    try {
      final date = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 0) {
        return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return 'Recently';
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void reset() {
    _communityFeed.clear();
    _userPosts.clear();
    _error = null;
    notifyListeners();
  }
} 