import 'package:flutter/material.dart';
import 'widgets/quest_card_widget.dart';

class QuestScreen extends StatelessWidget {
  const QuestScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: Stack(
          children: [
            // Background Image
            Image.asset(
              'assets/images/img_background_1440x635.png',
              height: MediaQuery.of(context).size.height,
              width: MediaQuery.of(context).size.width,
              fit: BoxFit.cover,
            ),
            
            // Main Content
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    _buildHeaderSection(),
                    const SizedBox(height: 24),
                    
                    // Active Quests Section
                    const Text(
                      'Active Quests',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildActiveQuests(),
                    
                    // Available Quests Section
                    const SizedBox(height: 24),
                    const Text(
                      'Available Quests',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildAvailableQuests(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Header Section
  Widget _buildHeaderSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Quests',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.notifications_none_outlined,
            color: Colors.black87,
            size: 24,
          ),
        ),
      ],
    );
  }



  // Active Quests List
  Widget _buildActiveQuests() {
    // Sample active quests data
    final List<Map<String, dynamic>> activeQuests = [
      {
        'title': 'Morning Routine',
        'progress': 0.7,
        'tasks': '3/5 tasks completed',
        'icon': Icons.wb_sunny_outlined,
        'color': Colors.blue,
      },
      {
        'title': 'Mindfulness',
        'progress': 0.4,
        'tasks': '2/5 tasks completed',
        'icon': Icons.self_improvement_outlined,
        'color': Colors.green,
      },
    ];

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: activeQuests.length,
      separatorBuilder: (context, index) => SizedBox(height: 16),
      itemBuilder: (context, index) {
        final quest = activeQuests[index];
        return QuestCardWidget(
          title: quest['title'] as String,
          subtitle: quest['tasks'] as String?,
          icon: quest['icon'] as IconData,
          color: quest['color'] as Color,
          onTap: () {},
        );
  }

  // Available Quests List
  Widget _buildAvailableQuests() {
    final List<Map<String, dynamic>> availableQuests = [
      {
        'title': 'Fitness Challenge',
        'subtitle': 'Complete 5 workouts this week',
        'icon': Icons.fitness_center_outlined,
        'color': Colors.red,
      },
      {
        'title': 'Nutrition Tracker',
        'subtitle': 'Log meals for 7 days',
        'icon': Icons.restaurant_outlined,
        'color': Colors.orange,
      },
      {
        'title': 'Sleep Well',
        'subtitle': 'Maintain a consistent sleep schedule',
        'icon': Icons.nightlight_outlined,
        'color': Colors.purple,
      },
    ];

    return _buildQuestsList(availableQuests);
  }

  Widget _buildQuestsList(List<Map<String, dynamic>> quests) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: quests.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final quest = quests[index];
        return QuestCardWidget(
          title: quest['title'] as String,
          subtitle: quest['subtitle'] as String?,
          icon: quest['icon'] as IconData,
          color: quest['color'] as Color,
          onTap: () {},
        );
      },
    );
  }
}
