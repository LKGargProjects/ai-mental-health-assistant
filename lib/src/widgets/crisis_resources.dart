import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class CrisisResources extends StatelessWidget {
  final List<Map<String, String>> resources;

  const CrisisResources({
    super.key,
    required this.resources,
  });

  Future<void> _launchUrl(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.emergency,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 8),
                Text(
                  'Crisis Resources',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...resources.map((resource) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  resource['name'] ?? '',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
                subtitle: Text(
                  resource['description'] ?? '',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onErrorContainer
                        .withOpacity(0.7),
                  ),
                ),
                trailing: resource['url'] != null
                    ? IconButton(
                        icon: const Icon(Icons.open_in_new),
                        onPressed: () => _launchUrl(resource['url']!),
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      )
                    : null,
              ),
            )),
          ],
        ),
      ),
    );
  }
} 