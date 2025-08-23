import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/mood_entry.dart';
import '../services/api_service.dart';

class MoodProvider extends ChangeNotifier {
  final ApiService _apiService;
  List<MoodEntry> _moodEntries = [];
  bool _isLoading = false;
  String? _error;
  static const String _cacheKey = 'mood_history_cache_v1';
  static const String _queueKey = 'mood_pending_queue_v1';

  // Pending mood submissions to retry in background
  final List<Map<String, dynamic>> _pendingQueue = <Map<String, dynamic>>[];
  bool _retryInProgress = false;
  int _retryBackoffMs = 2000; // exponential backoff starting at 2s

  MoodProvider({ApiService? apiService, bool eagerLoad = true})
      : _apiService = apiService ?? ApiService() {
    if (eagerLoad) {
      // Load cached data immediately for fast, offline-friendly UI
      _loadCachedMoodHistory();
      // Load any pending queue from disk
      _loadPendingQueue();
      // Then fetch fresh data from backend
      _loadMoodHistory();
      // Try draining any pending submissions in the background
      _scheduleDrain();
    }
  }

  List<MoodEntry> get moodEntries => List.unmodifiable(_moodEntries);
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> reload() => _loadMoodHistory();

  // Ensure consistent chronological order (oldest -> newest) across all code paths
  void _sortByTimestampAsc() {
    _moodEntries.sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  Future<void> _loadMoodHistory() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final entries = await _apiService.getMoodHistory();
      _moodEntries = entries;
      _sortByTimestampAsc();
      _error = null;
      // Persist cache for offline usage
      await _saveCachedMoodHistory();
    } catch (e) {
      // Backend unavailable; keep current list and surface a friendly error
      _error = 'Failed to load mood history';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadCachedMoodHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null || raw.isEmpty) return;
      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      final cached = list
          .map((e) => MoodEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      _moodEntries = cached;
      _sortByTimestampAsc();
      notifyListeners();
    } catch (_) {
      // Ignore cache errors silently
    }
  }

  Future<void> _loadPendingQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_queueKey);
      _pendingQueue.clear();
      if (raw == null || raw.isEmpty) return;
      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      for (final e in list) {
        if (e is Map<String, dynamic>) {
          _pendingQueue.add(e);
        } else if (e is Map) {
          _pendingQueue.add(Map<String, dynamic>.from(e));
        }
      }
    } catch (_) {
      // Ignore queue load errors
    }
  }

  Future<void> _savePendingQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_queueKey, jsonEncode(_pendingQueue));
    } catch (_) {
      // Ignore queue persistence failures
    }
  }

  void _enqueuePending(Map<String, dynamic> payload) {
    _pendingQueue.add(payload);
    _savePendingQueue();
  }

  void _scheduleDrain() {
    if (_pendingQueue.isEmpty) return;
    Future.delayed(Duration(milliseconds: _retryBackoffMs), () {
      _drainPendingQueue();
    });
    // increase backoff for subsequent schedules up to 60s
    _retryBackoffMs = (_retryBackoffMs * 2).clamp(2000, 60000);
  }

  Future<void> _drainPendingQueue() async {
    if (_retryInProgress) return;
    if (_pendingQueue.isEmpty) return;
    _retryInProgress = true;
    try {
      // Attempt to send all queued payloads
      int processed = 0;
      while (_pendingQueue.isNotEmpty) {
        final payload = Map<String, dynamic>.from(_pendingQueue.first);
        try {
          await _apiService.addMoodEntry(payload);
          _pendingQueue.removeAt(0);
          processed++;
          await _savePendingQueue();
        } catch (_) {
          // Stop on first failure; we'll retry later with backoff
          break;
        }
      }
      if (_pendingQueue.isEmpty && processed > 0) {
        // Reset backoff after success and refresh history silently
        _retryBackoffMs = 2000;
        // Best-effort refresh without disturbing UI state
        try {
          final entries = await _apiService.getMoodHistory();
          _moodEntries = entries;
          _sortByTimestampAsc();
          await _saveCachedMoodHistory();
          notifyListeners();
        } catch (_) {}
      } else if (_pendingQueue.isNotEmpty) {
        // Schedule another attempt later
        _scheduleDrain();
      }
    } finally {
      _retryInProgress = false;
    }
  }

  Future<void> _saveCachedMoodHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _moodEntries.map((e) => e.toJson()).toList();
      await prefs.setString(_cacheKey, jsonEncode(list));
    } catch (_) {
      // Ignore cache persistence failures
    }
  }

  Future<void> addMoodEntry(int moodLevel, {String? note}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final optimistic = MoodEntry(
      moodLevel: moodLevel,
      note: note,
      timestamp: DateTime.now().toUtc(),
    );

    // Phase 1: optimistic update immediately
    _moodEntries = [..._moodEntries, optimistic];
    _sortByTimestampAsc();
    await _saveCachedMoodHistory(); // persist optimistic state
    notifyListeners();

    bool postOk = false;

    // Phase 2: try to POST the new entry
    try {
      final payload = {
        'mood_level': moodLevel,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      };
      await _apiService.addMoodEntry(payload);
      postOk = true;
    } catch (_) {
      // Only set error if the POST itself fails
      _error = 'Failed to sync with server';
      // Enqueue payload for background retry and schedule drain
      final payload = {
        'mood_level': moodLevel,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        'timestamp': optimistic.timestamp.toIso8601String(),
      };
      _enqueuePending(payload);
      _scheduleDrain();
    }

    // Phase 3: if POST succeeded, refresh history for consistency
    if (postOk) {
      try {
        final entries = await _apiService.getMoodHistory();
        _moodEntries = entries;
        _error = null; // clear any previous error on success
        _sortByTimestampAsc();
        await _saveCachedMoodHistory();
      } catch (_) {
        // Silent: keep optimistic entries and cached state; next reload() will reconcile
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Manually trigger retry of pending submissions (testing and manual use)
  @visibleForTesting
  Future<void> retryPendingMoodSends() async => _drainPendingQueue();

  /// For tests: observe queue length
  @visibleForTesting
  int get pendingQueueLength => _pendingQueue.length;

  double get averageMood {
    if (_moodEntries.isEmpty) return 0;
    final sum = _moodEntries.fold<int>(
      0,
      (sum, entry) => sum + entry.moodLevel,
    );
    return sum / _moodEntries.length;
  }

  List<MoodEntry> getMoodEntriesForDate(DateTime date) {
    return _moodEntries.where((entry) {
      return entry.timestamp.year == date.year &&
          entry.timestamp.month == date.month &&
          entry.timestamp.day == date.day;
    }).toList();
  }

  Map<DateTime, List<MoodEntry>> get moodEntriesByDate {
    final map = <DateTime, List<MoodEntry>>{};
    for (final entry in _moodEntries) {
      final local = entry.timestamp.toLocal();
      final date = DateTime(
        local.year,
        local.month,
        local.day,
      );
      map.putIfAbsent(date, () => []).add(entry);
    }
    return map;
  }
}
