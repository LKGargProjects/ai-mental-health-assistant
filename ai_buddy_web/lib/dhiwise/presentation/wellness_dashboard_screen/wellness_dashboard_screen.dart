import 'package:flutter/material.dart';

import '../../core/app_export.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_image_view.dart';
import './widgets/progress_card_widget.dart';
import './widgets/recommendation_card_widget.dart';
import '../../../widgets/app_bottom_nav.dart';

class WellnessDashboardScreen extends StatelessWidget {
  WellnessDashboardScreen({Key? key}) : super(key: key);

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
            Text('HiAlex!',
                style: TextStyleHelper.instance.display37BoldInter
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
          Text('How are you feeling today?',
              textAlign: TextAlign.center,
              style: TextStyleHelper.instance.headline28Inter
                  .copyWith(color: Color(0xFF555F6D))),
          SizedBox(height: 32.h),
          CustomButton(
              text: 'Check In',
              backgroundColor: Colors.white,
              textColor: Color(0xFF5A616F),
              borderColor: Color(0xFFF1F5F7),
              showBorder: true,
              padding: EdgeInsets.symmetric(horizontal: 48.h, vertical: 24.h),
              borderRadius: 37.h,
              textStyle: TextStyleHelper.instance.headline25BoldInter,
              onPressed: () {
                // Handle check in click
              }),
        ]));
  }

  Widget _buildProgressSection() {
    return Padding(
        padding: EdgeInsets.symmetric(horizontal: 70.h).copyWith(bottom: 32.h),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Your Progress',
              style: TextStyleHelper.instance.display31BoldInter
                  .copyWith(color: Color(0xFF444D5C))),
          SizedBox(height: 28.h),
          Row(children: [
            Expanded(
                child: ProgressCardWidget(
                    imagePath: ImageConstant.imgImage65x52,
                    value: '3 days',
                    label: 'Streak',
                    backgroundColor: Color(0xFFE0F2E9))),
            SizedBox(width: 24.h),
            Expanded(
                child: ProgressCardWidget(
                    imagePath: ImageConstant.imgImage63x65,
                    value: '150',
                    label: 'XP Earned',
                    backgroundColor: Color(0xFFE8E7F8))),
          ]),
        ]));
  }

  Widget _buildRecommendationsSection() {
    return Padding(
        padding: EdgeInsets.symmetric(horizontal: 69.h).copyWith(bottom: 32.h),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Today\'s Recommendations',
              style: TextStyleHelper.instance.display32BoldInter
                  .copyWith(color: Color(0xFF4A5261))),
          SizedBox(height: 28.h),
          RecommendationCardWidget(
              category: 'MINDFULNESS',
              title: 'Guided Meditation',
              subtitle: '5 min',
              imagePath: ImageConstant.imgImage131x130,
              onTap: () {
                // Handle mindfulness recommendation click
              }),
          SizedBox(height: 24.h),
          RecommendationCardWidget(
              category: 'SOCIAL',
              title: 'Connect with Peers',
              subtitle: 'Join a group chat',
              imagePath: ImageConstant.imgImage130x130,
              onTap: () {
                // Handle social recommendation click
              }),
        ]));
  }
}
