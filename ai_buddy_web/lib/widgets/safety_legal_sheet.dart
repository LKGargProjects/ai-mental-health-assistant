import 'package:flutter/material.dart';
import '../screens/legal/legal_screen.dart';

/// Shows a minimal, accessible Safety & Legal sheet.
/// If [requireAcknowledge] is true, shows a primary "I understand" action.
Future<void> showSafetyLegalSheet(BuildContext context, {bool requireAcknowledge = false}) async {
  await showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            left: 16.0,
            right: 16.0,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16.0,
            top: 8.0,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Safety & Legal',
                        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(ctx).maybePop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'This app offers AI-based wellness support. It does not provide medical advice, diagnosis, or treatment.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                _Bullet(text: 'If you may harm yourself or others, contact local emergency services. Crisis resources are shown contextually.'),
                const SizedBox(height: 8),
                _Bullet(text: 'Your messages may be stored for a limited period to operate the service. You can request deletion.'),
                const SizedBox(height: 8),
                _Bullet(text: 'By continuing, you agree to the Terms of Service and Privacy Policy when presented.'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    TextButton(
                      onPressed: () async {
                        final nav = Navigator.of(context);
                        Navigator.of(ctx).maybePop();
                        // Wait a tick to ensure sheet is closed before pushing
                        await Future.delayed(Duration.zero);
                        nav.push(
                          MaterialPageRoute(
                            builder: (_) => const LegalScreen(
                              title: 'Terms of Service',
                              assetPath: 'assets/legal/terms.md',
                            ),
                          ),
                        );
                      },
                      child: const Text('View Terms of Service'),
                    ),
                    TextButton(
                      onPressed: () async {
                        final nav = Navigator.of(context);
                        Navigator.of(ctx).maybePop();
                        await Future.delayed(Duration.zero);
                        nav.push(
                          MaterialPageRoute(
                            builder: (_) => const LegalScreen(
                              title: 'Privacy Policy',
                              assetPath: 'assets/legal/privacy.md',
                            ),
                          ),
                        );
                      },
                      child: const Text('View Privacy Policy'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (requireAcknowledge)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(ctx).maybePop(),
                      child: const Text('I understand'),
                    ),
                  )
                else
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(ctx).maybePop(),
                      child: const Text('Close'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet({required this.text});
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('• '),
        Expanded(child: Text(text)),
      ],
    );
  }
}
