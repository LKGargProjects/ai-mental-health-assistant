import 'package:flutter/material.dart';

String _appTheme = "lightCode";
LightCodeColors get appTheme => ThemeHelper().themeColor();
ThemeData get theme => ThemeHelper().themeData();

/// Helper class for managing themes and colors.

// ignore_for_file: must_be_immutable
class ThemeHelper {
  // A map of custom color themes supported by the app
  Map<String, LightCodeColors> _supportedCustomColor = {
    'lightCode': LightCodeColors()
  };

  // A map of color schemes supported by the app
  Map<String, ColorScheme> _supportedColorScheme = {
    'lightCode': ColorSchemes.lightCodeColorScheme
  };

  /// Changes the app theme to [_newTheme].
  void changeTheme(String _newTheme) {
    _appTheme = _newTheme;
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

  // New Wellness Dashboard Colors
  Color get colorFF4750 => Color(0xFF47505E);
  Color get colorFFE3EC => Color(0xFFE3ECEF);
  Color get colorFF555F => Color(0xFF555F6D);
  Color get colorFF5A61 => Color(0xFF5A616F);
  Color get colorFFF1F5 => Color(0xFFF1F5F7);
  Color get colorFF444D => Color(0xFF444D5C);
  Color get colorFFE0F2 => Color(0xFFE0F2E9);
  Color get colorFFE8E7 => Color(0xFFE8E7F8);
  Color get colorFF4A52 => Color(0xFF4A5261);
  Color get colorFFF4F4 => Color(0xFFF4F4EF);
  Color get colorFF1616 => Color(0xFF16160F);
  Color get colorFF8C82 => Color(0xFF8C825E);
  Color get colorFF4E59 => Color(0xFF4E5965);
  Color get colorFF8C9C => Color(0xFF8C9CAA);
  Color get colorFFFEFE => Color(0xFFFEFEFE);
  Color get colorFFF4F5F7 => Color(0xFFF4F5F7);
  Color get colorFF939F => Color(0xFF939FAF);
  Color get colorFF4F58 => Color(0xFF4F5866);
  Color get colorFFA8B1 => Color(0xFFA8B1BF);

  // Color Shades - Each shade has its own dedicated constant
  Color get grey200 => Colors.grey.shade200;
  Color get grey100 => Colors.grey.shade100;
}
