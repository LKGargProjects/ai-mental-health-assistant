
import 'package:flutter/material.dart';
import '../widgets/mood_tracker.dart';
import '../core/utils/size_utils.dart';
import '../core/utils/image_constant.dart';
import '../theme/theme_helper.dart';
import '../theme/text_style_helper.dart';
import '../widgets/dhiwise/custom_image_view.dart';

class MoodTrackerScreen extends StatelessWidget {
  const MoodTrackerScreen({super.key});

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
      // Bottom Navigation
      bottomNavigationBar: Container(
        color: appTheme.whiteCustom,
        padding: EdgeInsets.symmetric(vertical: 8.h),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavItem(Icons.chat_bubble_outline, 'Talk', false, context),
            _buildNavItem(Icons.mood, 'Mood', true, context),
            _buildNavItem(Icons.emoji_events_outlined, 'Quest', false, context),
            _buildNavItem(Icons.people_outline, 'Community', false, context),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isActive, BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Handle navigation
        switch (label.toLowerCase()) {
          case 'talk':
            Navigator.of(context).pop(); // Go back to chat
            break;
          case 'mood':
            // Already on mood screen
            break;
          case 'quest':
            // TODO: Navigate to quest screen
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Quest coming soon!'),
                duration: Duration(seconds: 2),
              ),
            );
            break;
          case 'community':
            // TODO: Navigate to community screen
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Community coming soon!'),
                duration: Duration(seconds: 2),
              ),
            );
            break;
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 28.0, // iOS standard tab bar icon size
            color: isActive ? Colors.blue : Colors.grey,
          ),
          SizedBox(height: 4.h),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.0, // iOS standard tab bar label size
              color: isActive ? Colors.blue : Colors.grey,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
