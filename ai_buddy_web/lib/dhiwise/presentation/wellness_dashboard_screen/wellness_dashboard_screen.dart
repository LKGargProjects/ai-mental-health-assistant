import 'package:flutter/material.dart';

import '../../core/app_export.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_image_view.dart';
import './widgets/progress_card_widget.dart';
import './widgets/recommendation_card_widget.dart';
import '../../../widgets/app_bottom_nav.dart';
import '../../../theme/text_style_helper.dart' as CoreTextStyles;

class WellnessDashboardScreen extends StatefulWidget {
  WellnessDashboardScreen({Key? key}) : super(key: key);

  @override
  State<WellnessDashboardScreen> createState() => _WellnessDashboardScreenState();
}

class _WellnessDashboardScreenState extends State<WellnessDashboardScreen> {
  // UI-only state for TASK completion and progress
  bool _task1Done = false; // Focus reset
  bool _task2Done = false; // Study sprint
  int _baseSteps = 2; // total tasks today
  int _baseXp = 20; // base example XP shown initially
  bool _reminderOn = false; // UI-only reminder toggle

  @override
  Widget build(BuildContext context) {
    return Sizer(builder: (context, orientation, deviceType) {
      return SafeArea(
          child: Scaffold(
            body: Stack(children: [
              // Background Image (use full viewport like chat/mood)
              CustomImageView(
                  imagePath: ImageConstant.imgBackground1440x6351,
                  height: MediaQuery.of(context).size.height,
                  width: MediaQuery.of(context).size.width,
                  fit: BoxFit.cover),

              // Content (full viewport sizing)
              Container(
                  height: MediaQuery.of(context).size.height,
                  width: MediaQuery.of(context).size.width,
                  child: Stack(children: [
                    // Side Background
                    Positioned(
                        left: 0,
                        top: 0,
                        child: CustomImageView(
                            imagePath: ImageConstant.imgBackground,
                            height: 635.h,
                            width: 3.h,
                            fit: BoxFit.cover)),

                    // Main Content
                    SingleChildScrollView(
                        child: Padding(
                            padding: EdgeInsets.all(
                                0), // Modified: Added required padding parameter
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildHeaderSection(),
                                  _buildMoodCheckInSection(),
                                  _buildProgressSection(),
                                  _buildRecommendationsSection(),
                                ]))),

                    // Bottom Background
                    Positioned(
                        bottom: 0,
                        left: 0,
                        child: CustomImageView(
                            imagePath: ImageConstant.imgBackground13x635,
                            height: 13.h,
                            width: MediaQuery.of(context).size.width,
                            fit: BoxFit.cover)),
                  ])),
            ]),
            bottomNavigationBar: const AppBottomNav(current: AppTab.quest)));
    });
  }

  Widget _buildHeaderSection() {
    return Padding(
        padding: EdgeInsets.symmetric(horizontal: 28.h, vertical: 32.h),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Row(children: [
        // Header renamed per PDF priorities
        Text('Today\'s Quest',
            style: CoreTextStyles.TextStyleHelper.instance.headline24Bold
                .copyWith(color: Color(0xFF47505E))),
        SizedBox(width: 12.h),
        CustomImageView(
            imagePath: ImageConstant.imgImage43x43,
            height: 43.h,
            width: 43.h),
          ]),
          GestureDetector(
              onTap: () {
                // Handle settings click
              },
              child: Container(
                  height: 38.h,
                  width: 38.h,
                  child: CustomImageView(
                      imagePath: ImageConstant.imgImage38x38,
                      height: 38.h,
                      width: 38.h,
                      fit: BoxFit.cover))),
        ]));
  }

  Widget _buildMoodCheckInSection() {
    return Container(
        margin: EdgeInsets.symmetric(horizontal: 70.h)
            .copyWith(top: 64.h, bottom: 32.h),
        decoration: BoxDecoration(
            color: Color(0xFFE3ECEF),
            borderRadius: BorderRadius.circular(28.h)),
        padding: EdgeInsets.symmetric(horizontal: 32.h, vertical: 44.h),
        child: Column(children: [
          // Large prompt card title
          Text('Quick check-in',
              textAlign: TextAlign.center,
              style: TextStyleHelper.instance.headline28Inter.copyWith(
                  fontFamily: CoreTextStyles
                      .TextStyleHelper.instance.headline24Bold.fontFamily,
                  color: Color(0xFF555F6D))),
          SizedBox(height: 8.h),
          // Prompt subtitle
          Text('Takes 2 minutes',
              textAlign: TextAlign.center,
              style: TextStyleHelper.instance.headline21Inter.copyWith(
                  fontFamily: CoreTextStyles
                      .TextStyleHelper.instance.headline24Bold.fontFamily,
                  color: Color(0xFF8C9CAA))),
          SizedBox(height: 32.h),
          CustomButton(
              text: 'Start',
              backgroundColor: Colors.white,
              textColor: Color(0xFF5A616F),
              borderColor: Color(0xFFF1F5F7),
              showBorder: true,
              padding: EdgeInsets.symmetric(horizontal: 48.h, vertical: 24.h),
              borderRadius: 37.h,
              textStyle: TextStyleHelper.instance.headline25BoldInter.copyWith(
                  fontFamily: CoreTextStyles
                      .TextStyleHelper.instance.headline24Bold.fontFamily),
              onPressed: () {
                // Handle check in click
              }),
        ]));
  }

  Widget _buildProgressSection() {
    // Compute dynamic values from UI state (UI-only)
    final int completed = (_task1Done ? 1 : 0) + (_task2Done ? 1 : 0);
    final int stepsLeft = (_baseSteps - completed).clamp(0, _baseSteps);
    final int xpEarned = _baseXp + (completed * 10);
    return Padding(
        padding: EdgeInsets.symmetric(horizontal: 70.h).copyWith(bottom: 32.h),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Your Progress',
              style: TextStyleHelper.instance.display31BoldInter.copyWith(
                  fontFamily: CoreTextStyles
                      .TextStyleHelper.instance.headline24Bold.fontFamily,
                  color: Color(0xFF444D5C))),
          SizedBox(height: 28.h),
          Row(children: [
            Expanded(
                child: ProgressCardWidget(
                    imagePath: ImageConstant.imgImage65x52,
                    value: '$stepsLeft',
                    label: 'Steps Left',
                    backgroundColor: Color(0xFFE0F2E9))),
            SizedBox(width: 24.h),
            Expanded(
                child: ProgressCardWidget(
                    imagePath: ImageConstant.imgImage63x65,
                    value: '+$xpEarned',
                    label: 'XP Earned',
                    backgroundColor: Color(0xFFE8E7F8))),
          ]),
          SizedBox(height: 12.h),
          Text('Estimated time: 2–3 min',
              style: TextStyleHelper.instance.headline21Inter.copyWith(
                  fontFamily: CoreTextStyles
                      .TextStyleHelper.instance.headline24Bold.fontFamily,
                  color: Color(0xFF8C9CAA))),
        ]));
  }

  Widget _buildRecommendationsSection() {
    return Padding(
        padding: EdgeInsets.symmetric(horizontal: 69.h).copyWith(bottom: 32.h),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Today\'s Recommendations',
              style: TextStyleHelper.instance.display32BoldInter.copyWith(
                  fontFamily: CoreTextStyles
                      .TextStyleHelper.instance.headline24Bold.fontFamily,
                  color: Color(0xFF4A5261))),
          SizedBox(height: 28.h),
          // Card 1 (TASK)
          RecommendationCardWidget(
              category: 'TASK',
              title: 'Focus reset (2 min)',
              subtitle: (_task1Done && _task2Done)
                  ? 'All steps complete 🎉'
                  : 'Quick breathing + desk tidy',
              imagePath: ImageConstant.imgImage131x130,
              completed: _task1Done,
              onTap: () {
                setState(() {
                  _task1Done = !_task1Done;
                });
              }),
          SizedBox(height: 24.h),
          // Card 2 (TASK)
          RecommendationCardWidget(
              category: 'TASK',
              title: 'Study sprint (10 min)',
              subtitle: 'Timer + no‑phone rule',
              imagePath: ImageConstant.imgImage130x130,
              completed: _task2Done,
              onTap: () {
                setState(() {
                  _task2Done = !_task2Done;
                });
              }),
          SizedBox(height: 24.h),
          // Card 3 (RESOURCE)
          RecommendationCardWidget(
              category: 'RESOURCE',
              title: 'Calm music',
              subtitle: 'Lo‑fi playlist',
              imagePath: ImageConstant.imgImage131x130,
              onTap: () {
                // Open resource (UI-only for now)
              }),
          SizedBox(height: 24.h),
          // Card 4 (TIP)
          RecommendationCardWidget(
              category: 'TIP',
              title: 'One tiny step',
              subtitle: 'Pick the easiest task first',
              imagePath: ImageConstant.imgImage130x130,
              onTap: () {
                // Show tip (UI-only for now)
              }),
          SizedBox(height: 24.h),
          // Card 5 (REMINDER)
          RecommendationCardWidget(
              category: 'REMINDER',
              title: 'Tonight, 7:00 PM',
              subtitle: _reminderOn
                  ? 'Reminder on for 7:00 PM'
                  : 'Nudge me to finish the quest',
              imagePath: ImageConstant.imgImage131x130,
              onTap: () {
                // Toggle reminder (UI-only)
                setState(() {
                  _reminderOn = !_reminderOn;
                });
              }),
        ]));
  }
}
