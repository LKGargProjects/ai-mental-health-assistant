import 'package:flutter/material.dart';
import 'package:ai_buddy_web/screens/chat_screen.dart';
import 'package:ai_buddy_web/widgets/mood_tracker.dart';
import 'package:ai_buddy_web/widgets/self_assessment_screen.dart';
import 'package:ai_buddy_web/widgets/task_list_screen.dart';
import 'package:ai_buddy_web/widgets/community_feed_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    ChatScreen(),
    MoodTrackerWidget(),
    SelfAssessmentScreen(),
    TaskListScreen(),
    CommunityFeedScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.mood), label: 'Mood'),
          BottomNavigationBarItem(icon: Icon(Icons.psychology), label: 'Assess'),
          BottomNavigationBarItem(icon: Icon(Icons.task_alt), label: 'Tasks'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Community'),
        ],
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Color(0xFFE94057),
        unselectedItemColor: Colors.grey,
      ),
    );
  }
}
