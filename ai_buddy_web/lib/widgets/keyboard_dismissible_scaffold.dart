import 'package:flutter/material.dart';

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
    final isKeyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
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
