import 'package:flutter/material.dart';

/// App-wide bottom navigation used across Talk, Mood, Quest screens
/// Ensures consistent look and navigation behavior.
enum AppTab { talk, mood, quest, community }

class AppBottomNav extends StatelessWidget {
  final AppTab current;
  final ValueChanged<AppTab>? onTap; // if provided, used by HomeShell

  const AppBottomNav({super.key, required this.current, this.onTap});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final double vPad = bottomInset > 0 ? 6.0 : 10.0; // sit lower when inset exists

    return Material(
      color: Colors.white,
      elevation: 0, // ensure no shadow
      surfaceTintColor: Colors.transparent, // avoid M3 overlay tint
      child: Padding(
        // shave a few pixels so it visually sits lower without overlapping gestures
        padding: EdgeInsets.only(bottom: (bottomInset - 4).clamp(0.0, 100.0)),
        child: SafeArea(
          top: false,
          bottom: false,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: vPad), // adaptive touch target
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildItem(context, Icons.chat_bubble_outline, 'Talk', AppTab.talk),
                _buildItem(context, Icons.mood, 'Mood', AppTab.mood),
                _buildItem(context, Icons.emoji_events_outlined, 'Quest', AppTab.quest),
                _buildItem(context, Icons.people_outline, 'Community', AppTab.community),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItem(BuildContext context, IconData icon, String label, AppTab tab) {
    final bool isActive = current == tab;
    return InkWell(
      onTap: () {
        if (tab == current && onTap == null) return;
        if (onTap != null) {
          onTap!(tab);
          return;
        }
        // Fallback: navigate to shell which manages tabs via IndexedStack
        Navigator.pushReplacementNamed(context, '/home', arguments: tab);
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 28.0,
              color: isActive ? Colors.blue : Colors.grey, // keep current grey→blue
            ),
            const SizedBox(height: 4.0),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.0, // improve readability, still compact
                color: isActive ? Colors.blue : Colors.grey, // keep current grey→blue
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
