import 'package:flutter/material.dart';

import '../../../core/app_export.dart';
import '../../../widgets/custom_image_view.dart';
import '../../../../theme/text_style_helper.dart' as CoreTextStyles;

class RecommendationCardWidget extends StatelessWidget {
  final String category;
  final String title;
  final String subtitle;
  final String imagePath;
  final String? doneImagePath;
  final VoidCallback? onTap;
  final bool completed;
  final Key? containerKey;

  RecommendationCardWidget({
    Key? key,
    required this.category,
    required this.title,
    required this.subtitle,
    required this.imagePath,
    this.doneImagePath,
    this.onTap,
    this.completed = false,
    this.containerKey,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        key: containerKey,
        decoration: BoxDecoration(
          color: Color(0xFFFEFEFE),
          border: Border.all(color: Color(0xFFF4F5F7)),
          borderRadius: BorderRadius.circular(29.h),
        ),
        padding: EdgeInsets.all(28.h),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category,
                    style: TextStyleHelper.instance.title19BoldInter.copyWith(
                      fontFamily: CoreTextStyles
                          .TextStyleHelper.instance.headline24Bold.fontFamily,
                      color: Color(0xFF8E98A7),
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    title,
                    style: TextStyleHelper.instance.headline26BoldInter.copyWith(
                      fontFamily: CoreTextStyles
                          .TextStyleHelper.instance.headline24Bold.fontFamily,
                      color: Color(0xFF4C5664),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    subtitle,
                    style: TextStyleHelper.instance.headline21Inter.copyWith(
                      fontFamily: CoreTextStyles
                          .TextStyleHelper.instance.headline24Bold.fontFamily,
                      color: Color(0xFFA8B1BF),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 24.h),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(19.h),
              ),
              child: Stack(
                children: [
                  CustomImageView(
                    imagePath: (completed && doneImagePath != null)
                        ? doneImagePath
                        : imagePath,
                    height: 104.h,
                    width: 104.h,
                    fit: BoxFit.cover,
                    radius: BorderRadius.circular(19.h),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
