import 'package:flutter/material.dart';
import 'package:ai_buddy_web/models/quest.dart';

class QuestCard extends StatelessWidget {
  final String title;
  final String description;
  final double progress;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final bool showProgress;
  final bool isLocked;
  final int? xpReward;

  const QuestCard({
    super.key,
    required this.title,
    required this.description,
    this.progress = 0.0,
    required this.icon,
    required this.color,
    this.onTap,
    this.showProgress = true,
    this.isLocked = false,
    this.xpReward,
  });

  factory QuestCard.fromQuest(Quest quest, {VoidCallback? onTap}) {
    return QuestCard(
      title: quest.title,
      description: quest.description,
      progress: quest.target > 0 ? quest.progress / quest.target : 0.0,
      icon: quest.icon,
      color: _getCategoryColor(quest.category),
      onTap: onTap,
      showProgress: quest.status == QuestStatus.inProgress,
      isLocked: quest.status == QuestStatus.locked,
      xpReward: quest.xpReward,
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

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: isLocked ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Opacity(
          opacity: isLocked ? 0.6 : 1.0,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isLocked ? Icons.lock_outline : icon,
                        color: color,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isLocked ? '???' : title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (xpReward != null) ...[
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Text(
                                  '$xpReward XP',
                                  style: TextStyle(
                                    color: Theme.of(context).primaryColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            isLocked
                                ? 'Complete previous quests to unlock'
                                : description,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (showProgress && progress > 0) ...[
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 3,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (showProgress && progress > 0) ...[
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).primaryColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
