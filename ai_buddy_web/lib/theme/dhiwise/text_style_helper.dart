import 'package:flutter/material.dart';
import '../../dhiwise/core/utils/size_utils.dart';
import './theme_helper.dart';

/// A helper class for managing text styles in the application
class TextStyleHelper {
  static TextStyleHelper? _instance;

  TextStyleHelper._();

  static TextStyleHelper get instance {
    _instance ??= TextStyleHelper._();
    return _instance!;
  }

  // Display Styles
  // Extra-large text styles for main headings

  TextStyle get display37BoldInter => TextStyle(
        fontSize: 37.fSize,
        fontWeight: FontWeight.bold,
        fontFamily: 'Inter',
      );

  TextStyle get display32BoldInter => TextStyle(
        fontSize: 32.fSize,
        fontWeight: FontWeight.bold,
        fontFamily: 'Inter',
      );

  TextStyle get display31BoldInter => TextStyle(
        fontSize: 31.fSize,
        fontWeight: FontWeight.bold,
        fontFamily: 'Inter',
      );

  // Headline Styles
  // Medium-large text styles for section headers

  TextStyle get headline28BoldInter => TextStyle(
        fontSize: 28.fSize,
        fontWeight: FontWeight.bold,
        fontFamily: 'Inter',
      );

  TextStyle get headline28Inter => TextStyle(
        fontSize: 28.fSize,
        fontFamily: 'Inter',
      );

  TextStyle get headline26BoldInter => TextStyle(
        fontSize: 26.fSize,
        fontWeight: FontWeight.bold,
        fontFamily: 'Inter',
      );

  TextStyle get headline25BoldInter => TextStyle(
        fontSize: 25.fSize,
        fontWeight: FontWeight.bold,
        fontFamily: 'Inter',
      );

  TextStyle get headline24Bold => TextStyle(
        fontSize: 24.fSize,
        fontWeight: FontWeight.bold,
        color: appTheme.colorFF1F29,
      );

  TextStyle get headline22Inter => TextStyle(
        fontSize: 22.fSize,
        fontFamily: 'Inter',
      );

  TextStyle get headline21Inter => TextStyle(
        fontSize: 21.fSize,
        fontFamily: 'Inter',
      );

  // Title Styles
  // Medium text styles for titles and subtitles

  TextStyle get title20RegularRoboto => TextStyle(
        fontSize: 20.fSize,
        fontWeight: FontWeight.w400,
        fontFamily: 'Roboto',
      );

  TextStyle get title19MediumInter => TextStyle(
        fontSize: 19.fSize,
        fontWeight: FontWeight.w500,
        fontFamily: 'Inter',
      );

  TextStyle get title19BoldInter => TextStyle(
        fontSize: 19.fSize,
        fontWeight: FontWeight.bold,
        fontFamily: 'Inter',
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
