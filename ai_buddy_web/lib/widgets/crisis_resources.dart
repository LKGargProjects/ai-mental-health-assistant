import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/message.dart';

class CrisisResourcesWidget extends StatelessWidget {
  final RiskLevel riskLevel;
  final String? crisisMsg;
  final List<Map<String, dynamic>>? crisisNumbers;

  const CrisisResourcesWidget({
    super.key,
    required this.riskLevel,
    this.crisisMsg,
    this.crisisNumbers,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: _getBackgroundColor(context),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_rounded, color: _getIconColor(context)),
                const SizedBox(width: 8),
                Text(
                  _getTitle(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: _getIconColor(context),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Use geography-specific crisis message if available
            Text(
              crisisMsg ?? _getMessage(),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _getGeographySpecificResources().map((resource) {
                return ElevatedButton.icon(
                  onPressed: () => _launchUrl(context, resource.url, label: resource.label),
                  icon: Icon(resource.icon),
                  label: Text(resource.label),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _getButtonColor(context),
                    foregroundColor: _getButtonTextColor(context),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Color _getBackgroundColor(BuildContext context) {
    switch (riskLevel) {
      case RiskLevel.high:
        return Theme.of(context).colorScheme.errorContainer;
      case RiskLevel.medium:
        return Theme.of(context).colorScheme.secondaryContainer;
      case RiskLevel.low:
        return Theme.of(context).colorScheme.surfaceContainerHighest;
      default:
        return Theme.of(context).colorScheme.surface;
    }
  }

  Color _getIconColor(BuildContext context) {
    switch (riskLevel) {
      case RiskLevel.high:
        return Theme.of(context).colorScheme.error;
      case RiskLevel.medium:
        return Theme.of(context).colorScheme.secondary;
      case RiskLevel.low:
        return Theme.of(context).colorScheme.onSurfaceVariant;
      default:
        return Theme.of(context).colorScheme.onSurface;
    }
  }

  Color _getButtonColor(BuildContext context) {
    switch (riskLevel) {
      case RiskLevel.high:
        return Theme.of(context).colorScheme.error;
      case RiskLevel.medium:
        return Theme.of(context).colorScheme.secondary;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  Color _getButtonTextColor(BuildContext context) {
    switch (riskLevel) {
      case RiskLevel.high:
        return Theme.of(context).colorScheme.onError;
      case RiskLevel.medium:
        return Theme.of(context).colorScheme.onSecondary;
      default:
        return Theme.of(context).colorScheme.onPrimary;
    }
  }

  String _getTitle() {
    switch (riskLevel) {
      case RiskLevel.high:
        return 'Immediate Help Available';
      case RiskLevel.medium:
        return 'Support Resources';
      case RiskLevel.low:
        return 'Helpful Resources';
      default:
        return '';
    }
  }

  String _getMessage() {
    switch (riskLevel) {
      case RiskLevel.high:
        return 'If you\'re in crisis, please reach out. Help is available 24/7.';
      case RiskLevel.medium:
        return 'It sounds like you\'re going through a difficult time. These resources might help.';
      case RiskLevel.low:
        return 'Here are some resources that might be helpful.';
      default:
        return '';
    }
  }

  List<CrisisResource> _getGeographySpecificResources() {
    final resources = <CrisisResource>[];

    // Use geography-specific crisis numbers if available
    if (crisisNumbers != null && crisisNumbers!.isNotEmpty) {
      for (final number in crisisNumbers!) {
        final name = number['name'] as String? ?? 'Crisis Helpline';
        final phoneNumber = (number['number'] as String?) ?? (number['phone'] as String?);
        final textNumber = number['text'] as String?;
        final url = number['url'] as String?;

        if (phoneNumber != null) {
          resources.add(
            CrisisResource(
              label: name,
              url: 'tel:$phoneNumber',
              icon: Icons.phone,
            ),
          );
        } else if (textNumber != null) {
          resources.add(
            CrisisResource(label: name, url: 'sms:$textNumber', icon: Icons.message),
          );
        } else if (url != null) {
          resources.add(
            CrisisResource(label: name, url: url, icon: Icons.link),
          );
        }
      }
    }

    // Fallback to default resources if no geography-specific ones
    if (resources.isEmpty) {
      return _getResources();
    }

    return resources;
  }

  List<CrisisResource> _getResources() {
    final resources = <CrisisResource>[];

    // Add emergency resources for high risk
    if (riskLevel == RiskLevel.high) {
      resources.addAll([
        CrisisResource(label: 'Call 988', url: 'tel:988', icon: Icons.phone),
        CrisisResource(
          label: '988 Lifeline Chat',
          url: 'https://988lifeline.org/chat/',
          icon: Icons.chat,
        ),
      ]);
    }

    // Add general resources
    resources.addAll([
      CrisisResource(
        label: 'Crisis Text Line',
        url: 'sms:741741',
        icon: Icons.message,
      ),
      CrisisResource(
        label: 'Find a Therapist',
        url: 'https://www.psychologytoday.com/us/therapists',
        icon: Icons.person,
      ),
    ]);

    return resources;
  }

  Future<void> _launchUrl(BuildContext context, String url, {String? label}) async {
    final uri = Uri.parse(url);
    // Cache messenger to avoid using BuildContext across async gaps.
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final launched = await canLaunchUrl(uri) && await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (launched) return;
    } catch (_) {
      // Fall through to copy-to-clipboard
    }

    // Fallbacks by scheme, especially for web where tel:/sms: are unsupported
    if (uri.scheme == 'tel') {
      final number = uri.path; // after tel:
      await Clipboard.setData(ClipboardData(text: number));
      if (!kIsWeb) return; // On mobile, if we reach here copy is enough silently
      messenger?.showSnackBar(
        SnackBar(content: Text('Phone number copied: $number')),
      );
      return;
    }
    if (uri.scheme == 'sms') {
      final number = uri.path; // after sms:
      await Clipboard.setData(ClipboardData(text: number));
      if (!kIsWeb) return;
      final res = (label != null && label.isNotEmpty) ? ' for $label' : '';
      messenger?.showSnackBar(
        SnackBar(content: Text('SMS number$res copied: $number')),
      );
      return;
    }

    // Generic URL fallback: copy URL
    await Clipboard.setData(ClipboardData(text: url));
    if (kIsWeb) {
      messenger?.showSnackBar(
        SnackBar(content: Text('Link copied: $url')),
      );
    }
  }
}

class CrisisResource {
  final String label;
  final String url;
  final IconData icon;

  const CrisisResource({
    required this.label,
    required this.url,
    required this.icon,
  });
}
