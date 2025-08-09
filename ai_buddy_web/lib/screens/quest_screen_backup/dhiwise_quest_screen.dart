import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ai_buddy_web/providers/quest_provider.dart';
import 'package:ai_buddy_web/models/quest.dart';
import 'package:ai_buddy_web/widgets/dhiwise/custom_image_view.dart';

class DhiwiseQuestScreen extends StatelessWidget {
  const DhiwiseQuestScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: Stack(
          children: [
            // Background Image
            CustomImageView(
              imagePath: 'assets/images/quests/img_background_1440x635_1.png',
              height: MediaQuery.of(context).size.height,
              width: MediaQuery.of(context).size.width,
              fit: BoxFit.cover,
            ),
            
            // Main Content
            Consumer<QuestProvider>(
              builder: (context, questProvider, _) {
                return SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        _buildHeaderSection(context, questProvider),
                        const SizedBox(height: 24),
                        
                        // Active Quests Section
                        _buildSectionTitle('Active Quests'),
                        const SizedBox(height: 16),
                        _buildActiveQuests(questProvider),
                        
                        // Available Quests Section
                        const SizedBox(height: 24),
                        _buildSectionTitle('Available Quests'),
                        const SizedBox(height: 16),
                        _buildAvailableQuests(questProvider),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection(BuildContext context, QuestProvider questProvider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your Quests',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Complete quests to earn rewards',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          ],
        ),
        // Add any header actions here
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }

  Widget _buildActiveQuests(QuestProvider questProvider) {
    final activeQuests = questProvider.quests
        .where((q) => q.status == QuestStatus.inProgress)
        .toList();

    if (activeQuests.isEmpty) {
      return _buildEmptyState('No active quests. Start a quest to begin!');
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: activeQuests.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final quest = activeQuests[index];
        return _buildQuestCard(quest, questProvider, context);
      },
    );
  }

  Widget _buildAvailableQuests(QuestProvider questProvider) {
    final availableQuests = questProvider.quests
        .where((q) => q.status == QuestStatus.unlocked)
        .toList();

    if (availableQuests.isEmpty) {
      return _buildEmptyState('No available quests at the moment.');
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: availableQuests.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final quest = availableQuests[index];
        return _buildQuestCard(quest, questProvider, context);
      },
    );
  }

  Widget _buildQuestCard(Quest quest, QuestProvider questProvider, BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _getCategoryColor(quest.category).withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _getCategoryIcon(quest.category),
            color: _getCategoryColor(quest.category),
          ),
        ),
        title: Text(
          quest.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(quest.description),
            if (quest.status == QuestStatus.inProgress) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: quest.progress / quest.target,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(
                  _getCategoryColor(quest.category),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${quest.progress} / ${quest.target} completed',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ],
        ),
        trailing: Text(
          '${quest.xpReward} XP',
          style: const TextStyle(
            color: Colors.blue,
            fontWeight: FontWeight.bold,
          ),
        ),
        onTap: () => _showQuestDetails(context, quest, questProvider),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }

  void _showQuestDetails(
      BuildContext context, Quest quest, QuestProvider questProvider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _buildQuestDetails(quest, context, questProvider),
    );
  }

  Widget _buildQuestDetails(
      Quest quest, BuildContext context, QuestProvider questProvider) {
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
                  _getCategoryIcon(quest.category),
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
                      style: const TextStyle(
                        color: Colors.blue,
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
                _getCategoryColor(quest.category),
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
                    final updatedQuest = quest.copyWith(
                      progress: newProgress,
                      status: newProgress >= quest.target
                          ? QuestStatus.completed
                          : QuestStatus.inProgress,
                    );
                    
                    // Update the quest in the provider
                    // Note: In a real implementation, we would call a method on questProvider
                    // to update the quest. For now, we'll just reload the quests.
                    questProvider.loadQuests();
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
                  // Note: In a real implementation, we would call a method on questProvider
                  // to update the quest. For now, we'll just reload the quests.
                  questProvider.loadQuests();
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
  }

  IconData _getCategoryIcon(QuestCategory category) {
    switch (category) {
      case QuestCategory.mindfulness:
        return Icons.self_improvement;
      case QuestCategory.activity:
        return Icons.directions_run;
      case QuestCategory.social:
        return Icons.people;
      case QuestCategory.learning:
        return Icons.school;
      case QuestCategory.challenge:
        return Icons.emoji_events;
    }
  }

  Color _getCategoryColor(QuestCategory category) {
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
