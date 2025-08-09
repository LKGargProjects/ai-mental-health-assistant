import 'package:flutter/material.dart';
import '../screens/mood_tracker_screen.dart';

/// App-wide bottom navigation used across Talk, Mood, Quest screens
/// Ensures consistent look and navigation behavior.
enum AppTab { talk, mood, quest, community }

class AppBottomNav extends StatelessWidget {
  final AppTab current;

  const AppBottomNav({super.key, required this.current});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildItem(context, Icons.chat_bubble_outline, 'Talk', AppTab.talk),
          _buildItem(context, Icons.mood, 'Mood', AppTab.mood),
          _buildItem(context, Icons.emoji_events_outlined, 'Quest', AppTab.quest),
          _buildItem(context, Icons.people_outline, 'Community', AppTab.community),
        ],
      ),
    );
  }

  Widget _buildItem(BuildContext context, IconData icon, String label, AppTab tab) {
    final bool isActive = current == tab;
    return GestureDetector(
      onTap: () {
        if (tab == current) return;
        switch (tab) {
          case AppTab.talk:
            Navigator.pushNamed(context, '/interactive-chat');
            break;
          case AppTab.mood:
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MoodTrackerScreen()),
            );
            break;
          case AppTab.quest:
            Navigator.pushNamed(context, '/wellness-dashboard');
            break;
          case AppTab.community:
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Community coming soon!')),
            );
            break;
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 28.0,
            color: isActive ? Colors.blue : Colors.grey,
          ),
          const SizedBox(height: 4.0),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.0,
              color: isActive ? Colors.blue : Colors.grey,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
