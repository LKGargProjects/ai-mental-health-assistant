
import 'package:flutter/material.dart';
import '../widgets/mood_tracker.dart';
import '../core/utils/size_utils.dart';
import '../core/utils/image_constant.dart';
import '../theme/theme_helper.dart';
import '../theme/text_style_helper.dart';
import '../widgets/dhiwise/custom_image_view.dart';
import '../widgets/app_bottom_nav.dart';

class MoodTrackerScreen extends StatelessWidget {
  final bool showBottomNav;
  const MoodTrackerScreen({super.key, this.showBottomNav = true});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Image (same as chat)
          CustomImageView(
            imagePath: ImageConstant.imgBackground1440x635,
            height: MediaQuery.of(context).size.height,
            width: MediaQuery.of(context).size.width,
            fit: BoxFit.cover,
          ),
          // Main Content
          Column(
            children: [
              // Header
              Container(
                color: appTheme.whiteCustom,
                padding: EdgeInsets.symmetric(horizontal: 16.h, vertical: 16.h),
                child: SafeArea(
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).pop();
                        },
                        child: Container(
                          padding: EdgeInsets.all(8.h),
                          child: CustomImageView(
                            imagePath: ImageConstant.imgImage,
                            height: 24.h,
                            width: 16.h,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Mood Tracker',
                          textAlign: TextAlign.center,
                          style: TextStyleHelper.instance.headline24Bold,
                        ),
                      ),
                      SizedBox(width: 48.h), // Balance the back button
                    ],
                  ),
                ),
              ),
              // Divider
              Container(
                height: 8.h,
                color: appTheme.colorFFF3F4,
              ),
              // Mood Tracker Content
              Expanded(
                child: Container(
                  color: Colors.transparent,
                  child: const MoodTrackerWidget(), // Fixed - now without duplicate header
                ),
              ),
            ],
          ),
        ],
      ),
      // Bottom Navigation (shared)
      bottomNavigationBar: showBottomNav ? const AppBottomNav(current: AppTab.mood) : null,
    );
  }
}
