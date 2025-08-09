import 'package:flutter/material.dart';

import '../../../core/app_export.dart';
import '../../../widgets/custom_image_view.dart';

class ProgressCardWidget extends StatelessWidget {
  final String imagePath;
  final String value;
  final String label;
  final Color backgroundColor;

  ProgressCardWidget({
    Key? key,
    required this.imagePath,
    required this.value,
    required this.label,
    required this.backgroundColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(25.h),
      ),
      padding: EdgeInsets.all(24.h),
      child: Column(
        children: [
          CustomImageView(
            imagePath: imagePath,
            height: 65.h,
            width: 65.h,
            fit: BoxFit.contain,
          ),
          SizedBox(height: 16.h),
          Text(
            value,
            style: TextStyleHelper.instance.headline28BoldInter
                .copyWith(color: Color(0xFF4E5965)),
          ),
          SizedBox(height: 4.h),
          Text(
            label,
            style: TextStyleHelper.instance.headline22Inter
                .copyWith(color: Color(0xFF8C9CAA)),
          ),
        ],
      ),
    );
  }
}
