import 'package:flutter/material.dart';
import './self_assessment_widget.dart';
import '../dhiwise/core/app_export.dart';
import '../theme/text_style_helper.dart' as CoreTextStyles;

class AssessmentSplash extends StatelessWidget {
  final VoidCallback? onClosed;
  const AssessmentSplash({super.key, this.onClosed});

  @override
  Widget build(BuildContext context) {
    // Dialog with rounded corners and subtle shadow, centered, responsive width/height
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final media = MediaQuery.of(context);
          final screenH = media.size.height;
          final viewInsetsBottom = media.viewInsets.bottom; // keyboard
          // Keep dialog within 90% of viewport, minus keyboard insets
          final maxDialogHeight = (screenH * 0.9) - viewInsetsBottom;
          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 720,
                maxHeight: maxDialogHeight.clamp(320.0, screenH),
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(24, 24, 24, 16 + viewInsetsBottom),
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  // Header
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Quick check-in',
                          style: TextStyleHelper.instance.headline24Bold.copyWith(
                            color: const Color(0xFF555F6D),
                            fontFamily: CoreTextStyles.TextStyleHelper.instance.headline24Bold.fontFamily,
                          ),
                        ),
                      ),
                      // Close button (X)
                      IconButton(
                        icon: const Icon(Icons.close),
                        color: const Color(0xFF8C9CAA),
                        tooltip: 'Close',
                        onPressed: () {
                          Navigator.of(context).pop();
                          onClosed?.call();
                        },
                      )
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Takes about 2 minutes',
                    style: TextStyleHelper.instance.headline21Inter.copyWith(
                      color: const Color(0xFF8C9CAA),
                      fontFamily: CoreTextStyles.TextStyleHelper.instance.headline24Bold.fontFamily,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Body: existing self assessment widget (API-integrated)
                  // Use Expanded so the body takes remaining space and scrolls within, avoiding overflow
                  Expanded(
                    child: SelfAssessmentWidget(
                      onAssessmentSubmitted: () {
                        // Close on successful submit
                        Navigator.of(context).maybePop();
                        onClosed?.call();
                      },
                    ),
                  ),
                ],
              ),
            ),
            ),
          );
        },
      ),
    );
  }
}
