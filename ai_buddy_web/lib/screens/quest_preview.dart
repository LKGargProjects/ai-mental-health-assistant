import 'package:flutter/material.dart';

void main() {
  runApp(const QuestPreviewApp());
}

class QuestPreviewApp extends StatelessWidget {
  const QuestPreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Quest Screen Preview',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF667EEA),
          primary: const Color(0xFF667EEA),
          secondary: const Color(0xFFFF6B6B),
        ),
        useMaterial3: true,
      ),
      home: const QuestScreen(),
    );
  }
}

class QuestScreen extends StatelessWidget {
  const QuestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quests'),
        backgroundColor: const Color(0xFF667EEA),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildQuestCard(
              context,
              title: 'Daily Check-in',
              description: 'Complete your daily mood check-in',
              progress: 0.3,
              icon: Icons.check_circle,
              color: const Color(0xFF2563EB),
            ),
            const SizedBox(height: 16),
            _buildQuestCard(
              context,
              title: 'Meditation Challenge',
              description: 'Meditate for 5 minutes',
              progress: 0.7,
              icon: Icons.self_improvement,
              color: const Color(0xFF059669),
            ),
            const SizedBox(height: 16),
            _buildQuestCard(
              context,
              title: 'Gratitude Journal',
              description: 'Write 3 things you\'re grateful for',
              progress: 0.0,
              icon: Icons.book,
              color: const Color(0xFFD97706),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestCard(
    BuildContext context, {
    required String title,
    required String description,
    required double progress,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 2,
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
                    color: Colors.black.withOpacity(0.1),
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
                          fontSize: 16,
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: Text(
                    progress > 0 ? 'Continue' : 'Start',
                    style: const TextStyle(fontSize: 14),
                  ),
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
