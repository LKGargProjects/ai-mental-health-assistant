import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/community_provider.dart';
import './app_back_button.dart';
import '../services/analytics_service.dart' show logAnalyticsEvent;
import '../core/utils/size_utils.dart';
import '../theme/theme_helper.dart';
import '../theme/text_style_helper.dart';

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
  // Full topic set (used by picker)
  static const List<String> _topicsFull = <String>[
    'All', 'Anxiety', 'Sleep', 'Mood', 'Grounding', 'Journaling', 'Routines', 'Gratitude'
  ];

  final Set<int> _expandedPosts = <int>{};

  void _toggleExpanded(int id) {
    setState(() {
      if (_expandedPosts.contains(id)) {
        _expandedPosts.remove(id);
      } else {
        _expandedPosts.add(id);
      }
    });
  }

  String _relativeTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    final weeks = (diff.inDays / 7).floor();
    if (weeks < 4) return '${weeks}w ago';
    final months = (diff.inDays / 30).floor();
    return '${months}mo ago';
  }

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

  Future<void> _showTopicPicker() async {
    final picked = await showModalBottomSheet<String>(
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
              left: 16.h,
              right: 16.h,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16.h,
              top: 12.h,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Choose a topic', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                ..._topicsFull.map((t) => ListTile(
                      dense: true,
                      title: Text(t),
                      onTap: () => Navigator.of(ctx).pop(t),
                    )),
              ],
            ),
          ),
        );
      },
    );
    if (picked != null) {
      _onSelectTopic(picked);
    }
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
      body: Column(
        children: [
          // Header (matches other tabs)
          Container(
            color: appTheme.whiteCustom,
            padding: EdgeInsets.symmetric(horizontal: 16.h, vertical: 16.h),
            child: SafeArea(
              top: true,
              bottom: false,
              child: Row(
                children: [
                  Builder(
                    builder: (ctx) {
                      final canPop = Navigator.of(ctx).canPop();
                      final route = ModalRoute.of(ctx);
                      final isModal = route is PageRoute && route.fullscreenDialog == true;
                      if (canPop) {
                        return AppBackButton(isModal: isModal);
                      }
                      return SizedBox(width: 44.h); // balance left when no back
                    },
                  ),
                  Expanded(
                    child: Text(
                      'Community',
                      textAlign: TextAlign.center,
                      style: TextStyleHelper.instance.headline24Bold,
                    ),
                  ),
                  SizedBox(width: 44.h), // balance right
                ],
              ),
            ),
          ),
          // Divider under header
          Container(height: 8.h, color: appTheme.colorFFF3F4),
          // Topic filter chips (compact with 'More')
          SizedBox(
            height: 52,
            child: Consumer<CommunityProvider>(
              builder: (context, cp, _) {
                final sel = cp.selectedTopic ?? 'All';
                const visibleTopics = <String>['All', 'Anxiety', 'Sleep', 'Mood', 'Grounding', 'More'];
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  scrollDirection: Axis.horizontal,
                  itemBuilder: (ctx, i) {
                    final t = visibleTopics[i];
                    if (t == 'More') {
                      return ChoiceChip(
                        label: const Text('More'),
                        selected: false,
                        onSelected: (_) => _showTopicPicker(),
                        selectedColor: color.primary.withOpacity(0.12),
                        labelStyle: TextStyle(color: color.onSurface),
                      );
                    }
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
                  itemCount: visibleTopics.length,
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
                                  Row(
                                    children: [
                                      Container(
                                        width: 8, height: 8,
                                        decoration: BoxDecoration(color: color.primary, shape: BoxShape.circle),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(p.topic, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                      if (p.createdAt != null) ...[
                                        const SizedBox(width: 8),
                                        Text(
                                          '•  ' + _relativeTime(p.createdAt!),
                                          style: const TextStyle(fontSize: 11, color: Colors.black54),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const Spacer(),
                                  PopupMenuButton<String>(
                                    tooltip: 'More',
                                    icon: const Icon(Icons.more_horiz, size: 20, color: Colors.black54),
                                    onSelected: (v) {
                                      if (v == 'report') _showReportDialog(postId: p.id);
                                    },
                                    itemBuilder: (ctx) => const [
                                      PopupMenuItem<String>(value: 'report', child: Text('Report')),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Builder(builder: (_) {
                                final expanded = _expandedPosts.contains(p.id);
                                final shouldTruncate = p.body.length > 180;
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.body,
                                      maxLines: expanded ? null : 4,
                                      overflow: expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                                    ),
                                    if (shouldTruncate)
                                      TextButton(
                                        style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
                                        onPressed: () => _toggleExpanded(p.id),
                                        child: Text(expanded ? 'Show less' : 'Read more'),
                                      ),
                                  ],
                                );
                              }),
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
                                  PopupMenuButton<String>(
                                    tooltip: 'More actions',
                                    icon: const Icon(Icons.more_horiz, size: 20, color: Colors.black54),
                                    onSelected: (v) {
                                      switch (v) {
                                        case 'helped':
                                          context.read<CommunityProvider>().react(p.id, 'helped');
                                          logAnalyticsEvent('community_reaction_add', metadata: {
                                            'post_id': p.id,
                                            'kind': 'helped',
                                            'topic': p.topic,
                                            'surface': 'community_tab',
                                            'ts': DateTime.now().millisecondsSinceEpoch,
                                          });
                                          break;
                                        case 'strength':
                                          context.read<CommunityProvider>().react(p.id, 'strength');
                                          logAnalyticsEvent('community_reaction_add', metadata: {
                                            'post_id': p.id,
                                            'kind': 'strength',
                                            'topic': p.topic,
                                            'surface': 'community_tab',
                                            'ts': DateTime.now().millisecondsSinceEpoch,
                                          });
                                          break;
                                      }
                                    },
                                    itemBuilder: (ctx) => const [
                                      PopupMenuItem<String>(value: 'helped', child: Text('This helped')),
                                      PopupMenuItem<String>(value: 'strength', child: Text('Strength')),
                                    ],
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
          color: color.primary.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE0E6EE)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color.primary),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color.primary)),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Text('$count', style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ],
        ),
      ),
    );
  }
}
 