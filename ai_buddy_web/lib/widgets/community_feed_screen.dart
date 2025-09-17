import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/community_provider.dart';
import './app_back_button.dart';
import '../services/analytics_service.dart' show logAnalyticsEvent;

class CommunityFeedScreen extends StatefulWidget {
  const CommunityFeedScreen({super.key});

  @override
  State<CommunityFeedScreen> createState() => _CommunityFeedScreenState();
}

class _PinnedGuidelinesCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE0E6EE)),
      ),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Community Guidelines', style: TextStyle(fontWeight: FontWeight.w600)),
            SizedBox(height: 8),
            Text('• Be kind and respectful'),
            Text('• No personal info (we redact PII)'),
            Text('• If you see something worrying, report it'),
          ],
        ),
      ),
    );
  }
}

class _PinnedCrisisResourcesCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE0E6EE)),
      ),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Need help right now?', style: TextStyle(fontWeight: FontWeight.w600)),
            SizedBox(height: 8),
            Text('If you are in immediate danger or thinking about self-harm, please reach out to local emergency services or crisis hotlines.'),
          ],
        ),
      ),
    );
  }
}

class _CommunityFeedScreenState extends State<CommunityFeedScreen> {
  static const List<String> _topics = <String>[
    'All', 'Anxiety', 'Sleep', 'Mood', 'Grounding', 'Journaling', 'Routines', 'Gratitude'
  ];

  @override
  void initState() {
    super.initState();
    // Defer load to next microtask to avoid context issues
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<CommunityProvider>();
      provider.loadFeed();
      // Log feed view
      logAnalyticsEvent('community_feed_view', metadata: {
        'topic': 'All',
        'surface': 'community_tab',
        'ts': DateTime.now().millisecondsSinceEpoch,
      });
    });
  }

  void _onSelectTopic(String topic) {
    final selected = (topic == 'All') ? null : topic;
    context.read<CommunityProvider>().loadFeed(topic: selected);
    logAnalyticsEvent('community_feed_view', metadata: {
      'topic': topic,
      'surface': 'community_tab',
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> _showReportDialog({required int postId}) async {
    String reason = 'harm';
    final notesController = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 16, right: 16, top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Report post', style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 12),
              ...[
                {'key': 'harm', 'label': 'Harmful content'},
                {'key': 'pii', 'label': 'Personal information'},
                {'key': 'bullying', 'label': 'Bullying or harassment'},
                {'key': 'misinformation', 'label': 'Misinformation'},
                {'key': 'other', 'label': 'Other'},
              ].map((opt) => RadioListTile<String>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: opt['key']!,
                    groupValue: reason,
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => reason = v);
                      }
                    },
                    title: Text(opt['label']!),
                  )),
              const SizedBox(height: 8),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  border: OutlineInputBorder(),
                ),
                minLines: 2,
                maxLines: 4,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      await context.read<CommunityProvider>().report(
                            postId,
                            reason,
                            notes: notesController.text.trim().isEmpty
                                ? null
                                : notesController.text.trim(),
                          );
                      logAnalyticsEvent('community_report_submit', metadata: {
                        'post_id': postId,
                        'reason': reason,
                        'surface': 'community_tab',
                        'ts': DateTime.now().millisecondsSinceEpoch,
                      });
                      if (mounted) Navigator.pop(ctx);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Thanks for your report')), 
                      );
                    },
                    child: const Text('Submit'),
                  )
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Community'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 1,
        automaticallyImplyLeading: false,
        leading: Builder(
          builder: (ctx) {
            final canPop = Navigator.of(ctx).canPop();
            final route = ModalRoute.of(ctx);
            final isModal = route is PageRoute && route.fullscreenDialog == true;
            if (canPop) {
              return AppBackButton(isModal: isModal);
            }
            return const SizedBox.shrink();
          },
        ),
      ),
      body: Column(
        children: [
          // Topic filter chips
          SizedBox(
            height: 52,
            child: Consumer<CommunityProvider>(
              builder: (context, cp, _) {
                final sel = cp.selectedTopic ?? 'All';
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  scrollDirection: Axis.horizontal,
                  itemBuilder: (ctx, i) {
                    final t = _topics[i];
                    final bool active = (t == sel);
                    return ChoiceChip(
                      label: Text(t),
                      selected: active,
                      onSelected: (_) => _onSelectTopic(t),
                      selectedColor: color.primary.withOpacity(0.15),
                      labelStyle: TextStyle(
                        color: active ? color.primary : color.onSurface,
                      ),
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemCount: _topics.length,
                );
              },
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Consumer<CommunityProvider>(
              builder: (context, cp, _) {
                if (cp.isLoading && !cp.hasLoaded) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (cp.error != null) {
                  return Center(
                    child: Text(cp.error!, style: TextStyle(color: color.error)),
                  );
                }
                if (cp.posts.isEmpty) {
                  return const Center(
                    child: Text('No posts yet. Gentle reflections will appear here.'),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    await cp.loadFeed(topic: cp.selectedTopic);
                    logAnalyticsEvent('community_feed_refresh', metadata: {
                      'topic': cp.selectedTopic ?? 'All',
                      'surface': 'community_tab',
                      'ts': DateTime.now().millisecondsSinceEpoch,
                    });
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 16),
                    itemCount: cp.posts.length + 2, // +2 pinned cards
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _PinnedGuidelinesCard();
                      }
                      if (index == 1) {
                        return _PinnedCrisisResourcesCard();
                      }
                      final p = cp.posts[index - 2];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: const Color(0xFFE0E6EE)),
                        ),
                        elevation: 0,
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: color.primary.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(p.topic, style: TextStyle(color: color.primary, fontSize: 12)),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    tooltip: 'Report',
                                    icon: const Icon(Icons.flag_outlined, size: 20),
                                    onPressed: () => _showReportDialog(postId: p.id),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(p.body),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  _ReactionChip(
                                    icon: Icons.favorite_border,
                                    label: 'I relate',
                                    count: p.relate,
                                    onTap: () {
                                      context.read<CommunityProvider>().react(p.id, 'relate');
                                      logAnalyticsEvent('community_reaction_add', metadata: {
                                        'post_id': p.id,
                                        'kind': 'relate',
                                        'topic': p.topic,
                                        'surface': 'community_tab',
                                        'ts': DateTime.now().millisecondsSinceEpoch,
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  _ReactionChip(
                                    icon: Icons.thumb_up_outlined,
                                    label: 'This helped',
                                    count: p.helped,
                                    onTap: () {
                                      context.read<CommunityProvider>().react(p.id, 'helped');
                                      logAnalyticsEvent('community_reaction_add', metadata: {
                                        'post_id': p.id,
                                        'kind': 'helped',
                                        'topic': p.topic,
                                        'surface': 'community_tab',
                                        'ts': DateTime.now().millisecondsSinceEpoch,
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  _ReactionChip(
                                    icon: Icons.favorite_outline,
                                    label: 'Strength',
                                    count: p.strength,
                                    onTap: () {
                                      context.read<CommunityProvider>().react(p.id, 'strength');
                                      logAnalyticsEvent('community_reaction_add', metadata: {
                                        'post_id': p.id,
                                        'kind': 'strength',
                                        'topic': p.topic,
                                        'surface': 'community_tab',
                                        'ts': DateTime.now().millisecondsSinceEpoch,
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ReactionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final VoidCallback onTap;

  const _ReactionChip({
    required this.icon,
    required this.label,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.primary.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE0E6EE)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color.primary),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color.primary)),
            const SizedBox(width: 6),
            Text('$count', style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
 