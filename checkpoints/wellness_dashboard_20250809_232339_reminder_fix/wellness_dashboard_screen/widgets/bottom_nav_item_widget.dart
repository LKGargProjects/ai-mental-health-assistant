import 'package:flutter/material.dart';

import '../../../core/app_export.dart';
import '../../../widgets/custom_image_view.dart';

class BottomNavItemWidget extends StatelessWidget {
  final String iconPath;
  final String label;
  final bool isActive;
  final VoidCallback? onTap;

  BottomNavItemWidget({
    Key? key,
    required this.iconPath,
    required this.label,
    this.isActive = false,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomImageView(
            imagePath: iconPath,
            height: 39.h,
            width: 39.h,
            fit: BoxFit.contain,
          ),
          SizedBox(height: 8.h),
          Text(
            label,
            style: TextStyleHelper.instance.title19MediumInter.copyWith(
                color: isActive ? Color(0xFF16160F) : Color(0xFF8C825E)),
          ),
        ],
      ),
    );
  }
}
