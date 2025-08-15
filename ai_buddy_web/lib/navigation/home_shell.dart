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
  // Per-tab navigator keys
  final _talkNavKey = GlobalKey<NavigatorState>();
  final _moodNavKey = GlobalKey<NavigatorState>();
  final _questNavKey = GlobalKey<NavigatorState>();
  final _communityNavKey = GlobalKey<NavigatorState>();

  // Reselect notifiers to trigger screen-specific actions
  final ValueNotifier<int> _talkReselect = ValueNotifier<int>(0);
  final ValueNotifier<int> _moodReselect = ValueNotifier<int>(0);
  final ValueNotifier<int> _questReselect = ValueNotifier<int>(0);

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

  NavigatorState? _navFor(AppTab tab) {
    switch (tab) {
      case AppTab.talk:
        return _talkNavKey.currentState;
      case AppTab.mood:
        return _moodNavKey.currentState;
      case AppTab.quest:
        return _questNavKey.currentState;
      case AppTab.community:
        return _communityNavKey.currentState;
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget _buildTabNavigator({
      required GlobalKey<NavigatorState> key,
      required WidgetBuilder builder,
      required bool active,
    }) {
      return HeroMode(
        enabled: active,
        child: Navigator(
          key: key,
          onGenerateRoute: (settings) => MaterialPageRoute(builder: builder),
        ),
      );
    }

    final pages = <Widget>[
      _buildTabNavigator(
        key: _talkNavKey,
        active: _index == 0,
        builder: (_) => InteractiveChatScreen(showBottomNav: false, reselect: _talkReselect),
      ),
      _buildTabNavigator(
        key: _moodNavKey,
        active: _index == 1,
        builder: (_) => MoodTrackerScreen(showBottomNav: false, reselect: _moodReselect),
      ),
      _buildTabNavigator(
        key: _questNavKey,
        active: _index == 2,
        builder: (_) => DhiwiseSizer.Sizer(
          builder: (context, o, d) => DhiwiseWellness.WellnessDashboardScreen(showBottomNav: false, reselect: _questReselect),
        ),
      ),
      _buildTabNavigator(
        key: _communityNavKey,
        active: _index == 3,
        builder: (_) => const _CommunityComingSoon(),
      ),
    ];

    final nav = _navFor(_current);
    final isKeyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return PopScope(
      // Allow system back only when keyboard is closed and current tab stack cannot pop
      canPop: !(isKeyboardOpen || (nav?.canPop() ?? false)),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          if (isKeyboardOpen) {
            FocusScope.of(context).unfocus();
            return;
          }
          if (nav?.canPop() ?? false) {
            nav!.pop();
            return;
          }
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: pages,
        ),
        bottomNavigationBar: AppBottomNav(
          current: _current,
          onTap: (tab) => setState(() => _current = tab),
          onReselect: (tab) {
            // Pop to root of the tab, then trigger reselect action
            final nav = _navFor(tab);
            nav?.popUntil((route) => route.isFirst);
            switch (tab) {
              case AppTab.talk:
                _talkReselect.value++;
                break;
              case AppTab.mood:
                _moodReselect.value++;
                break;
              case AppTab.quest:
                _questReselect.value++;
                break;
              case AppTab.community:
                break;
            }
          },
        ),
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
