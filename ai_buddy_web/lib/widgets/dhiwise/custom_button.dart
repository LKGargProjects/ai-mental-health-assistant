import 'package:flutter/material.dart';

import '../../core/utils/size_utils.dart';
import '../../theme/theme_helper.dart';
import '../../theme/text_style_helper.dart';
import './custom_image_view.dart';

/// CustomButton - A flexible button component that supports text, icon, and mixed content
/// with customizable styling including background colors, borders, padding, and sizes.
///
/// @param text - Button text content
/// @param imagePath - Path to button icon/image
/// @param onPressed - Callback function when button is pressed
/// @param backgroundColor - Background color of the button
/// @param textColor - Color of the button text
/// @param borderColor - Color of the button border
/// @param showBorder - Whether to show border around button
/// @param padding - Internal padding of the button
/// @param borderRadius - Corner radius of the button
/// @param textStyle - Custom text style for button text
/// @param height - Height of the button
/// @param width - Width of the button
/// @param buttonType - Type of button (text, icon, or elevated)
/// @param imageHeight - Height of the button image
/// @param imageWidth - Width of the button image
class CustomButton extends StatelessWidget {
  const CustomButton({
    super.key,
    this.text,
    this.imagePath,
    this.onPressed,
    this.backgroundColor,
    this.textColor,
    this.borderColor,
    this.showBorder,
    this.padding,
    this.borderRadius,
    this.textStyle,
    this.height,
    this.width,
    this.buttonType,
    this.imageHeight,
    this.imageWidth,
  });

  /// Button text content
  final String? text;

  /// Path to button icon/image
  final String? imagePath;

  /// Callback function when button is pressed
  final VoidCallback? onPressed;

  /// Background color of the button
  final Color? backgroundColor;

  /// Color of the button text
  final Color? textColor;

  /// Color of the button border
  final Color? borderColor;

  /// Whether to show border around button
  final bool? showBorder;

  /// Internal padding of the button
  final EdgeInsetsGeometry? padding;

  /// Corner radius of the button
  final double? borderRadius;

  /// Custom text style for button text
  final TextStyle? textStyle;

  /// Height of the button
  final double? height;

  /// Width of the button
  final double? width;

  /// Type of button (text, icon, or elevated)
  final CustomButtonType? buttonType;

  /// Height of the button image
  final double? imageHeight;

  /// Width of the button image
  final double? imageWidth;

  @override
  Widget build(BuildContext context) {
    final effectiveButtonType = buttonType ?? CustomButtonType.elevated;
    final effectiveBackgroundColor = backgroundColor ?? appTheme.colorFFF5F5;
    final effectiveTextColor = textColor ?? appTheme.colorFF6666;
    final effectiveBorderColor = borderColor ?? appTheme.colorFFE5E7;
    final effectiveShowBorder = showBorder ?? false;
    final effectivePadding =
        padding ?? EdgeInsets.symmetric(horizontal: 24.h, vertical: 12.h);
    final effectiveBorderRadius = borderRadius ?? 25.h;
    final effectiveHeight = height;
    final effectiveWidth = width;

    switch (effectiveButtonType) {
      case CustomButtonType.icon:
        return _buildIconButton(
          effectiveBackgroundColor,
          effectiveBorderColor,
          effectiveShowBorder,
          effectivePadding,
          effectiveBorderRadius,
          effectiveHeight,
          effectiveWidth,
        );
      case CustomButtonType.text:
        return _buildTextButton(
          effectiveTextColor,
          effectiveBorderColor,
          effectiveShowBorder,
          effectivePadding,
          effectiveBorderRadius,
          effectiveHeight,
          effectiveWidth,
        );
      case CustomButtonType.elevated:
        return _buildElevatedButton(
          effectiveBackgroundColor,
          effectiveTextColor,
          effectiveBorderColor,
          effectiveShowBorder,
          effectivePadding,
          effectiveBorderRadius,
          effectiveHeight,
          effectiveWidth,
        );
    }
  }

  Widget _buildElevatedButton(
    Color backgroundColor,
    Color textColor,
    Color borderColor,
    bool showBorder,
    EdgeInsetsGeometry padding,
    double borderRadius,
    double? height,
    double? width,
  ) {
    return SizedBox(
      height: height,
      width: width,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          padding: padding,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            side: showBorder
                ? BorderSide(color: borderColor, width: 1.h)
                : BorderSide.none,
          ),
          elevation: 0,
        ),
        child: _buildButtonContent(textColor),
      ),
    );
  }

  Widget _buildTextButton(
    Color textColor,
    Color borderColor,
    bool showBorder,
    EdgeInsetsGeometry padding,
    double borderRadius,
    double? height,
    double? width,
  ) {
    return SizedBox(
      height: height,
      width: width,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: textColor,
          padding: padding,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            side: showBorder
                ? BorderSide(color: borderColor, width: 1.h)
                : BorderSide.none,
          ),
        ),
        child: _buildButtonContent(textColor),
      ),
    );
  }

  Widget _buildIconButton(
    Color backgroundColor,
    Color borderColor,
    bool showBorder,
    EdgeInsetsGeometry padding,
    double borderRadius,
    double? height,
    double? width,
  ) {
    return Container(
      height: height ?? 48.h,
      width: width ?? 48.h,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: showBorder ? Border.all(color: borderColor, width: 1.h) : null,
      ),
      child: IconButton(
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        icon: _buildButtonContent(null),
      ),
    );
  }

  Widget _buildButtonContent(Color? textColor) {
    if (imagePath != null && text != null) {
      // Both image and text
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomImageView(
            imagePath: imagePath!,
            height: imageHeight ?? 20.h,
            width: imageWidth ?? 20.h,
          ),
          SizedBox(width: 8.h),
          Text(
            text!,
            style: _getEffectiveTextStyle(
              textColor,
            ), // Modified: Fixed method call syntax
          ),
        ],
      );
    } else if (imagePath != null) {
      // Image only
      return CustomImageView(
        imagePath: imagePath!,
        height: imageHeight ?? 24.h,
        width: imageWidth ?? 16.h,
      );
    } else if (text != null) {
      // Text only
      return Text(
        text!,
        style: _getEffectiveTextStyle(
          textColor,
        ), // Modified: Fixed method call syntax
      );
    } else {
      // Fallback
      return const SizedBox();
    }
  }

  TextStyle _getEffectiveTextStyle(defaultColor) {
    // Modified: Fixed method signature and name
    final baseStyle = textStyle ?? TextStyleHelper.instance.title18Regular;

    return baseStyle.copyWith(
      color:
          baseStyle.color ??
          defaultColor ??
          Colors.black, // Modified: Fixed undefined defaultColor
    );
  }
}

/// Enum for different button types
enum CustomButtonType { elevated, text, icon }
