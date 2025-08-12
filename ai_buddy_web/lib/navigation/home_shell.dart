import 'package:flutter/material.dart';
import '../widgets/app_bottom_nav.dart';
import '../screens/interactive_chat_screen.dart';
import '../screens/mood_tracker_screen.dart';
import '../dhiwise/presentation/wellness_dashboard_screen/wellness_dashboard_screen.dart' as DhiwiseWellness;
import '../dhiwise/core/utils/size_utils.dart' as DhiwiseSizer;

class HomeShell extends StatefulWidget {
  final AppTab initialTab;
  const HomeShell({super.key, this.initialTab = AppTab.talk});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late AppTab _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialTab;
  }

  int get _index {
    switch (_current) {
      case AppTab.talk:
        return 0;
      case AppTab.mood:
        return 1;
      case AppTab.quest:
        return 2;
      case AppTab.community:
        return 3;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Children are kept alive; no route animations on tab change.
    final pages = <Widget>[
      const InteractiveChatScreen(showBottomNav: false),
      const MoodTrackerScreen(showBottomNav: false),
      DhiwiseSizer.Sizer(
        builder: (context, o, d) => DhiwiseWellness.WellnessDashboardScreen(showBottomNav: false),
      ),
      const _CommunityComingSoon(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: pages,
      ),
      bottomNavigationBar: AppBottomNav(
        current: _current,
        onTap: (tab) => setState(() => _current = tab),
      ),
    );
  }
}

class _CommunityComingSoon extends StatelessWidget {
  const _CommunityComingSoon();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Community coming soon!'),
    );
  }
}
