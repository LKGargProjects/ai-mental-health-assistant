import 'package:flutter/material.dart';
import 'package:ai_buddy_web/dhiwise/core/app_export.dart';
import 'package:ai_buddy_web/dhiwise/widgets/custom_button.dart';

class QuestCardWidget extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final bool isActive;
  final double? progress;
  final VoidCallback? onTap;

  const QuestCardWidget({
    Key? key,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.color,
    this.isActive = false,
    this.progress,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16.h),
        decoration: BoxDecoration(
          color: ColorConstant.whiteA700,
          borderRadius: BorderRadius.circular(16.h),
          boxShadow: [
            BoxShadow(
              color: ColorConstant.black900.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Icon Container
                Container(
                  width: 48.h,
                  height: 48.h,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12.h),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 24.h,
                  ),
                ),
                SizedBox(width: 16.h),
                
                // Title and Subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyleHelper.instance.titleSmallInter.copyWith(
                          color: ColorConstant.gray900,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (subtitle != null) ...[
                        SizedBox(height: 4.v),
                        Text(
                          subtitle!,
                          style: TextStyleHelper.instance.bodySmallInter.copyWith(
                            color: ColorConstant.gray500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                
                // Action Button
                isActive
                    ? CustomButton(
                        height: 32.h,
                        width: 90.h,
                        text: 'Continue',
                        onTap: onTap,
                        buttonType: CustomButtonType.outline,
                        buttonStyle: CustomButtonStyles.outlinePrimary,
                      )
                    : CustomButton(
                        height: 32.h,
                        width: 90.h,
                        text: 'Start',
                        onTap: onTap,
                      ),
              ],
            ),
            
            // Progress Bar (only for active quests)
            if (isActive && progress != null) ...[
              SizedBox(height: 16.v),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: ColorConstant.gray100,
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 8.h,
                borderRadius: BorderRadius.circular(4.h),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
