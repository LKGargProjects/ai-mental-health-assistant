import 'package:flutter/material.dart'; // These are the Viewport values of your Figma Design.

// These are used in the code as a reference to create your UI Responsively.
const num FIGMA_DESIGN_WIDTH = 635;
const num FIGMA_DESIGN_HEIGHT = 932;
const num FIGMA_DESIGN_STATUS_BAR = 0;

extension ResponsiveExtension on num {
  // Use safe accessors so tests/builds don't crash if setScreenSize
  // hasn't been called yet.
  double get _width => SizeUtils.safeWidth;
  double get _height => SizeUtils.safeHeight;

  double get h => ((this * _width) / FIGMA_DESIGN_WIDTH);

  double get fSize => ((this * _width) / FIGMA_DESIGN_WIDTH);

  // Vertical sizing based on Figma design height
  double get v => ((this * _height) / FIGMA_DESIGN_HEIGHT);
}

extension FormatExtension on double {
  double toDoubleValue({int fractionDigits = 2}) {
    return double.parse(toStringAsFixed(fractionDigits));
  }

  double isNonZero({num defaultValue = 0.0}) {
    return this > 0 ? this : defaultValue.toDouble();
  }
}

enum DeviceType { mobile, tablet, desktop }

typedef ResponsiveBuild = Widget Function(
  BuildContext context,
  Orientation orientation,
  DeviceType deviceType,
);

class Sizer extends StatelessWidget {
  const Sizer({super.key, required this.builder});

  /// Builds the widget whenever the orientation changes.
  final ResponsiveBuild builder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return OrientationBuilder(
          builder: (context, orientation) {
            SizeUtils.setScreenSize(constraints, orientation);
            return builder(context, orientation, SizeUtils.deviceType);
          },
        );
      },
    );
  }
}

// ignore_for_file: must_be_immutable
class SizeUtils {
  /// Device's BoxConstraints
  static late BoxConstraints boxConstraints;

  /// Device's Orientation
  static late Orientation orientation;

  /// Type of Device
  ///
  /// This can either be mobile or tablet
  static late DeviceType deviceType;

  /// Device's Height
  static late double height;

  /// Device's Width
  static late double width;

  /// Safe width that falls back to design width when uninitialized.
  static double get safeWidth {
    try {
      return width;
    } catch (_) {
      return FIGMA_DESIGN_WIDTH.toDouble();
    }
  }

  /// Safe height that falls back to design height when uninitialized.
  static double get safeHeight {
    try {
      return height;
    } catch (_) {
      return FIGMA_DESIGN_HEIGHT.toDouble();
    }
  }

  static void setScreenSize(
    BoxConstraints constraints,
    Orientation currentOrientation,
  ) {
    boxConstraints = constraints;
    orientation = currentOrientation;
    if (orientation == Orientation.portrait) {
      width = boxConstraints.maxWidth.isNonZero(
        defaultValue: FIGMA_DESIGN_WIDTH,
      );
      height = boxConstraints.maxHeight.isNonZero();
    } else {
      width = boxConstraints.maxHeight.isNonZero(
        defaultValue: FIGMA_DESIGN_WIDTH,
      );
      height = boxConstraints.maxWidth.isNonZero();
    }
    deviceType = DeviceType.mobile;
  }
}
