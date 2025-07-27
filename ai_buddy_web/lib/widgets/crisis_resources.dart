import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/message.dart';

class CrisisResourcesWidget extends StatelessWidget {
  final RiskLevel riskLevel;

  const CrisisResourcesWidget({
    super.key,
    required this.riskLevel,
  });

  @override
  Widget build(BuildContext context) {
    if (riskLevel == RiskLevel.none) return const SizedBox.shrink();

    return Card(
      color: _getBackgroundColor(context),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.warning_rounded,
                  color: _getIconColor(context),
                ),
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
            Text(
              _getMessage(),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _getResources().map((resource) {
                return ElevatedButton.icon(
                  onPressed: () => _launchUrl(resource.url),
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
        return Theme.of(context).colorScheme.surfaceVariant;
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

  List<CrisisResource> _getResources() {
    final resources = <CrisisResource>[];

    // Add emergency resources for high risk
    if (riskLevel == RiskLevel.high) {
      resources.addAll([
        CrisisResource(
          label: 'Call 988',
          url: 'tel:988',
          icon: Icons.phone,
        ),
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

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
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