import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import '../widgets/app_bottom_nav.dart';
import '../screens/interactive_chat_screen.dart';
import '../screens/mood_tracker_screen.dart';
import 'package:ai_buddy_web/dhiwise/presentation/wellness_dashboard_screen/wellness_dashboard_screen.dart';

import '../widgets/crisis_resources.dart';
import '../models/message.dart';
import '../widgets/safety_legal_sheet.dart';
import '../widgets/help_entrypoint.dart';
// Removed Provider dependency for Help overlay risk plumbing

// Global deep-link controller for switching HomeShell tabs from anywhere
// e.g., when handling a notification tap.
final ValueNotifier<AppTab> homeTabDeepLink = ValueNotifier<AppTab>(AppTab.talk);

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
    _onDeepLinkTab(); // Process any pre-set deep-link tab value on startup
    // Listen for deep-link tab change requests
    homeTabDeepLink.addListener(_onDeepLinkTab);
  }

  void _onDeepLinkTab() {
    final target = homeTabDeepLink.value;
    if (kDebugMode) {
      try { debugPrint('[HomeShell] deepLink request -> $target (current=$_current)'); } catch (_) {}
    }
    if (_current != target) {
      setState(() => _current = target);
      if (kDebugMode) {
        try { debugPrint('[HomeShell] switched to $target'); } catch (_) {}
      }
    } else {
      // If already on the tab, pop to its root and trigger reselect behavior
      final nav = _navFor(target);
      nav?.popUntil((route) => route.isFirst);
      switch (target) {
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
    }
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
  
  Future<void> _showHelpSheet() async {
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
              top: 12.0,
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
                          'Need help now?',
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
                  const SizedBox(height: 8),
                  Text(
                    'If you are in immediate danger, call your local emergency number.',
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54),
                  ),
                  const SizedBox(height: 12),
                  const CrisisResourcesWidget(riskLevel: RiskLevel.high),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () async {
                        Navigator.of(ctx).maybePop();
                        await Future.delayed(Duration.zero);
                        if (!mounted) return;
                        await showSafetyLegalSheet(context);
                      },
                      icon: const Icon(Icons.gavel_outlined),
                      label: const Text('Safety & Legal'),
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

  @override
  Widget build(BuildContext context) {
    // Help overlay no longer depends on chat risk; static and shown only on Community tab
    Widget buildTabNavigator({
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
      buildTabNavigator(
        key: _talkNavKey,
        active: _index == 0,
        builder: (_) => InteractiveChatScreen(
          showBottomNav: false,
          reselect: _talkReselect,
        ),
      ),
      buildTabNavigator(
        key: _moodNavKey,
        active: _index == 1,
        builder: (_) =>
            MoodTrackerScreen(showBottomNav: false, reselect: _moodReselect),
      ),
      buildTabNavigator(
        key: _questNavKey,
        active: _index == 2,
        builder: (_) => WellnessDashboardScreen(
          showBottomNav: false,
          reselect: _questReselect,
        ),
      ),
      buildTabNavigator(
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
        body: Stack(
          children: [
            IndexedStack(index: _index, children: pages),
            // Show Help entrypoint only on the Community tab
            if (_current == AppTab.community)
              HelpEntrypointOverlay(onPressed: _showHelpSheet),
          ],
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

  @override
  void dispose() {
    homeTabDeepLink.removeListener(_onDeepLinkTab);
    super.dispose();
  }

}

class _CommunityComingSoon extends StatelessWidget {
  const _CommunityComingSoon();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Community coming soon!'));
  }
}
