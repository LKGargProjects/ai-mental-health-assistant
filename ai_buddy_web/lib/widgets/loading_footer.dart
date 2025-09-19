import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/community_provider.dart';

/// A loading footer widget that shows loading, error, or no more content states.
class LoadingFooter extends StatelessWidget {
  const LoadingFooter({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<CommunityProvider>(
      builder: (context, cp, _) {
        if (cp.loadMoreError) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Failed to load more posts',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: cp.fetchMore,
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        
        if (!cp.hasMore) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24.0),
            child: Center(
              child: Text(
                'No more posts to show',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
            ),
          );
        }
        
        return const Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      },
    );
  }
}
