import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/quest_provider.dart';
import '../models/quest.dart';
import '../widgets/app_back_button.dart';

class QuestScreen extends StatefulWidget {
  const QuestScreen({Key? key}) : super(key: key);

  @override
  _QuestScreenState createState() => _QuestScreenState();
}

class _QuestScreenState extends State<QuestScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('Quests', style: TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
          automaticallyImplyLeading: false,
          leading: Builder(
            builder: (ctx) {
              final canPop = Navigator.of(ctx).canPop();
              final route = ModalRoute.of(ctx);
              final isModal = route is PageRoute && route.fullscreenDialog == true;
              if (canPop) {
                return AppBackButton(isModal: isModal);
              }
              return const SizedBox.shrink();
            },
          ),
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey[600],
            indicator: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Theme.of(context).primaryColor,
            ),
            tabs: const [
              Tab(text: 'All'),
              Tab(text: 'Active'),
              Tab(text: 'Completed'),
              Tab(text: 'Categories'),
            ],
          ),
        ),
        body: Consumer<QuestProvider>(
          builder: (context, questProvider, _) {
            return TabBarView(
              controller: _tabController,
              children: [
                // All Quests Tab
                _buildQuestList(questProvider.quests, 'No quests available'),
                
                // Active Quests Tab
                _buildQuestList(
                  questProvider.inProgressQuests,
                  'No active quests. Start a new quest!',
                ),
                
                // Completed Quests Tab
                _buildQuestList(
                  questProvider.completedQuests,
                  'No completed quests yet. Keep going!',
                  showProgress: false,
                ),
                
                // Categories Tab
                _buildCategoriesTab(questProvider),
              ],
            );
          },
        ),
      ),
    );
  }
  
  Widget _buildQuestList(List<Quest> quests, String emptyMessage, {bool showProgress = true}) {
    if (quests.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            emptyMessage,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: quests.length,
      itemBuilder: (context, index) {
        final quest = quests[index];
        return _buildQuestCard(quest, showProgress: showProgress);
      },
    );
  }
  
  Widget _buildQuestCard(Quest quest, {bool showProgress = true}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: quest.status == QuestStatus.completed 
              ? Colors.green.withOpacity(0.5) 
              : Colors.grey.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showQuestDetails(quest),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Quest Header
              Row(
                children: [
                  // Icon with category color
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: quest.categoryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      quest.icon,
                      color: quest.categoryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Title and XP
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
                        const SizedBox(height: 2),
                        Text(
                          quest.categoryName,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // XP Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber[200]!),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star, color: Colors.amber[700], size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '${quest.xpReward} XP',
                          style: TextStyle(
                            color: Colors.amber[900],
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Description
              Text(
                quest.description,
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 14,
                ),
              ),
              
              // Progress bar
              if (showProgress && quest.status != QuestStatus.completed) ...[
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: quest.progress / quest.target,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    quest.status == QuestStatus.completed 
                        ? Colors.green 
                        : Theme.of(context).primaryColor,
                  ),
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${quest.progress} / ${quest.target} ${quest.target > 1 ? 'times' : 'time'}' +
                          (quest.target > 1 ? ' (${(quest.progress / quest.target * 100).toStringAsFixed(0)}%)' : ''),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    if (quest.status == QuestStatus.unlocked)
                      TextButton(
                        onPressed: () => _startQuest(quest),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Start', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
              ]
              
              // Completed indicator
              else if (quest.status == QuestStatus.completed) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Completed on ${quest.completedAt?.toString().split(' ')[0] ?? ''}',
                      style: const TextStyle(
                        color: Colors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildCategoriesTab(QuestProvider questProvider) {
    final categories = QuestCategory.values;
    
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.5,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        final questsInCategory = questProvider.getQuestsByCategory(category);
        final completedQuests = questsInCategory.where((q) => q.isCompleted).length;
        final progress = questsInCategory.isEmpty ? 0.0 : completedQuests / questsInCategory.length;
        
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _showCategoryQuests(questProvider, category),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Category icon
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _getCategoryColor(category).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Quest.getIconForCategory(category),
                      color: _getCategoryColor(category),
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Category name
                  Text(
                    _getCategoryName(category),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Progress text
                  Text(
                    '$completedQuests/${questsInCategory.length} quests',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Progress bar
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _getCategoryColor(category),
                    ),
                    minHeight: 4,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
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
  
  String _getCategoryName(QuestCategory category) {
    switch (category) {
      case QuestCategory.mindfulness:
        return 'Mindfulness';
      case QuestCategory.activity:
        return 'Activity';
      case QuestCategory.social:
        return 'Social';
      case QuestCategory.learning:
        return 'Learning';
      case QuestCategory.challenge:
        return 'Challenge';
    }
  }
  
  void _showQuestDetails(Quest quest) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildQuestDetails(quest),
    );
  }
  
  Widget _buildQuestDetails(Quest quest) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with icon and title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: quest.categoryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  quest.icon,
                  color: quest.categoryColor,
                  size: 32,
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
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: quest.categoryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        quest.categoryName,
                        style: TextStyle(
                          color: quest.categoryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // XP Reward
          Row(
            children: [
              const Icon(Icons.star, color: Colors.amber, size: 20),
              const SizedBox(width: 8),
              Text(
                '${quest.xpReward} XP',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber.shade800,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Description
          const Text(
            'Description',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            quest.description,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Progress
          const Text(
            'Progress',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: quest.progress / quest.target,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(
              quest.status == QuestStatus.completed 
                  ? Colors.green 
                  : Theme.of(context).primaryColor,
            ),
            minHeight: 10,
            borderRadius: BorderRadius.circular(5),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${quest.progress} / ${quest.target} ${quest.target > 1 ? 'times' : 'time'}' +
                    (quest.target > 1 ? ' (${(quest.progress / quest.target * 100).toStringAsFixed(0)}%)' : ''),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (quest.status == QuestStatus.completed)
                Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Completed',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          
          const SizedBox(height: 32),
          
          // Action button
          if (quest.status == QuestStatus.unlocked)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Close the modal
                  _startQuest(quest);
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Start Quest',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            )
          else if (quest.status == QuestStatus.inProgress)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _updateQuestProgress(quest),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Update Progress',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            )
          else if (quest.status == QuestStatus.completed)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  // Option to restart the quest
                  _restartQuest(quest);
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(color: Theme.of(context).primaryColor),
                ),
                child: Text(
                  'Restart Quest',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
            ),
          
          const SizedBox(height: 16),
        ],
      ),
    );
  }
  
  void _startQuest(Quest quest) {
    // Mark as in progress with 0 progress
    context.read<QuestProvider>().updateQuestProgress(quest.id, 0);
    
    // Show a snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Started quest: ${quest.title}'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
  
  void _updateQuestProgress(Quest quest) {
    final newProgress = (quest.progress + 1).clamp(0, quest.target);
    context.read<QuestProvider>().updateQuestProgress(quest.id, newProgress);
    
    // Show a snackbar
    if (newProgress >= quest.target) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎉 Quest completed: ${quest.title}! +${quest.xpReward} XP'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Progress updated: $newProgress/${quest.target}'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }
  
  void _restartQuest(Quest quest) {
    // Reset progress to 0 and mark as in progress
    context.read<QuestProvider>().updateQuestProgress(quest.id, 0);
    
    // Show a snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Restarted quest: ${quest.title}'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
    
    // Close the bottom sheet
    Navigator.pop(context);
  }
  
  void _showCategoryQuests(QuestProvider questProvider, QuestCategory category) {
    final quests = questProvider.getQuestsByCategory(category);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getCategoryIcon(category),
                  color: _getCategoryColor(category),
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  _getCategoryName(category) + ' Quests',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: quests.isEmpty
                  ? Center(
                      child: Text(
                        'No quests in this category yet.',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: quests.length,
                      itemBuilder: (context, index) {
                        final quest = quests[index];
                        return ListTile(
                          leading: Icon(
                            quest.icon,
                            color: _getCategoryColor(category),
                          ),
                          title: Text(quest.title),
                          subtitle: Text(
                            '${quest.progress}/${quest.target} (${(quest.progress / quest.target * 100).toStringAsFixed(0)}%)',
                          ),
                          trailing: quest.isCompleted
                              ? const Icon(Icons.check_circle, color: Colors.green)
                              : null,
                          onTap: () {
                            Navigator.pop(context); // Close the category sheet
                            _showQuestDetails(quest);
                          },
                        );
                      },
                    ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
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
}
