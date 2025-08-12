import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// App-wide bottom navigation used across Talk, Mood, Quest screens
/// Ensures consistent look and navigation behavior.
enum AppTab { talk, mood, quest, community }

class AppBottomNav extends StatelessWidget {
  final AppTab current;
  final ValueChanged<AppTab>? onTap; // if provided, used by HomeShell
  final ValueChanged<AppTab>? onReselect; // called when tapping the active tab

  const AppBottomNav({super.key, required this.current, this.onTap, this.onReselect});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final double vPad = bottomInset > 0 ? 6.0 : 10.0; // sit lower when inset exists
    const bool kActiveLabelOnlyDemo = true; // demo: show label only for active tab

    return Material(
      color: Colors.white,
      elevation: 0, // ensure no shadow
      surfaceTintColor: Colors.transparent, // avoid M3 overlay tint
      child: Padding(
        // shave a few pixels so it visually sits lower without overlapping gestures
        padding: EdgeInsets.only(bottom: (bottomInset - 8).clamp(0.0, 100.0)),
        child: SafeArea(
          top: false,
          bottom: false,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: vPad), // adaptive touch target
            child: FocusTraversalGroup(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildItem(context, Icons.chat_bubble_outline, 'Talk', AppTab.talk, activeLabelOnly: kActiveLabelOnlyDemo),
                  _buildItem(context, Icons.mood, 'Mood', AppTab.mood, activeLabelOnly: kActiveLabelOnlyDemo),
                  _buildItem(context, Icons.emoji_events_outlined, 'Quest', AppTab.quest, activeLabelOnly: kActiveLabelOnlyDemo),
                  _buildItem(context, Icons.people_outline, 'Community', AppTab.community, activeLabelOnly: kActiveLabelOnlyDemo),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItem(BuildContext context, IconData icon, String label, AppTab tab, {required bool activeLabelOnly}) {
    final bool isActive = current == tab;
    return InkWell(
      onTap: () {
        // Haptic feedback on supported platforms
        if (!kIsWeb) {
          try { HapticFeedback.selectionClick(); } catch (_) {}
        }
        if (tab == current) {
          if (onReselect != null) {
            onReselect!(tab);
          } else {
            // Demo fallback: brief message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Re-tap: ' + label), duration: const Duration(milliseconds: 600)),
            );
          }
          return;
        }
        if (onTap != null) {
          onTap!(tab);
          return;
        }
        // Fallback: navigate to shell which manages tabs via IndexedStack
        Navigator.pushReplacementNamed(context, '/home', arguments: tab);
      },
      borderRadius: BorderRadius.circular(12),
      focusColor: Colors.blue.withOpacity(0.10),
      hoverColor: Colors.blue.withOpacity(0.06),
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
            AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: (!activeLabelOnly || isActive) ? 1.0 : 0.0,
              child: SizedBox(
                height: 16,
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12.0,
                      color: isActive ? Colors.blue : Colors.grey,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
