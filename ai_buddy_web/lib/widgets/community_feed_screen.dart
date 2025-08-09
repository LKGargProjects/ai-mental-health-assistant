import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/progress_provider.dart';

class CommunityFeedScreen extends StatelessWidget {
  const CommunityFeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Community'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: Consumer<ProgressProvider>(
        builder: (context, progressProvider, child) {
          if (progressProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (progressProvider.error != null) {
            return Center(
              child: Text(
                progressProvider.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            );
          }

          // Placeholder posts
          final posts = [
            {
              'author': 'Alex',
              'content': 'Just wanted to share that I went for a walk today and it really helped clear my head. Sending positive vibes to you all!',
              'likes': 12,
            },
            {
              'author': 'Jordan',
              'content': 'Feeling a bit overwhelmed today, but trying to take it one step at a time. We got this!',
              'likes': 25,
            },
            {
              'author': 'Sam',
              'content': 'Remember to be kind to yourself today. You deserve it.',
              'likes': 42,
            },
          ];

          return ListView.builder(
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              return Card(
                margin: const EdgeInsets.all(8.0),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post['author'] as String,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8.0),
                      Text(post['content'] as String),
                      const SizedBox(height: 8.0),
                      Row(
                        children: [
                          Icon(Icons.favorite_border, size: 16.0),
                          const SizedBox(width: 4.0),
                          Text('${post['likes']}'),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
} 