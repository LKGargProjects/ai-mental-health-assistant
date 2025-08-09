import 'package:flutter/material.dart';
import 'package:lokesh_s_application2/core/app_export.dart';
import 'package:lokesh_s_application2/widgets/custom_image_view.dart';
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
            CustomImageView(
              imagePath: ImageConstant.imgBackground1440x6351,
              height: SizeUtils.height,
              width: SizeUtils.width,
              fit: BoxFit.cover,
            ),
            
            // Main Content
            SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.h, vertical: 24.v),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    _buildHeaderSection(),
                    SizedBox(height: 24.v),
                    
                    // Active Quests Section
                    _buildSectionTitle('Active Quests'),
                    SizedBox(height: 16.v),
                    _buildActiveQuests(),
                    
                    // Available Quests Section
                    SizedBox(height: 24.v),
                    _buildSectionTitle('Available Quests'),
                    SizedBox(height: 16.v),
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
        Text(
          'Quests',
          style: TextStyleHelper.instance.headline37BoldInter.copyWith(
            color: ColorConstant.gray900,
          ),
        ),
        Container(
          width: 48.h,
          height: 48.h,
          decoration: BoxDecoration(
            color: ColorConstant.whiteA700,
            borderRadius: BorderRadius.circular(24.h),
            boxShadow: [
              BoxShadow(
                color: ColorConstant.black900.withOpacity(0.05),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            Icons.notifications_none_outlined,
            color: ColorConstant.gray900,
            size: 24.h,
          ),
        ),
      ],
    );
  }

  // Section Title
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyleHelper.instance.titleMediumInter.copyWith(
        color: ColorConstant.gray900,
        fontWeight: FontWeight.w600,
      ),
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
        'color': ColorConstant.blue500,
      },
      {
        'title': 'Mindfulness',
        'progress': 0.4,
        'tasks': '2/5 tasks completed',
        'icon': Icons.self_improvement_outlined,
        'color': ColorConstant.green500,
      },
    ];

    return ListView.separated(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: activeQuests.length,
      separatorBuilder: (context, index) => SizedBox(height: 16.v),
      itemBuilder: (context, index) {
        final quest = activeQuests[index];
        return _buildQuestCard(
          title: quest['title'],
          progress: quest['progress'],
          subtitle: quest['tasks'],
          icon: quest['icon'],
          color: quest['color'],
          isActive: true,
        );
      },
    );
  }

  // Available Quests List
  Widget _buildAvailableQuests() {
    // Sample available quests data
    final List<Map<String, dynamic>> availableQuests = [
      {
        'title': 'Fitness Challenge',
        'subtitle': 'Complete 5 workouts this week',
        'icon': Icons.fitness_center_outlined,
        'color': ColorConstant.red500,
      },
      {
        'title': 'Nutrition Tracker',
        'subtitle': 'Log meals for 7 days',
        'icon': Icons.restaurant_outlined,
        'color': ColorConstant.orange500,
      },
      {
        'title': 'Sleep Well',
        'subtitle': 'Maintain a consistent sleep schedule',
        'icon': Icons.nightlight_outlined,
        'color': ColorConstant.purple500,
      },
    ];

    return ListView.separated(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: availableQuests.length,
      separatorBuilder: (context, index) => SizedBox(height: 16.v),
      itemBuilder: (context, index) {
        final quest = availableQuests[index];
        return _buildQuestCard(
          title: quest['title'],
          subtitle: quest['subtitle'],
          icon: quest['icon'],
          color: quest['color'],
          isActive: false,
        );
      },
    );
  }

  // Quest Card Wrapper
  Widget _buildQuestCard({
    required String title,
    required IconData icon,
    required Color color,
    required bool isActive,
    double? progress,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return QuestCardWidget(
      title: title,
      subtitle: subtitle,
      icon: icon,
      color: color,
      isActive: isActive,
      progress: progress,
      onTap: onTap ?? () {},
    );
  }
}
