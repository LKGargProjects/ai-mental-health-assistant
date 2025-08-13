import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// A shared, adaptive back/close button with platform-aware behavior
/// and consistent hit target (44x44). Defaults to Navigator.maybePop.
class AppBackButton extends StatelessWidget {
  const AppBackButton({
    super.key,
    this.onPressed,
    this.isModal = false,
    this.iconColor,
    this.backgroundColor,
    this.showBackground = false,
    this.size = 44.0,
  });

  final VoidCallback? onPressed;
  final bool isModal; // if true, renders a close (X) icon
  final Color? iconColor;
  final Color? backgroundColor;
  final bool showBackground;
  final double size; // tap target size

  bool get _isCupertinoLike => defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  @override
  Widget build(BuildContext context) {
    final Color resolvedIconColor = iconColor ?? Theme.of(context).colorScheme.onSurface;
    final Color? resolvedBgColor = showBackground
        ? (backgroundColor ?? Theme.of(context).colorScheme.surface)
        : null;

    final IconData iconData = isModal
        ? Icons.close
        : (_isCupertinoLike ? Icons.arrow_back_ios_new : Icons.arrow_back);

    final Widget icon = Icon(iconData, size: 20, color: resolvedIconColor);

    final VoidCallback action = onPressed ?? () {
      final isKeyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
      if (isKeyboardOpen) {
        FocusScope.of(context).unfocus();
        return;
      }
      Navigator.of(context).maybePop();
    };

    final Widget content = Center(child: icon);

    // Platform-adaptive interaction: no ripple on iOS/macOS, ripple elsewhere
    Widget button = _isCupertinoLike
        ? GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: action,
            child: SizedBox(width: size, height: size, child: content),
          )
        : Material(
            color: resolvedBgColor ?? Colors.transparent,
            shape: showBackground ? const StadiumBorder() : null,
            child: InkWell(
              onTap: action,
              customBorder: const StadiumBorder(),
              child: SizedBox(width: size, height: size, child: content),
            ),
          );

    if (resolvedBgColor != null && _isCupertinoLike) {
      // Wrap to paint background on iOS without ripple
      button = Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: const ShapeDecoration(
          shape: StadiumBorder(),
        ),
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: resolvedBgColor,
            shape: const StadiumBorder(),
          ),
          child: SizedBox(width: size, height: size, child: content),
        ),
      );
    }

    return button;
  }
}
