import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import '../models/quest.dart';

class QuestProvider with ChangeNotifier {
  static const String _questsKey = 'user_quests';
  
  List<Quest> _quests = [];
  int _totalXP = 0;
  int _level = 1;
  
  List<Quest> get quests => _quests;
  int get totalXP => _totalXP;
  int get level => _level;
  
  // Getters for different quest categories
  List<Quest> get unlockedQuests => _quests.where((q) => q.status != QuestStatus.locked).toList();
  List<Quest> get inProgressQuests => _quests.where((q) => q.status == QuestStatus.inProgress).toList();
  List<Quest> get completedQuests => _quests.where((q) => q.status == QuestStatus.completed).toList();
  
  // Initialize with default quests
  QuestProvider() {
    loadQuests();
  }
  
  Future<void> loadQuests() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final questsJson = prefs.getString(_questsKey);
      
      if (questsJson != null) {
        // Load saved quests
        final List<dynamic> decoded = json.decode(questsJson);
        _quests = decoded.map((q) {
          // Find matching default quest for icon and other defaults
          final defaultQuest = defaultQuests.firstWhere(
            (quest) => quest.id == q['id'],
            orElse: () => Quest(
              id: q['id'],
              title: q['title'],
              description: q['description'],
              xpReward: q['xpReward'],
              category: QuestCategory.values[q['categoryIndex']],
              icon: Icons.help_outline,
              target: q['target'],
            ),
          );
          
          return Quest(
            id: q['id'],
            title: q['title'],
            description: q['description'],
            xpReward: q['xpReward'],
            category: QuestCategory.values[q['categoryIndex']],
            icon: defaultQuest.icon,
            progress: q['progress'],
            target: q['target'],
            status: QuestStatus.values[q['statusIndex']],
            completedAt: q['completedAt'] != null ? DateTime.parse(q['completedAt']) : null,
          );
        }).toList();
      } else {
        // First time - initialize with default quests
        _quests = List<Quest>.from(defaultQuests);
        await _saveQuests();
      }
      
      _calculateXPAndLevel();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading quests: $e');
      _quests = List<Quest>.from(defaultQuests);
    }
  }
  
  Future<void> _saveQuests() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> questsJson = _quests.map((q) => {
        'id': q.id,
        'title': q.title,
        'description': q.description,
        'xpReward': q.xpReward,
        'categoryIndex': q.category.index,
        'progress': q.progress,
        'target': q.target,
        'statusIndex': q.status.index,
        'completedAt': q.completedAt?.toIso8601String(),
      }).toList();
      
      await prefs.setString(_questsKey, json.encode(questsJson));
    } catch (e) {
      debugPrint('Error saving quests: $e');
    }
  }
  
  void _calculateXPAndLevel() {
    _totalXP = _quests
        .where((q) => q.status == QuestStatus.completed)
        .fold(0, (sum, q) => sum + q.xpReward);
    
    _level = (_totalXP / 1000).floor() + 1;
  }
  
  Future<void> updateQuestProgress(String questId, int newProgress) async {
    final index = _quests.indexWhere((q) => q.id == questId);
    if (index == -1) return;
    
    final quest = _quests[index];
    final updatedProgress = newProgress.clamp(0, quest.target);
    final isCompleted = updatedProgress >= quest.target;
    
    _quests[index] = quest.copyWith(
      progress: updatedProgress,
      status: isCompleted ? QuestStatus.completed : QuestStatus.inProgress,
      completedAt: isCompleted ? DateTime.now() : quest.completedAt,
    );
    
    _checkForUnlocks();
    await _saveQuests();
    _calculateXPAndLevel();
    notifyListeners();
  }
  
  void _checkForUnlocks() {
    // Unlock social quest when mindfulness quest is completed
    if (_quests.any((q) => q.id == 'mindfulness_1' && q.status == QuestStatus.completed)) {
      final socialQuestIndex = _quests.indexWhere((q) => q.id == 'social_1');
      if (socialQuestIndex != -1 && _quests[socialQuestIndex].status == QuestStatus.locked) {
        _quests[socialQuestIndex] = _quests[socialQuestIndex].copyWith(
          status: QuestStatus.unlocked,
        );
      }
    }
  }
  
  Future<void> resetQuests() async {
    _quests = List<Quest>.from(defaultQuests);
    await _saveQuests();
    _calculateXPAndLevel();
    notifyListeners();
  }
  
  List<Quest> getQuestsByCategory(QuestCategory category) {
    return _quests.where((q) => q.category == category).toList();
  }
  
  Quest? getQuestById(String questId) {
    try {
      return _quests.firstWhere((q) => q.id == questId);
    } catch (e) {
      return null;
    }
  }
}
