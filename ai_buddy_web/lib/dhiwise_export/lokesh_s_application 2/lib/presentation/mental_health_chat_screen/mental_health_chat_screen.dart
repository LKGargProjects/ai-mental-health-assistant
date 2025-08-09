import 'package:flutter/material.dart';

import '../../core/app_export.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_image_view.dart';

class MentalHealthChatScreen extends StatelessWidget {
  MentalHealthChatScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Image
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
                      // Back Button
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
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Profile Image with Online Status
                            Stack(
                              children: [
                                CustomImageView(
                                  imagePath: ImageConstant.imgImage66x66,
                                  height: 66.h,
                                  width: 66.h,
                                  fit: BoxFit.cover,
                                ),
                                Positioned(
                                  bottom: 4.h,
                                  right: 4.h,
                                  child: Container(
                                    height: 12.h,
                                    width: 12.h,
                                    decoration: BoxDecoration(
                                      color: appTheme.colorFF10B9,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: appTheme.whiteCustom,
                                        width: 2.h,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            SizedBox(width: 12.h),

                            // Name
                            Text(
                              'Alex',
                              style: TextStyleHelper.instance.headline24Bold,
                            ),
                          ],
                        ),
                      ),

                      SizedBox(width: 32.h),
                    ],
                  ),
                ),
              ),

              // Divider
              Container(
                height: 8.h,
                color: appTheme.colorFFF3F4,
              ),

              // Chat Messages
              Expanded(
                child: ListView(
                  padding: EdgeInsets.all(16.h),
                  children: [
                    // Alex's first message
                    _buildAlexMessage(
                      ImageConstant.imgImage52x52,
                      "Hey there! How are you feeling today?\nRemember, I'm here to listen and help you\nnavigate any challenges you might be facing.\nLet's work together to make today a great\nday!",
                    ),

                    SizedBox(height: 16.h),

                    // User's first message
                    _buildUserMessage(
                      "I'm feeling a bit overwhelmed with school and\nsocial stuff. It's hard to keep up.",
                    ),

                    SizedBox(height: 16.h),

                    // Alex's response
                    _buildAlexMessage(
                      ImageConstant.imgImage1,
                      "I understand. It's completely normal to feel\noverwhelmed sometimes. We can explore\nsome strategies to manage these feelings.\nHow does that sound?",
                    ),

                    SizedBox(height: 16.h),

                    // User's concerning message
                    _buildUserMessage(
                      "I just feel like I want to kill myself sometimes.",
                    ),

                    SizedBox(height: 16.h),

                    // Alex typing indicator
                    _buildTypingIndicator(),
                  ],
                ),
              ),

              // Divider
              Container(
                height: 16.h,
                color: appTheme.colorFFF3F4,
              ),

              // Quick Response Buttons
              Container(
                color: appTheme.whiteCustom,
                padding: EdgeInsets.all(16.h),
                child: Row(
                  children: [
                    Expanded(
                      child: CustomButton(
                        text: 'Tell me more',
                        backgroundColor: appTheme.colorFFF3F4,
                        textColor: appTheme.colorFF6B72,
                        showBorder: true,
                        borderColor: appTheme.colorFFE5E7,
                        textStyle: TextStyleHelper.instance.title18,
                        padding: EdgeInsets.symmetric(
                            horizontal: 24.h, vertical: 12.h),
                        onPressed: () {
                          // Handle quick response
                        },
                      ),
                    ),
                    SizedBox(width: 12.h),
                    Expanded(
                      child: CustomButton(
                        text: 'Okay',
                        backgroundColor: appTheme.colorFFF3F4,
                        textColor: appTheme.colorFF6B72,
                        textStyle: TextStyleHelper.instance.title18,
                        padding: EdgeInsets.symmetric(
                            horizontal: 24.h, vertical: 12.h),
                        onPressed: () {
                          // Handle quick response
                        },
                      ),
                    ),
                    SizedBox(width: 12.h),
                    Expanded(
                      child: CustomButton(
                        text: 'Got it, thanks!',
                        backgroundColor: appTheme.colorFFF3F4,
                        textColor: appTheme.colorFF6B72,
                        showBorder: true,
                        borderColor: appTheme.colorFFE5E7,
                        textStyle: TextStyleHelper.instance.title18,
                        padding: EdgeInsets.symmetric(
                            horizontal: 24.h, vertical: 12.h),
                        onPressed: () {
                          // Handle quick response
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // Message Input
              Container(
                color: appTheme.whiteCustom,
                padding: EdgeInsets.all(16.h),
                child: Container(
                  decoration: BoxDecoration(
                    color: appTheme.colorFFF3F4,
                    borderRadius: BorderRadius.circular(25.h),
                  ),
                  padding:
                      EdgeInsets.symmetric(horizontal: 16.h, vertical: 16.h),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Type a message...',
                            hintStyle: TextStyleHelper.instance.title18
                                .copyWith(color: appTheme.colorFF9CA3),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                          style: TextStyleHelper.instance.title18
                              .copyWith(color: appTheme.colorFF6B72),
                        ),
                      ),
                      SizedBox(width: 12.h),
                      GestureDetector(
                        onTap: () {
                          // Handle send message
                        },
                        child: Container(
                          height: 40.h,
                          width: 40.h,
                          decoration: BoxDecoration(
                            color: appTheme.colorFF4B55,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: CustomImageView(
                              imagePath: ImageConstant.img,
                              height: 20.h,
                              width: 20.h,
                              color: appTheme.whiteCustom,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Navigation
              Container(
                color: appTheme.whiteCustom,
                child: SafeArea(
                  top: false,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: appTheme.colorFFF3F4,
                          width: 1.h,
                        ),
                      ),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 16.h),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildBottomNavItem(
                          ImageConstant.imgVector0,
                          'Talk',
                          true,
                        ),
                        _buildBottomNavItem(
                          ImageConstant.imgVector0Gray60002,
                          'Mood',
                          false,
                        ),
                        _buildBottomNavItem(
                          ImageConstant.imgVector0Gray6000239x39,
                          'Quest',
                          false,
                        ),
                        _buildBottomNavItem(
                          ImageConstant.imgVector039x39,
                          'Community',
                          false,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAlexMessage(String avatarPath, String message) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomImageView(
          imagePath: avatarPath,
          height: 52.h,
          width: 52.h,
          fit: BoxFit.cover,
        ),
        SizedBox(width: 12.h),
        Flexible(
          child: Container(
            decoration: BoxDecoration(
              color: appTheme.colorFFF3F4,
              borderRadius: BorderRadius.circular(16.h),
            ),
            padding: EdgeInsets.all(16.h),
            child: Text(
              message,
              style: TextStyleHelper.instance.title18
                  .copyWith(color: appTheme.colorFF6B72, height: 1.44),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUserMessage(String message) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Flexible(
          child: Container(
            decoration: BoxDecoration(
              color: appTheme.colorFFBBF7,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16.h),
                topRight: Radius.circular(16.h),
                bottomLeft: Radius.circular(16.h),
                bottomRight: Radius.circular(0),
              ),
            ),
            padding: EdgeInsets.all(16.h),
            child: Text(
              message,
              style: TextStyleHelper.instance.title18
                  .copyWith(color: appTheme.colorFF1665, height: 1.44),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTypingIndicator() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomImageView(
          imagePath: ImageConstant.imgImage51x52,
          height: 52.h,
          width: 51.h,
          fit: BoxFit.cover,
        ),
        SizedBox(width: 12.h),
        Container(
          decoration: BoxDecoration(
            color: appTheme.colorFFF3F4,
            borderRadius: BorderRadius.circular(16.h),
          ),
          padding: EdgeInsets.all(12.h),
          child: CustomImageView(
            imagePath: ImageConstant.imgImage47x72,
            height: 48.h,
            width: 72.h,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNavItem(String iconPath, String label, bool isActive) {
    return GestureDetector(
      onTap: () {
        // Handle navigation
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomImageView(
            imagePath: iconPath,
            height: 40.h,
            width: 40.h,
          ),
          SizedBox(height: 4.h),
          Text(
            label,
            style: TextStyleHelper.instance.body14Medium.copyWith(
                color: isActive ? appTheme.blackCustom : appTheme.colorFF6B72),
          ),
        ],
      ),
    );
  }
}
