import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ai_buddy_web/providers/quest_provider.dart';
import 'package:ai_buddy_web/widgets/quest_card.dart';

class NewQuestScreen extends StatelessWidget {
  const NewQuestScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quests'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Active Quests'),
              const SizedBox(height: 16),
              _buildActiveQuests(),
              const SizedBox(height: 32),
              _buildSectionTitle('Available Quests'),
              const SizedBox(height: 16),
              _buildAvailableQuests(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildActiveQuests() {
    return Consumer<QuestProvider>(
      builder: (context, questProvider, _) {
        final activeQuests = questProvider.activeQuests;
        if (activeQuests.isEmpty) {
          return const Center(
            child: Text('No active quests. Start a new one!'),
          );
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: activeQuests.length,
          itemBuilder: (context, index) {
            final quest = activeQuests[index];
            return QuestCard(
              title: quest.title,
              description: quest.description,
              progress: quest.progress,
              icon: _getQuestIcon(quest.type),
              color: _getQuestColor(quest.type),
              onTap: () {
                // Handle quest tap
              },
            );
          },
        );
      },
    );
  }

  Widget _buildAvailableQuests() {
    final availableQuests = [
      {
        'title': 'Mindful Morning',
        'description': 'Start your day with 5 minutes of meditation',
        'type': 'mindfulness',
      },
      {
        'title': 'Gratitude Journal',
        'description': 'Write down 3 things you\'re grateful for today',
        'type': 'journal',
      },
      {
        'title': 'Breath Work',
        'description': 'Practice deep breathing for 2 minutes',
        'type': 'breathing',
      },
    ];

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: availableQuests.length,
      itemBuilder: (context, index) {
        final quest = availableQuests[index];
        return QuestCard(
          title: quest['title'] as String,
          description: quest['description'] as String,
          progress: 0.0,
          icon: _getQuestIcon(quest['type'] as String),
          color: _getQuestColor(quest['type'] as String),
          onTap: () {
            // Handle quest tap
          },
        );
      },
    );
  }

  IconData _getQuestIcon(String type) {
    switch (type) {
      case 'mindfulness':
        return Icons.self_improvement;
      case 'journal':
        return Icons.edit_note;
      case 'breathing':
        return Icons.air;
      default:
        return Icons.flag;
    }
  }

  Color _getQuestColor(String type) {
    switch (type) {
      case 'mindfulness':
        return Colors.blue;
      case 'journal':
        return Colors.purple;
      case 'breathing':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }
}
