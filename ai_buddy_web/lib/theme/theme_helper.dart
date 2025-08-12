import 'package:flutter/material.dart';

String _appTheme = "lightCode";
LightCodeColors get appTheme => ThemeHelper().themeColor();
ThemeData get theme => ThemeHelper().themeData();

/// Helper class for managing themes and colors.

// ignore_for_file: must_be_immutable
class ThemeHelper {
  // A map of custom color themes supported by the app
  final Map<String, LightCodeColors> _supportedCustomColor = {
    'lightCode': LightCodeColors(),
  };

  // A map of color schemes supported by the app
  final Map<String, ColorScheme> _supportedColorScheme = {
    'lightCode': ColorSchemes.lightCodeColorScheme,
  };

  /// Changes the app theme to [newTheme].
  void changeTheme(String newTheme) {
    _appTheme = newTheme;
  }

  /// Returns the lightCode colors for the current theme.
  LightCodeColors _getThemeColors() {
    return _supportedCustomColor[_appTheme] ?? LightCodeColors();
  }

  /// Returns the current theme data.
  ThemeData _getThemeData() {
    var colorScheme =
        _supportedColorScheme[_appTheme] ?? ColorSchemes.lightCodeColorScheme;
    return ThemeData(
      visualDensity: VisualDensity.standard,
      colorScheme: colorScheme,
    );
  }

  /// Returns the lightCode colors for the current theme.
  LightCodeColors themeColor() => _getThemeColors();

  /// Returns the current theme data.
  ThemeData themeData() => _getThemeData();
}

class ColorSchemes {
  static final lightCodeColorScheme = ColorScheme.light();
}

class LightCodeColors {
  // App Colors
  Color get black => Color(0xFF1E1E1E);
  Color get white => Color(0xFFFFFFFF);
  Color get gray50 => Color(0xFFF9FAFB);
  Color get gray100 => Color(0xFFF3F4F6);
  Color get green500 => Color(0xFF10B981);
  Color get gray800 => Color(0xFF1F2937);
  Color get gray600 => Color(0xFF4B5563);
  Color get green200 => Color(0xFFA7F3D0);
  Color get green800 => Color(0xFF065F46);
  Color get gray200 => Color(0xFFE5E7EB);
  Color get gray400 => Color(0xFF9CA3AF);
  Color get gray500 => Color(0xFF6B7280);

  // Additional Colors
  Color get whiteCustom => Colors.white;
  Color get blackCustom => Colors.black;
  Color get transparentCustom => Colors.transparent;
  Color get greyCustom => Colors.grey;
  Color get colorFF10B9 => Color(0xFF10B981);
  Color get colorFF1F29 => Color(0xFF1F2937);
  Color get colorFFF3F4 => Color(0xFFF3F4F6);
  Color get colorFF6B72 => Color(0xFF6B7280);
  Color get colorFFE5E7 => Color(0xFFE5E7EB);
  Color get colorFF9CA3 => Color(0xFF9CA3AF);
  Color get colorFF4B55 => Color(0xFF4B5563);
  Color get colorFFBBF7 => Color(0xFFBBF7D0);
  Color get colorFF1665 => Color(0xFF166534);
  Color get colorFFF5F5 => Color(0xFFF5F5F5);
  Color get colorFF6666 => Color(0xFF666666);

  // Color Shades - Each shade has its own dedicated constant
  Color get grey200 => Colors.grey.shade200;
  Color get grey100 => Colors.grey.shade100;
}
