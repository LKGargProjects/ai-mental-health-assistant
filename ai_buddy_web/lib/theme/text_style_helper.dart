import 'package:flutter/material.dart';
import '../core/app_export.dart';

/// A helper class for managing text styles in the application
class TextStyleHelper {
  static TextStyleHelper? _instance;

  TextStyleHelper._();

  static TextStyleHelper get instance {
    _instance ??= TextStyleHelper._();
    return _instance!;
  }

  // Headline Styles
  // Medium-large text styles for section headers

  TextStyle get headline24Bold => TextStyle(
        fontSize: 24.fSize,
        fontWeight: FontWeight.bold,
        color: appTheme.colorFF1F29,
      );

  // Title Styles
  // Medium text styles for titles and subtitles

  TextStyle get title20RegularRoboto => TextStyle(
        fontSize: 20.fSize,
        fontWeight: FontWeight.w400,
        fontFamily: 'Roboto',
      );

  TextStyle get title18 => TextStyle(
        fontSize: 18.fSize,
      );

  TextStyle get title18Regular => TextStyle(
        fontSize: 18.fSize,
        fontWeight: FontWeight.w400,
      );

  // Body Styles
  // Standard text styles for body content

  TextStyle get body14Medium => TextStyle(
        fontSize: 14.fSize,
        fontWeight: FontWeight.w500,
      );

  // Other Styles
  // Miscellaneous text styles without specified font size

  TextStyle get textStyle5 => TextStyle();
}
