import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../models/community_post.dart';

class CommunityProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  bool _hasLoaded = false;
  String? _selectedTopic; // null => All
  final List<CommunityPost> _posts = [];
  DateTime? _lastPostAt; // client-side cooldown anchor
  Map<String, dynamic>? _nextCursor;
  bool _hasMore = true;
  // Feature flags
  bool _communityEnabled = true;
  bool _postingEnabled = true;
  bool _templatesOnly = false;

  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  String? get error => _error;
  bool get hasLoaded => _hasLoaded;
  String? get selectedTopic => _selectedTopic;
  List<CommunityPost> get posts => List.unmodifiable(_posts);
  bool get hasMore => _hasMore;
  bool get communityEnabled => _communityEnabled;
  bool get postingEnabled => _postingEnabled;
  bool get templatesOnly => _templatesOnly;

  int get composeCooldownSecondsRemaining {
    if (_lastPostAt == null) return 0;
    final elapsed = DateTime.now().difference(_lastPostAt!).inSeconds;
    const cooldown = 30; // guardrail; server rate limit is 6/min
    return elapsed >= cooldown ? 0 : (cooldown - elapsed);
  }

  Future<void> fetchFlags() async {
    try {
      final data = await _api.getCommunityFlags();
      _communityEnabled = (data['enabled'] == true);
      _postingEnabled = (data['posting_enabled'] == true);
      _templatesOnly = (data['templates_only'] == true);
      notifyListeners();
    } catch (e) {
      // Keep defaults on error; do not block UI
      if (kDebugMode) {
        // ignore: avoid_print
        print('Community flags fetch error: $e');
      }
    }
  }

  Future<void> loadFeed({String? topic}) async {
    if (_isLoading) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _selectedTopic = (topic != null && topic.trim().isNotEmpty) ? topic.trim() : null;
      final page = await _api.getCommunityFeedPage(topic: _selectedTopic, limit: 20);
      _posts
        ..clear()
        ..addAll(page.items);
      _nextCursor = page.nextCursor;
      _hasMore = page.nextCursor != null && page.items.isNotEmpty;
      _hasLoaded = true;
    } catch (e) {
      _error = 'Failed to load community feed';
      if (kDebugMode) {
        // ignore: avoid_print
        print('Community load error: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchMore() async {
    if (_isLoading || _isLoadingMore || !_hasMore) return;
    _isLoadingMore = true;
    notifyListeners();
    try {
      final page = await _api.getCommunityFeedPage(
        topic: _selectedTopic,
        limit: 20,
        cursor: _nextCursor,
      );
      if (page.items.isNotEmpty) {
        _posts.addAll(page.items);
      }
      _nextCursor = page.nextCursor;
      _hasMore = page.nextCursor != null && page.items.isNotEmpty;
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('Community load more error: $e');
      }
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<CommunityPost?> compose({required String body, String? topic}) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      _error = 'Post cannot be empty';
      notifyListeners();
      return null;
    }
    final remain = composeCooldownSecondsRemaining;
    if (remain > 0) {
      _error = 'Please wait ${remain}s before posting again';
      notifyListeners();
      return null;
    }
    try {
      final created = await _api.createCommunityPost(body: trimmed, topic: topic);
      // Insert optimistically at top if current filter matches
      final matchesFilter = (_selectedTopic == null) ||
          (_selectedTopic != null && created.topic.toLowerCase() == _selectedTopic!.toLowerCase());
      if (matchesFilter) {
        _posts.insert(0, created);
        _hasLoaded = true;
        notifyListeners();
      }
      _lastPostAt = DateTime.now();
      _error = null;
      return created;
    } catch (e) {
      _error = 'Failed to create post';
      if (kDebugMode) {
        // ignore: avoid_print
        print('Community compose error: $e');
      }
      notifyListeners();
      return null;
    }
  }

  Future<void> react(int postId, String kind) async {
    try {
      await _api.addCommunityReaction(postId: postId, kind: kind);
      final idx = _posts.indexWhere((p) => p.id == postId);
      if (idx != -1) {
        final p = _posts[idx];
        _posts[idx] = CommunityPost(
          id: p.id,
          topic: p.topic,
          body: p.body,
          createdAt: p.createdAt,
          relate: p.relate + (kind == 'relate' ? 1 : 0),
          helped: p.helped + (kind == 'helped' ? 1 : 0),
          strength: p.strength + (kind == 'strength' ? 1 : 0),
        );
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('Community react error: $e');
      }
    }
  }

  Future<void> report(int postId, String reason, {String? notes}) async {
    try {
      await _api.reportCommunityPost(postId: postId, reason: reason, notes: notes);
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('Community report error: $e');
      }
    }
  }
}
