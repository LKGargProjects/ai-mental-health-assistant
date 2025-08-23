import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'app_back_button.dart';

// Centralized IME (keyboard) visibility detection
bool isImeOpen(BuildContext context) {
  // Primary signal on mobile: bottom viewInsets
  final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
  if (bottomInset > 0) return true;
  // Fallback (web/desktop): treat focused EditableText as IME open
  final primary = FocusManager.instance.primaryFocus;
  bool hasTextFocus = false;
  final focusCtx = primary?.context;
  if (focusCtx != null) {
    hasTextFocus = focusCtx.findAncestorWidgetOfExactType<EditableText>() != null;
  }
  if (kIsWeb) return hasTextFocus;
  return hasTextFocus;
}

/// A reusable Scaffold wrapper that standardizes keyboard dismissal and back behavior.
/// - Dismiss keyboard on background tap
/// - Dismiss keyboard on back button before popping the route (PopScope)
/// - Applies SafeArea with configurable top/bottom
class KeyboardDismissibleScaffold extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final Color? backgroundColor;
  final bool safeTop;
  final bool safeBottom;
  final bool resizeToAvoidBottomInset;
  final bool extendBody;

  const KeyboardDismissibleScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
    this.backgroundColor,
    this.safeTop = true,
    this.safeBottom = false,
    this.resizeToAvoidBottomInset = true,
    this.extendBody = false,
  });

  @override
  Widget build(BuildContext context) {
    final isKeyboardOpen = isImeOpen(context);
    return PopScope(
      canPop: !isKeyboardOpen,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && isKeyboardOpen) {
          FocusScope.of(context).unfocus();
        }
      },
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: appBar,
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
        extendBody: extendBody,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusScope.of(context).unfocus(),
          child: SafeArea(
            top: safeTop,
            bottom: safeBottom,
            child: body,
          ),
        ),
        bottomNavigationBar: bottomNavigationBar,
      ),
    );
  }
}

/// Renders [childWhenKeyboardOpen] only when the keyboard is visible.
/// Otherwise renders a fixed-size placeholder to keep header layout stable.
class KeyboardAwareLeading extends StatelessWidget {
  final Widget childWhenKeyboardOpen;
  final double size;
  final Duration animationDuration;

  const KeyboardAwareLeading({
    super.key,
    required this.childWhenKeyboardOpen,
    this.size = 44.0,
    this.animationDuration = const Duration(milliseconds: 150),
  });

  @override
  Widget build(BuildContext context) {
    final isKeyboardOpen = isImeOpen(context);
    final placeholder = SizedBox(
      key: const ValueKey('kw_leading_placeholder'),
      width: size,
      height: size,
    );
    final child = SizedBox(
      key: const ValueKey('kw_leading_child'),
      width: size,
      height: size,
      child: childWhenKeyboardOpen,
    );

    return AnimatedSwitcher(
      duration: animationDuration,
      child: isKeyboardOpen ? child : placeholder,
    );
  }
}

/// Convenience back/close button that is only visible when the keyboard is open.
/// When hidden, a same-size placeholder keeps the app bar title centered.
class KeyboardAwareBackButton extends StatefulWidget {
  final bool isModal;
  final double size;
  final VoidCallback? onPressed;
  final Duration animationDuration;

  const KeyboardAwareBackButton({
    super.key,
    this.isModal = false,
    this.size = 44.0,
    this.onPressed,
    this.animationDuration = const Duration(milliseconds: 150),
  });

  @override
  State<KeyboardAwareBackButton> createState() => _KeyboardAwareBackButtonState();
}

class _KeyboardAwareBackButtonState extends State<KeyboardAwareBackButton> with WidgetsBindingObserver {
  void _onFocusChange() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FocusManager.instance.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    FocusManager.instance.removeListener(_onFocusChange);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isKeyboardOpen = isImeOpen(context);
    final placeholder = SizedBox(
      key: const ValueKey('kw_back_placeholder'),
      width: widget.size,
      height: widget.size,
    );
    final back = AppBackButton(
      key: const ValueKey('kw_back_button'),
      isModal: widget.isModal,
      onPressed: widget.onPressed,
      size: widget.size,
    );
    final child = SizedBox(width: widget.size, height: widget.size, child: back);

    return AnimatedSwitcher(
      duration: widget.animationDuration,
      child: isKeyboardOpen ? child : placeholder,
    );
  }
}
