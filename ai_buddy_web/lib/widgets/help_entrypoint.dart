import 'package:flutter/material.dart';

/// A lightweight, adaptive Help entrypoint that blends into the UI.
/// - On wide layouts (>= 900px), shows a top-right icon overlay (AppBar-like action).
/// - On narrow layouts, shows a subtle floating shield icon near the bottom-right above the nav bar.
/// - Hides automatically when the keyboard is open.
class HelpEntrypointOverlay extends StatelessWidget {
  const HelpEntrypointOverlay({
    super.key,
    required this.onPressed,
  });

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final insets = MediaQuery.viewInsetsOf(context);
    final isKeyboardOpen = insets.bottom > 0;
    final isWide = size.width >= 900;

    // Hide overlay entirely when keyboard is open (both wide and narrow)
    if (isKeyboardOpen) return const SizedBox.shrink();

    if (isWide) {
      // AppBar-like action in the top-right corner
      return Positioned(
        top: padding.top + 8,
        right: padding.right + 12,
        child: _HelpIconButton(onPressed: onPressed),
      );
    }

    return Positioned(
      right: padding.right + 12,
      // Place above the bottom nav by an estimated offset; SafeArea padding included
      bottom: padding.bottom + 80,
      child: _HelpFloatingIcon(onPressed: onPressed),
    );
  }
}

class _HelpIconButton extends StatelessWidget {
  const _HelpIconButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: 'Help and crisis resources',
      child: Tooltip(
        message: 'Help & Crisis resources',
        child: Material(
          color: theme.colorScheme.surface.withValues(alpha: 0.9),
          shape: const CircleBorder(),
          elevation: 1,
          child: IconButton(
            icon: const Icon(Icons.health_and_safety_rounded),
            color: theme.colorScheme.primary,
            onPressed: onPressed,
          ),
        ),
      ),
    );
  }
}

class _HelpFloatingIcon extends StatelessWidget {
  const _HelpFloatingIcon({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Static styling: no risk-based color or animation
    final Color fill = theme.colorScheme.surface.withValues(alpha: 0.9);
    final Color iconColor = theme.colorScheme.primary;
    return Semantics(
      button: true,
      label: 'Help and crisis resources',
      child: Tooltip(
        message: 'Help & Crisis resources',
        child: Material(
          color: fill,
          shape: const CircleBorder(),
          elevation: 2,
          child: IconButton(
            icon: const Icon(Icons.health_and_safety_rounded),
            color: iconColor,
            onPressed: onPressed,
          ),
        ),
      ),
    );
  }
}
