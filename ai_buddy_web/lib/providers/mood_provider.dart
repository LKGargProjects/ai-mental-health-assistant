import 'package:flutter/material.dart';
import '../models/mood_entry.dart';
import '../services/api_service.dart';

class MoodProvider extends ChangeNotifier {
  final ApiService _apiService;
  List<MoodEntry> _moodEntries = [];
  bool _isLoading = false;
  String? _error;

  MoodProvider() : _apiService = ApiService() {
    _loadMoodHistory();
  }

  List<MoodEntry> get moodEntries => List.unmodifiable(_moodEntries);
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> _loadMoodHistory() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // For now, use local storage instead of backend
      // TODO: Implement backend mood tracking later
      _moodEntries = [];
      _error = null;
    } catch (e) {
      _error = 'Failed to load mood history';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addMoodEntry(int moodLevel, {String? note}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final entry = MoodEntry(moodLevel: moodLevel, note: note);
      
      // For now, store locally instead of backend
      // TODO: Implement backend mood tracking later
      _moodEntries = [..._moodEntries, entry];
      _error = null;
    } catch (e) {
      _error = 'Failed to save mood entry';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

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
      final date = DateTime(
        entry.timestamp.year,
        entry.timestamp.month,
        entry.timestamp.day,
      );
      map.putIfAbsent(date, () => []).add(entry);
    }
    return map;
  }
}
