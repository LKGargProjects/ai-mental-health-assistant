import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemMouseCursors;
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/app_export.dart';
import '../../../../theme/text_style_helper.dart' as CoreTextStyles;

class RecommendationCardWidget extends StatefulWidget {
  final String category;
  final String title;
  final String subtitle;
  final String imagePath;
  final String? doneImagePath;
  final VoidCallback? onTap;
  final bool completed;
  final Key? containerKey;

  const RecommendationCardWidget({
    Key? key,
    required this.category,
    required this.title,
    required this.subtitle,
    required this.imagePath,
    this.doneImagePath,
    this.onTap,
    this.completed = false,
    this.containerKey,
  }) : super(key: key);

  @override
  State<RecommendationCardWidget> createState() => _RecommendationCardWidgetState();
}

class _RecommendationCardWidgetState extends State<RecommendationCardWidget> {
  bool _pressed = false;
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(29.h);
    final theme = Theme.of(context);
    // Decide tint color heuristically by category/path and completion state
    final cat = widget.category.toLowerCase();
    final path = (widget.completed && widget.doneImagePath != null) ? widget.doneImagePath! : widget.imagePath;
    bool isAssess = cat.contains('assess');
    // Policy:
    // - Only Assess keeps overall tint (tertiary) for the whole SVG.
    // - For Task/Resource/Tip, do NOT tint the whole SVG (keep original colors).
    // - For completed tasks, overlay a green check badge instead of tinting the SVG.
    Color? tint = isAssess ? theme.colorScheme.tertiary : null;
    // Icons use their own stroke colors; avoid forcing a tint to keep parity with task icons
    final Color? iconColor = tint;
    return Material(
      color: const Color(0xFFFEFEFE),
      borderRadius: radius,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        cursor: SystemMouseCursors.click,
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: (v) => setState(() => _pressed = v),
          borderRadius: radius,
          splashColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.10),
          highlightColor: Colors.transparent,
          child: AnimatedScale(
            scale: _pressed ? 0.985 : (_hover ? 1.005 : 1.0),
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOut,
              key: widget.containerKey,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFF4F5F7)),
                borderRadius: radius,
                boxShadow: (_hover || _pressed)
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              padding: EdgeInsets.all(28.h),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.category,
                          style: TextStyleHelper.instance.title19BoldInter.copyWith(
                            fontFamily: CoreTextStyles.TextStyleHelper.instance.headline24Bold.fontFamily,
                            color: const Color(0xFF8E98A7),
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          widget.title,
                          style: TextStyleHelper.instance.headline26BoldInter.copyWith(
                            fontFamily: CoreTextStyles.TextStyleHelper.instance.headline24Bold.fontFamily,
                            color: const Color(0xFF4C5664),
                          ),
                        ),
                        SizedBox(height: 12.h),
                        Text(
                          widget.subtitle,
                          style: TextStyleHelper.instance.headline21Inter.copyWith(
                            fontFamily: CoreTextStyles.TextStyleHelper.instance.headline24Bold.fontFamily,
                            color: const Color(0xFFA8B1BF),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 24.h),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(19.h),
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Padding(
                          padding: EdgeInsets.all(0),
                          child: _IconRenderable(
                            path: path,
                            width: 104.h,
                            height: 104.h,
                            fit: BoxFit.cover,
                            color: iconColor,
                            borderRadius: BorderRadius.circular(19.h),
                          ),
                        ),
                        // Green completion tick overlay (only when no doneImagePath is provided)
                        if (widget.completed && widget.doneImagePath == null)
                          Positioned(
                            right: -6.h,
                            top: -6.h,
                            child: Container(
                              width: 28.h,
                              height: 28.h,
                              decoration: BoxDecoration(
                                color: const Color(0xFF22C55E),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Icon(Icons.check, size: 16.h, color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
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
