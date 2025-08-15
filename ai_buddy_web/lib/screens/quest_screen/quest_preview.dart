import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_buddy_web/providers/quest_provider.dart';
import 'package:ai_buddy_web/models/quest.dart';
import 'package:ai_buddy_web/widgets/quest_card.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => QuestProvider()),
      ],
      child: const QuestPreviewApp(),
    ),
  );
}

class QuestPreviewApp extends StatelessWidget {
  const QuestPreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quest Screen Preview',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const QuestsHomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class QuestsHomeScreen extends StatelessWidget {
  const QuestsHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Initialize with sample data for preview
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final questProvider = Provider.of<QuestProvider>(context, listen: false);
      if (questProvider.quests.isEmpty) {
        // Clear any existing quests
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('user_quests');
        
        // Add sample quests
        final sampleQuests = [
          Quest(
            id: 'mindfulness_1',
            title: 'Morning Meditation',
            description: 'Meditate for 5 minutes',
            xpReward: 50,
            category: QuestCategory.mindfulness,
            icon: Icons.self_improvement,
            progress: 3,
            target: 5,
            status: QuestStatus.inProgress,
          ),
          Quest(
            id: 'activity_1',
            title: 'Daily Steps',
            description: 'Walk 10,000 steps today',
            xpReward: 100,
            category: QuestCategory.activity,
            icon: Icons.directions_walk,
            progress: 7500,
            target: 10000,
            status: QuestStatus.inProgress,
          ),
          Quest(
            id: 'learning_1',
            title: 'Learn Something New',
            description: 'Read an article or watch an educational video',
            xpReward: 75,
            category: QuestCategory.learning,
            icon: Icons.school,
            progress: 0,
            target: 1,
            status: QuestStatus.unlocked,
          ),
          Quest(
            id: 'social_1',
            title: 'Connect with Friends',
            description: 'Message or call a friend',
            xpReward: 60,
            category: QuestCategory.social,
            icon: Icons.people,
            progress: 0,
            target: 1,
            status: QuestStatus.locked,
          ),
        ];
        
        // Save sample quests
        final questsJson = jsonEncode(sampleQuests.map((q) => q.toJson()).toList());
        await prefs.setString('user_quests', questsJson);
        
        // Reload quests
        await questProvider.loadQuests();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Quests'),
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              // Reset preview data
              final questProvider = Provider.of<QuestProvider>(context, listen: false);
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('user_quests');
              await questProvider.loadQuests();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Level and XP Indicator
              _buildLevelIndicator(context),
              const SizedBox(height: 24),
              
              // In Progress Quests
              _buildSectionTitle('In Progress'),
              const SizedBox(height: 16),
              _buildQuestList(context, QuestStatus.inProgress),
              
              const SizedBox(height: 24),
              
              // Available Quests
              _buildSectionTitle('Available Quests'),
              const SizedBox(height: 16),
              _buildQuestList(context, QuestStatus.unlocked),
              
              const SizedBox(height: 24),
              
              // Locked Quests (collapsed by default)
              _buildLockedQuestsSection(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLevelIndicator(BuildContext context) {
    return Consumer<QuestProvider>(
      builder: (context, questProvider, _) {
        final level = 5;
        final xp = 350; // XP in current level
        final xpNeeded = 1000; // XP needed for next level
        
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Level $level',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '$xp / $xpNeeded XP',
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: xp / xpNeeded,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildQuestList(BuildContext context, QuestStatus status) {
    return Consumer<QuestProvider>(
      builder: (context, questProvider, _) {
        List<Quest> quests;
        if (status == QuestStatus.inProgress) {
          quests = questProvider.inProgressQuests;
        } else if (status == QuestStatus.unlocked) {
          quests = questProvider.unlockedQuests.where((q) => q.status == status).toList();
        } else {
          quests = questProvider.quests.where((q) => q.status == status).toList();
        }

        if (quests.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: Center(
              child: Text(
                'No quests available',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: quests.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final quest = quests[index];
            return QuestCard.fromQuest(
              quest,
              onTap: () {
                _showQuestDetails(context, quest);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildLockedQuestsSection(BuildContext context) {
    return Consumer<QuestProvider>(
      builder: (context, questProvider, _) {
        final lockedQuests = questProvider.quests.where((q) => q.status == QuestStatus.locked).toList();

        if (lockedQuests.isEmpty) return const SizedBox.shrink();

        return ExpansionTile(
          title: const Text(
            'Locked Quests',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          children: [
            const SizedBox(height: 8),
            ...lockedQuests.map((quest) => Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: QuestCard.fromQuest(
                quest,
                onTap: null,
              ),
            )),
          ],
        );
      },
    );
  }

  void _showQuestDetails(BuildContext context, Quest quest) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _buildQuestDetails(quest, context),
    );
  }

  Widget _buildQuestDetails(Quest quest, BuildContext context) {
    return Consumer<QuestProvider>(
      builder: (context, questProvider, _) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _getCategoryColor(quest.category).withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(quest.icon, color: _getCategoryColor(quest.category)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          quest.title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${quest.xpReward} XP',
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                quest.description,
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 24),
              if (quest.status == QuestStatus.inProgress) ...[
                const Text(
                  'Progress',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: quest.progress / quest.target,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${quest.progress} / ${quest.target} completed',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      // Update progress
                      final newProgress = quest.progress + 1;
                      if (newProgress <= quest.target) {
                        // Update quest progress
                        final updatedQuest = quest.copyWith(
                          progress: newProgress,
                          status: newProgress >= quest.target 
                              ? QuestStatus.completed 
                              : QuestStatus.inProgress,
                        );
                        
                        // Save the updated quest
                        final prefs = await SharedPreferences.getInstance();
                        final quests = List<Quest>.from(questProvider.quests);
                        final index = quests.indexWhere((q) => q.id == quest.id);
                        if (index != -1) {
                          quests[index] = updatedQuest;
                          final questsJson = jsonEncode(quests.map((q) => q.toMap()).toList());
                          await prefs.setString('user_quests', questsJson);
                          await questProvider.loadQuests();
                        }
                      }
                      Navigator.pop(context);
                    },
                    child: const Text('Mark as Progressed'),
                  ),
                ),
              ] else if (quest.status == QuestStatus.unlocked) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      // Start quest
                      final updatedQuest = quest.copyWith(
                        progress: 1,
                        status: QuestStatus.inProgress,
                      );
                      
                      // Save the updated quest
                      final prefs = await SharedPreferences.getInstance();
                      final quests = List<Quest>.from(questProvider.quests);
                      final index = quests.indexWhere((q) => q.id == quest.id);
                      if (index != -1) {
                        quests[index] = updatedQuest;
                        final questsJson = jsonEncode(quests.map((q) => q.toMap()).toList());
                        await prefs.setString('user_quests', questsJson);
                        await questProvider.loadQuests();
                      }
                      Navigator.pop(context);
                    },
                    child: const Text('Start Quest'),
                  ),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  static Color _getCategoryColor(QuestCategory category) {
    switch (category) {
      case QuestCategory.mindfulness:
        return Colors.blue;
      case QuestCategory.activity:
        return Colors.green;
      case QuestCategory.social:
        return Colors.purple;
      case QuestCategory.learning:
        return Colors.orange;
      case QuestCategory.challenge:
        return Colors.red;
    }
  }
}
