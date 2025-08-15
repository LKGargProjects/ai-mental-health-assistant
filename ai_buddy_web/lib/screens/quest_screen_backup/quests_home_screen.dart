import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ai_buddy_web/providers/quest_provider.dart';
import 'package:ai_buddy_web/models/quest.dart';
import 'package:ai_buddy_web/widgets/quest_card.dart';

class QuestsHomeScreen extends StatelessWidget {
  const QuestsHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Quests'),
        elevation: 0,
        centerTitle: true,
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
        final level = questProvider.level;
        final xp = questProvider.totalXP % 1000; // XP in current level
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
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
    );
  }

  Widget _buildQuestList(BuildContext context, QuestStatus status) {
    return Consumer<QuestProvider>(
      builder: (context, questProvider, _) {
        final quests = status == QuestStatus.unlocked
            ? questProvider.unlockedQuests
            : questProvider.inProgressQuests;

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
            return QuestCard(
              title: quest.title,
              description: quest.description,
              progress: quest.progress / quest.target,
              icon: quest.icon,
              color: _getCategoryColor(quest.category),
              onTap: () {
                // Handle quest tap
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
        final lockedQuests = questProvider.quests
            .where((q) => q.status == QuestStatus.locked)
            .toList();

        if (lockedQuests.isEmpty) return const SizedBox.shrink();

        return ExpansionTile(
          title: const Text(
            'Locked Quests',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          children: [
            const SizedBox(height: 8),
            ...lockedQuests.map(
              (quest) => Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Opacity(
                  opacity: 0.6,
                  child: QuestCard(
                    title: '???',
                    description: 'Complete previous quests to unlock',
                    progress: 0,
                    icon: Icons.lock_outline,
                    color: Colors.grey,
                    onTap: null,
                  ),
                ),
              ),
            ),
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
      builder: (context) => _buildQuestDetails(quest),
    );
  }

  Widget _buildQuestDetails(Quest quest) {
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
                    child: Icon(
                      quest.icon,
                      color: _getCategoryColor(quest.category),
                    ),
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
                    Theme.of(context).primaryColor,
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
                        questProvider.updateQuestProgress(
                          quest.id,
                          newProgress,
                        );
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
                      questProvider.updateQuestProgress(quest.id, 1);
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
      default:
        return Colors.grey;
    }
  }
}
