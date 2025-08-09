import 'package:flutter/material.dart';

import '../../../core/app_export.dart';
import '../../../widgets/custom_image_view.dart';

class RecommendationCardWidget extends StatelessWidget {
  final String category;
  final String title;
  final String subtitle;
  final String imagePath;
  final VoidCallback? onTap;

  RecommendationCardWidget({
    Key? key,
    required this.category,
    required this.title,
    required this.subtitle,
    required this.imagePath,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
                    style: TextStyleHelper.instance.title19BoldInter
                        .copyWith(color: Color(0xFF939FAF)),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    title,
                    style: TextStyleHelper.instance.headline26BoldInter
                        .copyWith(color: Color(0xFF4F5866)),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    subtitle,
                    style: TextStyleHelper.instance.headline21Inter
                        .copyWith(color: Color(0xFFA8B1BF)),
                  ),
                ],
              ),
            ),
            SizedBox(width: 24.h),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(19.h),
              ),
              child: CustomImageView(
                imagePath: imagePath,
                height: 130.h,
                width: 130.h,
                fit: BoxFit.cover,
                radius: BorderRadius.circular(19.h),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
