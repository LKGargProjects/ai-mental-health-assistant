import 'package:flutter/material.dart';
import '../widgets/app_back_button.dart';

class DirectQuestPreview extends StatelessWidget {
  const DirectQuestPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quest Screen Preview',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF667EEA),
          primary: const Color(0xFF667EEA),
          secondary: const Color(0xFFFF6B6B),
        ),
        useMaterial3: true,
      ),
      home: const QuestPreviewScreen(),
    );
  }
}

class QuestPreviewScreen extends StatelessWidget {
  const QuestPreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quest Screen Preview'),
        backgroundColor: const Color(0xFF667EEA),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        leading: Builder(
          builder: (ctx) {
            final canPop = Navigator.of(ctx).canPop();
            final route = ModalRoute.of(ctx);
            final isModal = route is PageRoute && route.fullscreenDialog == true;
            if (canPop) {
              return AppBackButton(isModal: isModal, iconColor: Colors.white);
            }
            return const SizedBox.shrink();
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildQuestCard(
              title: 'Daily Check-in',
              description: 'Complete your daily mood check-in',
              progress: 0.3,
              icon: Icons.check_circle,
              color: Colors.blue,
            ),
            const SizedBox(height: 16),
            _buildQuestCard(
              title: 'Meditation Challenge',
              description: 'Meditate for 5 minutes',
              progress: 0.7,
              icon: Icons.self_improvement,
              color: Colors.green,
            ),
            const SizedBox(height: 16),
            _buildQuestCard(
              title: 'Gratitude Journal',
              description: 'Write 3 things you\'re grateful for',
              progress: 0.0,
              icon: Icons.book,
              color: Colors.orange,
            ),
            const SizedBox(height: 16),
            _buildQuestCard(
              title: 'Breathing Exercise',
              description: 'Complete a 2-minute breathing exercise',
              progress: 0.0,
              icon: Icons.air,
              color: Colors.purple,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestCard({
    required String title,
    required String description,
    required double progress,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
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
                    color: color.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(progress > 0 ? 'Continue' : 'Start'),
                ),
              ],
            ),
            if (progress > 0) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 4),
              Text(
                '${(progress * 100).toInt()}% complete',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
