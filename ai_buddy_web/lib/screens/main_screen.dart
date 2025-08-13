import 'package:ai_buddy_web/screens/chat_screen.dart';
import 'package:ai_buddy_web/screens/mood_tracker_screen.dart';
import 'package:ai_buddy_web/dhiwise/presentation/wellness_dashboard_screen/wellness_dashboard_screen.dart';
import '../dhiwise/core/utils/size_utils.dart' as DhiwiseSizer;
import 'package:flutter/material.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  static final List<Widget> _widgetOptions = <Widget>[
    const ChatScreen(),
    const MoodTrackerScreen(),
    DhiwiseSizer.Sizer(
      builder: (context, orientation, deviceType) => WellnessDashboardScreen(),
    ),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Mental Health Buddy'),
        actions: [
          // Quick access to Wellness Dashboard (optional)
          IconButton(
            icon: const Icon(Icons.emoji_events_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DhiwiseSizer.Sizer(
                    builder: (context, orientation, deviceType) => WellnessDashboardScreen(),
                  ),
                ),
              );
            },
            tooltip: 'Wellness Dashboard',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'quests_list') {
                Navigator.pushNamed(context, '/quests-list');
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem<String>(
                value: 'quests_list',
                child: Text('Open Quests List (backup)'),
              ),
            ],
          ),
        ],
      ),
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.sentiment_satisfied),
            label: 'Mood',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.emoji_events),
            label: 'Quest',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.amber[800],
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
      ),
    );
  }
}
