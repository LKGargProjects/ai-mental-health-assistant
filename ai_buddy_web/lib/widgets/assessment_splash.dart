import 'package:flutter/material.dart';
import './self_assessment_widget.dart';
import '../dhiwise/core/app_export.dart';
import '../theme/text_style_helper.dart' as CoreTextStyles;

class AssessmentSplash extends StatelessWidget {
  final VoidCallback? onClosed;
  const AssessmentSplash({super.key, this.onClosed});

  @override
  Widget build(BuildContext context) {
    // Dialog with rounded corners and subtle shadow, centered, responsive width
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                  const SizedBox(height: 16),

                  // Body: existing self assessment widget (API-integrated)
                  Flexible(
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
          ],
        ),
      ),
    );
  }
}
