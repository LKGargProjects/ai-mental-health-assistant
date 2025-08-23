import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemMouseCursors;
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/app_export.dart';
import '../../../../theme/text_style_helper.dart' as CoreTextStyles;

class ProgressCardWidget extends StatefulWidget {
  final String imagePath;
  final String value;
  final String label;
  final Color backgroundColor;
  final Widget? valueWidget;
  final Color? iconColor; // optional tint for SVG/raster icons

  ProgressCardWidget({
    Key? key,
    required this.imagePath,
    required this.value,
    required this.label,
    required this.backgroundColor,
    this.valueWidget,
    this.iconColor,
  }) : super(key: key);

  @override
  State<ProgressCardWidget> createState() => _ProgressCardWidgetState();
}

class _ProgressCardWidgetState extends State<ProgressCardWidget> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.985 : (_hover ? 1.005 : 1.0),
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              borderRadius: BorderRadius.circular(25.h),
              boxShadow: (_hover || _pressed)
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            padding: EdgeInsets.all(24.h),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _IconRenderable(
                  path: widget.imagePath,
                  width: 65.h,
                  height: 65.h,
                  fit: BoxFit.contain,
                  color: widget.iconColor,
                  borderRadius: null,
                ),
                SizedBox(height: 16.h),
                widget.valueWidget ?? Text(
                  widget.value,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: TextStyleHelper.instance.headline28BoldInter.copyWith(
                    fontFamily: CoreTextStyles.TextStyleHelper.instance.headline24Bold.fontFamily,
                    color: Color(0xFF4E5965),
                  ),
                ),
                if (widget.label.isNotEmpty) ...[
                  SizedBox(height: 4.h),
                  Text(
                    widget.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    softWrap: true,
                    style: TextStyleHelper.instance.headline22Inter.copyWith(
                      fontFamily: CoreTextStyles.TextStyleHelper.instance.headline24Bold.fontFamily,
                      color: Color(0xFF8C9CAA),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Renders either an SVG (with optional tint) or falls back to Image.asset
class _IconRenderable extends StatelessWidget {
  final String path;
  final double width;
  final double height;
  final BoxFit fit;
  final Color? color;
  final BorderRadius? borderRadius;

  const _IconRenderable({
    Key? key,
    required this.path,
    required this.width,
    required this.height,
    this.fit = BoxFit.contain,
    this.color,
    this.borderRadius,
  }) : super(key: key);

  bool get _isSvg => path.toLowerCase().endsWith('.svg');

  @override
  Widget build(BuildContext context) {
    final child = _isSvg
        ? SvgPicture.asset(
            path,
            width: width,
            height: height,
            fit: fit,
            colorFilter: color != null ? ColorFilter.mode(color!, BlendMode.srcIn) : null,
          )
        : Image.asset(
            path,
            width: width,
            height: height,
            fit: fit,
            color: color,
            colorBlendMode: color != null ? BlendMode.srcIn : null,
          );
    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius ?? BorderRadius.zero, child: child);
    }
    return child;
  }
}
