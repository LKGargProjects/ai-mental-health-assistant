import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ai_buddy_web/providers/quest_provider.dart';
import 'package:ai_buddy_web/models/quest.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => QuestProvider())],
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

class QuestsHomeScreen extends StatefulWidget {
  const QuestsHomeScreen({super.key});

  @override
  _QuestsHomeScreenState createState() => _QuestsHomeScreenState();
}

class _QuestsHomeScreenState extends State<QuestsHomeScreen> {
  @override
  void initState() {
    super.initState();
    _initializeSampleQuests();
  }

  Future<void> _initializeSampleQuests() async {
    final questProvider = Provider.of<QuestProvider>(context, listen: false);

    if (questProvider.quests.isEmpty) {
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
      ];

      // Add sample quests to the provider
      for (var quest in sampleQuests) {
        questProvider.addQuest(quest);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Quests'),
        elevation: 0,
        centerTitle: true,
      ),
      body: Consumer<QuestProvider>(
        builder: (context, questProvider, _) {
          final inProgressQuests = questProvider.quests
              .where((q) => q.status == QuestStatus.inProgress)
              .toList();

          final availableQuests = questProvider.quests
              .where((q) => q.status == QuestStatus.unlocked)
              .toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Level and XP Indicator
                _buildLevelIndicator(),
                const SizedBox(height: 24),

                // In Progress Quests
                const Text(
                  'In Progress',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildQuestList(inProgressQuests, context),

                const SizedBox(height: 24),

                // Available Quests
                const Text(
                  'Available Quests',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildQuestList(availableQuests, context),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLevelIndicator() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Level 5',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(
                  '350 / 1000 XP',
                  style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: 0.35,
              backgroundColor: Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestList(List<Quest> quests, BuildContext context) {
    if (quests.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24.0),
          child: Text(
            'No quests available',
            style: TextStyle(color: Colors.grey, fontSize: 16),
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
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: () {
              _showQuestDetails(context, quest);
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: quest.categoryColor.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(quest.icon, color: quest.categoryColor),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              quest.title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${quest.xpReward} XP',
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: Colors.grey[400]),
                    ],
                  ),
                  if (quest.status == QuestStatus.inProgress) ...[
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: quest.progress / quest.target,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        quest.categoryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${quest.progress} / ${quest.target} completed',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
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
                      color: quest.categoryColor.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(quest.icon, color: quest.categoryColor),
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
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: quest.progress / quest.target,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    quest.categoryColor,
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${quest.progress} / ${quest.target} completed',
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
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
                        final updatedQuest = quest.copyWith(
                          progress: newProgress,
                          status: newProgress >= quest.target
                              ? QuestStatus.completed
                              : QuestStatus.inProgress,
                        );

                        // Update the quest in the provider
                        questProvider.updateQuest(updatedQuest);
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

                      // Update the quest in the provider
                      questProvider.updateQuest(updatedQuest);
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
}
